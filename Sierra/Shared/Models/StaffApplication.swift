import Foundation
import SwiftUI

// MARK: - Approval Status
// Maps to PostgreSQL enum: approval_status

enum ApprovalStatus: String, Codable, CaseIterable {
    case pending  = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

// MARK: - StaffApplication
// Maps to table: staff_applications

struct StaffApplication: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var staffMemberId: UUID              // staff_member_id (FK → staff_members.id)
    var reviewedBy: UUID?               // reviewed_by (FK → staff_members.id)

    // MARK: Application details
    var role: UserRole                   // role
    var submittedDate: Date             // submitted_date (default now())
    var status: ApprovalStatus          // status (default 'Pending')
    var rejectionReason: String?        // rejection_reason
    var reviewedAt: Date?               // reviewed_at

    // MARK: Personal details
    var phone: String                    // phone
    var dateOfBirth: Date               // date_of_birth (date)
    var gender: String                   // gender
    var address: String                  // address
    var emergencyContactName: String     // emergency_contact_name
    var emergencyContactPhone: String    // emergency_contact_phone
    var aadhaarNumber: String            // aadhaar_number
    var aadhaarDocumentUrl: String?     // aadhaar_document_url
    var profilePhotoUrl: String?        // profile_photo_url

    // MARK: Driver-specific fields
    var driverLicenseNumber: String?         // driver_license_number
    var driverLicenseExpiry: Date?           // driver_license_expiry (date)
    var driverLicenseClass: String?          // driver_license_class
    var driverLicenseIssuingState: String?   // driver_license_issuing_state
    var driverLicenseDocumentUrl: String?    // driver_license_document_url

    // MARK: Maintenance-specific fields
    var maintCertificationType: String?       // maint_certification_type
    var maintCertificationNumber: String?     // maint_certification_number
    var maintIssuingAuthority: String?        // maint_issuing_authority
    var maintCertificationExpiry: Date?       // maint_certification_expiry (date)
    var maintCertificationDocumentUrl: String? // maint_certification_document_url
    var maintYearsOfExperience: Int?          // maint_years_of_experience
    var maintSpecializations: [String]?       // maint_specializations (text[])

