import SwiftUI
import LocalAuthentication

struct AdminProfileView: View {
    @Environment(\.dismiss) private var dismiss
    private var authManager = AuthManager.shared

    // Initialized from the canonical Keychain-backed preference.
    // Updated via onChange which writes back to the same store.
    @State private var isBiometricEnabled: Bool = BiometricPreference.isEnabled

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
                    Text(initials)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )

            VStack(spacing: 4) {
                Text(authManager.currentUser?.name ?? "Fleet Manager")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(authManager.currentUser?.email ?? "")
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
                        Image(systemName: biometricIcon)
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(biometricName)
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
                // CRITICAL FIX: do NOT require a Face ID authentication challenge
                // just to SET the preference. The challenge is required when USING
                // Face ID to sign in, not when enabling the setting. Previously the
                // LAContext challenge fired here — any failure (wrong face, cancel,
                // simulator) silently reverted the toggle to false, making it
                // impossible to enable biometrics on a device with Face ID issues.
                .onChange(of: isBiometricEnabled) { _, enabled in
                    BiometricPreference.isEnabled = enabled
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
        // Sync toggle state when the sheet re-appears (e.g. user dismissed another
        // sheet that may have changed the preference).
        .onAppear {
            isBiometricEnabled = BiometricPreference.isEnabled
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let name = authManager.currentUser?.name ?? "FM"
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    private var biometricIcon: String {
        switch LAContext().biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private var biometricName: String {
        switch LAContext().biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Biometrics"
        }
    }
}

#Preview {
    AdminProfileView()
}
