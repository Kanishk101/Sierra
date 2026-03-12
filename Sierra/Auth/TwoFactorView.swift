import SwiftUI

/// 2FA OTP verification screen.
/// Visual layout matches ForgotPasswordView — dark gradient, centered card, same components.
struct TwoFactorView: View {

    @Bindable var viewModel: TwoFactorViewModel

    var body: some View {
        ZStack {
            // Background — identical to LoginView / ForgotPasswordView
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)

                        // Logo + Title
                        headerSection
                            .padding(.bottom, 32)

                        // OTP Card or Locked State
                        if viewModel.isLockedOut {
                            lockedCard
                                .padding(.horizontal, Spacing.xl)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            otpCard
                                .padding(.horizontal, Spacing.xl)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Spacer(minLength: 40)

                        // Cancel link at bottom
                        cancelButton
                            .padding(.bottom, 32)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }

            // Alert banner
            VStack {
                if let banner = viewModel.banner {
                    SierraAlertBanner(alertType: banner)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { viewModel.banner = nil }
                }
                Spacer()
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.banner)
            .zIndex(10)
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            #if DEBUG
            print("🔐 [TwoFactorView] appeared — user is on OTP screen")
            print("🔐 [TwoFactorView] context: \(viewModel.maskedEmail) role: \(viewModel.context.role)")
            #endif
            viewModel.onAppear()
        }
        .onDisappear {
            #if DEBUG
            print("🔐 [TwoFactorView] disappeared. state: \(viewModel.state)")
            #endif
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(SierraTheme.Colors.ember)
                .symbolRenderingMode(.hierarchical)

            // Eyebrow
            Text("VERIFICATION")
                .font(SierraFont.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.5)

            Text("Two-Factor Auth")
                .font(SierraFont.title2)
                .foregroundStyle(.white)

            // Method indicator
            HStack(spacing: Spacing.xs) {
                Image(systemName: viewModel.methodIcon)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                Text("Code sent to \(viewModel.maskedEmail)")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember.opacity(0.8))
            }

            Text(viewModel.instructionText)
                .font(SierraFont.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: Spacing.lg) {
            // Digit input
            SixDigitInputView(
                digits: $viewModel.digits,
                focusedIndex: $viewModel.focusedIndex,
                shakeCount: viewModel.shakeCount,
                onComplete: { viewModel.verifyCode() }
            )
            .padding(.vertical, Spacing.xs)

            // Expiry timer
            expiryRow

            // Error message
            if case .failed(let remaining) = viewModel.state {
                Text("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Verify button
            Button {
                viewModel.verifyCode()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if viewModel.state == .verifying {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    }
                    Text("Verify Code")
                        .font(SierraFont.body(17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    verifyButtonEnabled ? SierraTheme.Colors.ember : Color.gray.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
            }
            .disabled(!verifyButtonEnabled)

            // Resend section
            resendSection
        }
        .padding(Spacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }

    private var verifyButtonEnabled: Bool {
        viewModel.isCodeComplete && viewModel.state != .verifying && !viewModel.isLockedOut
    }

    // MARK: - Expiry Row

    private var expiryRow: some View {
        Group {
            if case .expired = viewModel.state {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(SierraTheme.Colors.danger)
                    Text("Code expired. Please request a new one.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.danger)
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(SierraFont.caption2)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? SierraTheme.Colors.danger
                                         : .white.opacity(0.4))
                    Text("Expires in \(viewModel.expiryDisplayText)")
                        .font(SierraFont.caption1)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? SierraTheme.Colors.danger
                                         : .white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Locked Card

    private var lockedCard: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.danger.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.danger)
                }

                Text("Account Temporarily Locked")
                    .font(SierraFont.headline)
                    .foregroundStyle(.white)

                Text("Too many incorrect attempts.\nPlease wait before trying again.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .strokeBorder(SierraTheme.Colors.danger.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Resend

    private var resendSection: some View {
        HStack(spacing: Spacing.xxs) {
            Text("Didn't receive a code?")
                .font(SierraFont.caption1)
                .foregroundStyle(.white.opacity(0.4))

            if viewModel.canResend {
                Button("Resend") {
                    viewModel.resendCode()
                }
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.ember)
            } else {
                Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Cancel

    private var cancelButton: some View {
        Button {
            viewModel.cancelAndGoBack()
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "arrow.left")
                    .font(SierraFont.caption1)
                Text("Back to Sign In")
                    .font(SierraFont.subheadline)
            }
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Verifying…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Spacing.xxl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .transition(.opacity)
    }
}

#Preview {
    TwoFactorView(viewModel: TwoFactorViewModel(
        subtitle: "Enter the code sent to verify your identity.",
        maskedEmail: "a***@fleeeos.com",
        onVerified: {},
        onCancelled: {}
    ))
}
