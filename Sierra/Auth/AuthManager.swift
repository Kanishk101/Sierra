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
    var isAuthenticated: Bool = false
    var needsReauth: Bool = false

    /// 5-minute auto-lock threshold.
    private let autoLockSeconds: TimeInterval = 300

    // MARK: - Hardcoded Admin (dev/demo)

    private struct DemoCredential {
        let email: String
        let password: String
        let user: AuthUser
    }

    private let demoUsers: [DemoCredential] = [
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
        )
    ]

    // MARK: - Init

    private init() {
        restoreSessionSilently()
    }

    // MARK: - Sign In

    /// Authenticate with email + password.
    /// - Returns: The authenticated user's role for routing.
    func signIn(email: String, password: String) async throws -> UserRole {
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
        isAuthenticated = true

        return user.role
    }

    // MARK: - Sign Out

    func signOut() {
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
