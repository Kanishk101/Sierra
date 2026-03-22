import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - StaffMemberServiceError

enum StaffMemberServiceError: LocalizedError {
    case availabilityTargetMissing(UUID)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .availabilityTargetMissing(let id):
            return "No staff_members row found for id \(id.uuidString.lowercased())"
        case .deleteFailed(let reason):
            return "Staff member deletion failed: \(reason)"
        }
    }
}

// MARK: - StaffMemberInsertPayload

struct StaffMemberInsertPayload: Encodable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let is_first_login: Bool
    let is_profile_complete: Bool
    let is_approved: Bool
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?

    init(from s: StaffMember) {
        self.id                      = s.id.uuidString
        self.name                    = s.name
        self.role                    = s.role.rawValue
        self.status                  = s.status.rawValue
        self.email                   = s.email
        self.phone                   = s.phone
        self.availability            = s.availability.rawValue
        self.is_first_login          = s.isFirstLogin
        self.is_profile_complete     = s.isProfileComplete
        self.is_approved             = s.isApproved
        self.rejection_reason        = s.rejectionReason
        self.date_of_birth           = s.dateOfBirth
        self.gender                  = s.gender
        self.address                 = s.address
        self.emergency_contact_name  = s.emergencyContactName
        self.emergency_contact_phone = s.emergencyContactPhone
        self.aadhaar_number          = s.aadhaarNumber
        self.profile_photo_url       = s.profilePhotoUrl
        self.joined_date             = s.joinedDate.map { iso.string(from: $0) }
    }
}

// MARK: - StaffMemberUpdatePayload
// Profile-only fields. Intentionally excludes `role` and `email`.

struct StaffMemberUpdatePayload: Encodable {
    let name: String?
    let phone: String?
    let availability: String
    let is_profile_complete: Bool
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?

    init(from s: StaffMember) {
        self.name                    = s.name
        self.phone                   = s.phone
        self.availability            = s.availability.rawValue
        self.is_profile_complete     = s.isProfileComplete
        self.date_of_birth           = s.dateOfBirth
        self.gender                  = s.gender
        self.address                 = s.address
        self.emergency_contact_name  = s.emergencyContactName
        self.emergency_contact_phone = s.emergencyContactPhone
        self.aadhaar_number          = s.aadhaarNumber
        self.profile_photo_url       = s.profilePhotoUrl
    }
}

// MARK: - StaffMemberDB

struct StaffMemberDB: Decodable {
    let id: UUID
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let is_first_login: Bool?
    let is_profile_complete: Bool?
    let is_approved: Bool?
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?
    let created_at: String?
    let updated_at: String?
}

// MARK: - StaffMemberDB Mappers

extension StaffMemberDB {
    func toStaffMember() -> StaffMember {
        StaffMember(
            id: id,
            name: name,
            role: UserRole(rawValue: role) ?? .driver,
            status: StaffStatus(rawValue: status) ?? .pendingApproval,
            email: email,
            phone: phone,
            availability: StaffAvailability(rawValue: availability) ?? .unavailable,
            dateOfBirth: date_of_birth,
            gender: gender,
            address: address,
            emergencyContactName: emergency_contact_name,
            emergencyContactPhone: emergency_contact_phone,
            aadhaarNumber: aadhaar_number,
            profilePhotoUrl: profile_photo_url,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            rejectionReason: rejection_reason,
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
            joinedDate: joined_date.flatMap { iso.date(from: $0) },
            createdAt: created_at.flatMap { iso.date(from: $0) } ?? Date(),
            updatedAt: updated_at.flatMap { iso.date(from: $0) } ?? Date()
        )
    }

    func toAuthUser() -> AuthUser {
        AuthUser(
            id: id,
            email: email,
            role: UserRole(rawValue: role) ?? .driver,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            name: name,
            rejectionReason: rejection_reason,
            phone: phone,
            createdAt: created_at.flatMap { iso.date(from: $0) } ?? Date()
        )
    }
}

// MARK: - Edge function response type

private struct DeleteStaffResponse: Decodable {
    let success: Bool?
    let deletedId: String?
    let error: String?
}

// MARK: - StaffMemberService

struct StaffMemberService {

    // MARK: Fetch

    static func fetchAllStaffMembers() async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    static func fetchStaffMember(id: UUID) async throws -> StaffMember? {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
            .value
        return rows.first?.toStaffMember()
    }

