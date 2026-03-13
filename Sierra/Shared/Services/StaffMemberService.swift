import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - StaffMemberInsertPayload

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
        case id
        case name
        case role
        case status
        case email
        case phone
        case availability
        case dateOfBirth             = "date_of_birth"
        case gender
        case address
        case emergencyContactName    = "emergency_contact_name"
        case emergencyContactPhone   = "emergency_contact_phone"
        case aadhaarNumber           = "aadhaar_number"
        case profilePhotoUrl         = "profile_photo_url"
        case isFirstLogin            = "is_first_login"
        case isProfileComplete       = "is_profile_complete"
        case isApproved              = "is_approved"
        case rejectionReason         = "rejection_reason"
        case joinedDate              = "joined_date"
    }

    init(from member: StaffMember) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.id                   = member.id.uuidString
        self.name                 = member.name
        self.role                 = member.role.rawValue
        self.status               = member.status.rawValue
        self.email                = member.email
        self.phone                = member.phone
        self.availability         = member.availability.rawValue
        self.dateOfBirth          = member.dateOfBirth.map { fmt.string(from: $0) }
        self.gender               = member.gender
        self.address              = member.address
        self.emergencyContactName  = member.emergencyContactName
        self.emergencyContactPhone = member.emergencyContactPhone
        self.aadhaarNumber        = member.aadhaarNumber
        self.profilePhotoUrl      = member.profilePhotoUrl
        self.isFirstLogin         = member.isFirstLogin
        self.isProfileComplete    = member.isProfileComplete
        self.isApproved           = member.isApproved
        self.rejectionReason      = member.rejectionReason
        self.joinedDate           = member.joinedDate.map { fmt.string(from: $0) }
    }
}

// MARK: - StaffMemberUpdatePayload

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
        case name
        case role
        case status
        case phone
        case availability
        case dateOfBirth             = "date_of_birth"
        case gender
        case address
        case emergencyContactName    = "emergency_contact_name"
        case emergencyContactPhone   = "emergency_contact_phone"
        case aadhaarNumber           = "aadhaar_number"
        case profilePhotoUrl         = "profile_photo_url"
        case isFirstLogin            = "is_first_login"
        case isProfileComplete       = "is_profile_complete"
        case isApproved              = "is_approved"
        case rejectionReason         = "rejection_reason"
        case joinedDate              = "joined_date"
    }

    init(from member: StaffMember) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.name                  = member.name
        self.role                  = member.role.rawValue
        self.status                = member.status.rawValue
        self.phone                 = member.phone
        self.availability          = member.availability.rawValue
        self.dateOfBirth           = member.dateOfBirth.map { fmt.string(from: $0) }
        self.gender                = member.gender
        self.address               = member.address
        self.emergencyContactName  = member.emergencyContactName
        self.emergencyContactPhone = member.emergencyContactPhone
        self.aadhaarNumber         = member.aadhaarNumber
        self.profilePhotoUrl       = member.profilePhotoUrl
        self.isFirstLogin          = member.isFirstLogin
        self.isProfileComplete     = member.isProfileComplete
        self.isApproved            = member.isApproved
        self.rejectionReason       = member.rejectionReason
        self.joinedDate            = member.joinedDate.map { fmt.string(from: $0) }
    }
}

// MARK: - StaffMemberService

struct StaffMemberService {

    // MARK: - Fetch All

    static func fetchAllStaff() async throws -> [StaffMember] {
        return try await supabase
            .from("staff_members")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Fetch by ID

    static func fetchStaffMember(id: UUID) async throws -> StaffMember {
        return try await supabase
            .from("staff_members")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Fetch by Role

    static func fetchStaff(role: UserRole) async throws -> [StaffMember] {
        return try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: role.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Fetch Available Drivers

    static func fetchAvailableDrivers() async throws -> [StaffMember] {
        return try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: UserRole.driver.rawValue)
            .eq("status", value: StaffStatus.active.rawValue)
            .eq("availability", value: StaffAvailability.available.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Insert

    static func addStaffMember(_ member: StaffMember) async throws {
        let payload = StaffMemberInsertPayload(from: member)
        try await supabase
            .from("staff_members")
            .insert(payload)
            .execute()
    }

    // MARK: - Update

    static func updateStaffMember(_ member: StaffMember) async throws {
        let payload = StaffMemberUpdatePayload(from: member)
        try await supabase
            .from("staff_members")
            .update(payload)
            .eq("id", value: member.id.uuidString)
            .execute()
    }

    // MARK: - Delete

    static func deleteStaffMember(id: UUID) async throws {
        try await supabase
            .from("staff_members")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
