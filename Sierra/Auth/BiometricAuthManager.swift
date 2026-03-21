import LocalAuthentication

enum BiometricAuthManager {
    private static let key = "sierra.biometric.enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func enable() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: key)
    }

    /// Performs biometric authentication. Returns true on success.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )) ?? false
    }
}
