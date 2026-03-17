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

// MARK: - StaffLoginRow (local Decodable for signIn query)

private struct StaffLoginRow: Decodable {
    let id: String
    let email: String
    let password: String
    let role: String
    let name: String?
    let phone: String?
    let is_first_login: Bool?
    let is_profile_complete: Bool?
    let is_approved: Bool?
    let rejection_reason: String?
    let created_at: String?
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
    // Vinayak pattern: query staff_members by email, compare password column directly.

    func signIn(email: String, password: String) async throws -> UserRole {
        // Reset OTP cooldown for each fresh login attempt so switching between
        // test accounts doesn't silently skip OTP generation.
        otpLastSentAt = nil

        let rows: [StaffLoginRow] = try await supabase
            .from("staff_members")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            throw AuthError.invalidCredentials
        }

        guard row.password == password else {
            throw AuthError.invalidCredentials
        }

        let user = AuthUser(
            id: UUID(uuidString: row.id) ?? UUID(),
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
        // NOTE: Do NOT set isAuthenticated here - 2FA must complete first
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
            // Rejected: profile complete, not approved, has a rejection reason
            if !user.isApproved {
                if let reason = user.rejectionReason, !reason.isEmpty {
                    return .rejected
                }
                return .pendingApproval
            }
            return .driverDashboard

        case .maintenancePersonnel:
            if user.isFirstLogin        { return .changePassword }
            if !user.isProfileComplete  { return .maintenanceOnboarding }
            if !user.isApproved {
                if let reason = user.rejectionReason, !reason.isEmpty {
                    return .rejected
                }
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
        // Rate-limit: ignore if an OTP was already sent within the cooldown window.
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
            Task.detached {
                await sendEmail(userEmail: email, otp: otp)
            }
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

        struct Payload: Encodable {
            let password: String
            let is_first_login: Bool
        }

        try await supabase
            .from("staff_members")
            .update(Payload(password: newPassword, is_first_login: false))
            .eq("id", value: user.id.uuidString)
            .execute()

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
        // Rate-limit: ignore duplicate requests within the cooldown window.
        if let last = resetOTPLastSentAt, Date().timeIntervalSince(last) < otpCooldownSeconds {
            print("[AuthManager] requestPasswordReset skipped - cooldown active")
            return true  // return true so UI advances normally (OTP was already sent)
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
            sendResetEmail(userEmail: email, otp: otp)
            return true
        } catch {
            return false
        }
    }

    func resetPassword(code: String, newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
        guard code == resetOTP else { throw AuthError.invalidCredentials }
        guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }

        try await supabase
            .from("staff_members")
            .update(["password": newPassword])
            .eq("email", value: email)
            .execute()

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
