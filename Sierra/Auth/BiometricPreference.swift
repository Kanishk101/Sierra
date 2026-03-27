import Foundation

/// Single source of truth for whether the user has enrolled biometric login.
/// Previously split across UserDefaults (BiometricAuthManager) and Keychain
/// (BiometricEnrollmentSheet) using two different keys — both leading to the
/// Face ID loop bug. All callers now use this single type and single Keychain key.
enum BiometricPreference {

    private static let enabledKey  = "com.sierra.biometricEnabled"   // ONE canonical key
    private static let promptedKey = "com.sierra.biometricPrompted"

    static var isEnabled: Bool {
        get {
            guard let data = KeychainService.load(key: enabledKey),
                  let str  = String(data: data, encoding: .utf8) else { return false }
            return str == "true"
        }
        set {
            let str = newValue ? "true" : "false"
            if let data = str.data(using: .utf8) {
                _ = KeychainService.save(data, forKey: enabledKey)
            }
        }
    }

    static var hasBeenPrompted: Bool {
        KeychainService.load(key: promptedKey) != nil
    }

    static func markPrompted() {
        if let data = "true".data(using: .utf8) {
            _ = KeychainService.save(data, forKey: promptedKey)
        }
    }

    /// Called on signOut. Wipes enrollment so the post-login Face ID prompt
    /// appears again on each fresh credential + 2FA sign-in flow.
    static func clearSessionData() {
        KeychainService.delete(key: enabledKey)
        KeychainService.delete(key: promptedKey)
    }
}
