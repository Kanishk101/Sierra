import Foundation
import Supabase

// ⚠️ DEPRECATED — This file targets auth_users which no longer exists in Schema v2.
// All functionality has been moved to StaffMemberService + AuthManager (Supabase Auth).
// This file will be deleted in the cleanup phase.
// No call sites remain — safe to remove.

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

struct AuthUserService {

    // MARK: - Fetch

    /// Fetches the staff_members row that mirrors auth.users.id.
    static func fetchAuthUser(id: UUID) async throws -> StaffMember? {
        let rows: [StaffMember] = try await supabase
            .from("staff_members")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Update Auth Fields

    static func updateAuthFields(
        id: UUID,
        isFirstLogin: Bool,
        isProfileComplete: Bool,
        isApproved: Bool,
        name: String?,
        phone: String?
    ) async throws {
        struct Payload: Encodable {
            let is_first_login: Bool
            let is_profile_complete: Bool
            let is_approved: Bool
            let name: String?
            let phone: String?
        }
        try await supabase
            .from("staff_members")
            .update(Payload(
                is_first_login: isFirstLogin,
                is_profile_complete: isProfileComplete,
                is_approved: isApproved,
                name: name,
                phone: phone
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Mark First Login Complete

    static func markFirstLoginComplete(id: UUID) async throws {
        struct Payload: Encodable { let is_first_login: Bool }
        try await supabase
            .from("staff_members")
            .update(Payload(is_first_login: false))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Mark Profile Complete

    static func markProfileComplete(id: UUID) async throws {
        struct Payload: Encodable { let is_profile_complete: Bool }
        try await supabase
            .from("staff_members")
            .update(Payload(is_profile_complete: true))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Set Approval Status

    static func setApprovalStatus(id: UUID, approved: Bool, rejectionReason: String?) async throws {
        struct Payload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
        }
        let status = approved ? StaffStatus.active.rawValue : StaffStatus.suspended.rawValue
        try await supabase
            .from("staff_members")
            .update(Payload(is_approved: approved, status: status, rejection_reason: rejectionReason))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
