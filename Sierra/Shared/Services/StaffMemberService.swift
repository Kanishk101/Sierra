import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - StaffMemberInsertPayload
// Includes id + password (vinayak pattern)
// Excludes: created_at, updated_at

struct StaffMemberInsertPayload: Encodable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let email: String
    let password: String
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

    init(from s: StaffMember, password: String = "") {
        self.id                      = s.id.uuidString
        self.name                    = s.name
        self.role                    = s.role.rawValue
        self.status                  = s.status.rawValue
        self.email                   = s.email
        self.password                = password
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
// Profile-only fields — excludes auth and admin-controlled columns:
//   password        → only via AuthManager.updatePasswordAndFirstLogin()
//   is_first_login  → only via AuthManager.updatePasswordAndFirstLogin() / markPasswordChanged()
//   is_approved     → only via StaffMemberService.setApprovalStatus()
//   rejection_reason→ only via StaffMemberService.setApprovalStatus()
//   id, created_at, updated_at → never in updates

struct StaffMemberUpdatePayload: Encodable {
    let name: String?
    let role: String
    let status: String
    let email: String
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
        self.role                    = s.role.rawValue
        self.status                  = s.status.rawValue
        self.email                   = s.email
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

// MARK: - StaffMemberDB (full v2 decode struct with password)

struct StaffMemberDB: Decodable {
    let id: UUID
    let name: String?
    let role: String
    let status: String
    let email: String
    let password: String
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
            .eq("id", value: id.uuidString)
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

    static func addStaffMember(_ member: StaffMember, password: String = "") async throws {
        try await supabase
            .from("staff_members")
            .insert(StaffMemberInsertPayload(from: member, password: password))
            .execute()
    }

    // MARK: Update (profile fields only — never touches auth/admin columns)

    static func updateStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .update(StaffMemberUpdatePayload(from: member))
            .eq("id", value: member.id.uuidString)
            .execute()
    }

    // MARK: Delete

    static func deleteStaffMember(id: UUID) async throws {
        try await supabase
            .from("staff_members")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Mark Profile Complete (targeted update — does not touch auth/admin fields)

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
            .eq("id", value: staffId.uuidString)
            .execute()
    }

    // MARK: - Set Approval Status (admin-only — targeted update)

    static func setApprovalStatus(
        staffId: UUID,
        approved: Bool,
        rejectionReason: String? = nil
    ) async throws {
        struct Payload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
        }
        try await supabase
            .from("staff_members")
            .update(Payload(
                is_approved:      approved,
                status:           approved ? StaffStatus.active.rawValue : StaffStatus.suspended.rawValue,
                rejection_reason: rejectionReason
            ))
            .eq("id", value: staffId.uuidString)
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
