import SwiftUI
import LocalAuthentication

struct AdminProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isBiometricEnabled: Bool = BiometricAuthManager.isEnabled

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Avatar
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 72, height: 72)
                .overlay(
                    Text("FA")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )

            VStack(spacing: 4) {
                Text("Fleet Admin")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("admin@fleeeos.com")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Fleet Manager")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .padding(.top, 4)
            }

            // Security Section
            VStack(alignment: .leading, spacing: 0) {
                Text("SECURITY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .kerning(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                Toggle(isOn: $isBiometricEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: LAContext().biometryType == .faceID ? "faceid" : "touchid")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LAContext().biometryType == .faceID ? "Face ID" : "Touch ID")
                                .font(.body)
                            Text("Sign in without typing your password")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .onChange(of: isBiometricEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let ok = await BiometricAuthManager.authenticate(reason: "Enable biometric sign-in for Sierra")
                            if ok {
                                BiometricAuthManager.enable()
                            } else {
                                isBiometricEnabled = false
                            }
                        }
                    } else {
                        BiometricAuthManager.disable()
                    }
                }
            }

            Spacer()

            Button {
                AuthManager.shared.signOut()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body)
                    Text("Log Out")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.red.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    AdminProfileView()
}
