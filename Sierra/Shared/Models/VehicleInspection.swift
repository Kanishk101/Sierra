import Foundation

// MARK: - Inspection Type
// Maps to PostgreSQL enum: inspection_type

enum InspectionType: String, Codable, CaseIterable {
    case preTrip  = "Pre-Trip"
    case postTrip = "Post-Trip"
}

// MARK: - Inspection Result
// Maps to PostgreSQL enum: inspection_result

enum InspectionResult: String, Codable, CaseIterable {
    case passed             = "Passed"
    case failed             = "Failed"
    case passedWithWarnings = "Passed with Warnings"
    case notChecked         = "Not Checked"
}

// MARK: - Inspection Item
// Represents a single checklist item stored in the jsonb `items` column.

struct InspectionItem: Codable, Identifiable {
    var id: String                    // generated locally, not a DB column
    var name: String
    var result: InspectionResult
    var notes: String?
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
    var type: InspectionType             // type
    var overallResult: InspectionResult  // overall_result (default 'Passed')
    var items: [InspectionItem]          // items (jsonb, default '[]')
    var defectsReported: String?         // defects_reported
    var additionalNotes: String?         // additional_notes
    var driverSignatureUrl: String?      // driver_signature_url

    // MARK: Timestamps
    var inspectedAt: Date                // inspected_at
    var createdAt: Date                  // created_at

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
