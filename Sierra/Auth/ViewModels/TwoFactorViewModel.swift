import Foundation
import SwiftUI

/// ViewModel for the 2FA OTP verification screen.
@MainActor @Observable
final class TwoFactorViewModel {

    // MARK: - Input

    var digits: [String] = Array(repeating: "", count: 6)
    // Starts nil — focus is requested by TwoFactorView after the fullScreenCover
    // animation completes (iOS 17+ requires the input session to be ready first).
    var focusedIndex: Int? = nil

    // MARK: - State

    var state: TwoFactorState = .idle
    var expiryCountdown: Int = 600
    var resendCooldown: Int = 0
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
#if DEBUG
        print("🛡️ [TwoFactorViewModel] onAppear – starting sendOTP for user=\(context.userID) role=\(context.role.rawValue) method=\(context.method)")
#endif
        Task { await sendOTP() }
    }

    /// Called by TwoFactorView after a delay to let the fullScreenCover animation
    /// fully settle before requesting keyboard focus (iOS 17+ input session requirement).
    func requestInitialFocus() {
        guard focusedIndex == nil else { return }
        focusedIndex = 0
    }

    func sendOTP() async {
#if DEBUG
        print("🛡️ [TwoFactorViewModel] sendOTP() starting | userID=\(context.userID) destination=\(context.maskedDestination)")
#endif
        state = .sending
        isLoading = true
        do {
            let result = try await service.sendOTP(context: context)
#if DEBUG
            print("🛡️ [TwoFactorViewModel] sendOTP() success | expiresAt=\(result.expiresAt) cooldownUntil=\(result.cooldownUntil)")
#endif
            state = .awaitingEntry
            isLoading = false
            startExpiryCountdown(until: result.expiresAt)
            startResendCooldown(until: result.cooldownUntil)
        } catch let authErr as AuthError {
#if DEBUG
            print("🛡️ [TwoFactorViewModel] sendOTP() AuthError=\(authErr)")
#endif
            state = .idle
            isLoading = false
            switch authErr {
            case .networkError(let msg) where msg.lowercased().contains("invalid"):
                banner = .error("Could not send code - email address is not valid. Contact your fleet manager.")
            case .networkError(let msg):
                banner = .error("Could not send code: \(msg)")
            case .userNotFound:
                banner = .error("Account not found. Please sign in again.")
            case .otpExpired:
                banner = .warning("Previous code expired. Tap Resend for a fresh code.")
                state = .awaitingEntry
            default:
                banner = .error("Failed to send code. Please try again.")
            }
        } catch {
#if DEBUG
            print("🛡️ [TwoFactorViewModel] sendOTP() unexpected error=\(error)")
#endif
            state = .idle
            isLoading = false
            banner = .error("Failed to send code: \(error.localizedDescription)")
        }
    }

    func verifyCode() {
        guard isCodeComplete else { return }
#if DEBUG
        print("🛡️ [TwoFactorViewModel] verifyCode() starting | code=\(enteredCode) userID=\(context.userID) role=\(context.role.rawValue)")
#endif
        state = .verifying
        isLoading = true
        Task {
            do {
                let result = try await service.verifyOTP(code: enteredCode, context: context)
#if DEBUG
                print("🛡️ [TwoFactorViewModel] verifyOTP result | success=\(result.success) locked=\(result.isLocked) attemptsRemaining=\(String(describing: result.attemptsRemaining)) lockUntil=\(String(describing: result.lockUntil)) fullSessionToken length=\(result.fullSessionToken?.count ?? 0)")
#endif
                isLoading = false
                if result.success {
                    expiryTimer?.cancel()
                    state = .success
                    SecureSessionStore.shared.save(
                        token: result.fullSessionToken ?? "",
                        role: context.role
                    )
#if DEBUG
                    print("🛡️ [TwoFactorViewModel] verifyCode SUCCESS | state=success, tokenSaved=\(result.fullSessionToken != nil)")
#endif
                    onVerified?()
                } else if result.isLocked, let lockUntil = result.lockUntil {
                    state = .locked(unlockAt: lockUntil)
                    banner = .error("Too many incorrect attempts. Account temporarily locked.")
                    startLockoutCountdown(until: lockUntil)
#if DEBUG
                    print("🛡️ [TwoFactorViewModel] verifyCode LOCKED until \(lockUntil)")
#endif
                } else {
                    let remaining = result.attemptsRemaining ?? 0
                    state = .failed(attemptsRemaining: remaining)
                    clearDigits()
                    banner = .warning("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
#if DEBUG
                    print("🛡️ [TwoFactorViewModel] verifyCode FAILED | remaining=\(remaining)")
#endif
                }
            } catch let authErr as AuthError {
                isLoading = false
#if DEBUG
                print("🛡️ [TwoFactorViewModel] verifyCode AuthError=\(authErr)")
#endif
                switch authErr {
                case .otpExpired:
                    state = .expired
                    expiryTimer?.cancel()
                    clearDigits()
                    banner = .warning("Code has expired. Tap Resend to get a new one.")
                case .otpInvalid:
                    state = .failed(attemptsRemaining: 0)
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
                    banner = .error("Verification failed - \(authErr.localizedDescription)")
                }
            } catch {
                state = .awaitingEntry
                isLoading = false
                banner = .error("Verification failed: \(error.localizedDescription)")
#if DEBUG
                print("🛡️ [TwoFactorViewModel] verifyCode unexpected error=\(error)")
#endif
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
#if DEBUG
        print("🛡️ [TwoFactorViewModel] resendCode() starting for userID=\(context.userID)")
#endif
        clearDigits()
        Task {
            state = .sending
            isLoading = true
            do {
                let result = try await service.resendOTP(context: context)
#if DEBUG
                print("🛡️ [TwoFactorViewModel] resendCode() success | expiresAt=\(result.expiresAt) cooldownUntil=\(result.cooldownUntil)")
#endif
                state = .awaitingEntry
                isLoading = false
                startExpiryCountdown(until: result.expiresAt)
                startResendCooldown(until: result.cooldownUntil)
                banner = .info("A new code has been sent to \(maskedEmail).")
            } catch {
                state = .awaitingEntry
                isLoading = false
                banner = .error("Could not resend code. Please try again.")
#if DEBUG
                print("🛡️ [TwoFactorViewModel] resendCode() error=\(error)")
#endif
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
