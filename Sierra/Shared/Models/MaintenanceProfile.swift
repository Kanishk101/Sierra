import Foundation

// MARK: - MaintenanceProfile
// Maps to table: maintenance_profiles

struct MaintenanceProfile: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign key
    var staffMemberId: UUID                    // staff_member_id (FK → staff_members.id, UNIQUE)

    // MARK: Certification details
    var certificationType: String              // certification_type
    var certificationNumber: String            // certification_number
    var issuingAuthority: String               // issuing_authority
    var certificationExpiry: Date              // certification_expiry (date)
    var certificationDocumentUrl: String?      // certification_document_url

    // MARK: Experience
    var yearsOfExperience: Int                 // years_of_experience (default 0)
    var specializations: [String]              // specializations (text[], default '{}')

    // MARK: Documents
    var aadhaarDocumentUrl: String?            // aadhaar_document_url

    // MARK: Metrics
    var totalTasksAssigned: Int                // total_tasks_assigned (default 0)
    var totalTasksCompleted: Int               // total_tasks_completed (default 0)

    var notes: String?                         // notes

    // MARK: Timestamps
    var createdAt: Date                        // created_at
    var updatedAt: Date                        // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case staffMemberId             = "staff_member_id"
        case certificationType         = "certification_type"
        case certificationNumber       = "certification_number"
        case issuingAuthority          = "issuing_authority"
        case certificationExpiry       = "certification_expiry"
        case certificationDocumentUrl  = "certification_document_url"
        case yearsOfExperience         = "years_of_experience"
        case specializations
        case aadhaarDocumentUrl        = "aadhaar_document_url"
        case totalTasksAssigned        = "total_tasks_assigned"
        case totalTasksCompleted       = "total_tasks_completed"
        case notes
        case createdAt                 = "created_at"
        case updatedAt                 = "updated_at"
    }
}
