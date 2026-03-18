import Foundation
import Supabase

// MARK: - AuthDestination

enum AuthDestination: Equatable {
    case fleetManagerDashboard
    case changePassword
    case driverOnboarding
    case maintenanceOnboarding
    case pendingApproval
    case rejected
    case driverDashboard
    case maintenanceDashboard
}

// MARK: - StaffLoginRow  (decoded from sign-in edge function response)

private struct StaffLoginRow: Decodable {
    let id: String
    let email: String
    let role: String
    let name: String?
    let phone: String?
    let is_first_login: Bool?
    let is_profile_complete: Bool?
    let is_approved: Bool?
    let rejection_reason: String?
    let created_at: String?
}

// MARK: - SignInPayload

private struct SignInPayload: Encodable {
    let email: String
    let password: String
}

// MARK: - AuthManager

@MainActor
@Observable
final class AuthManager {

    static let shared = AuthManager()

    private enum Keys {
        static let currentUser       = "com.fleetOS.currentUser"
        static let backgroundTS      = "com.fleetOS.backgroundTimestamp"
        static let sessionToken      = "com.fleetOS.sessionToken"
        static let hashedCred        = "com.fleetOS.hashedCredential"
        static let biometricOn       = "com.fleetOS.biometricEnabled"
        static let biometricPrompted = "com.fleetOS.hasPromptedBiometric"
    }

    // MARK: - State

    var currentUser: AuthUser?
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false
    private var currentOTP: String = ""
    var pendingOTPEmail: String?
    private var resetOTP: String = ""
    private let autoLockSeconds: TimeInterval = 300
    /// Cooldown to prevent 2FA OTP spam (30 s window)
    private var otpLastSentAt: Date?
    /// Cooldown to prevent reset OTP spam (30 s window)
    private var resetOTPLastSentAt: Date?
    private let otpCooldownSeconds: TimeInterval = 30

    private init() { restoreSessionSilently() }

    // MARK: - Sign In
    //
    // Two-step login:
    //   1. Call the `sign-in` edge function (verify_jwt: false, service-role on server).
    //      - Verifies email+password against staff_members.password, bypassing RLS.
    //      - Syncs the Supabase Auth password so step 2 always succeeds, even for
    //        users whose password was previously changed only in staff_members.
    //   2. Call supabase.auth.signInWithPassword() so auth.uid() is set for RLS.

    func signIn(email: String, password: String) async throws -> UserRole {
        // Reset OTP cooldown for each fresh login attempt.
        otpLastSentAt = nil

        // Step 1 — Verify credentials + sync Auth password via edge function
        let row: StaffLoginRow
        do {
            row = try await supabase.functions.invoke(
                "sign-in",
                options: FunctionInvokeOptions(body: SignInPayload(email: email, password: password))
            )
        } catch {
            throw AuthError.invalidCredentials
        }

        guard let userId = UUID(uuidString: row.id) else {
            throw AuthError.invalidCredentials
        }

        // Step 2 — Establish a real Supabase Auth session so auth.uid() != null.
        // The edge function already synced the Auth password, so this succeeds
        // even for users who previously changed their password (fixing drift).
        do {
            try await supabase.auth.signInWithPassword(
                email: email,
                password: password
            )
        } catch {
            throw AuthError.invalidCredentials
        }

        let user = AuthUser(
            id: userId,
            email: row.email,
            role: UserRole(rawValue: row.role) ?? .driver,
            isFirstLogin: row.is_first_login ?? true,
            isProfileComplete: row.is_profile_complete ?? false,
            isApproved: row.is_approved ?? false,
            name: row.name,
            rejectionReason: row.rejection_reason,
            phone: row.phone,
            createdAt: ISO8601DateFormatter().date(from: row.created_at ?? "") ?? Date()
        )

        let hashed = CryptoService.hash(password: password)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        currentUser = user
        pendingOTPEmail = user.email
        // NOTE: Do NOT set isAuthenticated here — 2FA must complete first
        return user.role
    }

    // MARK: - Complete Authentication
    // Called after 2FA succeeds (or for first-login bypass).
    // Triggers role-specific AppDataStore load so dashboards have data immediately.

    func completeAuthentication() {
        isAuthenticated = true
        saveSessionToken()
        guard let user = currentUser else { return }
        Task {
            switch user.role {
            case .fleetManager:
                await AppDataStore.shared.loadAll()
            case .driver:
                await AppDataStore.shared.loadDriverData(driverId: user.id)
            case .maintenancePersonnel:
                await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
            }
        }
    }

