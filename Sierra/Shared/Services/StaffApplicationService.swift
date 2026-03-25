import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - StaffApplicationInsertPayload
// Excludes: id, created_at

struct StaffApplicationInsertPayload: Encodable {
    let staffMemberId: String
    let role: String
    let submittedDate: String
    let status: String
    let rejectionReason: String?
    let reviewedBy: String?
    let reviewedAt: String?
    let phone: String
    let dateOfBirth: String
    let gender: String
    let address: String
    let emergencyContactName: String
    let emergencyContactPhone: String
    let aadhaarNumber: String
    let aadhaarDocumentUrl: String?
    let profilePhotoUrl: String?
    let driverLicenseNumber: String?
    let driverLicenseExpiry: String?
    let driverLicenseClass: String?
    let driverLicenseIssuingState: String?
    let driverLicenseDocumentUrl: String?
    let maintCertificationType: String?
    let maintCertificationNumber: String?
    let maintIssuingAuthority: String?
    let maintCertificationExpiry: String?
    let maintCertificationDocumentUrl: String?
    let maintYearsOfExperience: Int?
    let maintSpecializations: [String]?

    enum CodingKeys: String, CodingKey {
        case staffMemberId                 = "staff_member_id"
        case role, status
        case submittedDate                 = "submitted_date"
        case rejectionReason               = "rejection_reason"
        case reviewedBy                    = "reviewed_by"
        case reviewedAt                    = "reviewed_at"
        case phone
        case dateOfBirth                   = "date_of_birth"
        case gender, address
        case emergencyContactName          = "emergency_contact_name"
        case emergencyContactPhone         = "emergency_contact_phone"
        case aadhaarNumber                 = "aadhaar_number"
        case aadhaarDocumentUrl            = "aadhaar_document_url"
        case profilePhotoUrl               = "profile_photo_url"
        case driverLicenseNumber           = "driver_license_number"
        case driverLicenseExpiry           = "driver_license_expiry"
        case driverLicenseClass            = "driver_license_class"
        case driverLicenseIssuingState     = "driver_license_issuing_state"
        case driverLicenseDocumentUrl      = "driver_license_document_url"
        case maintCertificationType        = "maint_certification_type"
        case maintCertificationNumber      = "maint_certification_number"
        case maintIssuingAuthority         = "maint_issuing_authority"
        case maintCertificationExpiry      = "maint_certification_expiry"
        case maintCertificationDocumentUrl = "maint_certification_document_url"
        case maintYearsOfExperience        = "maint_years_of_experience"
        case maintSpecializations          = "maint_specializations"
    }

    init(from a: StaffApplication) {
        staffMemberId                 = a.staffMemberId.uuidString
        role                          = a.role.rawValue
        submittedDate                 = iso.string(from: a.submittedDate)
        status                        = a.status.rawValue
        rejectionReason               = a.rejectionReason
        reviewedBy                    = a.reviewedBy?.uuidString
        reviewedAt                    = a.reviewedAt.map { iso.string(from: $0) }
        phone                         = a.phone
        dateOfBirth                   = a.dateOfBirth
        gender                        = a.gender
        address                       = a.address
        emergencyContactName          = a.emergencyContactName
        emergencyContactPhone         = a.emergencyContactPhone
        aadhaarNumber                 = a.aadhaarNumber
        aadhaarDocumentUrl            = a.aadhaarDocumentUrl
        profilePhotoUrl               = a.profilePhotoUrl
        driverLicenseNumber           = a.driverLicenseNumber
        driverLicenseExpiry           = a.driverLicenseExpiry
        driverLicenseClass            = a.driverLicenseClass
        driverLicenseIssuingState     = a.driverLicenseIssuingState
        driverLicenseDocumentUrl      = a.driverLicenseDocumentUrl
        maintCertificationType        = a.maintCertificationType
        maintCertificationNumber      = a.maintCertificationNumber
        maintIssuingAuthority         = a.maintIssuingAuthority
        maintCertificationExpiry      = a.maintCertificationExpiry
        maintCertificationDocumentUrl = a.maintCertificationDocumentUrl
        maintYearsOfExperience        = a.maintYearsOfExperience
        maintSpecializations          = a.maintSpecializations
    }
}

// MARK: - StaffApplicationUpdatePayload
// Only mutable admin-facing fields

struct StaffApplicationUpdatePayload: Encodable {
    let status: String
    let rejectionReason: String?
    let reviewedBy: String?
    let reviewedAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case rejectionReason = "rejection_reason"
        case reviewedBy      = "reviewed_by"
        case reviewedAt      = "reviewed_at"
    }

    init(from a: StaffApplication) {
        status          = a.status.rawValue
        rejectionReason = a.rejectionReason
        reviewedBy      = a.reviewedBy?.uuidString
        reviewedAt      = a.reviewedAt.map { iso.string(from: $0) }
    }
}

// MARK: - StaffApplicationService

struct StaffApplicationService {

    // MARK: Fetch

    static func fetchAllStaffApplications() async throws -> [StaffApplication] {
        try await supabase
            .from("staff_applications")
            .select()
            .order("submitted_date", ascending: false)
            .execute()
            .value
    }

    static func fetchStaffApplications(staffMemberId: UUID) async throws -> [StaffApplication] {
        try await supabase
            .from("staff_applications")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .order("submitted_date", ascending: false)
            .execute()
            .value
    }

    static func fetchPendingApplications() async throws -> [StaffApplication] {
        try await supabase
            .from("staff_applications")
            .select()
            .eq("status", value: ApprovalStatus.pending.rawValue)
            .order("submitted_date", ascending: false)
            .execute()
            .value
    }

    static func fetchStaffApplication(id: UUID) async throws -> StaffApplication? {
        let rows: [StaffApplication] = try await supabase
            .from("staff_applications")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: Insert

    static func addStaffApplication(_ app: StaffApplication) async throws {
        try await supabase
            .from("staff_applications")
            .insert(StaffApplicationInsertPayload(from: app))
            .execute()
    }

    // MARK: Update (admin-facing fields only)

    static func updateStaffApplication(_ app: StaffApplication) async throws {
        try await supabase
            .from("staff_applications")
            .update(StaffApplicationUpdatePayload(from: app))
            .eq("id", value: app.id.uuidString)
            .execute()
    }

    // MARK: Delete

    static func deleteStaffApplication(id: UUID) async throws {
        try await supabase
            .from("staff_applications")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
