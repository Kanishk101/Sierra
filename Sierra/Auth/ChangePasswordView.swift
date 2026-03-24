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
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.orange)

                        Text("Update your account password")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                Section("Current Password") {
                    SecureField("Enter current password", text: $currentPassword)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let currentPasswordError {
                        Text(currentPasswordError)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.leading, 4)
                    }
                }

                Section("New Password") {
                    SecureField("Enter new password", text: $newPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !confirmPassword.isEmpty, confirmPassword != newPassword {
                        Text("Passwords do not match.")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.leading, 4)
                    }
                    if !newPassword.isEmpty, newPassword.count < 8 {
                        Text("Use at least 8 characters.")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.leading, 4)
                    }
                    if !currentPassword.isEmpty, !newPassword.isEmpty, currentPassword == newPassword {
                        Text("New password must be different from current password.")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.leading, 4)
                    }
                }

                Section {
                    Button {
                        Task { await updatePassword() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Update Password")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isLoading)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Password Update Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unable to update password. Please try again.")
        }
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty
            && !newPassword.isEmpty
            && !confirmPassword.isEmpty
            && currentPassword != newPassword
            && newPassword.count >= 8
            && confirmPassword == newPassword
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

        guard currentPassword != newPassword else {
            errorMessage = "New password must be different from your current password."
            showErrorAlert = true
            return
        }

        isLoading = true
        errorMessage = nil
        showErrorAlert = false

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
