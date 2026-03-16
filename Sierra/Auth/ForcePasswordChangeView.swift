import SwiftUI


struct ForcePasswordChangeView: View {
    @State private var viewModel       = ForcePasswordChangeViewModel()
    @State private var appeared        = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading { loadingOverlay.zIndex(20) }

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 72)

                        // ── Header ──
                        headerSection
                            .padding(.bottom, 32)

                        // ── Form card ──
                        formCard
                            .scaleEffect(appeared ? 1 : 0.94)
                            .opacity(appeared ? 1 : 0)

                        Spacer(minLength: 48)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
        }
        .fullScreenCover(isPresented: $viewModel.awaitingOTP) {
            TwoFactorView(
                viewModel: TwoFactorViewModel(
                    subtitle: "Verify your identity",
                    maskedEmail: AuthManager.shared.maskedEmail,
                    onVerified: {
                        viewModel.awaitingOTP = false
                        AuthManager.shared.confirmFirstLoginComplete()
                    },
                    onCancelled: {
                        viewModel.awaitingOTP = false
                    }
                )
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 88, height: 88)

                Image(systemName: "lock.rotation.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 4) {
                Text("Set Your Password")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("Create a strong password - you'll use it\nto sign in going forward.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 0) {

            VStack(spacing: 0) {

                // Current Password
                VStack(alignment: .leading, spacing: 0) {
                    passwordField("Current Password",
                                  text: $viewModel.currentPassword,
                                  isVisible: $viewModel.isCurrentPasswordVisible)
                    if let err = viewModel.currentPasswordError {
                        errorLabel(err)
                    }
                }

                Divider().padding(.leading, 52)

                // New Password + strength
                VStack(alignment: .leading, spacing: 0) {
                    passwordField("New Password",
                                  text: $viewModel.newPassword,
                                  isVisible: $viewModel.isNewPasswordVisible)

                    if !viewModel.newPassword.isEmpty {
                        PasswordStrengthView(password: viewModel.newPassword)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }

                Divider().padding(.leading, 52)

                // Confirm Password
                VStack(alignment: .leading, spacing: 0) {
                    passwordField("Confirm New Password",
                                  text: $viewModel.confirmPassword,
                                  isVisible: $viewModel.isConfirmPasswordVisible)
                    if let err = viewModel.confirmPasswordError {
                        errorLabel(err)
                    }
                }

                // General error (inline banner)
                if let err = viewModel.errorMessage {
                    Divider()
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 15))
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.opacity)
                }

            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)

            // Submit button
            Button {
                Task { await viewModel.setNewPassword() }
            } label: {
                Text("Update Password")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        viewModel.canSubmit ? Color.orange : Color(.systemFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    // MARK: - Password Field

    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .frame(width: 20)

            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isVisible.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    // MARK: - Error Label

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.opacity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color(.systemOrange))
                Text("Updating password…")
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
    ForcePasswordChangeView()
}
