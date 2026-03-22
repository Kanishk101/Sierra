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
        // biometricOn + biometricPrompted moved to BiometricPreference (single canonical keys)
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
    //   1. supabase.auth.signIn() — Supabase Auth validates credentials.
    //   2. sign-in edge function (verify_jwt: true) — fetches staff profile.
    //      JWT payload decoded inside to get user ID — no redundant getUser() call.

    func signIn(email: String, password: String) async throws -> UserRole {
        otpLastSentAt = nil

        #if DEBUG
        let signInStart = Date()
        let t: (String) -> Int = { _ in Int(Date().timeIntervalSince(signInStart) * 1000) }
        print("")
        print("🔐 [AuthManager.signIn] ════════════════════════════════════════")
        print("🔐 [AuthManager.signIn] ▶ T+0ms: Starting signIn for \(email)")
        print("🔐 [AuthManager.signIn] ────────────────────────────────────────")
        #endif

        // ── STEP 1: Supabase Auth credential check ─────────────────────────
        #if DEBUG
        print("🔐 [AuthManager.signIn] T+\(t("s1"))ms: STEP 1 — supabase.auth.signIn() START")
        let step1Start = Date()
        #endif

        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            #if DEBUG
            let step1ms = Int(Date().timeIntervalSince(step1Start) * 1000)
            print("🔐 [AuthManager.signIn] ❌ T+\(t("s1e"))ms: STEP 1 FAILED in \(step1ms)ms")
            print("🔐 [AuthManager.signIn] ❌ Error type : \(type(of: error))")
            print("🔐 [AuthManager.signIn] ❌ Error full : \(error)")
            print("🔐 [AuthManager.signIn] ❌ Localized  : \(error.localizedDescription)")
            #endif
            throw AuthError.invalidCredentials
        }

        #if DEBUG
        let step1ms = Int(Date().timeIntervalSince(step1Start) * 1000)
        print("🔐 [AuthManager.signIn] ✅ T+\(t("s1ok"))ms: STEP 1 succeeded in \(step1ms)ms")

        // Inspect the session immediately after signIn()
        print("🔐 [AuthManager.signIn] 📋 Inspecting Supabase session after signIn...")
        do {
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            let tokenParts = accessToken.split(separator: ".").map(String.init)
            print("🔐 [AuthManager.signIn] 📋 Session user ID  : \(session.user.id)")
            print("🔐 [AuthManager.signIn] 📋 Session user email: \(session.user.email ?? "nil")")
            print("🔐 [AuthManager.signIn] 📋 Access token length: \(accessToken.count) chars")
            print("🔐 [AuthManager.signIn] 📋 Access token parts (valid=3): \(tokenParts.count)")
            print("🔐 [AuthManager.signIn] 📋 Access token prefix [0..39]: \(String(accessToken.prefix(40)))...")
            if tokenParts.count == 3 {
                // Decode the JWT payload to show role/sub
                if let payloadData = Data(base64Encoded: tokenParts[1].padding(
                        toLength: ((tokenParts[1].count + 3) / 4) * 4,
                        withPad: "=", startingAt: 0)) {
                    if let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                        print("🔐 [AuthManager.signIn] 📋 JWT.sub (user ID): \(payloadJSON["sub"] ?? "<MISSING>")")
                        print("🔐 [AuthManager.signIn] 📋 JWT.role         : \(payloadJSON["role"] ?? "<MISSING>")")
                        print("🔐 [AuthManager.signIn] 📋 JWT.iss          : \(payloadJSON["iss"] ?? "<MISSING>")")
                        if let exp = payloadJSON["exp"] as? Double {
                            let expDate = Date(timeIntervalSince1970: exp)
                            print("🔐 [AuthManager.signIn] 📋 JWT.exp          : \(expDate) (in \(Int(exp - Date().timeIntervalSince1970))s)")
                        }
                    } else {
                        print("🔐 [AuthManager.signIn] ⚠️ Could not parse JWT payload JSON")
                    }
                } else {
                    print("🔐 [AuthManager.signIn] ⚠️ Could not base64-decode JWT payload")
                }
            }
            print("🔐 [AuthManager.signIn] 📋 Refresh token present: \(!session.refreshToken.isEmpty)")
            print("🔐 [AuthManager.signIn] 📋 Token type: \(session.tokenType)")
        } catch {
            print("🔐 [AuthManager.signIn] ⚠️ WARNING: Could not retrieve session after signIn!")
            print("🔐 [AuthManager.signIn] ⚠️ Error: \(error)")
        }
        print("🔐 [AuthManager.signIn] ────────────────────────────────────────")
        #endif

        // ── STEP 2: Wait for JWT propagation ──────────────────────────────
        #if DEBUG
        print("🔐 [AuthManager.signIn] T+\(t("s2"))ms: STEP 2 — sleeping 500ms for JWT propagation")
        #endif

        try await Task.sleep(for: .milliseconds(500))

        #if DEBUG
        print("🔐 [AuthManager.signIn] T+\(t("s2e"))ms: STEP 2 — sleep complete")
        print("🔐 [AuthManager.signIn] ────────────────────────────────────────")
        #endif

        // ── STEP 3: Fetch staff profile via edge function ─────────────────
        struct StaffProfile: Decodable {
            let id: String; let email: String; let name: String?
            let role: String; let is_first_login: Bool?
            let is_profile_complete: Bool?; let is_approved: Bool?
            let rejection_reason: String?; let phone: String?; let created_at: String?
        }

        #if DEBUG
        print("🔐 [AuthManager.signIn] T+\(t("s3"))ms: STEP 3 — invoking 'sign-in' edge function")
        let edgeFnStart = Date()
        // Re-check session one more time right before the edge function call
        print("🔐 [AuthManager.signIn] 🔍 Session check immediately before functions.invoke():")
        do {
            let session = try await supabase.auth.session
            print("🔐 [AuthManager.signIn] 🔍   ✅ Session exists: userId=\(session.user.id)")
            print("🔐 [AuthManager.signIn] 🔍   Token prefix: \(String(session.accessToken.prefix(30)))...")
        } catch {
            print("🔐 [AuthManager.signIn] 🔍   ❌ NO SESSION at edge function call time!")
            print("🔐 [AuthManager.signIn] 🔍   Error: \(error)")
        }
        #endif

        let profile: StaffProfile
        do {
            profile = try await supabase.functions.invoke("sign-in", options: FunctionInvokeOptions())
            #if DEBUG
            let edgeFnMs = Int(Date().timeIntervalSince(edgeFnStart) * 1000)
            print("🔐 [AuthManager.signIn] ✅ T+\(t("s3ok"))ms: Edge fn succeeded in \(edgeFnMs)ms")
            print("🔐 [AuthManager.signIn] 📋 Profile id    : \(profile.id)")
            print("🔐 [AuthManager.signIn] 📋 Profile role  : \(profile.role)")
            print("🔐 [AuthManager.signIn] 📋 First login   : \(profile.is_first_login ?? true)")
            print("🔐 [AuthManager.signIn] 📋 Approved      : \(profile.is_approved ?? false)")
            print("🔐 [AuthManager.signIn] 📋 Profile complete: \(profile.is_profile_complete ?? false)")
            print("🔐 [AuthManager.signIn] ────────────────────────────────────────")
            #endif
        } catch {
            #if DEBUG
            let edgeFnMs = Int(Date().timeIntervalSince(edgeFnStart) * 1000)
            print("🔐 [AuthManager.signIn] ❌ T+\(t("s3e"))ms: Edge fn FAILED in \(edgeFnMs)ms")
            print("🔐 [AuthManager.signIn] ❌ Error type     : \(type(of: error))")
            print("🔐 [AuthManager.signIn] ❌ Error full     : \(error)")
            print("🔐 [AuthManager.signIn] ❌ Localized      : \(error.localizedDescription)")
            // Try to extract HTTP status code if the SDK wraps it
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                print("🔐 [AuthManager.signIn] ❌ Error field [\(child.label ?? "?")]: \(child.value)")
            }
            print("🔐 [AuthManager.signIn] ════════════════════════════════════════")
            #endif
            try? await supabase.auth.signOut()
            throw AuthError.edgeFunctionFailed(error.localizedDescription)
        }

        guard let userId = UUID(uuidString: profile.id) else {
            #if DEBUG
            print("🔐 [AuthManager.signIn] ❌ Could not parse profile.id as UUID: \(profile.id)")
            #endif
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

        #if DEBUG
        print("🔐 [AuthManager.signIn] ✅ T+\(t("done"))ms: signIn() complete — role=\(user.role.rawValue)")
        print("🔐 [AuthManager.signIn] ════════════════════════════════════════")
        print("")
        #endif

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
        #if DEBUG
        print("🔐 [AuthManager.signOut] Signing out user: \(currentUser?.email ?? "unknown")")
        #endif
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
        // Biometric preference is intentionally NOT cleared on signOut —
        // keeping it enables the biometric button to reappear on next login.
        // See BiometricPreference.clearSessionData() for rationale.
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
    case edgeFunctionFailed(String)
    case networkError(String)

    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials): return true
        case (.userNotFound, .userNotFound): return true
        case (.biometricFailed, .biometricFailed): return true
        case (.sessionExpired, .sessionExpired): return true
        case (.createStaffFailed, .createStaffFailed): return true
        case (.accountSuspended, .accountSuspended): return true
        case (.otpExpired, .otpExpired): return true
        case (.otpInvalid, .otpInvalid): return true
        case (.edgeFunctionFailed(let a), .edgeFunctionFailed(let b)): return a == b
        case (.networkError(let a), .networkError(let b)): return a == b
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:        return "Invalid email or password."
        case .userNotFound:              return "Account not found. Contact your fleet administrator."
        case .biometricFailed:           return "Biometric authentication failed."
        case .sessionExpired:            return "Your session has expired. Please sign in again."
        case .createStaffFailed:         return "Failed to create staff account. Please try again."
        case .accountSuspended:          return "Your account has been suspended. Contact your fleet manager."
        case .otpExpired:                return "The verification code has expired. Please request a new one."
        case .otpInvalid:                return "Incorrect verification code. Please check and try again."
        case .edgeFunctionFailed(let d): return "Profile fetch failed (\(d)). Please try again."
        case .networkError(let d):       return "Connection error: \(d)"
        }
    }
}
