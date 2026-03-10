import Foundation

struct AuthUser: Codable, Equatable {
    let id: UUID
    let email: String
    var role: UserRole
    var isFirstLogin: Bool
    var isProfileComplete: Bool
    var isApproved: Bool
    var name: String?
}
