import Foundation
import SwiftUI

@Observable
final class LoginViewModel {

    // MARK: - Form Fields

    var email: String = ""
    var password: String = ""
    var isPasswordVisible: Bool = false

    // MARK: - UI State

    var isLoading: Bool = false
    var errorMessage: String?
    var loginSuccess: Bool = false
    var authDestination: AuthDestination?

    /// `true` when the current successful login used biometrics (skip 2FA).
    var usedBiometric: Bool = false

    // MARK: - Biometric

    /// Show the Face ID / Touch ID button only when:
    ///  1. Device hardware supports biometrics
    ///  2. User previously opted-in via the enrollment sheet
    ///  3. There is an existing session token to restore
    var showBiometricButton: Bool {
        BiometricManager.shared.canUseBiometrics()
            && BiometricEnrollmentSheet.isBiometricEnabled()
            && AuthManager.shared.hasSessionToken()
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

    // MARK: - Sign In (Credential)

    @MainActor
    func signIn() async {
        emailError = nil
        passwordError = nil
        errorMessage = nil

        guard validate() else { return }

        isLoading = true
        usedBiometric = false

        do {
            let role = try await AuthManager.shared.signIn(email: email, password: password)
            isLoading = false
            if let user = AuthManager.shared.currentUser {
                authDestination = AuthManager.shared.destination(for: user)
            } else {
                authDestination = defaultDestination(for: role)
            }
            loginSuccess = true
        } catch {
            isLoading = false
            errorMessage = "Invalid credentials"
        }
    }

    // MARK: - Biometric Sign In (skips 2FA)

    @MainActor
    func biometricSignIn() async {
        errorMessage = nil
        isLoading = true

        do {
            try await BiometricManager.shared.authenticate()
            // Biometric succeeded — restore the existing session
            if let _ = AuthManager.shared.restoreSession(),
               let user = AuthManager.shared.currentUser {
                isLoading = false
                usedBiometric = true
                authDestination = AuthManager.shared.destination(for: user)
                loginSuccess = true
            } else {
                isLoading = false
                errorMessage = "Session expired. Please sign in with your password."
                AuthManager.shared.signOut()
            }
        } catch {
            isLoading = false
            if let bioError = error as? BiometricError {
                switch bioError {
                case .userCancelled:
                    break // User cancelled, don't show error
                default:
                    errorMessage = bioError.errorDescription
                }
            } else {
                errorMessage = "Biometric authentication failed."
            }
        }
    }

    // MARK: - Dismiss Error

    func dismissError() {
        withAnimation(.easeOut(duration: 0.2)) {
            errorMessage = nil
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
