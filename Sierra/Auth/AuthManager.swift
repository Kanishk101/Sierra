import Foundation
import Supabase

// MARK: - AuthDestination

enum AuthDestination: Equatable {
    case fleetManagerDashboard
    case changePassword
    case driverOnboarding
    case maintenanceOnboarding
    case pendingApproval
    case driverDashboard
    case maintenanceDashboard
}

// MARK: - RPC Params (top-level so it is Sendable)
// Used by createStaffAccount — must live outside @MainActor class.

private struct CreateStaffRPCParams: Encodable, Sendable {
    let p_email:        String
    let p_raw_password: String
    let p_name:         String
    let p_role:         String
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
    private let autoLockSeconds: TimeInterval = 300

    private init() { restoreSessionSilently() }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> UserRole {
        let session = try await supabase.auth.signIn(email: email, password: password)
        let authUserId = session.user.id

        struct RoleRow: Decodable {
            let role: String
            let name: String?
            let isFirstLogin: Bool
            let isProfileComplete: Bool
            let isApproved: Bool
            let rejectionReason: String?
            let phone: String?
            let createdAt: Date?
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
            .eq("id", value: authUserId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            try? await supabase.auth.signOut()
            throw AuthError.userNotFound
        }

        let user = AuthUser(
            id: authUserId,
            email: session.user.email ?? email,
            role: UserRole(rawValue: row.role) ?? .driver,
            isFirstLogin: row.isFirstLogin,
            isProfileComplete: row.isProfileComplete,
            isApproved: row.isApproved,
            name: row.name,
            rejectionReason: row.rejectionReason,
            phone: row.phone,
            createdAt: row.createdAt
        )
        currentUser = user
        pendingOTPEmail = user.email
        _ = KeychainService.save(user, forKey: Keys.currentUser)
        return user.role
    }

    // MARK: - Complete Authentication

    func completeAuthentication(saveToken: Bool = true) {
        if saveToken { saveSessionToken() }
        isAuthenticated = true
        if let user = currentUser {
            Task {
                switch user.role {
                case .fleetManager:         await AppDataStore.shared.loadAll()
                case .driver:               await AppDataStore.shared.loadDriverData(driverId: user.id)
                case .maintenancePersonnel: await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
                }
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
        Task { try? await supabase.auth.signOut() }
        currentUser = nil
        isAuthenticated = false
        needsReauth = false
        pendingOTPEmail = nil
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCred)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
        KeychainService.delete(key: Keys.biometricOn)
        KeychainService.delete(key: Keys.biometricPrompted)
    }

    // MARK: - Session Restore

    @discardableResult
    func restoreSession() -> UserRole? {
        guard hasSessionToken(),
              let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) else { return nil }
        currentUser = user
        isAuthenticated = true
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
            if user.isFirstLogin       { return .changePassword }
            if !user.isProfileComplete  { return .driverOnboarding }
            if !user.isApproved        { return .pendingApproval }
            return .driverDashboard
        case .maintenancePersonnel:
            if user.isFirstLogin       { return .changePassword }
            if !user.isProfileComplete  { return .maintenanceOnboarding }
            if !user.isApproved        { return .pendingApproval }
            return .maintenanceDashboard
        }
    }

    // MARK: - Masked Email

    var maskedEmail: String {
        let email = pendingOTPEmail ?? currentUser?.email ?? ""
        guard !email.isEmpty, let atRange = email.range(of: "@") else { return "***@***.com" }
        return "\(email.prefix(1))***\(email[atRange.lowerBound...])"
    }

    // MARK: - Legacy OTP helpers

    @discardableResult
    func generateOTP() -> String {
        let otp = String(format: "%06d", Int.random(in: 100000...999999))
        currentOTP = otp
        pendingOTPEmail = currentUser?.email
        return otp
    }

    func verifyOTP(_ code: String) -> Bool {
        let match = code == currentOTP
        if match { currentOTP = "" }
        return match
    }

    // MARK: - Password Management

    func updatePasswordAndFirstLogin(newPassword: String) async throws {
        guard let user = currentUser else { throw AuthError.invalidCredentials }
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
        try await AuthUserService.markFirstLoginComplete(id: user.id)
        var updated = user
        updated.isFirstLogin = false
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await updatePasswordAndFirstLogin(newPassword: newPassword)
    }

    func markProfileComplete() async throws {
        guard let user = currentUser else { return }
        try await AuthUserService.markProfileComplete(id: user.id)
        var updated = user
        updated.isProfileComplete = true
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    func markPasswordChanged() async throws {
        guard let user = currentUser else { return }
        try await AuthUserService.markFirstLoginComplete(id: user.id)
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
        do {
            struct EmailRow: Decodable { let id: String }
            let rows: [EmailRow] = try await supabase
                .from("staff_members").select("id")
                .eq("email", value: email).limit(1).execute().value
            guard !rows.isEmpty else { return true }
            try await supabase.auth.resetPasswordForEmail(email)
            return true
        } catch { return true }
    }

    // MARK: - Create Staff Account
    // Calls `create_staff_member` SECURITY DEFINER Postgres RPC — no Edge Function.
    // The nonisolated static helper escapes @MainActor so the Supabase SDK
    // async/throws calls resolve correctly without Sendable conflicts.

    func createStaffAccount(
        email: String,
        name: String,
        role: UserRole,
        tempPassword: String
    ) async throws -> UUID {
        try await AuthManager.invokeCreateStaffRPC(
            email: email,
            name: name,
            roleRawValue: role.rawValue,
            tempPassword: tempPassword
        )
    }

    private static func invokeCreateStaffRPC(
        email: String,
        name: String,
        roleRawValue: String,
        tempPassword: String
    ) async throws -> UUID {
        let params = CreateStaffRPCParams(
            p_email:        email,
            p_raw_password: tempPassword,
            p_name:         name,
            p_role:         roleRawValue
        )
        let uuidString: String = try await supabase
            .rpc("create_staff_member", params: params)
            .execute()
            .value
        guard let uuid = UUID(uuidString: uuidString) else {
            throw AuthError.createStaffFailed
        }
        return uuid
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
