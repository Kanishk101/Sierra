import LocalAuthentication

enum BiometricAuthManager {

    static var isEnabled: Bool {
        get { BiometricPreference.isEnabled }
        set { BiometricPreference.isEnabled = newValue }
    }

    static func enable()  { BiometricPreference.isEnabled = true }
    static func disable() { BiometricPreference.isEnabled = false }

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
