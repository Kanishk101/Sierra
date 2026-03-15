//
//  AuthManagerOTPVerificationService.swift
//  Sierra
//
//  Created by kan on 14/03/26.
//

import Foundation

// OTP is sent via SwiftSMTP — look for the 📧 line in Xcode console after sign-in.

final class AuthManagerOTPVerificationService: OTPVerificationServiceProtocol {

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        _ = AuthManager.shared.generateOTP()   // prints OTP to console in DEBUG
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
        try await sendOTP(context: context)
    }
}
