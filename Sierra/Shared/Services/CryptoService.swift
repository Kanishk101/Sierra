import Foundation
import CryptoKit

/// Password hashing using SHA-256 + random salt via CryptoKit.
// COMPLIANCE: OTP values are NEVER stored raw.
// Only the SHA-256 hash is persisted to two_factor_sessions.otp_hash
// and proof_of_deliveries.otp_hash. See Sprint 2 security audit.
struct CryptoService {

    struct HashedCredential: Codable {
        let hash: String
        let salt: String
    }

    /// Hash a password with a freshly generated 16-byte salt.
    static func hash(password: String) -> HashedCredential {
        let saltData = generateSalt()
        let salt = saltData.map { String(format: "%02x", $0) }.joined()
        let hash = sha256(password: password, salt: salt)
        return HashedCredential(hash: hash, salt: salt)
    }

    /// Verify a password against a stored credential.
    static func verify(password: String, credential: HashedCredential) -> Bool {
        let candidateHash = sha256(password: password, salt: credential.salt)
        return candidateHash == credential.hash
    }

    // MARK: - Private

    private static func sha256(password: String, salt: String) -> String {
        let combined = salt + password
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func generateSalt(length: Int = 16) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes
    }
}
