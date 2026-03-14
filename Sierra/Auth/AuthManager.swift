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

// MARK: - AuthManager

@MainActor
@Observable
final class AuthManager {

    static let shared = AuthManager()

    // MARK: - Keychain Keys

    private enum Keys {
        static let currentUser   = "com.fleetOS.currentUser"
        static let backgroundTS  = "com.fleetOS.backgroundTimestamp"
        static let sessionToken  = "com.fleetOS.sessionToken"
        static let hashedCred    = "com.fleetOS.hashedCredential"
        static let biometricOn   = "com.fleetOS.biometricEnabled"
        static let biometricPrompted = "com.fleetOS.hasPromptedBiometric"
    }

    // MARK: - State

    var currentUser: AuthUser?
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false

    /// App-side 2FA OTP (6-digit, stored in memory only)
    private var currentOTP: String = ""
    var pendingOTPEmail: String?

    /// Password reset OTP (separate flow)
    private var resetOTP: String = ""

    private let autoLockSeconds: TimeInterval = 300  // 5 minutes

    // MARK: - Init

    private init() {
        restoreSessionSilently()
    }

    // MARK: - Sign In

    /// Authenticates with Supabase Auth, fetches from `staff_members`, builds `AuthUser`.
    /// Does NOT set `isAuthenticated` — that requires 2FA completion via `completeAuthentication()`.
    func signIn(email: String, password: String) async throws -> UserRole {
        // 1. Supabase Auth sign-in
        let session = try await supabase.auth.signIn(email: email, password: password)
        let authUserId = session.user.id

        // 2. Fetch staff_members row — decode role as raw String to avoid StaffRole/UserRole mismatch
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
                case role
                case name
                case isFirstLogin      = "is_first_login"
                case isProfileComplete = "is_profile_complete"
                case isApproved        = "is_approved"
                case rejectionReason   = "rejection_reason"
                case phone
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

        // 3. Build AuthUser
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

        // 4. Persist locally
        currentUser = user
        pendingOTPEmail = user.email
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        // NOTE: isAuthenticated NOT set here — 2FA must complete first.
        #if DEBUG
        print("🔑 [AuthManager.signIn] Signed in: \(user.email) role=\(user.role.rawValue)")
        #endif

        return user.role
    }

    // MARK: - Complete Authentication (post-2FA / biometric)

    /// Called exclusively after successful 2FA OTP verification.
    /// Saves session token and triggers the appropriate AppDataStore load.
    func completeAuthentication(saveToken: Bool = true) {
        if saveToken { saveSessionToken() }
        isAuthenticated = true

        // Trigger role-specific data load
        if let user = currentUser {
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

    /// Synchronous check for biometric gate — restores currentUser from Keychain.
    @discardableResult
    func restoreSession() -> UserRole? {
        guard hasSessionToken(),
              let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) else {
            return nil
        }
        currentUser = user
        isAuthenticated = true
        return user.role
    }

    func hasSessionToken() -> Bool {
        KeychainService.load(key: Keys.sessionToken) != nil
    }

    private func restoreSessionSilently() {
        // Fast path: restore from Keychain for immediate UI
        if let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) {
            currentUser = user
        }
        // Do NOT set isAuthenticated — require biometric / password re-entry
    }

    // MARK: - Routing

    func destination(for user: AuthUser) -> AuthDestination {
        switch user.role {
        case .fleetManager:
            return .fleetManagerDashboard

        case .driver:
            if user.isFirstLogin      { return .changePassword }
            if !user.isProfileComplete { return .driverOnboarding }
            if !user.isApproved       { return .pendingApproval }
            return .driverDashboard

        case .maintenancePersonnel:
            if user.isFirstLogin      { return .changePassword }
            if !user.isProfileComplete { return .maintenanceOnboarding }
            if !user.isApproved       { return .pendingApproval }
            return .maintenanceDashboard
        }
    }

    // MARK: - OTP (App-Side 2FA)

    @discardableResult
    func generateOTP() -> String {
        let otp = String(format: "%06d", Int.random(in: 100000...999999))
        currentOTP = otp
        pendingOTPEmail = currentUser?.email
        // In production, deliver via SMTP through your backend.
        // For test/debug, OTP is printed below.
        #if DEBUG
        print("📧 OTP for \(pendingOTPEmail ?? "?"): \(otp)")
        #endif
        return otp
    }

    func verifyOTP(_ code: String) -> Bool {
        let match = code == currentOTP
        if match { currentOTP = "" }
        return match
    }

    var maskedEmail: String {
        guard let email = pendingOTPEmail ?? currentUser?.email,
              let atIndex = email.firstIndex(of: "@") else { return "***@***.com" }
        return "\(email.prefix(1))***\(email[atIndex...])"
    }

    // MARK: - Password Management

