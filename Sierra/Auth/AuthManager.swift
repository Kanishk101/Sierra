import Foundation
import Auth

// MARK: - AuthDestination

/// Determines which screen to show after authentication.
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

/// Centralized authentication manager.
/// Handles sign-in, sign-out, session persistence, and role-based routing.
/// Delegates all supabase.auth.* calls to SupabaseAuthService.
@Observable
final class AuthManager {

    static let shared = AuthManager()

    // MARK: - Keychain Keys

    private enum Keys {
        static let currentUser       = "com.fleetOS.currentUser"
        static let hashedCredential  = "com.fleetOS.hashedCredential"
        static let sessionToken      = "com.fleetOS.sessionToken"
        static let backgroundTS      = "com.fleetOS.backgroundTimestamp"
    }

    // MARK: - State

    var currentUser: AuthUser?
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false

    /// Email address awaiting OTP verification (used for masked display in TwoFactorView).
    var pendingOTPEmail: String?

    /// 5-minute auto-lock threshold.
    private let autoLockSeconds: TimeInterval = 300

    // MARK: - Init

    private init() {
        restoreSessionSilently()
    }

    // MARK: - Sign In

    /// Authenticates with Supabase Auth, then fetches the staff_members row to build AuthUser.
    /// Does NOT set isAuthenticated — that happens only after 2FA via completeAuthentication().
    /// - Returns: The authenticated user's `UserRole` for routing decisions.
    func signIn(email: String, password: String) async throws -> UserRole {
        // 1. Authenticate with Supabase
        let session = try await SupabaseAuthService.signIn(email: email, password: password)
        let authUserId = session.user.id

        // 2. Fetch staff_members row to get role + profile state
        let staffRow: StaffMember
        do {
            staffRow = try await StaffMemberService.fetchStaffMember(id: authUserId)
        } catch {
            // Auth succeeded but no staff_members row — account not provisioned yet
            try? await SupabaseAuthService.signOut()
            throw AuthError.staffRecordNotFound
        }

        // 3. Check account standing
        if staffRow.status == .suspended {
            try? await SupabaseAuthService.signOut()
            throw AuthError.accountSuspended
        }

        // 4. Build AuthUser from session + staff row
        let user = AuthUser(
            id: authUserId,
            email: session.user.email ?? email,
            role: staffRow.role,
            isFirstLogin: staffRow.isFirstLogin,
            isProfileComplete: staffRow.isProfileComplete,
            isApproved: staffRow.isApproved,
            name: staffRow.name,
            rejectionReason: staffRow.rejectionReason,
            phone: staffRow.phone,
            profilePhotoUrl: staffRow.profilePhotoUrl,
            status: staffRow.status.rawValue,
            availability: staffRow.availability.rawValue,
            createdAt: staffRow.createdAt
        )

        // 5. Persist hashed local credential for biometric re-verification
        let hashed = CryptoService.hash(password: password)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCredential)
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        currentUser = user
        pendingOTPEmail = user.email

        // NOTE: isAuthenticated NOT set here — 2FA must complete first via completeAuthentication().
        #if DEBUG
        print("🔑 [AuthManager.signIn] Supabase session established. role=\(user.role.rawValue) firstLogin=\(user.isFirstLogin)")
        #endif

