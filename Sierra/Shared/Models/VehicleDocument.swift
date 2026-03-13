import Foundation

// MARK: - Vehicle Document Type
// Maps to PostgreSQL enum: vehicle_document_type

enum VehicleDocumentType: String, Codable, CaseIterable {
    case registration      = "Registration"
    case insurance         = "Insurance"
    case fitnessCertificate = "Fitness Certificate"
    case pucCertificate    = "PUC Certificate"
    case permit            = "Permit"
    case other             = "Other"
}

// MARK: - VehicleDocument
// Maps to table: vehicle_documents

struct VehicleDocument: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign key
    var vehicleId: UUID                     // vehicle_id (FK → vehicles.id)

    // MARK: Document details
    var documentType: VehicleDocumentType   // document_type
    var documentNumber: String              // document_number
    var issuedDate: Date                    // issued_date (date)
    var expiryDate: Date                    // expiry_date (date)
    var issuingAuthority: String            // issuing_authority
    var documentUrl: String?                // document_url
    var notes: String?                      // notes

    // MARK: Timestamps
    var createdAt: Date                     // created_at
    var updatedAt: Date                     // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId          = "vehicle_id"
        case documentType       = "document_type"
        case documentNumber     = "document_number"
        case issuedDate         = "issued_date"
        case expiryDate         = "expiry_date"
        case issuingAuthority   = "issuing_authority"
        case documentUrl        = "document_url"
        case notes
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }

    // MARK: - Computed

    /// True if document expires within 30 days from now.
    var isExpiringSoon: Bool {
        expiryDate.timeIntervalSinceNow < 30 * 86400
    }

    /// True if document has already expired.
    var isExpired: Bool {
        expiryDate < Date()
    }
}
