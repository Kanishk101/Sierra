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
    private let supabaseAccessTokenKey  = "sierra.supabase.accessToken"
    private let supabaseRefreshTokenKey = "sierra.supabase.refreshToken"
    private let supabaseUserIdKey       = "sierra.supabase.userId"

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

    struct SupabaseSessionSnapshot: Equatable {
        let accessToken: String
        let refreshToken: String
        let userId: UUID
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

    func saveSupabaseSession(
        accessToken: String,
        refreshToken: String,
        userId: UUID
    ) {
        guard !accessToken.isEmpty, !refreshToken.isEmpty else { return }
        saveString(accessToken, forKey: supabaseAccessTokenKey)
        saveString(refreshToken, forKey: supabaseRefreshTokenKey)
        saveString(userId.uuidString.lowercased(), forKey: supabaseUserIdKey)
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

    func loadSupabaseSession() -> SupabaseSessionSnapshot? {
        guard
            let accessToken = loadString(forKey: supabaseAccessTokenKey),
            let refreshToken = loadString(forKey: supabaseRefreshTokenKey),
            let userIdRaw = loadString(forKey: supabaseUserIdKey),
            let userId = UUID(uuidString: userIdRaw)
        else {
            return nil
        }
        return SupabaseSessionSnapshot(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId
        )
    }

    // MARK: - Clear

    /// Clears session tokens but keeps the last profile for Face ID welcome screen.
    func clearSessionButKeepProfile() {
        deleteItem(forKey: tokenKey)
        deleteItem(forKey: roleKey)
        clearSupabaseSession()
    }

    /// Clears everything including profile (explicit "forget me").
    func clearAll() {
        deleteItem(forKey: tokenKey)
        deleteItem(forKey: roleKey)
        deleteItem(forKey: profileKey)
        clearSupabaseSession()
    }

    func clearSupabaseSession() {
        deleteItem(forKey: supabaseAccessTokenKey)
        deleteItem(forKey: supabaseRefreshTokenKey)
        deleteItem(forKey: supabaseUserIdKey)
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