    /// Updates password via Supabase Auth and marks `is_first_login = false`.
    func updatePasswordAndFirstLogin(newPassword: String) async throws {
        guard let user = currentUser else { throw AuthError.invalidCredentials }

        // 1. Supabase Auth password update
        try await supabase.auth.update(user: UserAttributes(password: newPassword))

        // 2. Mark first login complete in staff_members
        try await AuthUserService.markFirstLoginComplete(id: user.id)

        // 3. Update local state
        var updated = user
        updated.isFirstLogin = false
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    /// Legacy alias used by ForcePasswordChangeViewModel.
    func updatePassword(_ newPassword: String) async throws {
        try await updatePasswordAndFirstLogin(newPassword: newPassword)
    }

    /// Marks `is_profile_complete = true` in staff_members via AuthUserService.
    func markProfileComplete() async throws {
        guard let user = currentUser else { return }
        try await AuthUserService.markProfileComplete(id: user.id)
        var updated = user
        updated.isProfileComplete = true
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    /// Marks `is_first_login = false` in staff_members (standalone, useful post-reset).
    func markPasswordChanged() async throws {
        guard let user = currentUser else { return }
        try await AuthUserService.markFirstLoginComplete(id: user.id)
        var updated = user
        updated.isFirstLogin = false
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    /// Refreshes current user from staff_members (for pending-approval polling).
    func refreshCurrentUser() async throws {
        guard let userId = currentUser?.id else { return }
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
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first, let current = currentUser else { return }
        var updated = current
        updated.isApproved        = row.isApproved
        updated.isProfileComplete = row.isProfileComplete
        updated.isFirstLogin      = row.isFirstLogin
        updated.rejectionReason   = row.rejectionReason
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    // MARK: - Password Reset (Forgot Password Flow)

    func requestPasswordReset(email: String) async -> Bool {
        do {
            struct RoleRow: Decodable {
                let role: String
            }
            let rows: [RoleRow] = try await supabase
                .from("staff_members")
                .select("role")
                .eq("email", value: email)
                .limit(1)
                .execute()
                .value
            guard !rows.isEmpty else { return false }

            pendingOTPEmail = email
            let otp = String(format: "%06d", Int.random(in: 100000...999999))
            resetOTP = otp
            // In production, deliver via SMTP through your backend.
            #if DEBUG
            print("🔑 Reset OTP for \(email): \(otp)")
            #endif
            return true
        } catch {
            return false
        }
    }

    func verifyResetOTP(_ code: String) -> Bool {
        code == resetOTP
    }

    func resetPassword(code: String, newPassword: String) async throws {
        guard code == resetOTP, let email = pendingOTPEmail else {
            throw AuthError.invalidCredentials
        }
        // Use Supabase password reset email flow for production.
        // The user must be signed in — for cases where they're not, fall back to email link.
        try await supabase.auth.resetPasswordForEmail(email)
        resetOTP = ""
        pendingOTPEmail = nil
    }

    // MARK: - Create Staff Account (Admin only — requires Edge Function)

    func createStaffAccount(
        email: String,
        name: String,
        role: UserRole,
        tempPassword: String
    ) async throws -> UUID {
        let payload: [String: String] = [
            "email":    email,
            "password": tempPassword,
            "name":     name,
            "role":     role.rawValue
        ]
        let data: Data = try await supabase.functions.invoke(
            "create-staff-account",
            options: FunctionInvokeOptions(body: try JSONEncoder().encode(payload))
        )

        // Decode response — Edge Function returns { id, email } on success or { error } on failure
        struct CreateResponse: Decodable {
            let id:    String?
            let email: String?
            let error: String?
        }

        guard let response = try? JSONDecoder().decode(CreateResponse.self, from: data) else {
            throw AuthError.createStaffFailed
        }

        if let errorMsg = response.error {
            throw AuthError.networkError(errorMsg)
        }

        guard let idString = response.id, let uuid = UUID(uuidString: idString) else {
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
              let str = String(data: data, encoding: .utf8),
              let ts = TimeInterval(str) else { return }
        if Date().timeIntervalSince1970 - ts > autoLockSeconds {
            needsReauth = true
        }
    }

    func reauthCompleted() {
        needsReauth = false
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
        case .invalidCredentials: return "Invalid email or password."
        case .userNotFound:       return "Account not found. Contact your fleet administrator."
        case .biometricFailed:    return "Biometric authentication failed."
        case .sessionExpired:     return "Your session has expired. Please sign in again."
        case .createStaffFailed:  return "Staff creation requires the backend service. Please deploy the Edge Function."
        case .accountSuspended:   return "Your account has been suspended. Contact your fleet manager."
        case .otpExpired:         return "The verification code has expired. Please request a new one."
        case .otpInvalid:         return "Incorrect verification code. Please check the code and try again."
        case .networkError(let d): return "Connection error: \(d). Check your internet connection."
        }
    }
}
