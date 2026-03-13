import Foundation

// MARK: - DriverProfile
// Maps to table: driver_profiles

struct DriverProfile: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign key
    var staffMemberId: UUID              // staff_member_id (FK → staff_members.id, UNIQUE)

    // MARK: License details
    var licenseNumber: String            // license_number
    var licenseExpiry: Date              // license_expiry (date)
    var licenseClass: String             // license_class
    var licenseIssuingState: String      // license_issuing_state
    var licenseDocumentUrl: String?      // license_document_url

    // MARK: Documents
    var aadhaarDocumentUrl: String?      // aadhaar_document_url

    // MARK: Metrics
    var totalTripsCompleted: Int         // total_trips_completed (default 0)
    var totalDistanceKm: Double          // total_distance_km (default 0)
    var averageRating: Double?           // average_rating

    // MARK: Assignment
    var currentVehicleId: String?          // current_vehicle_id (FK as TEXT)
    var notes: String?                   // notes

    // MARK: Timestamps
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case staffMemberId       = "staff_member_id"
        case licenseNumber       = "license_number"
        case licenseExpiry       = "license_expiry"
        case licenseClass        = "license_class"
        case licenseIssuingState = "license_issuing_state"
        case licenseDocumentUrl  = "license_document_url"
        case aadhaarDocumentUrl  = "aadhaar_document_url"
        case totalTripsCompleted = "total_trips_completed"
        case totalDistanceKm     = "total_distance_km"
        case averageRating       = "average_rating"
        case currentVehicleId    = "current_vehicle_id"
        case notes
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }
}
