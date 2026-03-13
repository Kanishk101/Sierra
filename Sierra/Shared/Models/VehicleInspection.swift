import Foundation

// MARK: - Inspection Type
// Maps to PostgreSQL enum: inspection_type

enum InspectionType: String, Codable {
    case preTripInspection  = "Pre-Trip"
    case postTripInspection = "Post-Trip"
}

// MARK: - Inspection Result
// Maps to PostgreSQL enum: inspection_result

enum InspectionResult: String, Codable {
    case passed             = "Passed"
    case failed             = "Failed"
    case passedWithWarnings = "Passed with Warnings"
    case notChecked         = "Not Checked"
}

// MARK: - Inspection Category

enum InspectionCategory: String, Codable, CaseIterable {
    case tyres  = "Tyres"
    case engine = "Engine"
    case lights = "Lights"
    case body   = "Body"
    case safety = "Safety"
    case fluids = "Fluids"
}

// MARK: - Inspection Item
// Single checklist entry stored as a JSONB element in the `items` column.

struct InspectionItem: Codable, Identifiable {
    let id: UUID
    var checkName: String         // check_name
    var category: InspectionCategory
    var result: InspectionResult
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case checkName = "check_name"
        case category, result, notes
    }
}

// MARK: - VehicleInspection
// Maps to table: vehicle_inspections

struct VehicleInspection: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var tripId: UUID                     // trip_id (FK → trips.id)
    var vehicleId: UUID                  // vehicle_id (FK → vehicles.id)
    var driverId: UUID                   // driver_id (FK → staff_members.id)

    // MARK: Inspection
    var type: InspectionType
    var overallResult: InspectionResult  // overall_result
    var items: [InspectionItem]          // items (stored as JSONB)
    var defectsReported: String?
    var additionalNotes: String?
    var driverSignatureUrl: String?

    // MARK: Timestamps
    var inspectedAt: Date
    var createdAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case tripId             = "trip_id"
        case vehicleId          = "vehicle_id"
        case driverId           = "driver_id"
        case type
        case overallResult      = "overall_result"
        case items
        case defectsReported    = "defects_reported"
        case additionalNotes    = "additional_notes"
        case driverSignatureUrl = "driver_signature_url"
        case inspectedAt        = "inspected_at"
        case createdAt          = "created_at"
    }
}
