import Foundation
import SwiftUI

/// ViewModel for the 2FA OTP verification screen.
/// Supports both login 2FA and post-password-change OTP re-verification.
@MainActor @Observable
final class TwoFactorViewModel {

    // MARK: - Input

    var digits: [String] = Array(repeating: "", count: 6)
    var focusedIndex: Int? = 0

    // MARK: - State

    var failCount: Int = 0
    var shakeCount: Int = 0
    var isLockedOut: Bool = false
    var lockoutSecondsRemaining: Int = 30
    var resendSecondsRemaining: Int = 60
    var canResend: Bool = false
    var errorMessage: String?
    var isVerified: Bool = false
    var isLoading: Bool = false

    // MARK: - Configuration

    var subtitle: String
    var maskedEmail: String
    var onVerified: () -> Void
    var onCancelled: () -> Void

    // MARK: - Private

    private var resendTask: Task<Void, Never>?
    private var lockoutTask: Task<Void, Never>?

    // MARK: - Init

    init(
        subtitle: String,
        maskedEmail: String,
        onVerified: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.subtitle = subtitle
        self.maskedEmail = maskedEmail
        self.onVerified = onVerified
        self.onCancelled = onCancelled
        startResendCountdown()
    }

    // MARK: - Actions

    func verifyCode() {
        let code = digits.joined()
        guard code.count == 6 else { return }

        isLoading = true
        let success = AuthManager.shared.verifyOTP(code)
        isLoading = false

        if success {
            isVerified = true
            onVerified()
        } else {
            failCount += 1
            withAnimation(.default) {
                shakeCount += 1
            }
            if failCount >= 3 {
                errorMessage = "Too many failed attempts. Please wait."
                startLockoutCountdown()
            } else {
                errorMessage = "Incorrect code. \(3 - failCount) attempt\(3 - failCount == 1 ? "" : "s") remaining."
            }
        }
    }

    func tryAgain() {
        clearDigits()
        errorMessage = nil
    }

    func resendCode() {
        guard canResend else { return }
        AuthManager.shared.generateOTP()
        canResend = false
        resendSecondsRemaining = 60
        errorMessage = nil
        failCount = 0
        clearDigits()
        startResendCountdown()
    }

    func cancelAndGoBack() {
        resendTask?.cancel()
        lockoutTask?.cancel()
        AuthManager.shared.signOut()
        onCancelled()
    }

    func clearDigits() {
        digits = Array(repeating: "", count: 6)
        focusedIndex = 0
    }

    // MARK: - Timers

    private func startResendCountdown() {
        resendTask?.cancel()
        resendTask = Task { [weak self] in
            while let self, self.resendSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.resendSecondsRemaining -= 1
            }
            if !Task.isCancelled {
                self?.canResend = true
            }
        }
    }

    private func startLockoutCountdown() {
        isLockedOut = true
        lockoutSecondsRemaining = 30
        lockoutTask?.cancel()
        lockoutTask = Task { [weak self] in
            while let self, self.lockoutSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.lockoutSecondsRemaining -= 1
            }
            if !Task.isCancelled {
                self?.isLockedOut = false
                self?.failCount = 0
                self?.errorMessage = nil
                self?.clearDigits()
            }
        }
    }
}
