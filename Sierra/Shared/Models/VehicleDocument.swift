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

    // MARK: - Memberwise Init

    init(
        id: UUID,
        vehicleId: UUID,
        documentType: VehicleDocumentType,
        documentNumber: String,
        issuedDate: Date,
        expiryDate: Date,
        issuingAuthority: String,
        documentUrl: String? = nil,
        notes: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id               = id
        self.vehicleId        = vehicleId
        self.documentType     = documentType
        self.documentNumber   = documentNumber
        self.issuedDate       = issuedDate
        self.expiryDate       = expiryDate
        self.issuingAuthority = issuingAuthority
        self.documentUrl      = documentUrl
        self.notes            = notes
        self.createdAt        = createdAt
        self.updatedAt        = updatedAt
    }

    // MARK: - Date Parsing Helpers

    private static let plainDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let isoWithFrac: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let isoWithoutFrac: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func parseFlexibleDate(_ string: String) -> Date? {
        plainDateFormatter.date(from: string)
            ?? isoWithFrac.date(from: string)
            ?? isoWithoutFrac.date(from: string)
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id               = try c.decode(UUID.self, forKey: .id)
        vehicleId        = try c.decode(UUID.self, forKey: .vehicleId)
        documentType     = try c.decode(VehicleDocumentType.self, forKey: .documentType)
        documentNumber   = try c.decode(String.self, forKey: .documentNumber)
        issuingAuthority = try c.decode(String.self, forKey: .issuingAuthority)
        documentUrl      = try c.decodeIfPresent(String.self, forKey: .documentUrl)
        notes            = try c.decodeIfPresent(String.self, forKey: .notes)

        // issuedDate – try Date first (for decoders that already handle it), fall back to String parsing
        if let d = try? c.decode(Date.self, forKey: .issuedDate) {
            issuedDate = d
        } else {
            let s = try c.decode(String.self, forKey: .issuedDate)
            guard let d = Self.parseFlexibleDate(s) else {
                throw DecodingError.dataCorruptedError(forKey: .issuedDate, in: c,
                                                       debugDescription: "Cannot parse date: \(s)")
            }
            issuedDate = d
        }

        // expiryDate – same approach
        if let d = try? c.decode(Date.self, forKey: .expiryDate) {
            expiryDate = d
        } else {
            let s = try c.decode(String.self, forKey: .expiryDate)
            guard let d = Self.parseFlexibleDate(s) else {
                throw DecodingError.dataCorruptedError(forKey: .expiryDate, in: c,
                                                       debugDescription: "Cannot parse date: \(s)")
            }
            expiryDate = d
        }

        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    // MARK: - Computed

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }

    var isExpired: Bool { expiryDate < Date() }

    var isExpiringSoon: Bool { !isExpired && daysUntilExpiry <= 30 }
}
