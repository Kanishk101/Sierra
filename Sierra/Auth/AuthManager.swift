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
        static let biometricPrompted = "com.fleetOS.hasPromptedBiometric"
    }

    // MARK: - State

    var currentUser: AuthUser?
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false
    private var currentOTP: String = ""
    private var otpGeneratedAt: Date?
    private let otpValidSeconds: TimeInterval = 600
    var pendingOTPEmail: String?
    private var pendingResetToken: String = ""
    private var resetOTP: String = ""
    private var resetOTPGeneratedAt: Date?
    private let autoLockSeconds: TimeInterval = 300
    private var otpLastSentAt: Date?
    private var resetOTPLastSentAt: Date?
    private let otpCooldownSeconds: TimeInterval = 30

    private init() { restoreSessionSilently() }

    // MARK: - Sign In
    //
    // Two-step login:
    //   1. supabase.auth.signIn() — Supabase Auth validates credentials (bcrypt).
    //      If this fails the password is genuinely wrong — throw invalidCredentials.
    //   2. 500ms sleep — gives GoTrue time to propagate the new JWT to all
    //      edge nodes before the sign-in edge function calls auth.getUser().
    //      The edge function also retries getUser() up to 3 times with 200ms
    //      gaps as an extra safety net.
    //   3. sign-in edge function (verify_jwt: true) — fetches staff profile.
    //      If this fails throw sessionExpired (not invalidCredentials) so the
    //      error message is accurate: the password was right, the profile fetch failed.

    func signIn(email: String, password: String) async throws -> UserRole {
        otpLastSentAt = nil

        // Step 1: Supabase Auth credential check
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            // Auth rejected the credentials — wrong email/password
            print("[AuthManager] signIn step 1 failed: \(error)")
            throw AuthError.invalidCredentials
        }

        // Step 2: Wait for JWT propagation
        try await Task.sleep(for: .milliseconds(500))

        // Step 3: Fetch staff profile via edge function
        struct StaffProfile: Decodable {
            let id: String; let email: String; let name: String?
            let role: String; let is_first_login: Bool?
            let is_profile_complete: Bool?; let is_approved: Bool?
            let rejection_reason: String?; let phone: String?; let created_at: String?
        }

        let profile: StaffProfile
        do {
            profile = try await supabase.functions.invoke("sign-in", options: FunctionInvokeOptions())
        } catch {
            print("[AuthManager] signIn step 3 (edge fn) failed: \(error)")
            try? await supabase.auth.signOut()
            // Password was correct but profile fetch failed — distinct error
            throw AuthError.userNotFound
        }

        guard let userId = UUID(uuidString: profile.id) else {
            try? await supabase.auth.signOut()
            throw AuthError.userNotFound
        }

        let user = AuthUser(
            id: userId, email: profile.email,
            role: UserRole(rawValue: profile.role) ?? .driver,
            isFirstLogin: profile.is_first_login ?? true,
            isProfileComplete: profile.is_profile_complete ?? false,
            isApproved: profile.is_approved ?? false,
            name: profile.name, rejectionReason: profile.rejection_reason,
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
            case .fleetManager:          await AppDataStore.shared.loadAll()
            case .driver:                await AppDataStore.shared.loadDriverData(driverId: user.id)
            case .maintenancePersonnel:  await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
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
        currentOTP = ""
        otpGeneratedAt = nil
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCred)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
        KeychainService.delete(key: Keys.biometricOn)
        KeychainService.delete(key: Keys.biometricPrompted)
        AppDataStore.shared.unsubscribeAll()
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
            case .fleetManager:         await AppDataStore.shared.loadAll()
            case .driver:               await AppDataStore.shared.loadDriverData(driverId: user.id)
            case .maintenancePersonnel: await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
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
        case .fleetManager: return .fleetManagerDashboard
        case .driver:
            if user.isFirstLogin        { return .changePassword }
            if !user.isProfileComplete  { return .driverOnboarding }
            if !user.isApproved {
                if let r = user.rejectionReason, !r.isEmpty { return .rejected }
                return .pendingApproval
            }
            return .driverDashboard
        case .maintenancePersonnel:
            if user.isFirstLogin        { return .changePassword }
            if !user.isProfileComplete  { return .maintenanceOnboarding }
            if !user.isApproved {
                if let r = user.rejectionReason, !r.isEmpty { return .rejected }
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

    // MARK: - OTP

    @discardableResult
    func generateOTP() -> String {
        if let last = otpLastSentAt, Date().timeIntervalSince(last) < otpCooldownSeconds {
            return currentOTP
        }
        let otp = String(format: "%06d", Int.random(in: 100000...999999))
        currentOTP = otp
        otpGeneratedAt = Date()
        otpLastSentAt = Date()
        pendingOTPEmail = currentUser?.email
        #if DEBUG
        print("🔑 [AuthManager] OTP = \(otp) → \(pendingOTPEmail ?? "no email")")
        #endif
        if let email = pendingOTPEmail {
            EmailService.sendLoginOTP(to: email, otp: otp)
        }
        return otp
    }

    func verifyOTP(_ code: String) -> Bool {
        guard let generatedAt = otpGeneratedAt,
              Date().timeIntervalSince(generatedAt) < otpValidSeconds else {
            currentOTP = ""
            otpGeneratedAt = nil
            return false
        }
        let match = code == currentOTP
        if match { currentOTP = ""; otpGeneratedAt = nil }
        return match
    }

    func verifyResetOTP(_ code: String) -> Bool { code == resetOTP }

    // MARK: - Password Management

    func updatePasswordAndFirstLogin(newPassword: String) async throws {
        guard var user = currentUser else { throw AuthError.invalidCredentials }
        struct Payload: Encodable { let is_first_login: Bool }
        try await supabase.from("staff_members")
            .update(Payload(is_first_login: false)).eq("id", value: user.id.uuidString).execute()
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
        user.isFirstLogin = false
        currentUser = user
        _ = KeychainService.save(user, forKey: Keys.currentUser)
        _ = KeychainService.save(CryptoService.hash(password: newPassword), forKey: Keys.hashedCred)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await updatePasswordAndFirstLogin(newPassword: newPassword)
    }

    func markProfileComplete() async throws {
        guard let user = currentUser else { return }
        struct P: Encodable { let is_profile_complete: Bool }
        try await supabase.from("staff_members")
            .update(P(is_profile_complete: true)).eq("id", value: user.id.uuidString).execute()
        var updated = user; updated.isProfileComplete = true
        currentUser = updated; _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    func markPasswordChanged() async throws {
        guard let user = currentUser else { return }
        struct P: Encodable { let is_first_login: Bool }
        try await supabase.from("staff_members")
            .update(P(is_first_login: false)).eq("id", value: user.id.uuidString).execute()
        var updated = user; updated.isFirstLogin = false
        currentUser = updated; _ = KeychainService.save(updated, forKey: Keys.currentUser)
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
        let rows: [RoleRow] = try await supabase.from("staff_members")
            .select("role,name,is_first_login,is_profile_complete,is_approved,rejection_reason,phone,created_at")
            .eq("id", value: userId.uuidString).limit(1).execute().value
        guard let row = rows.first, let current = currentUser else { return }
        var updated = current
        updated.isApproved = row.isApproved; updated.isProfileComplete = row.isProfileComplete
        updated.isFirstLogin = row.isFirstLogin; updated.rejectionReason = row.rejectionReason
        currentUser = updated; _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    // MARK: - Password Reset

    func requestPasswordReset(email: String) async -> Bool {
        if let last = resetOTPLastSentAt, Date().timeIntervalSince(last) < otpCooldownSeconds { return true }
        pendingResetToken = ""
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase.from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value
            guard let userRow = rows.first else { return false }

            pendingOTPEmail = email
            let otp = String(format: "%06d", Int.random(in: 100000...999999))
            resetOTP = otp
            resetOTPGeneratedAt = Date()
            resetOTPLastSentAt = Date()
            EmailService.sendResetOTP(to: email, otp: otp)

            let resetToken = UUID().uuidString
            pendingResetToken = resetToken

            let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600))
            struct TokenInsert: Encodable {
                let email: String; let token: String; let user_id: String
                let expires_at: String; let used: Bool
            }
            try await supabase.from("password_reset_tokens")
                .insert(TokenInsert(email: email, token: resetToken, user_id: userRow.id,
                                    expires_at: expiresAt, used: false))
                .execute()
            return true
        } catch {
            pendingResetToken = ""
            return false
        }
    }

    func resetPassword(code: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard let generatedAt = resetOTPGeneratedAt,
              Date().timeIntervalSince(generatedAt) < otpValidSeconds else {
            throw AuthError.otpExpired
        }
        guard code == resetOTP else { throw AuthError.invalidCredentials }
        guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }
        guard !pendingResetToken.isEmpty else { throw AuthError.invalidCredentials }

        struct ResetPayload: Encodable { let email: String; let reset_token: String; let new_password: String }
        struct ResetResponse: Decodable { let success: Bool? }
        do {
            let _: ResetResponse = try await supabase.functions.invoke(
                "reset-password",
                options: FunctionInvokeOptions(body: ResetPayload(
                    email: email, reset_token: pendingResetToken, new_password: newPassword
                ))
            )
        } catch { throw AuthError.invalidCredentials }

        _ = KeychainService.save(CryptoService.hash(password: newPassword), forKey: Keys.hashedCred)
        resetOTP = ""; resetOTPGeneratedAt = nil; pendingResetToken = ""; pendingOTPEmail = nil
    }

    // MARK: - Email Existence Check

    func emailExists(_ email: String) async -> Bool {
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase.from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value
            return !rows.isEmpty
        } catch { return false }
    }

    // MARK: - Auto-Lock

    func appDidEnterBackground() {
        let ts = "\(Date().timeIntervalSince1970)"
        if let data = ts.data(using: .utf8) { _ = KeychainService.save(data, forKey: Keys.backgroundTS) }
    }

    func appWillEnterForeground() {
        guard isAuthenticated else { return }
        guard let data = KeychainService.load(key: Keys.backgroundTS),
              let str = String(data: data, encoding: .utf8),
              let ts  = TimeInterval(str) else { return }
        if Date().timeIntervalSince1970 - ts > autoLockSeconds { needsReauth = true }
    }

    func reauthCompleted() {
        needsReauth = false
        Task { _ = try? await supabase.auth.session }
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials, userNotFound, biometricFailed, sessionExpired
    case createStaffFailed, accountSuspended, otpExpired, otpInvalid
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password."
        case .userNotFound:       return "Account not found. Contact your fleet administrator."
        case .biometricFailed:    return "Biometric authentication failed."
        case .sessionExpired:     return "Your session has expired. Please sign in again."
        case .createStaffFailed:  return "Failed to create staff account. Please try again."
        case .accountSuspended:   return "Your account has been suspended. Contact your fleet manager."
        case .otpExpired:         return "The verification code has expired. Please request a new one."
        case .otpInvalid:         return "Incorrect verification code. Please check and try again."
        case .networkError(let d): return "Connection error: \(d)"
        }
    }
}
