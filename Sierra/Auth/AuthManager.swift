import Foundation
import CryptoKit

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

/// Centralized authentication manager.
/// Handles sign-in, sign-out, session persistence in Keychain, and role-based routing.
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
    var isAuthenticated: Bool = false {
        didSet {
            print("🚨🚨🚨 isAuthenticated SET: \(oldValue) → \(isAuthenticated)")
            print("🚨 CALL STACK:\n\(Thread.callStackSymbols.prefix(10).joined(separator: "\n"))")
        }
    }
    var needsReauth: Bool = false

    // OTP state
    private var currentOTP: String = ""
    var pendingOTPEmail: String?

    // Password reset OTP (separate from login OTP)
    private var resetOTP: String = ""

    /// 5-minute auto-lock threshold.
    private let autoLockSeconds: TimeInterval = 300

    // MARK: - Hardcoded Admin (dev/demo)

    private struct DemoCredential {
        let email: String
        let password: String
        let user: AuthUser
    }

    private let demoUsers: [DemoCredential] = [
        // Admin — fully set up
        DemoCredential(
            email: "admin@fleeeos.com",
            password: "Admin@123",
            user: AuthUser(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                email: "admin@fleeeos.com",
                role: .fleetManager,
                isFirstLogin: false,
                isProfileComplete: true,
                isApproved: true,
                name: "Fleet Admin"
            )
        ),
        // Driver — first login, needs password change + onboarding + approval
        DemoCredential(
            email: "driver@fleeeos.com",
            password: "Driver@123",
            user: AuthUser(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                email: "driver@fleeeos.com",
                role: .driver,
                isFirstLogin: true,
                isProfileComplete: false,
                isApproved: false,
                name: "James Turner"
            )
        ),
        // Maintenance — first login, needs password change + onboarding + approval
        DemoCredential(
            email: "mech@fleeeos.com",
            password: "Mech@123",
            user: AuthUser(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                email: "mech@fleeeos.com",
                role: .maintenancePersonnel,
                isFirstLogin: true,
                isProfileComplete: false,
                isApproved: false,
                name: "Tom Bradley"
            )
        ),
        // Approved Driver — skips onboarding, goes straight to DriverDashboard
        DemoCredential(
            email: "driver2@fleeeos.com",
            password: "Driver2@123",
            user: AuthUser(
                id: UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!,
                email: "driver2@fleeeos.com",
                role: .driver,
                isFirstLogin: false,
                isProfileComplete: true,
                isApproved: true,
                name: "James Turner"
            )
        ),
        // Approved Maintenance — skips onboarding, goes straight to MaintenanceDashboard
        DemoCredential(
            email: "mech2@fleeeos.com",
            password: "Mech2@123",
            user: AuthUser(
                id: UUID(uuidString: "D0000000-0000-0000-0000-000000000004")!,
                email: "mech2@fleeeos.com",
                role: .maintenancePersonnel,
                isFirstLogin: false,
                isProfileComplete: true,
                isApproved: true,
                name: "Sarah Miller"
            )
        ),
    ]

    // MARK: - Init

    private init() {
        restoreSessionSilently()
    }

    // MARK: - Sign In

    /// Authenticate with email + password.
    /// - Returns: The authenticated user's role for routing.
    func signIn(email: String, password: String) async throws -> UserRole {
        print("🚀 AuthManager.signIn() called — isAuthenticated BEFORE=\(isAuthenticated)")
        #if DEBUG
        print("🔑 [AuthManager.signIn] Called with email: \(email)")
        #endif
        // Simulate a tiny network delay for realism
        try await Task.sleep(for: .milliseconds(800))

        guard let demo = demoUsers.first(where: { $0.email.lowercased() == email.lowercased() }) else {
            throw AuthError.invalidCredentials
        }
        guard demo.password == password else {
            throw AuthError.invalidCredentials
        }

        let user = demo.user

        // Hash password + store credential
        let hashed = CryptoService.hash(password: password)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCredential)

        // Store session
        _ = KeychainService.save(user, forKey: Keys.currentUser)

        // Generate a fake session token so biometric can check for existing session
        let token = UUID().uuidString
        if let tokenData = token.data(using: .utf8) {
            _ = KeychainService.save(tokenData, forKey: Keys.sessionToken)
        }

        currentUser = user
        // NOTE: Do NOT set isAuthenticated here.
        // Credential login must complete 2FA first.
        // isAuthenticated is set only via completeAuthentication() after 2FA succeeds.

        #if DEBUG
        print("🔑 [AuthManager.signIn] Completed. isAuthenticated=\(isAuthenticated) currentUser=\(currentUser?.email ?? "nil")")
        #endif
        print("🚀 AuthManager.signIn() returning — isAuthenticated AFTER=\(isAuthenticated)")

        return user.role
    }

    // MARK: - Complete Authentication (post-2FA)

    /// Called exclusively after successful 2FA verification.
    /// Never call this from signIn() — credentials alone do not authenticate.
    func completeAuthentication() {
        isAuthenticated = true
        #if DEBUG
        print("✅ [AuthManager.completeAuthentication] isAuthenticated = true — 2FA complete")
        #endif
    }

    // MARK: - Sign Out

    func signOut() {
        #if DEBUG
        print("🔑 [AuthManager.signOut] Clearing session")
        #endif
        currentUser = nil
        isAuthenticated = false
        needsReauth = false
        KeychainService.delete(key: Keys.currentUser)
        KeychainService.delete(key: Keys.hashedCredential)
        KeychainService.delete(key: Keys.sessionToken)
        KeychainService.delete(key: Keys.backgroundTS)
    }

    // MARK: - Session Restore

    /// Returns the stored user's role if a session token exists, or nil.
    func restoreSession() -> UserRole? {
        guard hasSessionToken(),
              let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) else {
            return nil
        }
        currentUser = user
        isAuthenticated = true
        #if DEBUG
        print("🔑 [AuthManager.restoreSession] isAuthenticated=true (biometric path)")
        #endif
        return user.role
    }

    /// Check if a session token exists in Keychain (for biometric gate).
    func hasSessionToken() -> Bool {
        KeychainService.load(key: Keys.sessionToken) != nil
    }

    // MARK: - Routing

    func destination(for user: AuthUser) -> AuthDestination {
        switch user.role {
        case .fleetManager:
            return user.isApproved ? .fleetManagerDashboard : .pendingApproval

        case .driver:
            if user.isFirstLogin { return .changePassword }
            if !user.isProfileComplete { return .driverOnboarding }
            if !user.isApproved { return .pendingApproval }
            return .driverDashboard

        case .maintenancePersonnel:
            if user.isFirstLogin { return .changePassword }
            if !user.isProfileComplete { return .maintenanceOnboarding }
            if !user.isApproved { return .pendingApproval }
            return .maintenanceDashboard
        }
    }

    // MARK: - Password Verification (Demo)

    /// Verify a password against the current user's demo credential.
    func verifyDemoPassword(_ password: String) -> Bool {
        guard let email = currentUser?.email else { return false }
        return demoUsers.first(where: { $0.email.lowercased() == email.lowercased() })?.password == password
    }

    // MARK: - OTP

    /// Generate a 6-digit OTP (hardcoded "123456" for demo).
    @discardableResult
    func generateOTP() -> String {
        currentOTP = "123456"
        pendingOTPEmail = currentUser?.email
        print("📧 OTP for \(pendingOTPEmail ?? "unknown"): \(currentOTP)")
        return currentOTP
    }

    /// Verify a submitted OTP code.
    func verifyOTP(_ code: String) -> Bool {
        let match = code == currentOTP
        if match { currentOTP = "" }
        return match
    }

    /// Masked email: first char + "***" + "@" + domain
    var maskedEmail: String {
        guard let email = pendingOTPEmail,
              let atIndex = email.firstIndex(of: "@") else {
            return "***@***.com"
        }
        let firstChar = email.prefix(1)
        let domain = email[atIndex...]
        return "\(firstChar)***\(domain)"
    }

    // MARK: - Password Reset

    /// Request a password reset code for an email address.
    func requestPasswordReset(email: String) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(800))

        guard demoUsers.contains(where: { $0.email.lowercased() == email.lowercased() }) else {
            return false
        }

        pendingOTPEmail = email
        resetOTP = "123456"
        print("📧 Password reset OTP for \(email): \(resetOTP)")
        return true
    }

    /// Reset password using the verification code.
    func resetPassword(code: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(600))

        guard code == resetOTP else {
            throw AuthError.invalidCredentials
        }

        // Hash and store the new password
        let hashed = CryptoService.hash(password: newPassword)
        _ = KeychainService.save(hashed, forKey: Keys.hashedCredential)

        resetOTP = ""
        pendingOTPEmail = nil
    }

    /// Check if an email exists in the demo accounts.
    func emailExists(_ email: String) -> Bool {
        demoUsers.contains(where: { $0.email.lowercased() == email.lowercased() })
    }

    // MARK: - Auto-Lock (5 min background)

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

    // MARK: - Private

    private func restoreSessionSilently() {
        if let user = KeychainService.load(key: Keys.currentUser, as: AuthUser.self) {
            currentUser = user
            // Don't set isAuthenticated — require biometric / password first
        }
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredentials
    case biometricFailed
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Invalid email or password."
        case .biometricFailed:    "Biometric authentication failed."
        case .sessionExpired:     "Your session has expired. Please sign in again."
        }
    }
}
