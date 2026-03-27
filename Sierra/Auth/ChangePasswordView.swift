import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false
    @State private var currentPasswordError: String?

    var body: some View {
        ZStack {
            SierraTheme.Colors.appBackground
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)

                        headerSection

                        VStack(spacing: 20) {
                            SierraTextField(
                                label: "Current Password",
                                placeholder: "Enter current password",
                                text: $currentPassword,
                                style: .native,
                                leadingIcon: "lock.fill",
                                errorMessage: currentPasswordError,
                                isSecure: true,
                                maxLength: 128
                            )
                            .accessibilityLabel("Current Password")

                            Divider()
                                .background(SierraTheme.Colors.cloud.opacity(0.5))
                                .padding(.vertical, 8)

                            SierraTextField(
                                label: "New Password",
                                placeholder: "Enter new password",
                                text: $newPassword,
                                style: .native,
                                leadingIcon: "lock.rotation",
                                isSecure: true,
                                maxLength: 128
                            )
                            .accessibilityLabel("New Password")

                            if !newPassword.isEmpty {
                                PasswordStrengthView(password: newPassword)
                                    .padding(.top, -8)
                            }

                            SierraTextField(
                                label: "Confirm New Password",
                                placeholder: "Confirm your password",
                                text: $confirmPassword,
                                style: .native,
                                leadingIcon: "lock.shield.fill",
                                errorMessage: confirmPasswordError,
                                isSecure: true,
                                maxLength: 128
                            )
                            .accessibilityLabel("Confirm New Password")
                        }
                        .padding(24)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .sierraShadow(SierraTheme.Shadow.card)
                        .padding(.horizontal, 24)

                        SierraButton.primary("Update Password", isLoading: isLoading) {
                            Task { await updatePassword() }
                        }
                        .disabled(!canSubmit || isLoading)
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SierraTheme.Colors.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Password Update Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unable to update password. Please try again.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SierraTheme.Colors.ember.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.rotation")
                    .font(SierraFont.scaled(34, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Update Password")
                    .font(.title3.weight(.bold))
                Text("Choose a strong password to secure your account")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
            }
        }
    }

    private var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return confirmPassword == newPassword ? nil : "Passwords do not match"
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty
            && !newPassword.isEmpty
            && !confirmPassword.isEmpty
            && currentPassword != newPassword
            && newPassword.count >= 8
            && confirmPassword == newPassword
            && PasswordStrength.evaluate(newPassword).rawValue >= 2 // Requires at least Medium
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(SierraTheme.Colors.ember)
                Text("Updating...")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.granite)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
    }

    private func verifyCurrentPassword() -> Bool {
        guard let stored = KeychainService.load(
            key: "com.sierra.hashedCredential",
            as: CryptoService.HashedCredential.self
        ) else {
            return false
        }
        return CryptoService.verify(password: currentPassword, credential: stored)
    }

    @MainActor
    private func updatePassword() async {
        guard canSubmit else { return }
        currentPasswordError = nil
        errorMessage = nil
        showErrorAlert = false

        guard verifyCurrentPassword() else {
            currentPasswordError = "Current password is incorrect."
            return
        }

        isLoading = true
        do {
            try await AuthManager.shared.updatePassword(newPassword)
            isLoading = false
            dismiss()
        } catch {
            isLoading = false
            errorMessage = "Unable to update password. Please try again."
            showErrorAlert = true
        }
    }
}

#Preview {
    ChangePasswordView()
}
