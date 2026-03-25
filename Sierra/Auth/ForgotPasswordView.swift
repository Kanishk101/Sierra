import SwiftUI


/// 3-step forgot password flow: Email > Code > New Password > Success
struct ForgotPasswordView: View {

    @State private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                SierraTheme.Colors.appBackground
                    .ignoresSafeArea()

                // Content by step
                Group {
                    switch viewModel.step {
                    case .enterEmail:  emailStep
                    case .enterCode:   codeStep
                    case .newPassword: passwordStep
                    case .success:     successStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.step != .success {
                        backButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SierraTheme.Colors.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(
                "Reset Failed",
                isPresented: Binding(
                    get: { viewModel.showErrorAlert },
                    set: { viewModel.showErrorAlert = $0 }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Failed to reset password. Please try again.")
            }
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            if viewModel.step == .enterEmail {
                dismiss()
            } else {
                viewModel.goBack()
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SierraTheme.Colors.ember)
        }
    }

    // MARK: - Step 1: Enter Email

    private var emailStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                // Icon
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
                VStack(spacing: 8) {
                    Text("Forgot Password?")
                        .font(SierraFont.body(28, weight: .bold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                    Text("Enter your email address and we\u{2019}ll send\nyou a verification code.")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(SierraTheme.Colors.granite)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                // Email field
                SierraTextField(
                    label: "",
                    placeholder: "Email address",
                    text: $viewModel.email,
                    style: .native,
                    keyboardType: .emailAddress,
                    leadingIcon: "envelope.fill",
                    errorMessage: viewModel.emailError,
                    maxLength: 100
                )
                .padding(.horizontal, 24)
                // Send button
                SierraButton.primary("Send Reset Code", isLoading: viewModel.isLoading) {
                    Task { await viewModel.sendResetCode() }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 40)
            }
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Enter Code

    private var codeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
                VStack(spacing: 8) {
                    Text("Enter Verification Code")
                        .font(SierraFont.body(28, weight: .bold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                    Text("Enter the 6-digit code sent to\n\(viewModel.maskedEmail)")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(SierraTheme.Colors.granite)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                // OTP input
                SixDigitInputView(
                    digits: $viewModel.digits,
                    focusedIndex: $viewModel.focusedIndex,
                    onComplete: { viewModel.verifyResetCode() }
                )
                if let error = viewModel.codeError {
                    Text(error)
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.danger)
                }
                SierraButton.primary("Verify Code", isLoading: viewModel.isLoading) {
                    viewModel.verifyResetCode()
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 40)
            }
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 3: New Password

    private var passwordStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 60)
                Image(systemName: "key.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
                VStack(spacing: 8) {
                    Text("Set New Password")
                        .font(SierraFont.body(28, weight: .bold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                    Text("Choose a strong password for your account.")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(SierraTheme.Colors.granite)
                }
                // Password fields card
                VStack(spacing: 16) {
                    // New password
                    SierraTextField(
                        label: "New Password",
                        placeholder: "Enter new password",
                        text: $viewModel.newPassword,
                        style: .native,
                        leadingIcon: "lock.fill",
                        errorMessage: viewModel.newPasswordError,
                        isSecure: true,
                        maxLength: 128
                    )
                    if !viewModel.newPassword.isEmpty {
                        PasswordStrengthView(password: viewModel.newPassword)
                            .padding(.top, -8)
                    }
                    // Confirm password
                    SierraTextField(
                        label: "Confirm Password",
                        placeholder: "Confirm your password",
                        text: $viewModel.confirmPassword,
                        style: .native,
                        leadingIcon: "lock.fill",
                        errorMessage: viewModel.confirmPasswordError,
                        isSecure: true,
                        maxLength: 128
                    )
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.danger)
                    }
                    // Submit
                    SierraButton.primary("Reset Password", isLoading: viewModel.isLoading) {
                        Task { await viewModel.resetPassword() }
                    }
                    .disabled(!viewModel.canSubmitNewPassword)
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .sierraShadow(SierraTheme.Shadow.card)
                .padding(.horizontal, 24)
                Spacer(minLength: 40)
            }
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Success

    // MARK: - Success

    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedCheckmarkView(size: 100, color: SierraTheme.Colors.alpineMint)

            VStack(spacing: 10) {
                Text("Password Reset!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Your password has been updated.\nYou can now sign in with your new password.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            SierraButton.primary("Back to Login") {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(SierraTheme.Colors.ember)
                Text("Processing\u{2026}")
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
    ForgotPasswordView()
}
