import Foundation

// OTP is pre-generated in LoginViewModel.signIn() before the 2FA screen appears.
// sendOTP() returns instantly — no email wait on screen appear.
// resendOTP() generates a fresh OTP and fires a new email via the send-email edge fn.
//
// Attempt tracking:
//   Each instance of this service tracks how many wrong codes have been entered.
//   A new instance is created per login session (LoginViewModel holds it), so the
//   counter resets naturally on each new sign-in.
//   Max 5 attempts before lockout — mirrors the max_attempts column in two_factor_sessions.

final class AuthManagerOTPVerificationService: OTPVerificationServiceProtocol {

    // MARK: - Attempt Tracking

    private var attemptsUsed: Int = 0
    private let maxAttempts: Int = 5
    private var lockedUntil: Date?

    // MARK: - sendOTP

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        // OTP was pre-generated in LoginViewModel.signIn() before screen appeared.
        // Do NOT call generateOTP() again — it would overwrite the already-sent OTP.
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }

    // MARK: - verifyOTP

    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
        // Check if currently locked out
        if let lockEnd = lockedUntil, Date() < lockEnd {
            return OTPVerifyResult(
                success: false,
                attemptsRemaining: 0,
                isLocked: true,
                lockUntil: lockEnd,
                fullSessionToken: nil
            )
        }

        let correct = AuthManager.shared.verifyOTP(code)

        if correct {
            attemptsUsed = 0
            lockedUntil = nil
            return OTPVerifyResult(
                success: true,
                attemptsRemaining: nil,
                isLocked: false,
                lockUntil: nil,
                fullSessionToken: "sierra_session_\(UUID().uuidString)"
            )
        } else {
            attemptsUsed += 1
            let remaining = max(0, maxAttempts - attemptsUsed)

            if remaining == 0 {
                // Lock for 15 minutes after exhausting all attempts
                let lockEnd = Date().addingTimeInterval(15 * 60)
                lockedUntil = lockEnd
                return OTPVerifyResult(
                    success: false,
                    attemptsRemaining: 0,
                    isLocked: true,
                    lockUntil: lockEnd,
                    fullSessionToken: nil
                )
            }

            return OTPVerifyResult(
                success: false,
                attemptsRemaining: remaining,
                isLocked: false,
                lockUntil: nil,
                fullSessionToken: nil
            )
        }
    }

    // MARK: - resendOTP

    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        // Resend: generate a fresh OTP and fire a new email via the send-email edge function.
        // Also reset the attempt counter — a new code means a fresh session.
        attemptsUsed = 0
        lockedUntil = nil
        _ = AuthManager.shared.generateOTP()
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }
}
