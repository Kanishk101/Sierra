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

            // Always show Face ID symbol — biometricIconName returns lock.fill on Simulator
            // since LAContext.biometryType == .none without real hardware.
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(SierraTheme.Colors.ember)
                .padding(.bottom, 8)

            Text("Enable \(biometric.biometricDisplayName)?")
                .font(SierraFont.title3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Use \(biometric.biometricDisplayName) for faster, more secure sign-in to FleetOS.")
                .font(SierraFont.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)

            Spacer()

            // Allow button
            Button {
                enableBiometric()
            } label: {
                Text("Allow \(biometric.biometricDisplayName)")
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        SierraTheme.Colors.ember,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }

            // Skip button
            Button {
                skipBiometric()
            } label: {
                Text("Skip for Now")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 20)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        // Prompt once per install — don't gate on canUseBiometrics() here
        // because that can return false at timing-sensitive moments.
        // The sheet itself always shows; Face ID works on physical devices.
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
