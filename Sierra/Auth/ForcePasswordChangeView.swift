import SwiftUI

struct ForcePasswordChangeView: View {
    @State private var viewModel = ForcePasswordChangeViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            SierraTheme.Colors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    Image(systemName: "lock.rotation.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(SierraTheme.Colors.ember)
                        .symbolRenderingMode(.hierarchical)
                    VStack(spacing: 8) {
                        Text("Set Your Password")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Create a strong password \u{2014} you\u{2019}ll use it to sign in going forward.")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(SierraTheme.Colors.granite)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    formCard
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 40)
                }
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .toolbarBackground(SierraTheme.Colors.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            if viewModel.isLoading { loadingOverlay }
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
        }
        .alert("Password Update Failed", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Failed to update password. Please try again.")
        }
        // 2FA OTP screen - shown after password change succeeds.
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
            SierraTextField(
                label: "Current Password",
                placeholder: "Enter current password",
                text: $viewModel.currentPassword,
                style: .native,
                leadingIcon: "lock.fill",
                errorMessage: viewModel.currentPasswordError,
                isSecure: true,
                maxLength: 128
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                SierraTextField(
                    label: "New Password",
                    placeholder: "Enter new password",
                    text: $viewModel.newPassword,
                    style: .native,
                    leadingIcon: "lock.fill",
                    isSecure: true,
                    maxLength: 128
                )

                if !viewModel.newPassword.isEmpty {
                    PasswordStrengthView(password: viewModel.newPassword)
                        .padding(.top, -8)
                }
            }

            SierraTextField(
                label: "Confirm New Password",
                placeholder: "Confirm your new password",
                text: $viewModel.confirmPassword,
                style: .native,
                leadingIcon: "lock.fill",
                errorMessage: viewModel.confirmPasswordError,
                isSecure: true,
                maxLength: 128
            )

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            SierraButton.primary("Update Password", isLoading: viewModel.isLoading) {
                Task { await viewModel.setNewPassword() }
            }
            .disabled(!viewModel.canSubmit)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
        .padding(.horizontal, 20)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(SierraTheme.Colors.ember)
                Text("Updating password\u{2026}")
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
    ForcePasswordChangeView()
}
