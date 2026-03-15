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

    var showBiometricButton: Bool {
        BiometricManager.shared.canUseBiometrics()
            && AuthManager.shared.hasSessionToken()
            && BiometricEnrollmentSheet.isBiometricEnabled()
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

        do {
            let role = try await AuthManager.shared.signIn(email: email, password: password)
            let user = AuthManager.shared.currentUser

            let destination: AuthDestination
            if let user {
                destination = AuthManager.shared.destination(for: user)
            } else {
                destination = defaultDestination(for: role)
            }

            // 2FA is only required when the user is about to enter a real dashboard.
            // Pending, rejected, onboarding, and first-login users skip 2FA entirely
            // and go directly to their respective screens.
            let needsTwoFactor: Bool
            switch destination {
            case .fleetManagerDashboard, .driverDashboard, .maintenanceDashboard:
                needsTwoFactor = true
            default:
                needsTwoFactor = false
            }

            if !needsTwoFactor {
                // Complete auth immediately — ContentView routes via destination(for:)
                AuthManager.shared.completeAuthentication()
                return
            }

            // Dashboard-bound user: pre-generate OTP (fires SwiftSMTP in background)
            // and start prefetching data. 2FA screen appears instantly.
            AuthManager.shared.generateOTP()

            if let user {
                Task.detached {
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

            let context = TwoFactorContext(
                userID: user?.id.uuidString ?? UUID().uuidString,
                role: role,
                method: .email,
                maskedDestination: AuthManager.shared.maskedEmail,
                sessionToken: "",
                authDestination: destination
            )
            authState = .requiresTwoFactor(context: context)

        } catch {
            authState = .error("Invalid credentials")
        }
    }

    // MARK: - Biometric Sign In
    //
    // FIX: The original implementation called AuthManager.restoreSession() which sets
    // isAuthenticated = true immediately, then set authState = .authenticated on the
    // next tick. This caused two competing navigation systems to fire in rapid succession:
    //   1. ContentView observed isAuthenticated = true → started transitioning LoginView out
    //   2. LoginView.onChange observed .authenticated → tried to present fullScreenCover
    // The fullScreenCover’s parent (LoginView) was already being removed, so it briefly
    // appeared and then collapsed — producing the “flash to dashboard then back to login”.
    //
    // Fix: call completeAuthentication() directly (which sets isAuthenticated = true and
    // starts the data load), then reset authState to .idle. ContentView is the single
    // authority on routing — it sees isAuthenticated = true and transitions cleanly.
    // LoginView never sees .authenticated so it never attempts a competing fullScreenCover.

    @MainActor
    func biometricSignIn() async {
        authState = .loading
        do {
            try await BiometricManager.shared.authenticate()

            // Verify a valid persisted session and user exist.
            // currentUser is already populated by restoreSessionSilently() at AuthManager init.
            guard AuthManager.shared.hasSessionToken(),
                  AuthManager.shared.currentUser != nil else {
                authState = .error("Session expired. Please sign in with your password.")
                AuthManager.shared.signOut()
                return
            }

            // completeAuthentication() sets isAuthenticated = true and kicks off the
            // role-appropriate data load. ContentView observes isAuthenticated and routes
            // directly to the dashboard — no fullScreenCover race condition.
            AuthManager.shared.completeAuthentication()

            // Reset to idle so LoginView’s onChange does nothing further.
            authState = .idle

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
