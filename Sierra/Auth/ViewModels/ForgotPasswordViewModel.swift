import Foundation
import SwiftUI

/// Steps in the Forgot Password flow (Supabase link-based reset).
/// Step 2 (enterCode) is omitted — Supabase sends a magic link, not a 6-digit code.
enum ForgotPasswordStep {
    case enterEmail
    case emailSent    // replace enterCode — user checks email
    case success
}

/// ViewModel for the Forgot Password flow.
/// Supabase Auth uses email magic-links for password reset (not OTP codes).
/// The new password is set via the deep-link callback — not in this view.
@MainActor @Observable
final class ForgotPasswordViewModel {

    // MARK: - Navigation

    var step: ForgotPasswordStep = .enterEmail

    // MARK: - Step 1: Email

    var email: String = ""
    var emailError: String?

    // MARK: - UI State

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Computed

    var maskedEmail: String {
        AuthManager.shared.maskedEmail
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
        _ = await AuthManager.shared.requestPasswordReset(email: trimmed)
        isLoading = false
        // Supabase does not reveal whether the email exists to prevent enumeration.
        // Always show the sent step — the user sees a neutral message.
        withAnimation(.easeInOut(duration: 0.3)) {
            step = .emailSent
        }
    }

    // MARK: - Navigation

    func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .emailSent:
                step = .enterEmail
            default:
                break
            }
        }
    }

    /// Allow user to resend the reset email without going back.
    func resendResetEmail() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        _ = await AuthManager.shared.requestPasswordReset(email: trimmed)
        isLoading = false
    }
}
