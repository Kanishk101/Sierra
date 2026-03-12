import Foundation
import Security

/// Thin Keychain wrapper for persisting session token after 2FA success.
/// Used by biometric sign-in to restore sessions without re-entering credentials.
final class SecureSessionStore {

    static let shared = SecureSessionStore()
    private init() {}

    private let tokenKey = "sierra.2fa.sessionToken"
    private let roleKey  = "sierra.2fa.userRole"

    // MARK: - Save

    func save(token: String, role: UserRole) {
        saveString(token, forKey: tokenKey)
        saveString(role.rawValue, forKey: roleKey)
    }

    // MARK: - Load

    func loadToken() -> String? {
        loadString(forKey: tokenKey)
    }

    func loadRole() -> UserRole? {
        guard let raw = loadString(forKey: roleKey) else { return nil }
        return UserRole(rawValue: raw)
    }

    // MARK: - Clear

    func clear() {
        deleteItem(forKey: tokenKey)
        deleteItem(forKey: roleKey)
    }

    // MARK: - Private Keychain Helpers

    private func saveString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Delete existing first
        deleteItem(forKey: key)

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
