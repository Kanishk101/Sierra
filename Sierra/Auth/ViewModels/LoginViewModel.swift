import Foundation
import SwiftUI

@Observable
final class LoginViewModel {

    // MARK: - Form Fields

    var email: String = ""
    var password: String = ""
    var isPasswordVisible: Bool = false

    // MARK: - OTP Service

    var otpService: OTPVerificationServiceProtocol = AuthManagerOTPVerificationService()

    // MARK: - Auth State

    var authState: AuthState = .idle

    enum AuthState: Equatable {
        case idle
        case loading
        case requiresTwoFactor(context: TwoFactorContext)
        case authenticated(destination: AuthDestination)
        case error(String)

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading): return true
            case (.requiresTwoFactor(let a), .requiresTwoFactor(let b)): return a.userID == b.userID
            case (.authenticated(let a), .authenticated(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Biometric
    // FIX: was guarding on hasSessionToken() which is always false after signOut().
    // The session token check is irrelevant here — we need to know if we have a
    // cached user identity (currentUser) and that the user previously opted in.
    // hasSessionToken() is only meaningful inside the app (auto-lock reauth),
    // not on the LoginView login screen.

    var showBiometricButton: Bool {
        BiometricManager.shared.canUseBiometrics()
            && AuthManager.shared.currentUser != nil
            && AuthManager.shared.hasCompletedFullAuth
            && BiometricPreference.isEnabled
    }

    var biometricLabel: String { "Sign in with \(BiometricManager.shared.biometricDisplayName)" }
    var biometricIcon: String  { BiometricManager.shared.biometricIconName }

    // MARK: - Validation Errors

    var emailError: String?
    var passwordError: String?

    // MARK: - Computed

    var isLoading: Bool { authState == .loading }

    var errorMessage: String? {
        if case .error(let msg) = authState { return msg }
        return nil
    }

    // MARK: - Sign In

    @MainActor
    func signIn() async {
        emailError = nil
        passwordError = nil
        guard validate() else { return }
        authState = .loading

        #if DEBUG
        print("")
        print("🖥️ [LoginViewModel.signIn] ════════════════════════════════════════")
        print("🖥️ [LoginViewModel.signIn] ▶ Calling AuthManager.signIn()")
        let vmStart = Date()
        #endif

        do {
            let role = try await AuthManager.shared.signIn(email: email, password: password)
            let user = AuthManager.shared.currentUser

            #if DEBUG
            let vmMs = Int(Date().timeIntervalSince(vmStart) * 1000)
            print("🖥️ [LoginViewModel.signIn] ✅ AuthManager.signIn() succeeded in \(vmMs)ms")
            print("🖥️ [LoginViewModel.signIn] 📋 role=\(role.rawValue), user=\(user?.email ?? "nil")")
            #endif

            let destination: AuthDestination
            if let user {
                destination = AuthManager.shared.destination(for: user)
            } else {
                destination = defaultDestination(for: role)
            }

            #if DEBUG
            print("🖥️ [LoginViewModel.signIn] 📋 destination=\(destination)")
            #endif

            // 2FA is only required when the user is about to enter a real dashboard.
            let needsTwoFactor: Bool
            switch destination {
            case .fleetManagerDashboard, .driverDashboard, .maintenanceDashboard:
                needsTwoFactor = true
            default:
                needsTwoFactor = false
            }

            if !needsTwoFactor {
                #if DEBUG
                print("🖥️ [LoginViewModel.signIn] ⏩ Skipping 2FA (non-dashboard destination)")
                #endif
                AuthManager.shared.completeAuthentication()
                return
            }

            // Dashboard-bound: generate OTP.
            // Data loading happens only after full auth success
            // (AuthManager.completeAuthentication), to avoid duplicate heavy
            // network work while still on the 2FA screen.
            AuthManager.shared.generateOTP()

            let context = TwoFactorContext(
                userID: user?.id.uuidString ?? UUID().uuidString,
                role: role,
                method: .email,
                maskedDestination: AuthManager.shared.maskedEmail,
                sessionToken: "",
                authDestination: destination
            )

            #if DEBUG
            print("🖥️ [LoginViewModel.signIn] ✅ Transitioning to 2FA screen")
            print("🖥️ [LoginViewModel.signIn] ════════════════════════════════════════")
            print("")
            #endif

            authState = .requiresTwoFactor(context: context)

        } catch let authError as AuthError {
            #if DEBUG
            let vmMs = Int(Date().timeIntervalSince(vmStart) * 1000)
            print("🖥️ [LoginViewModel.signIn] ❌ AuthError after \(vmMs)ms: \(authError)")
            print("🖥️ [LoginViewModel.signIn] ❌ Description: \(authError.localizedDescription)")
            print("🖥️ [LoginViewModel.signIn] ════════════════════════════════════════")
            print("")
            #endif
            authState = .error(authError.localizedDescription)

        } catch {
            #if DEBUG
            let vmMs = Int(Date().timeIntervalSince(vmStart) * 1000)
            print("🖥️ [LoginViewModel.signIn] ❌ Unexpected error after \(vmMs)ms")
            print("🖥️ [LoginViewModel.signIn] ❌ Type: \(type(of: error))")
            print("🖥️ [LoginViewModel.signIn] ❌ Full: \(error)")
            print("🖥️ [LoginViewModel.signIn] ❌ Localized: \(error.localizedDescription)")
            print("🖥️ [LoginViewModel.signIn] ════════════════════════════════════════")
            print("")
            #endif
            authState = .error("Sign-in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Biometric Sign In
    // FIX: removed hasSessionToken() guard — the session token is cleared by
    // signOut() so it is always absent on the login screen. currentUser is
    // persisted in the Keychain independently and is the correct identity check.

    @MainActor
    func biometricSignIn() async {
        authState = .loading

        do {
            try await BiometricManager.shared.authenticate()

            guard let user = AuthManager.shared.currentUser else {
                authState = .error("No cached session. Please sign in with your password.")
                AuthManager.shared.signOut()
                return
            }

            // completeAuthentication() performs the role-specific data load.
            AuthManager.shared.completeAuthentication()
            AuthManager.shared.reauthCompleted()

            // CRITICAL: explicitly set .authenticated so LoginView's onChange
            // actually navigates — setting .idle did nothing when isAuthenticated
            // was already true, causing the Face ID loop.
            let dest = AuthManager.shared.destination(for: user)
            authState = .authenticated(destination: dest)

        } catch {
            if let bioError = error as? BiometricError {
                authState = bioError == .userCancelled
                    ? .idle
                    : .error(bioError.errorDescription ?? "Biometric authentication failed.")
            } else {
                authState = .error("Biometric authentication failed.")
            }
        }
    }

    // MARK: - 2FA callbacks

    func twoFactorCompleted() {
        guard case .requiresTwoFactor(let ctx) = authState else { return }
        authState = .authenticated(destination: ctx.authDestination)
    }

    func twoFactorCancelled() {
        AuthManager.shared.signOut()
        authState = .idle
    }

    func dismissError() {
        withAnimation(.easeOut(duration: 0.2)) { authState = .idle }
    }

    // MARK: - Private

    private func validate() -> Bool {
        var isValid = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            emailError = "Email is required"; isValid = false
        } else if !isValidEmail(trimmedEmail) {
            emailError = "Enter a valid email address"; isValid = false
        }
        if password.isEmpty { passwordError = "Password is required"; isValid = false }
        return isValid
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }

    private func defaultDestination(for role: UserRole) -> AuthDestination {
        switch role {
        case .fleetManager:         return .fleetManagerDashboard
        case .driver:               return .driverDashboard
        case .maintenancePersonnel: return .maintenanceDashboard
        }
    }
}
