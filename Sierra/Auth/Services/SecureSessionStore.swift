import Foundation
import Security

/// Thin Keychain wrapper for persisting session token after 2FA success.
/// Used by biometric sign-in to restore sessions without re-entering credentials.
final class SecureSessionStore {

    static let shared = SecureSessionStore()
    private init() {}

    private let tokenKey   = "sierra.2fa.sessionToken"
    private let roleKey    = "sierra.2fa.userRole"
    private let profileKey = "sierra.lastProfile"

    // MARK: - Stored Profile

    /// Persisted profile for the "Welcome back" returning-user UI.
    struct StoredProfile: Codable {
        let userID: String
        let displayName: String   // "James Turner"
        let role: UserRole
        let initials: String      // "JT"
        let email: String

        var roleSubtitle: String { role.displayName }
    }

    // MARK: - Save

    func save(token: String, role: UserRole) {
        saveString(token, forKey: tokenKey)
        saveString(role.rawValue, forKey: roleKey)
    }

    func saveLastProfile(_ profile: StoredProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        deleteItem(forKey: profileKey)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: profileKey,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Load

    func loadToken() -> String? {
        loadString(forKey: tokenKey)
    }

    func loadRole() -> UserRole? {
        guard let raw = loadString(forKey: roleKey) else { return nil }
        return UserRole(rawValue: raw)
    }

    func loadLastProfile() -> StoredProfile? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: profileKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredProfile.self, from: data)
    }

    // MARK: - Clear

    /// Clears session tokens but keeps the last profile for Face ID welcome screen.
    func clearSessionButKeepProfile() {
        deleteItem(forKey: tokenKey)
        deleteItem(forKey: roleKey)
    }

    /// Clears everything including profile (explicit "forget me").
    func clearAll() {
        deleteItem(forKey: tokenKey)
        deleteItem(forKey: roleKey)
        deleteItem(forKey: profileKey)
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
