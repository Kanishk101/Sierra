import SwiftUI

struct ForcePasswordChangeView: View {
    @State private var viewModel = ForcePasswordChangeViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 60)

                        Image(systemName: "lock.rotation.fill")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(.orange)
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: 8) {
                            Text("Set Your Password")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Create a strong password \u{2014} you\u{2019}ll use it to sign in going forward.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        formCard
                            .scaleEffect(appeared ? 1 : 0.95)
                            .opacity(appeared ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if viewModel.isLoading { loadingOverlay }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
        }
        // 2FA OTP screen — shown after password change succeeds.
        .fullScreenCover(isPresented: $viewModel.awaitingOTP) {
            TwoFactorView(
                viewModel: TwoFactorViewModel(
                    subtitle: "Verify your identity",
                    maskedEmail: AuthManager.shared.maskedEmail,
                    onVerified: {
                        viewModel.awaitingOTP = false
                        AuthManager.shared.saveSessionToken()
                    },
                    onCancelled: {
                        viewModel.awaitingOTP = false
                    }
                )
            )
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 16) {

            VStack(alignment: .leading, spacing: 6) {
                passwordField("Current Password",
                              text: $viewModel.currentPassword,
                              isVisible: $viewModel.isCurrentPasswordVisible)
                if let err = viewModel.currentPasswordError {
                    errorLabel(err)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                passwordField("New Password",
                              text: $viewModel.newPassword,
                              isVisible: $viewModel.isNewPasswordVisible)

                if !viewModel.newPassword.isEmpty {
                    PasswordStrengthView(password: viewModel.newPassword)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                passwordField("Confirm New Password",
                              text: $viewModel.confirmPassword,
                              isVisible: $viewModel.isConfirmPasswordVisible)
                if let err = viewModel.confirmPasswordError {
                    errorLabel(err)
                }
            }

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button {
                Task { await viewModel.setNewPassword() }
            } label: {
                Text("Update Password")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.canSubmit ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        viewModel.canSubmit ? Color.orange : Color.gray.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(!viewModel.canSubmit)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }

    // MARK: - Password Field

    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(.primary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }

    // MARK: - Error Label

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.red.opacity(0.9))
            .padding(.leading, 4)
            .transition(.opacity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.orange)
                Text("Updating password\u{2026}")
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
    ForcePasswordChangeView()
}
