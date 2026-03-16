import SwiftUI

/// 2FA OTP verification screen.
/// Supabase is configured to send 6-digit tokens (Auth → Settings → OTP length = 6).
struct TwoFactorView: View {

    @Bindable var viewModel: TwoFactorViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 32)
                        headerSection.padding(.bottom, 16)

                        if viewModel.isLockedOut {
                            lockedCard
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            otpCard
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Spacer(minLength: 16)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if viewModel.isLoading { loadingOverlay }
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            #if DEBUG
            print("🔐 [TwoFactorView] appeared")
            #endif
            viewModel.onAppear()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color(.systemOrange))
                .symbolRenderingMode(.hierarchical)

            Text("VERIFICATION")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
                .tracking(1.2)

            Text("Two-Factor Auth")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Code sent to \(viewModel.maskedEmail)")
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemOrange).opacity(0.8))

            Text("Enter the 6-digit code sent to your email address. The code expires in 10 minutes.")
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: 14) {
            SixDigitInputView(
                digits: $viewModel.digits,
                focusedIndex: $viewModel.focusedIndex,
                shakeCount: viewModel.shakeCount,
                onComplete: { viewModel.verifyCode() }
            )
            .padding(.vertical, 4)

            expiryRow

            if case .failed(let remaining) = viewModel.state {
                Text("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
                    .font(.system(size: 12))
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
                    verifyButtonEnabled ? Color(.systemOrange) : Color.gray.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .disabled(!verifyButtonEnabled)

            resendSection
        }
        .padding(24)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
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
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(Color(.systemRed))
                    Text("Code expired. Please request a new one.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.systemRed))
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? Color(.systemRed) : Color.secondary.opacity(0.7))
                    Text("Expires in \(viewModel.expiryDisplayText)")
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? Color(.systemRed) : Color.secondary.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Locked Card

    private var lockedCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.red)
                }
                Text("Account Temporarily Locked")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("Too many incorrect attempts.\nPlease wait before trying again.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Resend

    private var resendSection: some View {
        HStack(spacing: 4) {
            Text("Didn't receive a code?")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary.opacity(0.7))
            if viewModel.canResend {
                Button("Resend") { viewModel.resendCode() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.systemOrange))
            } else {
                Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.2).tint(Color(.systemOrange))
                Text("Verifying…")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary)
            }
            .padding(28)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
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
