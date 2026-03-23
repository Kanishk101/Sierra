import SwiftUI

/// Prompt shown after every fresh login when Face ID is NOT yet enabled.
/// The user can enable it (persist forever) or skip (show again next login).
///
/// DESIGN: show every login unless biometric is already enabled.
/// Previously used a one-time `hasBeenPrompted` flag which caused the
/// prompt to disappear permanently after the first Skip. Now:
///   - `shouldPrompt()` = biometric is not yet enabled
///   - Tapping "Allow" enables biometric and stops future prompts
///   - Tapping "Skip" does nothing permanent — prompt reappears next login
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

            Button {
                BiometricPreference.isEnabled = true
                dismiss()
            } label: {
                Text("Allow \(biometric.biometricDisplayName)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                // Skip: don't enable, don't mark as permanently prompted.
                // Prompt will appear again on next fresh login.
                dismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)
        }
        .padding(24)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    // MARK: - Static Helpers

    /// Show the enrollment prompt whenever biometric is not enabled.
    /// This means: show on every fresh login until the user enables it.
    static func shouldPrompt() -> Bool {
        !BiometricPreference.isEnabled
    }

    static func isBiometricEnabled() -> Bool {
        BiometricPreference.isEnabled
    }
}

#Preview {
    BiometricEnrollmentSheet()
}
