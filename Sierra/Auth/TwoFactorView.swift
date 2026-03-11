import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

/// 2FA OTP verification screen.
/// Used for both post-login and post-password-change OTP flows.
struct TwoFactorView: View {

    @Bindable var viewModel: TwoFactorViewModel

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
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

                        // OTP Input Card
                        otpCard
                            .padding(.horizontal, 24)

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
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "truck.box.fill")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(accentOrange)
                .symbolRenderingMode(.hierarchical)

            Text("Verify Identity")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text(viewModel.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Text("Code sent to \(viewModel.maskedEmail)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accentOrange.opacity(0.8))
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: 20) {
            // Digit input
            SixDigitInputView(
                digits: $viewModel.digits,
                focusedIndex: $viewModel.focusedIndex,
                shakeCount: viewModel.shakeCount,
                onComplete: { viewModel.verifyCode() }
            )
            .padding(.vertical, 8)

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Action buttons based on state
            if viewModel.isLockedOut {
                lockoutCard
            } else if viewModel.failCount > 0 && !viewModel.isVerified {
                retryButtons
            }

            // Verify button
            Button {
                viewModel.verifyCode()
            } label: {
                Text("Verify")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        verifyButtonEnabled ? accentOrange : Color.gray.opacity(0.3),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(!verifyButtonEnabled)

            // Resend section
            resendSection
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage != nil)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLockedOut)
        .animation(.easeInOut(duration: 0.2), value: viewModel.failCount)
    }

    private var verifyButtonEnabled: Bool {
        viewModel.digits.joined().count == 6 && !viewModel.isLockedOut && !viewModel.isLoading
    }

    // MARK: - Lockout Card

    private var lockoutCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("Too many attempts")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text("Try again in \(viewModel.lockoutSecondsRemaining)s")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Retry Buttons (Gap 2)

    private var retryButtons: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.tryAgain()
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(accentOrange.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                viewModel.cancelAndGoBack()
            } label: {
                Text("Cancel & Go Back")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }

    // MARK: - Resend

    private var resendSection: some View {
        HStack(spacing: 4) {
            Text("Didn't receive a code?")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))

            if viewModel.canResend {
                Button("Resend") {
                    viewModel.resendCode()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentOrange)
            } else {
                Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Cancel

    private var cancelButton: some View {
        Button {
            viewModel.cancelAndGoBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("Cancel & Go Back")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Verifying…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