        return user.role
    }

    // MARK: - Complete Authentication (post-2FA / biometric)

    /// Called after successful 2FA verification or biometric login.
    /// - Parameter saveToken: Pass true (default) to persist session token for Face ID on next launch.
    ///   Pass false for first-login users — token saved only after onboarding fully completes.
    func completeAuthentication(saveToken: Bool = true) {
        if saveToken { saveSessionToken() }
        isAuthenticated = true
        #if DEBUG
        print("[AuthManager] completeAuthentication — isAuthenticated=true, saveToken=\(saveToken)")
        #endif
    }

    /// Saves a session token to Keychain, enabling Face ID on next launch.
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
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCredential)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
        KeychainService.delete(key: "com.fleetOS.hasPromptedBiometric")
        KeychainService.delete(key: "com.fleetOS.biometricEnabled")
        // Best-effort Supabase signout — fire and forget
        Task { try? await SupabaseAuthService.signOut() }
    }

    // MARK: - Session Restore

    /// Synchronous check for biometric gate — restores currentUser from Keychain.
    /// Does NOT set isAuthenticated (biometric step handles that).
    @discardableResult
    func restoreSession() -> UserRole? {
        guard hasSessionToken(),
              let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) else {
            return nil
        }
        currentUser = user
        isAuthenticated = true
        #if DEBUG
        print("🔑 [AuthManager.restoreSession] Restored via Keychain (biometric path)")
        #endif
        return user.role
    }

    /// Async launch-time check — uses Supabase's in-memory session to silently restore currentUser.
    /// Does NOT set isAuthenticated (biometric / password step still required).
    private func restoreSessionSilently() {
        // First restore from Keychain for immediate UI (fast path)
        if let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) {
            currentUser = user
        }
        // Then refresh from Supabase in background to pick up any server-side changes
        Task { await refreshSessionFromSupabase() }
    }

    private func refreshSessionFromSupabase() async {
        guard let session = await SupabaseAuthService.currentSession() else { return }
        let staffRow = try? await StaffMemberService.fetchStaffMember(id: session.user.id)
        guard let staffRow else { return }

        let user = AuthUser(
            id: session.user.id,
            email: session.user.email ?? "",
            role: staffRow.role,
            isFirstLogin: staffRow.isFirstLogin,
            isProfileComplete: staffRow.isProfileComplete,
            isApproved: staffRow.isApproved,
            name: staffRow.name,
            rejectionReason: staffRow.rejectionReason,
            phone: staffRow.phone,
            profilePhotoUrl: staffRow.profilePhotoUrl,
            status: staffRow.status.rawValue,
            availability: staffRow.availability.rawValue,
            createdAt: staffRow.createdAt
        )
        await MainActor.run {
            self.currentUser = user
            _ = KeychainService.save(user, forKey: Keys.currentUser)
        }
    }

    /// Returns true if a session token exists in Keychain (used for biometric gate).
    func hasSessionToken() -> Bool {
        KeychainService.load(key: Keys.sessionToken) != nil
    }

    // MARK: - Routing

    /// Returns the correct post-authentication destination based on the user's profile state.
    /// This logic is the single source of truth for all role-based routing — do NOT duplicate in views.
    func destination(for user: AuthUser) -> AuthDestination {
        switch user.role {
        case .fleetManager:
            return user.isApproved ? .fleetManagerDashboard : .pendingApproval

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

    // MARK: - OTP / 2FA

    /// Masked display of the email address the OTP was sent to.
    var maskedEmail: String {
        guard let email = pendingOTPEmail ?? currentUser?.email,
              let atIndex = email.firstIndex(of: "@") else {
            return "***@***.com"
        }
        let first = email.prefix(1)
        let domain = email[atIndex...]
        return "\(first)***\(domain)"
    }

    // MARK: - Password Management

    /// Updates the authenticated user's password via Supabase Auth and marks isFirstLogin = false.
    func updatePassword(_ newPassword: String) async throws {
        try await SupabaseAuthService.updatePassword(newPassword)
        try await markPasswordChanged()
    }

    /// Sets staff_members.is_first_login = false after a forced password change.
    func markPasswordChanged() async throws {
        guard let userId = currentUser?.id,
              var staffRow = try? await StaffMemberService.fetchStaffMember(id: userId) else { return }
        staffRow.isFirstLogin = false
        try await StaffMemberService.updateStaffMember(staffRow)
        currentUser?.isFirstLogin = false
        _ = KeychainService.save(currentUser, forKey: Keys.currentUser)
    }

    /// Marks staff_members.is_profile_complete = true after onboarding form submission.
    func markProfileComplete() async throws {
        guard let userId = currentUser?.id,
              var staffRow = try? await StaffMemberService.fetchStaffMember(id: userId) else { return }
        staffRow.isProfileComplete = true
        try await StaffMemberService.updateStaffMember(staffRow)
        currentUser?.isProfileComplete = true
        _ = KeychainService.save(currentUser, forKey: Keys.currentUser)
    }

    /// Sends a password reset email. The user follows the link in the email.
    func requestPasswordReset(email: String) async throws {
        try await SupabaseAuthService.requestPasswordReset(email: email)
        pendingOTPEmail = email
    }

    // MARK: - User Refresh

    /// Re-fetches the staff_members row for the current user and updates currentUser.
    /// Called from PendingApprovalView when polling for status changes.
    func refreshCurrentUser() async throws {
        guard let userId = currentUser?.id else { return }
        let staffRow = try await StaffMemberService.fetchStaffMember(id: userId)
        let updated = AuthUser(
            id: userId,
            email: currentUser?.email ?? "",
            role: staffRow.role,
            isFirstLogin: staffRow.isFirstLogin,
            isProfileComplete: staffRow.isProfileComplete,
            isApproved: staffRow.isApproved,
            name: staffRow.name,
            rejectionReason: staffRow.rejectionReason,
            phone: staffRow.phone,
            profilePhotoUrl: staffRow.profilePhotoUrl,
            status: staffRow.status.rawValue,
            availability: staffRow.availability.rawValue,
            createdAt: staffRow.createdAt
        )
        currentUser = updated
        _ = KeychainService.save(updated, forKey: Keys.currentUser)
    }

    // MARK: - Staff Account Provisioning

    /// Creates a new staff account. Requires a Supabase Edge Function — NOT implementable client-side.
    /// - Note: Admin must use the Supabase Dashboard or a secure backend endpoint to create auth.users entries.
    ///   When the Edge Function is ready, replace this method with the actual call.
    func createStaffAccount(email: String, role: UserRole) async throws -> UUID {
        throw AuthError.notImplemented(
            "createStaffAccount requires a Supabase Edge Function. " +
            "Use the Supabase Dashboard to provision staff accounts manually " +
            "until the Edge Function is deployed."
        )
    }

    // MARK: - Auto-Lock (5-minute background threshold)

    func appDidEnterBackground() {
        let ts = "\(Date().timeIntervalSince1970)".data(using: .utf8) ?? Data()
        _ = KeychainService.save(ts, forKey: Keys.backgroundTS)
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

enum AuthError: LocalizedError {
    case invalidCredentials
    case biometricFailed
    case sessionExpired
    case staffRecordNotFound
    case accountSuspended
    case otpExpired
    case otpInvalid
    case networkError(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please check your credentials and try again."
        case .biometricFailed:
            return "Biometric authentication failed. Please sign in with your password."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .staffRecordNotFound:
            return "Your account profile could not be found. Contact your fleet manager."
        case .accountSuspended:
            return "Your account has been suspended. Contact your fleet manager."
        case .otpExpired:
            return "The verification code has expired. Please request a new one."
        case .otpInvalid:
            return "Incorrect verification code. Please check the code and try again."
        case .networkError(let detail):
            return "Connection error: \(detail). Check your internet connection and try again."
        case .notImplemented(let detail):
            return "Feature not available: \(detail)"
        }
    }
}