    // MARK: Timestamps
    var createdAt: Date                  // created_at (default now())

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case staffMemberId                = "staff_member_id"
        case reviewedBy                   = "reviewed_by"
        case role
        case submittedDate                = "submitted_date"
        case status
        case rejectionReason              = "rejection_reason"
        case reviewedAt                   = "reviewed_at"
        case phone
        case dateOfBirth                  = "date_of_birth"
        case gender
        case address
        case emergencyContactName         = "emergency_contact_name"
        case emergencyContactPhone        = "emergency_contact_phone"
        case aadhaarNumber                = "aadhaar_number"
        case aadhaarDocumentUrl           = "aadhaar_document_url"
        case profilePhotoUrl              = "profile_photo_url"
        case driverLicenseNumber          = "driver_license_number"
        case driverLicenseExpiry          = "driver_license_expiry"
        case driverLicenseClass           = "driver_license_class"
        case driverLicenseIssuingState    = "driver_license_issuing_state"
        case driverLicenseDocumentUrl     = "driver_license_document_url"
        case maintCertificationType       = "maint_certification_type"
        case maintCertificationNumber     = "maint_certification_number"
        case maintIssuingAuthority        = "maint_issuing_authority"
        case maintCertificationExpiry     = "maint_certification_expiry"
        case maintCertificationDocumentUrl = "maint_certification_document_url"
        case maintYearsOfExperience       = "maint_years_of_experience"
        case maintSpecializations         = "maint_specializations"
        case createdAt                    = "created_at"
    }

    // MARK: - Computed

    var initials: String {
        // staffMemberId doesn't carry a name — initials derived from staffMemberId UUID prefix for display
        return "??"
    }

    var daysAgo: String {
        let days = Calendar.current.dateComponents([.day], from: submittedDate, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    // MARK: - Samples

    static let samples: [StaffApplication] = [
        // Driver sample (pending)
        StaffApplication(
            id: UUID(),
            staffMemberId: UUID(uuidString: "D0000000-0000-0000-0000-000000000003")!,
            reviewedBy: nil,
            role: .driver,
            submittedDate: Date().addingTimeInterval(-86400 * 2),
            status: .pending,
            rejectionReason: nil,
            reviewedAt: nil,
            phone: "+91 9876543210",
            dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 28),
            gender: "Male",
            address: "42 Fleet Street, Mumbai 400001",
            emergencyContactName: "Jin Park",
            emergencyContactPhone: "+91 9876543211",
            aadhaarNumber: "2345 6789 0123",
            aadhaarDocumentUrl: nil,
            profilePhotoUrl: nil,
            driverLicenseNumber: "MH-0120230045678",
            driverLicenseExpiry: Date().addingTimeInterval(86400 * 365 * 2),
            driverLicenseClass: "LMV",
            driverLicenseIssuingState: "Maharashtra",
            driverLicenseDocumentUrl: nil,
            maintCertificationType: nil,
            maintCertificationNumber: nil,
            maintIssuingAuthority: nil,
            maintCertificationExpiry: nil,
            maintCertificationDocumentUrl: nil,
            maintYearsOfExperience: nil,
            maintSpecializations: nil,
            createdAt: Date().addingTimeInterval(-86400 * 2)
        ),
        // Maintenance sample (pending)
        StaffApplication(
            id: UUID(),
            staffMemberId: UUID(uuidString: "D0000000-0000-0000-0000-000000000007")!,
            reviewedBy: nil,
            role: .maintenancePersonnel,
            submittedDate: Date().addingTimeInterval(-86400 * 4),
            status: .pending,
            rejectionReason: nil,
            reviewedAt: nil,
            phone: "+91 8765432109",
            dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 32),
            gender: "Male",
            address: "15 Workshop Lane, Pune 411001",
            emergencyContactName: "Sarah Bradley",
            emergencyContactPhone: "+91 8765432100",
            aadhaarNumber: "3456 7890 1234",
            aadhaarDocumentUrl: nil,
            profilePhotoUrl: nil,
            driverLicenseNumber: nil,
            driverLicenseExpiry: nil,
            driverLicenseClass: nil,
            driverLicenseIssuingState: nil,
            driverLicenseDocumentUrl: nil,
            maintCertificationType: "Diesel Mechanic",
            maintCertificationNumber: "DM-2024-78901",
            maintIssuingAuthority: "NSDC India",
            maintCertificationExpiry: Date().addingTimeInterval(86400 * 365),
            maintCertificationDocumentUrl: nil,
            maintYearsOfExperience: 8,
            maintSpecializations: ["Engine Repair", "Transmission", "Tyres"],
            createdAt: Date().addingTimeInterval(-86400 * 4)
        ),
        // Driver sample (approved)
        StaffApplication(
            id: UUID(),
            staffMemberId: UUID(),
            reviewedBy: UUID(uuidString: "F0000000-0000-0000-0000-000000000001"),
            role: .driver,
            submittedDate: Date().addingTimeInterval(-86400 * 10),
            status: .approved,
            rejectionReason: nil,
            reviewedAt: Date().addingTimeInterval(-86400 * 9),
            phone: "+91 7654321098",
            dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 25),
            gender: "Female",
            address: "8 Ring Road, Delhi 110001",
            emergencyContactName: "Raj Sharma",
            emergencyContactPhone: "+91 7654321099",
            aadhaarNumber: "4567 8901 2345",
            aadhaarDocumentUrl: nil,
            profilePhotoUrl: nil,
            driverLicenseNumber: "DL-0120210012345",
            driverLicenseExpiry: Date().addingTimeInterval(86400 * 365 * 3),
            driverLicenseClass: "LMV-TR",
            driverLicenseIssuingState: "Delhi",
            driverLicenseDocumentUrl: nil,
            maintCertificationType: nil,
            maintCertificationNumber: nil,
            maintIssuingAuthority: nil,
            maintCertificationExpiry: nil,
            maintCertificationDocumentUrl: nil,
            maintYearsOfExperience: nil,
            maintSpecializations: nil,
            createdAt: Date().addingTimeInterval(-86400 * 10)
        ),
    ]
}
