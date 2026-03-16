import SwiftUI


/// One-time sheet asking the user to enable Face ID after first successful login.
/// Stores the preference and prompt flag in Keychain.
struct BiometricEnrollmentSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let biometric = BiometricManager.shared

    // Keychain keys
    private static let kBiometricEnabled = "com.fleetOS.biometricEnabled"
    private static let kHasPrompted = "com.fleetOS.hasPromptedBiometric"

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

            Text("Use \(biometric.biometricDisplayName) for faster, more secure sign-in to FleetOS.")
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
        .onAppear {
            // Mark as prompted so we never show again
            Self.markAsPrompted()
        }
    }

    // MARK: - Actions

    private func enableBiometric() {
        Self.setBiometricEnabled(true)
        dismiss()
    }

    private func skipBiometric() {
        Self.setBiometricEnabled(false)
        dismiss()
    }

    // MARK: - Keychain Helpers

    static func shouldPrompt() -> Bool {
        let prompted = KeychainService.load(key: kHasPrompted) != nil
        return !prompted
    }

    static func isBiometricEnabled() -> Bool {
        guard let data = KeychainService.load(key: kBiometricEnabled),
              let str = String(data: data, encoding: .utf8) else {
            return false
        }
        return str == "true"
    }

    private static func setBiometricEnabled(_ enabled: Bool) {
        if let data = (enabled ? "true" : "false").data(using: .utf8) {
            _ = KeychainService.save(data, forKey: kBiometricEnabled)
        }
    }

    private static func markAsPrompted() {
        if let data = "true".data(using: .utf8) {
            _ = KeychainService.save(data, forKey: kHasPrompted)
        }
    }
}

#Preview {
    BiometricEnrollmentSheet()
}