    func saveSessionToken() {
        let token = UUID().uuidString
        if let data = token.data(using: .utf8) {
            _ = KeychainService.save(data, forKey: Keys.sessionToken)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        currentUser = nil
        isAuthenticated = false
        needsReauth = false
        pendingOTPEmail = nil
        otpLastSentAt = nil
        resetOTPLastSentAt = nil
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCred)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
        KeychainService.delete(key: Keys.biometricOn)
        KeychainService.delete(key: Keys.biometricPrompted)
        // Invalidate the Supabase Auth session server-side
        Task { try? await supabase.auth.signOut() }
    }

    // MARK: - Session Restore

    @discardableResult
    func restoreSession() -> UserRole? {
        guard hasSessionToken(),
              let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) else { return nil }
        currentUser = user
        isAuthenticated = true
        Task {
            switch user.role {
            case .fleetManager:
                await AppDataStore.shared.loadAll()
            case .driver:
                await AppDataStore.shared.loadDriverData(driverId: user.id)
            case .maintenancePersonnel:
                await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
            }
        }
        return user.role
    }

    func hasSessionToken() -> Bool {
        KeychainService.load(key: Keys.sessionToken) != nil
    }

    private func restoreSessionSilently() {
        if let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) {
            currentUser = user
        }
    }

    // MARK: - Routing

    func destination(for user: AuthUser) -> AuthDestination {
        switch user.role {
        case .fleetManager:
            return .fleetManagerDashboard

        case .driver:
            if user.isFirstLogin        { return .changePassword }
            if !user.isProfileComplete  { return .driverOnboarding }
            if !user.isApproved {
                if let reason = user.rejectionReason, !reason.isEmpty { return .rejected }
                return .pendingApproval
            }
            return .driverDashboard

        case .maintenancePersonnel:
            if user.isFirstLogin        { return .changePassword }
            if !user.isProfileComplete  { return .maintenanceOnboarding }
            if !user.isApproved {
                if let reason = user.rejectionReason, !reason.isEmpty { return .rejected }
                return .pendingApproval
            }
            return .maintenanceDashboard
        }
    }

    // MARK: - Masked Email

    var maskedEmail: String {
        let email = pendingOTPEmail ?? currentUser?.email ?? ""
        guard !email.isEmpty, let atRange = email.range(of: "@") else { return "***@***.com" }
        return "\(email.prefix(1))***\(email[atRange.lowerBound...])"
    }

    // MARK: - OTP helpers

    @discardableResult
    func generateOTP() -> String {
        if let last = otpLastSentAt, Date().timeIntervalSince(last) < otpCooldownSeconds {
            print("[AuthManager] generateOTP skipped - cooldown active (\(Int(otpCooldownSeconds - Date().timeIntervalSince(last)))s remaining)")
            return currentOTP
        }
        let otp = String(format: "%06d", Int.random(in: 100000...999999))
        currentOTP = otp
        otpLastSentAt = Date()
        pendingOTPEmail = currentUser?.email
        #if DEBUG
        print("🔑 [AuthManager.generateOTP] OTP = \(otp) → \(pendingOTPEmail ?? "no email")")
        #endif
        if let email = pendingOTPEmail {
            EmailService.sendLoginOTP(to: email, otp: otp)
        }
        return otp
    }

    func verifyOTP(_ code: String) -> Bool {
        let match = code == currentOTP
        if match { currentOTP = "" }
        return match
    }

    func verifyResetOTP(_ code: String) -> Bool {
        return code == resetOTP
    }

    // MARK: - Password Management
    //
    // IMPORTANT: Every password change must update BOTH:
    //   a) staff_members.password  — used by the sign-in edge function for verification
    //   b) Supabase Auth           — used by supabase.auth.signInWithPassword for sessions
    // Skipping (b) causes RLS failures on the next login after a password change.

    func updatePasswordAndFirstLogin(newPassword: String) async throws {
        guard var user = currentUser else { throw AuthError.invalidCredentials }

        struct Payload: Encodable {
            let password: String
            let is_first_login: Bool
        }

        // (a) Update staff_members table
        try await supabase
            .from("staff_members")
            .update(Payload(password: newPassword, is_first_login: false))
            .eq("id", value: user.id.uuidString)
            .execute()

        // (b) Keep Supabase Auth in sync so the next signInWithPassword succeeds
        try await supabase.auth.update(user: UserAttributes(password: newPassword))

        user.isFirstLogin = false
        currentUser = user
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        let hashed = CryptoService.hash(password: newPassword)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await updatePasswordAndFirstLogin(newPassword: newPassword)
    }

    func markProfileComplete() async throws {
        guard let user = currentUser else { return }
        struct ProfilePayload: Encodable { let is_profile_complete: Bool }
        try await supabase
            .from("staff_members")
            .update(ProfilePayload(is_profile_complete: true))
            .eq("id", value: user.id.uuidString)
            .execute()
        var updated = user
        updated.isProfileComplete = true
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    func markPasswordChanged() async throws {
        guard let user = currentUser else { return }
        struct FirstLoginPayload: Encodable { let is_first_login: Bool }
        try await supabase
            .from("staff_members")
            .update(FirstLoginPayload(is_first_login: false))
            .eq("id", value: user.id.uuidString)
            .execute()
        var updated = user
        updated.isFirstLogin = false
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    func refreshCurrentUser() async throws {
        guard let userId = currentUser?.id else { return }
        struct RoleRow: Decodable {
            let role: String; let name: String?; let isFirstLogin: Bool
            let isProfileComplete: Bool; let isApproved: Bool
            let rejectionReason: String?; let phone: String?; let createdAt: Date?
            enum CodingKeys: String, CodingKey {
                case role, name, phone
                case isFirstLogin      = "is_first_login"
                case isProfileComplete = "is_profile_complete"
                case isApproved        = "is_approved"
                case rejectionReason   = "rejection_reason"
                case createdAt         = "created_at"
            }
        }
        let rows: [RoleRow] = try await supabase
            .from("staff_members")
            .select("role, name, is_first_login, is_profile_complete, is_approved, rejection_reason, phone, created_at")
            .eq("id", value: userId.uuidString)
            .limit(1).execute().value
        guard let row = rows.first, let current = currentUser else { return }
        var updated = current
        updated.isApproved        = row.isApproved
        updated.isProfileComplete = row.isProfileComplete
        updated.isFirstLogin      = row.isFirstLogin
        updated.rejectionReason   = row.rejectionReason
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    // MARK: - Password Reset

    func requestPasswordReset(email: String) async -> Bool {
        if let last = resetOTPLastSentAt, Date().timeIntervalSince(last) < otpCooldownSeconds {
            print("[AuthManager] requestPasswordReset skipped - cooldown active")
            return true
        }
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase
                .from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value

            guard !rows.isEmpty else { return false }

            pendingOTPEmail = email
            let otp = String(format: "%06d", Int.random(in: 100000...999999))
            resetOTP = otp
            resetOTPLastSentAt = Date()
            EmailService.sendResetOTP(to: email, otp: otp)
            return true
        } catch {
            return false
        }
    }

    func resetPassword(code: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard code == resetOTP else { throw AuthError.invalidCredentials }
        guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }

        // (a) Update staff_members.password
        try await supabase
            .from("staff_members")
            .update(["password": newPassword])
            .eq("email", value: email)
            .execute()

        // (b) Supabase Auth sync — the sign-in edge function re-syncs on the next
        //     signIn() call, so the user can log in immediately with the new password.
        //     (No active session here so supabase.auth.update is not available.)
        let hashed = CryptoService.hash(password: newPassword)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCred)

        resetOTP = ""
        pendingOTPEmail = nil
    }

    // MARK: - Email Existence Check

    func emailExists(_ email: String) async -> Bool {
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase
                .from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value
            return !rows.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Auto-Lock

    func appDidEnterBackground() {
        let ts = "\(Date().timeIntervalSince1970)"
        if let data = ts.data(using: .utf8) {
            _ = KeychainService.save(data, forKey: Keys.backgroundTS)
        }
    }

    func appWillEnterForeground() {
        guard isAuthenticated else { return }
        guard let data = KeychainService.load(key: Keys.backgroundTS),
              let str  = String(data: data, encoding: .utf8),
              let ts   = TimeInterval(str) else { return }
        if Date().timeIntervalSince1970 - ts > autoLockSeconds { needsReauth = true }
    }

    func reauthCompleted() { needsReauth = false }
}

// MARK: - AuthError

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case userNotFound
    case biometricFailed
    case sessionExpired
    case createStaffFailed
    case accountSuspended
    case otpExpired
    case otpInvalid
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:  return "Invalid email or password."
        case .userNotFound:        return "Account not found. Contact your fleet administrator."
        case .biometricFailed:     return "Biometric authentication failed."
        case .sessionExpired:      return "Your session has expired. Please sign in again."
        case .createStaffFailed:   return "Failed to create staff account. Please try again."
        case .accountSuspended:    return "Your account has been suspended. Contact your fleet manager."
        case .otpExpired:          return "The verification code has expired. Please request a new one."
        case .otpInvalid:          return "Incorrect verification code. Please check and try again."
        case .networkError(let d): return "Connection error: \(d)"
        }
    }
}
