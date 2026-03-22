import SwiftUI


/// One-time sheet asking the user to enable Face ID after first successful login.
/// Preference is stored via BiometricPreference (single Keychain key, persists across sessions).
struct BiometricEnrollmentSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let biometric = BiometricManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .padding(.bottom, 8)

            Text("Enable \(biometric.biometricDisplayName)?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("Use \(biometric.biometricDisplayName) for faster, more secure sign-in to Sierra.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)

            Spacer()

            // Allow button
            Button {
                enableBiometric()
            } label: {
                Text("Allow \(biometric.biometricDisplayName)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Color.orange,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }

            // Skip button
            Button {
                skipBiometric()
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)
        }
        .padding(24)
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        )
        // Prevent drag-to-dismiss so the user must explicitly choose.
        // markPrompted() is called INSIDE each action button — not in onAppear —
        // to guarantee it's only marked after the user makes an explicit choice.
        // Previously calling it in onAppear meant a force-close mid-presentation
        // could mark as prompted before the user had a chance to respond.
        .interactiveDismissDisabled(true)
    }

    // MARK: - Actions

    private func enableBiometric() {
        // Mark prompted BEFORE writing isEnabled so the state is consistent
        // even if the app is killed between these two writes.
        BiometricPreference.markPrompted()
        BiometricPreference.isEnabled = true
        dismiss()
    }

    private func skipBiometric() {
        BiometricPreference.markPrompted()
        BiometricPreference.isEnabled = false
        dismiss()
    }

    // MARK: - Static Helpers (used by ContentView)

    static func shouldPrompt() -> Bool {
        !BiometricPreference.hasBeenPrompted && BiometricManager.shared.canUseBiometrics()
    }

    static func isBiometricEnabled() -> Bool {
        BiometricPreference.isEnabled
    }
}

#Preview {
    BiometricEnrollmentSheet()
}
