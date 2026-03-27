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

            ZStack {
                Circle()
                    .fill(SierraTheme.Colors.ember.opacity(0.12))
                    .frame(width: 120, height: 120)
                
                Image(systemName: biometric.biometricIconName)
                    .font(SierraFont.scaled(52, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, 8)

            VStack(spacing: 12) {
                Text("Enable \(biometric.biometricDisplayName)?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Use \(biometric.biometricDisplayName) for faster, more secure sign-in to Sierra. You can always change this later in Settings.")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }

            if !biometric.canUseBiometrics() {
                Text("Biometric authentication is not available on this device.")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 12) {
                SierraButton.primary("Allow \(biometric.biometricDisplayName)") {
                    BiometricPreference.isEnabled = true
                    dismiss()
                }
                .disabled(!biometric.canUseBiometrics())
                .opacity(biometric.canUseBiometrics() ? 1 : 0.6)

                Button {
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(SierraFont.body(16, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(24)
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    // MARK: - Static Helpers

    /// Show the enrollment prompt whenever biometric is not enabled.
    /// This means: show on every fresh login until the user enables it.
    static func shouldPrompt() -> Bool {
        BiometricManager.shared.canUseBiometrics() && !BiometricPreference.isEnabled
    }

    static func isBiometricEnabled() -> Bool {
        BiometricPreference.isEnabled
    }
}

#Preview {
    BiometricEnrollmentSheet()
}
