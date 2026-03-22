import SwiftUI


/// One-time sheet asking the user to enable Face ID after first successful login.
/// Preference is stored via BiometricPreference (single Keychain key, persists across sessions).
struct BiometricEnrollmentSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let biometric = BiometricManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Always show Face ID symbol
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
        .interactiveDismissDisabled(true)
        // FIX: markPrompted() was called in .onAppear which fired before the user
        // made any choice. If the sheet was dismissed (e.g. app backgrounded),
        // hasBeenPrompted was permanently true and the sheet never showed again.
        // Now markPrompted() is called ONLY when the user explicitly taps a button.
    }

    // MARK: - Actions

    private func enableBiometric() {
        BiometricPreference.markPrompted()   // record choice BEFORE dismissing
        BiometricPreference.isEnabled = true
        dismiss()
    }

    private func skipBiometric() {
        BiometricPreference.markPrompted()   // record choice BEFORE dismissing
        BiometricPreference.isEnabled = false
        dismiss()
    }

    // MARK: - Static Helpers (used by LoginViewModel and ContentView)

    static func shouldPrompt() -> Bool {
        !BiometricPreference.hasBeenPrompted
    }

    static func isBiometricEnabled() -> Bool {
        BiometricPreference.isEnabled
    }
}

#Preview {
    BiometricEnrollmentSheet()
}
