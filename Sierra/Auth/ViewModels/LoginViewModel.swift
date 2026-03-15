import Foundation
import SwiftUI

@Observable
final class LoginViewModel {

    // MARK: - Form Fields

    var email: String = ""
    var password: String = ""
    var isPasswordVisible: Bool = false

    // MARK: - OTP Service

    /// Production OTP service injected into TwoFactorViewModel.
    /// Override in tests with a MockOTPVerificationService.
    var otpService: OTPVerificationServiceProtocol = AuthManagerOTPVerificationService()

    // MARK: - Auth State (single source of truth)

    /// Replaces the old `loginSuccess` Bool + `authDestination` + `usedBiometric`.
    /// Navigation is driven entirely by this enum.
    var authState: AuthState = .idle

    enum AuthState: Equatable {
        case idle
        case loading
        case requiresTwoFactor(context: TwoFactorContext)
        case authenticated(destination: AuthDestination)
        case error(String)

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading):
                return true
            case (.requiresTwoFactor(let a), .requiresTwoFactor(let b)):
                return a.userID == b.userID
            case (.authenticated(let a), .authenticated(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Biometric

    var showBiometricButton: Bool {
        BiometricManager.shared.canUseBiometrics()
            && AuthManager.shared.hasSessionToken()
            && BiometricEnrollmentSheet.isBiometricEnabled()
    }

    var biometricLabel: String {
        "Sign in with \(BiometricManager.shared.biometricDisplayName)"
    }

    var biometricIcon: String {
        BiometricManager.shared.biometricIconName
    }

    // MARK: - Validation Errors

    var emailError: String?
    var passwordError: String?

    // MARK: - Computed

    var isLoading: Bool { authState == .loading }

    var errorMessage: String? {
        if case .error(let msg) = authState { return msg }
        return nil
    }

    // MARK: - Sign In (Credential → 2FA required)

    @MainActor
    func signIn() async {
        print("🚀 LoginViewModel.signIn() called")
        #if DEBUG
        print("📋 [LoginViewModel.signIn] Called")
        #endif
        emailError = nil
        passwordError = nil

        guard validate() else { return }

        authState = .loading

        do {
            let role = try await AuthManager.shared.signIn(email: email, password: password)
            #if DEBUG
            print("📋 [LoginViewModel.signIn] AuthManager.signIn returned")
            print("📋 [LoginViewModel.signIn] AuthManager.isAuthenticated = \(AuthManager.shared.isAuthenticated)")
            print("📋 [LoginViewModel.signIn] AuthManager.currentUser = \(AuthManager.shared.currentUser?.email ?? "nil")")
            #endif
            let user = AuthManager.shared.currentUser

            // Resolve destination from user profile state
            let destination: AuthDestination
            if let user {
                destination = AuthManager.shared.destination(for: user)
            } else {
                destination = defaultDestination(for: role)
            }

            // First-login users skip 2FA — complete auth immediately so ContentView
            // naturally routes to ForcePasswordChangeView via its destination logic.
            // This avoids the fullScreenCover race condition that caused a white screen.
            if user?.isFirstLogin == true {
                #if DEBUG
                print("📋 [LoginViewModel.signIn] First login — completing auth, ContentView will route to password change")
                #endif
                AuthManager.shared.completeAuthentication()
                return
            }

            // Build 2FA context — do NOT navigate to dashboard yet.
            let context = TwoFactorContext(
                userID: user?.id.uuidString ?? UUID().uuidString,
                role: role,
                method: .email,
                maskedDestination: AuthManager.shared.maskedEmail,
                sessionToken: "",
                authDestination: destination
            )

            // Prefetch dashboard data while the user is on the 2FA screen.
            // By the time they verify the OTP and land on the dashboard,
            // AppDataStore will already be populated — no 0→value flicker.
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

            // Pre-generate OTP and fire SwiftSMTP NOW — before the screen appears.
            // service.sendOTP() returns instantly (no re-generate), so the 2FA screen
            // shows immediately in .awaitingEntry with no SMTP lag.
            AuthManager.shared.generateOTP()

            // This triggers TwoFactorView — NOT the dashboard
            #if DEBUG
            print("📋 [LoginViewModel.signIn] About to set authState = .requiresTwoFactor")
            #endif
            authState = .requiresTwoFactor(context: context)
            #if DEBUG
            print("📋 [LoginViewModel.signIn] authState is now: \(authState)")
            #endif

        } catch {
            authState = .error("Invalid credentials")
        }
    }

    // MARK: - Biometric Sign In (skips 2FA entirely)

    @MainActor
    func biometricSignIn() async {
        authState = .loading

        // Start prefetching dashboard data immediately while the biometric prompt shows.
        // AuthManager.currentUser is already restored from Keychain at init via
        // restoreSessionSilently(), so the role is available without any async work.
        // Face ID/Touch ID takes ~1–2s — by the time it resolves, data is ready.
        if let existingUser = AuthManager.shared.currentUser {
            Task.detached {
                switch existingUser.role {
                case .fleetManager:
                    await AppDataStore.shared.loadAll()
                case .driver:
                    await AppDataStore.shared.loadDriverData(driverId: existingUser.id)
                case .maintenancePersonnel:
                    await AppDataStore.shared.loadMaintenanceData(staffId: existingUser.id)
                }
            }
        }

        do {
            try await BiometricManager.shared.authenticate()
            if let _ = AuthManager.shared.restoreSession(),
               let user = AuthManager.shared.currentUser {
                let destination = AuthManager.shared.destination(for: user)
                // Biometric → go straight to dashboard, skip 2FA
                authState = .authenticated(destination: destination)
            } else {
                authState = .error("Session expired. Please sign in with your password.")
                AuthManager.shared.signOut()
            }
        } catch {
            if let bioError = error as? BiometricError {
                switch bioError {
                case .userCancelled:
                    authState = .idle
                default:
                    authState = .error(bioError.errorDescription ?? "Biometric authentication failed.")
                }
            } else {
                authState = .error("Biometric authentication failed.")
            }
        }
    }

    // MARK: - 2FA Completed

    /// Called by TwoFactorView when OTP verification succeeds.
    func twoFactorCompleted() {
        guard case .requiresTwoFactor(let ctx) = authState else { return }
        authState = .authenticated(destination: ctx.authDestination)
    }

    /// Called when user cancels 2FA (back to sign in).
    func twoFactorCancelled() {
        AuthManager.shared.signOut()
        authState = .idle
    }

    // MARK: - Dismiss Error

    func dismissError() {
        withAnimation(.easeOut(duration: 0.2)) {
            authState = .idle
        }
    }

    // MARK: - Private

    private func validate() -> Bool {
        var isValid = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !isValidEmail(trimmedEmail) {
            emailError = "Enter a valid email address"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        }

        return isValid
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func defaultDestination(for role: UserRole) -> AuthDestination {
        switch role {
        case .fleetManager:         return .fleetManagerDashboard
        case .driver:               return .driverDashboard
        case .maintenancePersonnel: return .maintenanceDashboard
        }
    }
}
