import SwiftUI


/// 3-step forgot password flow: Email > Code > New Password > Success
struct ForgotPasswordView: View {

    @State private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
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
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Step 1: Enter Email

    private var emailStep: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    // Icon
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Forgot Password?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Enter your email address and we\u{2019}ll send\nyou a verification code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            TextField("Email address", text: $viewModel.email)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    viewModel.emailError != nil ? Color.red.opacity(0.7) : Color(.separator),
                                    lineWidth: 1
                                )
                        )

                        if let error = viewModel.emailError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Send button
                    Button {
                        Task { await viewModel.sendResetCode() }
                    } label: {
                        Text("Send Reset Code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Step 2: Enter Code

    private var codeStep: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Enter Verification Code")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Enter the 6-digit code sent to\n\(viewModel.maskedEmail)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // OTP input
                    SixDigitInputView(
                        digits: $viewModel.digits,
                        focusedIndex: $viewModel.focusedIndex,
                        shakeCount: viewModel.shakeCount,
                        onComplete: { viewModel.verifyResetCode() }
                    )

                    if let error = viewModel.codeError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        viewModel.verifyResetCode()
                    } label: {
                        Text("Verify Code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Step 3: New Password

    private var passwordStep: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 60)

                    Image(systemName: "key.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text("Set New Password")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Choose a strong password for your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Password fields card
                    VStack(spacing: 16) {
                        // New password
                        VStack(alignment: .leading, spacing: 8) {
                            passwordField("New Password", text: $viewModel.newPassword)

                            if !viewModel.newPassword.isEmpty {
                                PasswordStrengthView(password: viewModel.newPassword)
                            }

                            if let err = viewModel.newPasswordError {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.9))
                                    .padding(.leading, 4)
                                    .transition(.opacity)
                            }
                        }

                        // Confirm password
                        VStack(alignment: .leading, spacing: 5) {
                            passwordField("Confirm Password", text: $viewModel.confirmPassword)

                            if let error = viewModel.confirmPasswordError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.9))
                                    .padding(.leading, 4)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        // Submit
                        Button {
                            Task { await viewModel.resetPassword() }
                        } label: {
                            Text("Reset Password")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(viewModel.canSubmitNewPassword ? .white : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    viewModel.canSubmitNewPassword ? Color.orange : Color.gray.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .disabled(!viewModel.canSubmitNewPassword)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Password Field

    private func passwordField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }

    // MARK: - Success

    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedCheckmarkView(size: 100, color: .green)

            VStack(spacing: 10) {
                Text("Password Reset!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Your password has been updated.\nYou can now sign in with your new password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Back to Login")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .tint(.orange)
                Text("Processing\u{2026}")
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
    ForgotPasswordView()
}
