import Foundation

// MARK: - SupabaseOTPVerificationService
// Production implementation of OTPVerificationServiceProtocol using Supabase Auth email OTP.
// Drop-in replacement for MockOTPVerificationService — injected via TwoFactorViewModel init.

final class SupabaseOTPVerificationService: OTPVerificationServiceProtocol {

    /// OTP expiry window Supabase uses (10 minutes). Used locally for countdown UI only.
    private let otpExpirySeconds: TimeInterval = 600

    /// Resend cooldown — prevents spamming the OTP endpoint.
    private let resendCooldownSeconds: TimeInterval = 60

    // MARK: - Send OTP

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        guard !context.userID.isEmpty else {
            throw AuthError.userNotFound
        }
        // Retrieve email from AuthManager (currentUser was populated at signIn)
        guard let email = AuthManager.shared.currentUser?.email else {
            throw AuthError.userNotFound
        }
        try await SupabaseAuthService.sendOTP(email: email)
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(otpExpirySeconds),
            cooldownUntil: Date().addingTimeInterval(resendCooldownSeconds)
        )
    }

    // MARK: - Verify OTP

    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
        guard let email = AuthManager.shared.currentUser?.email else {
            throw AuthError.userNotFound
        }
        do {
            try await SupabaseAuthService.verifyOTP(email: email, token: code)
            // Success — no session token needed (Supabase SDK manages the session internally)
            return OTPVerifyResult(
                success: true,
                attemptsRemaining: nil,
                isLocked: false,
                lockUntil: nil,
                fullSessionToken: "supabase_session"
            )
        } catch let authErr as AuthError {
            switch authErr {
            case .otpExpired:
                // Surface as expired so the UI shows the correct state
                throw authErr
            case .otpInvalid:
                // Return a failure result so the view shows "X attempts remaining"
                // Supabase does not expose attempt count — we report nil and let UI use defaults
                return OTPVerifyResult(
                    success: false,
                    attemptsRemaining: nil,
                    isLocked: false,
                    lockUntil: nil,
                    fullSessionToken: nil
                )
            default:
                throw authErr
            }
        }
    }

    // MARK: - Resend OTP

    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        try await sendOTP(context: context)
    }
}
