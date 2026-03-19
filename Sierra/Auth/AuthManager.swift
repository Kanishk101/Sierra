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
        // NOTE: biometricPrompted is intentionally NOT deleted on signOut.
        // It is only cleared on fresh install (SierraApp.init) so the enrollment
        // sheet never re-appears just because the user logged out and back in.
        // Clearing it on signOut caused an annoying re-prompt on every login.
        static let biometricPrompted = "com.fleetOS.hasPromptedBiometric"
    }

    // MARK: - State

    var currentUser: AuthUser?
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false
    private var currentOTP: String = ""
    var pendingOTPEmail: String?
    private var pendingResetToken: String = ""
    private var resetOTP: String = ""
    private let autoLockSeconds: TimeInterval = 300
    private var otpLastSentAt: Date?
    private var resetOTPLastSentAt: Date?
    private let otpCooldownSeconds: TimeInterval = 30

    private init() { restoreSessionSilently() }

    // MARK: - Sign In
    //
    // Two-step login:
    //   1. supabase.auth.signIn(email:password:) — Supabase Auth validates
    //      credentials server-side (bcrypt). Sets auth.uid() so RLS works.
    //   2. 150 ms sleep — ensures the JWT is fully propagated before the
    //      edge function's anonClient.auth.getUser() call resolves it.
    //      Without this, a fast network can trigger a race where getUser()
    //      returns null and the function throws 401 → invalidCredentials.
    //   3. sign-in edge function (verify_jwt: true) — fetches staff profile.

    func signIn(email: String, password: String) async throws -> UserRole {
        otpLastSentAt = nil

        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            throw AuthError.invalidCredentials
        }

        // Allow JWT to propagate before calling the edge function
        try await Task.sleep(for: .milliseconds(150))

        struct StaffProfile: Decodable {
            let id: String
            let email: String
            let name: String?
            let role: String
            let is_first_login: Bool?
            let is_profile_complete: Bool?
            let is_approved: Bool?
            let rejection_reason: String?
            let phone: String?
            let created_at: String?
        }

        let profile: StaffProfile
        do {
            profile = try await supabase.functions.invoke(
                "sign-in",
                options: FunctionInvokeOptions()
            )
        } catch {
            try? await supabase.auth.signOut()
            throw AuthError.invalidCredentials
        }

        guard let userId = UUID(uuidString: profile.id) else {
            try? await supabase.auth.signOut()
            throw AuthError.invalidCredentials
        }

        let user = AuthUser(
            id: userId,
            email: profile.email,
            role: UserRole(rawValue: profile.role) ?? .driver,
            isFirstLogin: profile.is_first_login ?? true,
            isProfileComplete: profile.is_profile_complete ?? false,
            isApproved: profile.is_approved ?? false,
            name: profile.name,
            rejectionReason: profile.rejection_reason,
            phone: profile.phone,
            createdAt: ISO8601DateFormatter().date(from: profile.created_at ?? "") ?? Date()
        )

        let hashed = CryptoService.hash(password: password)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        currentUser = user
        pendingOTPEmail = user.email
        return user.role
    }

    // MARK: - Complete Authentication

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
        pendingResetToken = ""
        otpLastSentAt = nil
        resetOTPLastSentAt = nil
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCred)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
        // biometricEnabled is cleared on signOut so the Face ID login button
        // correctly disappears after logout — the user must explicitly re-enable
        // it on their next login via the enrollment sheet.
        KeychainService.delete(key: Keys.biometricOn)
        // biometricPrompted is intentionally NOT deleted here — see Keys comment.
        // Deleting it caused the enrollment sheet to re-appear on every login,
        // even if the user had already declined or enabled biometric. It is
        // cleared on fresh install in SierraApp.init() instead.
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
            do {
                _ = try await supabase.auth.session
            } catch {
                await MainActor.run { self.signOut() }
            }
        }
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
        Task { _ = try? await supabase.auth.session }
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

    func updatePasswordAndFirstLogin(newPassword: String) async throws {
        guard var user = currentUser else { throw AuthError.invalidCredentials }

        struct Payload: Encodable { let is_first_login: Bool }

        try await supabase
            .from("staff_members")
            .update(Payload(is_first_login: false))
            .eq("id", value: user.id.uuidString)
            .execute()

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
        pendingResetToken = ""
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase
                .from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value

            guard let userRow = rows.first else { return false }

            pendingOTPEmail = email

            let otp = String(format: "%06d", Int.random(in: 100000...999999))
            resetOTP = otp
            resetOTPLastSentAt = Date()
            EmailService.sendResetOTP(to: email, otp: otp)

            let resetToken = UUID().uuidString
            pendingResetToken = resetToken

            let expiresAt = ISO8601DateFormatter().string(
                from: Date().addingTimeInterval(600)
            )
            struct TokenInsert: Encodable {
                let email: String
                let token: String
                let user_id: String
                let expires_at: String
                let used: Bool
            }
            _ = try? await supabase
                .from("password_reset_tokens")
                .insert(TokenInsert(
                    email: email,
                    token: resetToken,
                    user_id: userRow.id,
                    expires_at: expiresAt,
                    used: false
                ))
                .execute()

            return true
        } catch {
            pendingResetToken = ""
            return false
        }
    }

    func resetPassword(code: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard code == resetOTP else { throw AuthError.invalidCredentials }
        guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }
        guard !pendingResetToken.isEmpty else { throw AuthError.invalidCredentials }

        struct ResetPayload: Encodable {
            let email: String
            let reset_token: String
            let new_password: String
        }
        struct ResetResponse: Decodable { let success: Bool? }

        do {
            let _: ResetResponse = try await supabase.functions.invoke(
                "reset-password",
                options: FunctionInvokeOptions(body: ResetPayload(
                    email: email,
                    reset_token: pendingResetToken,
                    new_password: newPassword
                ))
            )
        } catch {
            throw AuthError.invalidCredentials
        }

        let hashed = CryptoService.hash(password: newPassword)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCred)

        resetOTP = ""
        pendingResetToken = ""
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

    func reauthCompleted() {
        needsReauth = false
        Task { _ = try? await supabase.auth.session }
    }
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
