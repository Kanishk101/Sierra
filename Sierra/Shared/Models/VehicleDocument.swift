import Foundation

// MARK: - Vehicle Document Type
// Maps to PostgreSQL enum: vehicle_document_type

enum VehicleDocumentType: String, Codable, CaseIterable {
    case registration       = "Registration"
    case insurance          = "Insurance"
    case fitnessCertificate = "Fitness Certificate"
    case puc                = "PUC Certificate"
    case permit             = "Permit"
    case other              = "Other"
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
    var issuedDate: Date                    // issued_date
    var expiryDate: Date                    // expiry_date
    var issuingAuthority: String            // issuing_authority
    var documentUrl: String?                // document_url
    var notes: String?

    // MARK: Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId        = "vehicle_id"
        case documentType     = "document_type"
        case documentNumber   = "document_number"
        case issuedDate       = "issued_date"
        case expiryDate       = "expiry_date"
        case issuingAuthority = "issuing_authority"
        case documentUrl      = "document_url"
        case notes
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }

    // MARK: - Computed

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }

    var isExpired: Bool { expiryDate < Date() }

    var isExpiringSoon: Bool { !isExpired && daysUntilExpiry <= 30 }
}