    static func fetchStaffMembers(role: UserRole) async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: role.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    static func fetchAvailableDrivers() async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: UserRole.driver.rawValue)
            .eq("status", value: StaffStatus.active.rawValue)
            .eq("availability", value: StaffAvailability.available.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    // MARK: Insert
    // NOTE: New staff creation goes through the `create-staff-account` edge
    // function (called from CreateStaffViewModel), which atomically creates
    // the auth user + DB row with rollback on failure. This direct method
    // remains for internal/test use only.

    static func addStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .insert(StaffMemberInsertPayload(from: member))
            .execute()
    }

    // MARK: Update (profile fields only — role and email excluded intentionally)

    static func updateStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .update(StaffMemberUpdatePayload(from: member))
            .eq("id", value: member.id.uuidString.lowercased())
            .execute()
    }

    // MARK: - Targeted availability-only update with verification

    static func updateAvailability(staffId: UUID, available: Bool) async throws -> String {
        struct Row: Decodable { let id: UUID; let availability: String }
        let value = available
            ? StaffAvailability.available.rawValue
            : StaffAvailability.unavailable.rawValue
        struct Payload: Encodable { let availability: String }

        let idLower = staffId.uuidString.lowercased()
        let rows: [Row] = try await supabase
            .from("staff_members")
            .update(Payload(availability: value))
            .eq("id", value: idLower)
            .select("id, availability")
            .execute()
            .value

        if rows.isEmpty {
            throw StaffMemberServiceError.availabilityTargetMissing(staffId)
        }
        return rows[0].availability
    }

    // MARK: - Delete (via edge function — fixes C-07: orphaned auth users)
    //
    // Previously this did a direct DB delete leaving auth.users entries alive.
    // Deleted staff members could still authenticate but would crash on app load.
    //
    // The `delete-staff-member` edge function:
    //   1. Verifies the caller is a fleet manager
    //   2. Prevents self-deletion and inter-manager deletion
    //   3. Deletes staff_members row (blocks app access immediately)
    //   4. Deletes Supabase Auth user via admin API (non-fatal if it fails)

    static func deleteStaffMember(id: UUID) async throws {
        struct Payload: Encodable { let staffMemberId: String }

        let response: DeleteStaffResponse = try await supabase.functions.invoke(
            "delete-staff-member",
            options: FunctionInvokeOptions(body: Payload(staffMemberId: id.uuidString))
        )

        if let errorMsg = response.error {
            throw StaffMemberServiceError.deleteFailed(errorMsg)
        }
    }

    // MARK: - Mark Profile Complete

    static func markProfileComplete(
        staffId: UUID,
        name: String,
        phone: String,
        gender: String,
        dateOfBirth: String,
        address: String,
        emergencyContactName: String,
        emergencyContactPhone: String,
        aadhaarNumber: String
    ) async throws {
        struct Payload: Encodable {
            let is_profile_complete: Bool
            let name: String
            let phone: String
            let gender: String
            let date_of_birth: String
            let address: String
            let emergency_contact_name: String
            let emergency_contact_phone: String
            let aadhaar_number: String
        }
        try await supabase
            .from("staff_members")
            .update(Payload(
                is_profile_complete:     true,
                name:                    name,
                phone:                   phone,
                gender:                  gender,
                date_of_birth:           dateOfBirth,
                address:                 address,
                emergency_contact_name:  emergencyContactName,
                emergency_contact_phone: emergencyContactPhone,
                aadhaar_number:          aadhaarNumber
            ))
            .eq("id", value: staffId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Set Approval Status
    //
    // CRITICAL: when approving a driver or maintenance person, we MUST also set
    // `availability = 'Available'`. The DB default is 'Unavailable', which means
    // newly-approved staff members are invisible to availableDrivers() / any trip
    // assignment flow, making the entire trip creation wizard show "No available
    // drivers" forever regardless of how many approved drivers exist.

    static func setApprovalStatus(
        staffId: UUID,
        approved: Bool,
        rejectionReason: String? = nil
    ) async throws {
        struct ApprovePayload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
            let availability: String
        }
        struct RejectPayload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
        }

        if approved {
            try await supabase
                .from("staff_members")
                .update(ApprovePayload(
                    is_approved:      true,
                    status:           StaffStatus.active.rawValue,
                    rejection_reason: nil,
                    availability:     StaffAvailability.available.rawValue
                ))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()
        } else {
            try await supabase
                .from("staff_members")
                .update(RejectPayload(
                    is_approved:      false,
                    status:           StaffStatus.suspended.rawValue,
                    rejection_reason: rejectionReason
                ))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()
        }
    }

    // MARK: - Set Status (admin-only: suspend / reactivate)

    static func setStatus(staffId: UUID, status: StaffStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("staff_members")
            .update(Payload(status: status.rawValue))
            .eq("id", value: staffId.uuidString.lowercased())
            .execute()
    }
}

// MARK: - StaffMember → AuthUser Mapper

extension StaffMember {
    func toAuthUser() -> AuthUser {
        AuthUser(
            id:                id,
            email:             email,
            role:              role,
            isFirstLogin:      isFirstLogin,
            isProfileComplete: isProfileComplete,
            isApproved:        isApproved,
            name:              name,
            rejectionReason:   rejectionReason,
            phone:             phone,
            createdAt:         createdAt
        )
    }
}
