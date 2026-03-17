//
//  AuthManagerOTPVerificationService.swift
//  Sierra
//
//  Created by kan on 14/03/26.
//

import Foundation

// OTP is pre-generated in LoginViewModel.signIn() before the 2FA screen appears.
// sendOTP() returns instantly - no SMTP wait on screen appear.
// resendOTP() generates a fresh OTP and fires a new email.

final class AuthManagerOTPVerificationService: OTPVerificationServiceProtocol {

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        // OTP was pre-generated in LoginViewModel.signIn() before screen appeared.
        // Do NOT call generateOTP() again - it would overwrite the already-sent OTP.
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }

    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
        let correct = AuthManager.shared.verifyOTP(code)
        return OTPVerifyResult(
            success: correct,
            attemptsRemaining: correct ? nil : 2,
            isLocked: false,
            lockUntil: nil,
            fullSessionToken: correct ? "sierra_session_\(UUID().uuidString)" : nil
        )
    }

    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        // Resend: generate a new OTP and fire a fresh email
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        _ = AuthManager.shared.generateOTP()
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }
}
