import Foundation
import SwiftUI

/// Steps in the Forgot Password flow.
enum ForgotPasswordStep {
    case enterEmail
    case enterCode
    case newPassword
    case success
}

/// ViewModel for the 3-step forgot password flow.
@MainActor @Observable
final class ForgotPasswordViewModel {

    // MARK: - Navigation

    var step: ForgotPasswordStep = .enterEmail

    // MARK: - Step 1: Email

    var email: String = ""
    var emailError: String?

    // MARK: - Step 2: OTP

    var digits: [String] = Array(repeating: "", count: 6)
    var focusedIndex: Int? = 0
    var codeError: String?

    // MARK: - Step 3: New Password

    var newPassword: String = ""
    var confirmPassword: String = ""

    // MARK: - UI State

    var isLoading: Bool = false
    var errorMessage: String?
    var showErrorAlert: Bool = false

    // MARK: - Computed

    var maskedEmail: String {
        AuthManager.shared.maskedEmail
    }

    var strength: PasswordStrength {
        PasswordStrength.evaluate(newPassword)
    }

    var hasMinLength: Bool { newPassword.count >= 8 }
    var hasUppercase: Bool { newPassword.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasNumber: Bool    { newPassword.range(of: "[0-9]", options: .regularExpression) != nil }
    var hasSpecialChar: Bool { newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil }

    var allRequirementsMet: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    var canSubmitNewPassword: Bool {
        allRequirementsMet && passwordsMatch && !isLoading && !newPasswordSameAsOld
    }

    /// True if the new password is the same as the existing password for the email entered.
    /// Compares against the Keychain stored hash (populated from the last sign-in for this account).
    var newPasswordSameAsOld: Bool {
        guard !newPassword.isEmpty else { return false }
        // Check against Keychain stored hash if available
        if let stored = KeychainService.load(
            key: "com.sierra.hashedCredential",
            as: CryptoService.HashedCredential.self
        ) {
            return CryptoService.verify(password: newPassword, credential: stored)
        }
        return false
    }

    var newPasswordSameAsStored: Bool { newPasswordSameAsOld }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Passwords don't match"
    }

    var newPasswordError: String? {
        guard !newPassword.isEmpty else { return nil }
        return newPasswordSameAsStored ? "New password must differ from your current password" : nil
    }

    // MARK: - Step 1 Action

    func sendResetCode() async {
        emailError = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            emailError = "Email is required"
            return
        }
        guard trimmed.contains("@") && trimmed.contains(".") else {
            emailError = "Enter a valid email address"
            return
        }

        isLoading = true
        let found = await AuthManager.shared.requestPasswordReset(email: trimmed)
        isLoading = false

        if found {
            withAnimation(.easeInOut(duration: 0.3)) {
                step = .enterCode
            }
        } else {
            emailError = "No account found with this email"
        }
    }

    // MARK: - Step 2 Action

    func verifyResetCode() {
        let code = digits.joined()
        guard code.count == 6 else {
            codeError = "Enter all 6 digits"
            return
        }

        // Verify against the reset OTP stored in AuthManager
        if AuthManager.shared.verifyResetOTP(code) {
            codeError = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                step = .newPassword
            }
        } else {
            codeError = "Incorrect code. Please try again."
        }
    }

    // MARK: - Step 3 Action

    func resetPassword() async {
        guard canSubmitNewPassword else { return }
        isLoading = true
        errorMessage = nil
        showErrorAlert = false

        do {
            try await AuthManager.shared.resetPassword(
                code: digits.joined(),
                newPassword: newPassword
            )
            isLoading = false
            withAnimation(.easeInOut(duration: 0.3)) {
                step = .success
            }
        } catch let error as AuthError {
            isLoading = false
            // Prioritize the errorDescription from the AuthError itself,
            // which now includes direct messages from the edge function.
            errorMessage = error.errorDescription ?? "Failed to reset password. Please try again."
            showErrorAlert = true
        } catch {
            isLoading = false
            errorMessage = "Failed to reset password. Please try again."
            showErrorAlert = true
        }
    }

    // MARK: - Navigation

    func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .enterCode:
                step = .enterEmail
            case .newPassword:
                step = .enterCode
            default:
                break
            }
        }
    }
}
