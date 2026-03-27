import SwiftUI

/// 2FA OTP verification screen.
struct TwoFactorView: View {

    @Bindable var viewModel: TwoFactorViewModel

    var body: some View {
        ZStack {
            SierraTheme.Colors.appBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.focusedIndex = nil
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .accessibilityHidden(true)

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
                }
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { viewModel.cancelAndGoBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(SierraFont.scaled(16, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
            }
        }
        .toolbarBackground(SierraTheme.Colors.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                .font(SierraFont.scaled(50, weight: .light))
                .foregroundStyle(SierraTheme.Colors.ember)
                .symbolRenderingMode(.hierarchical)

            Text("VERIFICATION")
                .font(SierraFont.caption2)
                .foregroundStyle(SierraTheme.Colors.granite)
                .tracking(1.5)

            Text("Two-Factor Auth")
                .font(SierraFont.body(28, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)

            HStack(spacing: 6) {
                Image(systemName: viewModel.methodIcon)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                Text("Code sent to \(viewModel.maskedEmail)")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember.opacity(0.8))
            }

            Text("Enter the 6-digit code sent to your email address.\nThe code expires in 10 minutes.")
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.granite)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: 24) {
            SixDigitInputView(
                digits: $viewModel.digits,
                focusedIndex: $viewModel.focusedIndex,
                onComplete: { viewModel.verifyCode() }
            )
            .padding(.top, 8)
            
            VStack(spacing: 16) {
                expiryRow
                
                if case .failed(let remaining) = viewModel.state {
                    Text("Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                
                SierraButton.primary("Verify Code", isLoading: viewModel.state == .verifying) {
                    viewModel.verifyCode()
                }
                .disabled(!verifyButtonEnabled)
                
                resendSection
            }
            .padding(.horizontal, 24)
        }
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
                        .foregroundStyle(SierraTheme.Colors.danger)
                    Text("Code expired. Please request a new one.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.danger)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(SierraFont.caption2)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? SierraTheme.Colors.danger : SierraTheme.Colors.granite)
                    Text("Expires in \(viewModel.expiryDisplayText)")
                        .font(SierraFont.caption1)
                        .foregroundStyle(viewModel.expiryCountdown < 60
                                         ? SierraTheme.Colors.danger : SierraTheme.Colors.granite)
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
                        .fill(SierraTheme.Colors.danger.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.fill")
                        .font(SierraFont.scaled(28, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.danger)
                }
                Text("Account Temporarily Locked")
                    .font(.headline).foregroundStyle(.primary)
                Text("Too many incorrect attempts.\nPlease wait before trying again.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(SierraTheme.Colors.danger.opacity(0.2), lineWidth: 1)
        )
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // MARK: - Resend

    private var resendSection: some View {
        HStack(spacing: 4) {
            Text("Didn\u{2019}t receive a code?")
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.granite)
            if viewModel.canResend {
                Button("Resend") { viewModel.resendCode() }
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
            } else {
                Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.mist)
            }
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.3).tint(SierraTheme.Colors.ember)
                Text("Verifying\u{2026}")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.granite)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
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
