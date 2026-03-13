import Foundation

// MARK: - AuthUser
// Mirrors the fields from auth.users joined with staff_members
// that are needed for app-wide session management.

struct AuthUser: Codable, Equatable {
    let id: UUID
    let email: String
    var role: UserRole
    var isFirstLogin: Bool
    var isProfileComplete: Bool
    var isApproved: Bool
    var name: String?
    var rejectionReason: String?
    var phone: String?
    var profilePhotoUrl: String?
    var status: String?
    var availability: String?
    var createdAt: Date?
}
