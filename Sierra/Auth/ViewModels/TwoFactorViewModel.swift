import Foundation
import SwiftUI

/// ViewModel for the 2FA OTP verification screen.
/// Supabase is configured to send 6-digit OTP tokens (Auth → Settings → OTP length = 6).
@MainActor @Observable
final class TwoFactorViewModel {

    // MARK: - Input

    var digits: [String] = Array(repeating: "", count: 6)
    var focusedIndex: Int? = 0

    // MARK: - State

    var state: TwoFactorState = .idle
    var expiryCountdown: Int = 600
    var resendCooldown: Int = 0
    var shakeCount: Int = 0
    var banner: SierraAlertType?
    var isLoading: Bool = false

    // MARK: - Configuration

    let context: TwoFactorContext
    var onVerified: (() -> Void)?
    var onCancelled: (() -> Void)?

    // MARK: - Dependencies

    private let service: OTPVerificationServiceProtocol
    private var expiryTimer: Task<Void, Never>?
    private var cooldownTimer: Task<Void, Never>?

    // MARK: - Init

    init(
        context: TwoFactorContext,
        service: OTPVerificationServiceProtocol? = nil,
        onVerified: (() -> Void)? = nil,
        onCancelled: (() -> Void)? = nil
    ) {
        self.context = context
        self.service = service ?? AuthManagerOTPVerificationService()
        self.onVerified = onVerified
        self.onCancelled = onCancelled
    }

    convenience init(
        subtitle: String,
        maskedEmail: String,
        onVerified: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        let ctx = TwoFactorContext(
            userID: AuthManager.shared.currentUser?.id.uuidString ?? "",
            role: AuthManager.shared.currentUser?.role ?? .fleetManager,
            method: .email,
            maskedDestination: maskedEmail,
            sessionToken: "",
            authDestination: AuthManager.shared.currentUser.map { AuthManager.shared.destination(for: $0) } ?? .fleetManagerDashboard
        )
        self.init(context: ctx, service: AuthManagerOTPVerificationService(), onVerified: onVerified, onCancelled: onCancelled)
    }

    // MARK: - Computed

    var enteredCode: String { digits.joined() }
    var isCodeComplete: Bool { digits.allSatisfy { $0.count == 1 } }
    var canResend: Bool { resendCooldown == 0 && state != .sending && state != .verifying }
    var maskedEmail: String { context.maskedDestination }
    var methodIcon: String { context.method.icon }
    var instructionText: String { context.method.instructionText }
    var subtitle: String { context.method.instructionText }

    var isLockedOut: Bool {
        if case .locked = state { return true }
        return false
    }

    var isVerified: Bool { state == .success }

    var failCount: Int {
        if case .failed(let remaining) = state { return 3 - remaining }
        return 0
    }

    var lockoutSecondsRemaining: Int {
        if case .locked(let unlockAt) = state {
            return max(0, Int(unlockAt.timeIntervalSinceNow))
        }
        return 0
    }

    var resendSecondsRemaining: Int { resendCooldown }

    var expiryDisplayText: String {
        let m = expiryCountdown / 60
        let s = expiryCountdown % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    func onAppear() {
        Task { await sendOTP() }
    }

    func sendOTP() async {
        // Immediately show the OTP input — don't block on the SMTP round-trip.
        // Fire the email in the background; if it fails a banner will appear.
        state = .awaitingEntry
        isLoading = false
        // Start timers optimistically (10-minute expiry, 30-second resend cooldown)
        startExpiryCountdown(until: Date().addingTimeInterval(600))
        startResendCooldown(until: Date().addingTimeInterval(30))

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.service.sendOTP(context: self.context)
            } catch {
                await MainActor.run {
                    self.banner = .error("Could not send code. Check your connection and tap Resend.")
                }
            }
        }
    }

    func verifyCode() {
        guard isCodeComplete else { return }
        state = .verifying
        isLoading = true
        Task {
            do {
                let result = try await service.verifyOTP(code: enteredCode, context: context)
                isLoading = false
                if result.success {
                    expiryTimer?.cancel()
                    state = .success
                    SecureSessionStore.shared.save(
                        token: result.fullSessionToken ?? "",
                        role: context.role
                    )
                    onVerified?()
                } else if result.isLocked, let lockUntil = result.lockUntil {
                    state = .locked(unlockAt: lockUntil)
                    banner = .error("Too many incorrect attempts. Account temporarily locked.")
                    startLockoutCountdown(until: lockUntil)
                } else {
                    let remaining = result.attemptsRemaining ?? 0
                    state = .failed(attemptsRemaining: remaining)
                    withAnimation(.default) { shakeCount += 1 }
                    clearDigits()
                    banner = .warning("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
                }
            } catch let authErr as AuthError {
                isLoading = false
                switch authErr {
                case .otpExpired:
                    state = .expired
                    expiryTimer?.cancel()
                    clearDigits()
                    banner = .warning("Code has expired. Tap Resend to get a new one.")
                case .otpInvalid:
                    state = .failed(attemptsRemaining: 0)
                    withAnimation(.default) { shakeCount += 1 }
                    clearDigits()
                    banner = .warning("Incorrect code. Please check and try again.")
                case .networkError(let msg):
                    state = .awaitingEntry
                    banner = .error("Network error: \(msg)")
                case .userNotFound:
                    state = .awaitingEntry
                    banner = .error("Session expired. Please sign in again.")
                default:
                    state = .awaitingEntry
                    banner = .error("Verification failed — \(authErr.localizedDescription)")
                }
            } catch {
                state = .awaitingEntry
                isLoading = false
                banner = .error("Verification failed: \(error.localizedDescription)")
            }
        }
    }

    func tryAgain() {
        clearDigits()
        state = .awaitingEntry
        banner = nil
    }

    func resendCode() {
        guard canResend else { return }
        clearDigits()
        Task {
            await sendOTP()
            if case .awaitingEntry = state {
                banner = .info("A new code has been sent to \(maskedEmail).")
            }
        }
    }

    func cancelAndGoBack() {
        expiryTimer?.cancel()
        cooldownTimer?.cancel()
        AuthManager.shared.signOut()
        onCancelled?()
    }

    func clearDigits() {
        digits = Array(repeating: "", count: 6)
        focusedIndex = 0
    }

    // MARK: - Timers

    private func startExpiryCountdown(until date: Date) {
        expiryTimer?.cancel()
        expiryCountdown = max(0, Int(date.timeIntervalSinceNow))
        expiryTimer = Task { [weak self] in
            while let self, self.expiryCountdown > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.expiryCountdown -= 1
            }
            if !Task.isCancelled {
                self?.state = .expired
                self?.banner = .warning("Code expired. Please request a new one.")
            }
        }
    }

    private func startResendCooldown(until date: Date) {
        cooldownTimer?.cancel()
        resendCooldown = max(0, Int(date.timeIntervalSinceNow))
        cooldownTimer = Task { [weak self] in
            while let self, self.resendCooldown > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.resendCooldown -= 1
            }
        }
    }

    private func startLockoutCountdown(until date: Date) {
        Task {
            var remaining = max(0, Int(date.timeIntervalSinceNow))
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            if !Task.isCancelled {
                state = .awaitingEntry
                banner = nil
                clearDigits()
            }
        }
    }
}
