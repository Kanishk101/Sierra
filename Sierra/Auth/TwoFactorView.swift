import SwiftUI

/// 2FA OTP verification screen.
struct TwoFactorView: View {

    @Bindable var viewModel: TwoFactorViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        headerSection.padding(.bottom, 32)

                        if viewModel.isLockedOut {
                            lockedCard
                                .padding(.horizontal, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            otpCard
                                .padding(.horizontal, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Spacer(minLength: 40)
                        cancelButton.padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if viewModel.isLoading { loadingOverlay }

            VStack {
                if let banner = viewModel.banner {
                    SierraAlertBanner(alertType: banner)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
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
            print("\u{1F510} [TwoFactorView] appeared")
            #endif
            viewModel.onAppear()
        }
        .task {
            // iOS 17+: UITextField inside fullScreenCover needs the presentation
            // animation to fully complete before becomeFirstResponder() will work.
            // 'perform input operation requires a valid sessionID' is the symptom
            // of requesting focus too early. 650ms covers the cover animation.
            try? await Task.sleep(for: .milliseconds(650))
            viewModel.requestInitialFocus()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text("VERIFICATION")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text("Two-Factor Auth")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Image(systemName: viewModel.methodIcon)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Code sent to \(viewModel.maskedEmail)")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Text("Enter the 6-digit code sent to your email address.\nThe code expires in 10 minutes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: 20) {
            SixDigitInputView(
                digits: $viewModel.digits,
                focusedIndex: $viewModel.focusedIndex,
                shakeCount: viewModel.shakeCount,
                onComplete: { viewModel.verifyCode() }
            )
            .padding(.vertical, 8)

            expiryRow

            if case .failed(let remaining) = viewModel.state {
                Text("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Button {
                viewModel.verifyCode()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.state == .verifying {
                        ProgressView().tint(.white).scaleEffect(0.9)
                    }
                    Text("Verify Code")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    verifyButtonEnabled ? Color.orange : Color.gray.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .disabled(!verifyButtonEnabled)

            resendSection
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }

    private var verifyButtonEnabled: Bool {
        viewModel.isCodeComplete && viewModel.state != .verifying && !viewModel.isLockedOut
    }

    // MARK: - Expiry Row

    private var expiryRow: some View {
        Group {
            if case .expired = viewModel.state {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.red)
                    Text("Code expired. Please request a new one.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? .red : .secondary)
                    Text("Expires in \(viewModel.expiryDisplayText)")
                        .font(.caption)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? .red : .secondary)
                }
            }
        }
    }

    // MARK: - Locked Card

    private var lockedCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.red)
                }
                Text("Account Temporarily Locked")
                    .font(.headline).foregroundStyle(.primary)
                Text("Too many incorrect attempts.\nPlease wait before trying again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Resend

    private var resendSection: some View {
        HStack(spacing: 4) {
            Text("Didn\u{2019}t receive a code?")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.canResend {
                Button("Resend") { viewModel.resendCode() }
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Cancel

    private var cancelButton: some View {
        Button { viewModel.cancelAndGoBack() } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left").font(.caption)
                Text("Back to Sign In").font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.3).tint(.orange)
                Text("Verifying\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
    }
}

#Preview {
    TwoFactorView(viewModel: TwoFactorViewModel(
        subtitle: "Enter the code sent to verify your identity.",
        maskedEmail: "f***@gmail.com",
        onVerified: {},
        onCancelled: {}
    ))
}
