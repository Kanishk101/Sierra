import Foundation

// MARK: - AuthUser
// Assembled by AuthManager from auth.users + staff_members.
// Keychain-persisted via Codable. NOT a direct Supabase table row.

struct AuthUser: Codable, Equatable, Identifiable {
    var id: UUID
    var email: String
    var role: UserRole
    var isFirstLogin: Bool
    var isProfileComplete: Bool
    var isApproved: Bool
    var name: String?
    var rejectionReason: String?
    var phone: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case isFirstLogin       = "is_first_login"
        case isProfileComplete  = "is_profile_complete"
        case isApproved         = "is_approved"
        case name
        case rejectionReason    = "rejection_reason"
        case phone
        case createdAt          = "created_at"
    }
}
