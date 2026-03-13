import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - StaffApplicationPayload

struct StaffApplicationPayload: Encodable {
    let staffMemberId: String
    let reviewedBy: String?
    let role: String
    let status: String
    let rejectionReason: String?
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
        case reviewedBy                    = "reviewed_by"
        case role
        case status
        case rejectionReason               = "rejection_reason"
        case reviewedAt                    = "reviewed_at"
        case phone
        case dateOfBirth                   = "date_of_birth"
        case gender
        case address
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

    init(from app: StaffApplication) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.staffMemberId                 = app.staffMemberId.uuidString
        self.reviewedBy                    = app.reviewedBy?.uuidString
        self.role                          = app.role.rawValue
        self.status                        = app.status.rawValue
        self.rejectionReason               = app.rejectionReason
        self.reviewedAt                    = app.reviewedAt.map { fmt.string(from: $0) }
        self.phone                         = app.phone
        self.dateOfBirth                   = fmt.string(from: app.dateOfBirth)
        self.gender                        = app.gender
        self.address                       = app.address
        self.emergencyContactName          = app.emergencyContactName
        self.emergencyContactPhone         = app.emergencyContactPhone
        self.aadhaarNumber                 = app.aadhaarNumber
        self.aadhaarDocumentUrl            = app.aadhaarDocumentUrl
        self.profilePhotoUrl               = app.profilePhotoUrl
        self.driverLicenseNumber           = app.driverLicenseNumber
        self.driverLicenseExpiry           = app.driverLicenseExpiry.map { fmt.string(from: $0) }
        self.driverLicenseClass            = app.driverLicenseClass
        self.driverLicenseIssuingState     = app.driverLicenseIssuingState
        self.driverLicenseDocumentUrl      = app.driverLicenseDocumentUrl
        self.maintCertificationType        = app.maintCertificationType
        self.maintCertificationNumber      = app.maintCertificationNumber
        self.maintIssuingAuthority         = app.maintIssuingAuthority
        self.maintCertificationExpiry      = app.maintCertificationExpiry.map { fmt.string(from: $0) }
        self.maintCertificationDocumentUrl = app.maintCertificationDocumentUrl
        self.maintYearsOfExperience        = app.maintYearsOfExperience
        self.maintSpecializations          = app.maintSpecializations
    }
}

// MARK: - StaffApplicationService

struct StaffApplicationService {

    static func fetchAllApplications() async throws -> [StaffApplication] {
        return try await supabase
            .from("staff_applications")
            .select()
            .order("submitted_date", ascending: false)
            .execute()
            .value
    }

    static func fetchApplications(status: ApprovalStatus) async throws -> [StaffApplication] {
        return try await supabase
            .from("staff_applications")
            .select()
            .eq("status", value: status.rawValue)
            .order("submitted_date", ascending: false)
            .execute()
            .value
    }

    static func fetchApplication(staffMemberId: UUID) async throws -> StaffApplication {
        return try await supabase
            .from("staff_applications")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .single()
            .execute()
            .value
    }

    static func addApplication(_ application: StaffApplication) async throws {
        let payload = StaffApplicationPayload(from: application)
        try await supabase
            .from("staff_applications")
            .insert(payload)
            .execute()
    }

    static func updateApplication(_ application: StaffApplication) async throws {
        let payload = StaffApplicationPayload(from: application)
        try await supabase
            .from("staff_applications")
            .update(payload)
            .eq("id", value: application.id.uuidString)
            .execute()
    }

    static func deleteApplication(id: UUID) async throws {
        try await supabase
            .from("staff_applications")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
