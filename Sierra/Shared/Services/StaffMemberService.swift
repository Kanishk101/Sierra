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
// Includes id (mirrors auth.users.id — must be set explicitly)
// Excludes: created_at, updated_at

struct StaffMemberInsertPayload: Encodable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let dateOfBirth: String?
    let gender: String?
    let address: String?
    let emergencyContactName: String?
    let emergencyContactPhone: String?
    let aadhaarNumber: String?
    let profilePhotoUrl: String?
    let isFirstLogin: Bool
    let isProfileComplete: Bool
    let isApproved: Bool
    let rejectionReason: String?
    let joinedDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, role, status, email, phone, availability
        case dateOfBirth          = "date_of_birth"
        case gender, address
        case emergencyContactName  = "emergency_contact_name"
        case emergencyContactPhone = "emergency_contact_phone"
        case aadhaarNumber        = "aadhaar_number"
        case profilePhotoUrl      = "profile_photo_url"
        case isFirstLogin         = "is_first_login"
        case isProfileComplete    = "is_profile_complete"
        case isApproved           = "is_approved"
        case rejectionReason      = "rejection_reason"
        case joinedDate           = "joined_date"
    }

    init(from m: StaffMember) {
        id                   = m.id.uuidString
        name                 = m.name
        role                 = m.role.rawValue
        status               = m.status.rawValue
        email                = m.email
        phone                = m.phone
        availability         = m.availability.rawValue
        dateOfBirth          = m.dateOfBirth.map { iso.string(from: $0) }
        gender               = m.gender
        address              = m.address
        emergencyContactName  = m.emergencyContactName
        emergencyContactPhone = m.emergencyContactPhone
        aadhaarNumber        = m.aadhaarNumber
        profilePhotoUrl      = m.profilePhotoUrl
        isFirstLogin         = m.isFirstLogin
        isProfileComplete    = m.isProfileComplete
        isApproved           = m.isApproved
        rejectionReason      = m.rejectionReason
        joinedDate           = m.joinedDate.map { iso.string(from: $0) }
    }
}

// MARK: - StaffMemberUpdatePayload
// Excludes: id, created_at, updated_at

struct StaffMemberUpdatePayload: Encodable {
    let name: String?
    let role: String
    let status: String
    let phone: String?
    let availability: String
    let dateOfBirth: String?
    let gender: String?
    let address: String?
    let emergencyContactName: String?
    let emergencyContactPhone: String?
    let aadhaarNumber: String?
    let profilePhotoUrl: String?
    let isFirstLogin: Bool
    let isProfileComplete: Bool
    let isApproved: Bool
    let rejectionReason: String?
    let joinedDate: String?

    enum CodingKeys: String, CodingKey {
        case name, role, status, phone, availability
        case dateOfBirth          = "date_of_birth"
        case gender, address
        case emergencyContactName  = "emergency_contact_name"
        case emergencyContactPhone = "emergency_contact_phone"
        case aadhaarNumber        = "aadhaar_number"
        case profilePhotoUrl      = "profile_photo_url"
        case isFirstLogin         = "is_first_login"
        case isProfileComplete    = "is_profile_complete"
        case isApproved           = "is_approved"
        case rejectionReason      = "rejection_reason"
        case joinedDate           = "joined_date"
    }

    init(from m: StaffMember) {
        name                 = m.name
        role                 = m.role.rawValue
        status               = m.status.rawValue
        phone                = m.phone
        availability         = m.availability.rawValue
        dateOfBirth          = m.dateOfBirth.map { iso.string(from: $0) }
        gender               = m.gender
        address              = m.address
        emergencyContactName  = m.emergencyContactName
        emergencyContactPhone = m.emergencyContactPhone
        aadhaarNumber        = m.aadhaarNumber
        profilePhotoUrl      = m.profilePhotoUrl
        isFirstLogin         = m.isFirstLogin
        isProfileComplete    = m.isProfileComplete
        isApproved           = m.isApproved
        rejectionReason      = m.rejectionReason
        joinedDate           = m.joinedDate.map { iso.string(from: $0) }
    }
}

// MARK: - StaffMemberService

struct StaffMemberService {

    // MARK: Fetch

    static func fetchAllStaffMembers() async throws -> [StaffMember] {
        try await supabase
            .from("staff_members")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchStaffMember(id: UUID) async throws -> StaffMember? {
        let rows: [StaffMember] = try await supabase
            .from("staff_members")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func fetchStaffMembers(role: UserRole) async throws -> [StaffMember] {
        try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: role.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func fetchAvailableDrivers() async throws -> [StaffMember] {
        try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: UserRole.driver.rawValue)
            .eq("status", value: StaffStatus.active.rawValue)
            .eq("availability", value: StaffAvailability.available.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: Insert

    static func addStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .insert(StaffMemberInsertPayload(from: member))
            .execute()
    }

    // MARK: Update

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
}
