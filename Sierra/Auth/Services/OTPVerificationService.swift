import Foundation

// MARK: - OTP Verification Protocol

/// Protocol for OTP send/verify — add SMS or TOTP conformances without changing UI.
protocol OTPVerificationServiceProtocol {
    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult
    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult
    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult
}

// MARK: - Result Types

struct OTPSendResult {
    let success: Bool
    let maskedDestination: String
    let expiresAt: Date
    let cooldownUntil: Date
}

struct OTPVerifyResult {
    let success: Bool
    let attemptsRemaining: Int?
    let isLocked: Bool
    let lockUntil: Date?
    let fullSessionToken: String?
}

// MARK: - Mock Implementation (dev only)

final class MockOTPVerificationService: OTPVerificationServiceProtocol {

    /// Dev-only valid OTP. In production this lives server-side.
    private let devOTP = "123456"
    private var attemptsUsed = 0

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 1_200_000_000)
        attemptsUsed = 0
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(60)
        )
    }

    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
        try await Task.sleep(nanoseconds: 800_000_000)
        let correct = code == devOTP
        if correct {
            attemptsUsed = 0
            return OTPVerifyResult(
                success: true,
                attemptsRemaining: nil,
                isLocked: false,
                lockUntil: nil,
                fullSessionToken: "sierra_session_\(UUID().uuidString)"
            )
        } else {
            attemptsUsed += 1
            let remaining = max(0, 3 - attemptsUsed)
            let locked = remaining == 0
            return OTPVerifyResult(
                success: false,
                attemptsRemaining: remaining,
                isLocked: locked,
                lockUntil: locked ? Date().addingTimeInterval(900) : nil,
                fullSessionToken: nil
            )
        }
    }

    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        try await sendOTP(context: context)
    }
}
