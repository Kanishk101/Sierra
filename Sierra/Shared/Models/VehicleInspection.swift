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
    /// Per-item defect photo URLs. Empty for pass/warn items; required for failed items.
    var photoUrls: [String]       // photo_urls

    enum CodingKeys: String, CodingKey {
        case id
        case checkName  = "check_name"
        case category, result, notes
        case photoUrls  = "photo_urls"
    }

    init(id: UUID, checkName: String, category: InspectionCategory,
         result: InspectionResult, notes: String? = nil, photoUrls: [String] = []) {
        self.id = id; self.checkName = checkName; self.category = category
        self.result = result; self.notes = notes; self.photoUrls = photoUrls
    }
}

// MARK: - VehicleInspection
// Maps to table: vehicle_inspections
//
// JSONB Note: Supabase PostgREST sometimes returns JSONB columns double-encoded
// as a JSON string (e.g. "[{\"id\":\"...\"}]") instead of a parsed array.
// The custom init(from:) below handles both cases for the `items` field.

struct VehicleInspection: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var tripId: UUID                     // trip_id
    var vehicleId: UUID                  // vehicle_id
    var driverId: UUID                   // driver_id

    // MARK: Inspection
    var type: InspectionType
    var overallResult: InspectionResult
    var items: [InspectionItem]          // items (JSONB — may arrive as string)
    var defectsReported: String?
    var additionalNotes: String?
    var driverSignatureUrl: String?

    // MARK: Defect tracking
    var photoUrls: [String]              // photo_urls
    var isDefectRaised: Bool             // is_defect_raised
    var raisedTaskId: UUID?              // raised_task_id

    // MARK: Timestamps
    var inspectedAt: Date
    var createdAt: Date

    // MARK: Readings (nullable DB columns)
    var odometerReading: Double?         // odometer_reading
    var fuelLevelPct: Int?               // fuel_level_pct
    var fuelReceiptUrl: String?          // fuel_receipt_url

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
        case photoUrls          = "photo_urls"
        case isDefectRaised     = "is_defect_raised"
        case raisedTaskId       = "raised_task_id"
        case inspectedAt        = "inspected_at"
        case createdAt          = "created_at"
        case odometerReading    = "odometer_reading"
        case fuelLevelPct       = "fuel_level_pct"
        case fuelReceiptUrl     = "fuel_receipt_url"
    }

    // MARK: - Custom Decoder
    // Handles the Supabase JSONB double-encoding bug where `items` arrives
    // as a JSON string instead of a parsed array. Falls back to empty array
    // so a single bad row never crashes the entire inspections fetch.

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id            = try c.decode(UUID.self, forKey: .id)
        tripId        = try c.decode(UUID.self, forKey: .tripId)
        vehicleId     = try c.decode(UUID.self, forKey: .vehicleId)
        driverId      = try c.decode(UUID.self, forKey: .driverId)
        type          = try c.decode(InspectionType.self, forKey: .type)
        overallResult = try c.decode(InspectionResult.self, forKey: .overallResult)

        // items: try native array first (normal JSONB), then string (double-encoded JSONB)
        if let arr = try? c.decode([InspectionItem].self, forKey: .items) {
            items = arr
        } else if let str = try? c.decode(String.self, forKey: .items),
                  let data = str.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([InspectionItem].self, from: data) {
            items = parsed
        } else {
            items = []
        }

        defectsReported    = try c.decodeIfPresent(String.self, forKey: .defectsReported)
        additionalNotes    = try c.decodeIfPresent(String.self, forKey: .additionalNotes)
        driverSignatureUrl = try c.decodeIfPresent(String.self, forKey: .driverSignatureUrl)
        photoUrls          = try c.decodeIfPresent([String].self, forKey: .photoUrls) ?? []
        isDefectRaised     = try c.decodeIfPresent(Bool.self, forKey: .isDefectRaised) ?? false
        raisedTaskId       = try c.decodeIfPresent(UUID.self, forKey: .raisedTaskId)
        inspectedAt        = try c.decode(Date.self, forKey: .inspectedAt)
        createdAt          = try c.decode(Date.self, forKey: .createdAt)
        odometerReading    = try c.decodeIfPresent(Double.self, forKey: .odometerReading)
        fuelLevelPct       = try c.decodeIfPresent(Int.self, forKey: .fuelLevelPct)
        fuelReceiptUrl     = try c.decodeIfPresent(String.self, forKey: .fuelReceiptUrl)
    }

    // MARK: - Memberwise init (for VehicleInspectionService.addInspection)

    init(
        id: UUID, tripId: UUID, vehicleId: UUID, driverId: UUID,
        type: InspectionType, overallResult: InspectionResult,
        items: [InspectionItem], defectsReported: String?,
        additionalNotes: String?, driverSignatureUrl: String?,
        photoUrls: [String] = [], isDefectRaised: Bool = false,
        raisedTaskId: UUID? = nil, inspectedAt: Date, createdAt: Date,
        odometerReading: Double? = nil, fuelLevelPct: Int? = nil,
        fuelReceiptUrl: String? = nil
    ) {
        self.id = id; self.tripId = tripId; self.vehicleId = vehicleId
        self.driverId = driverId; self.type = type; self.overallResult = overallResult
        self.items = items; self.defectsReported = defectsReported
        self.additionalNotes = additionalNotes; self.driverSignatureUrl = driverSignatureUrl
        self.photoUrls = photoUrls; self.isDefectRaised = isDefectRaised
        self.raisedTaskId = raisedTaskId; self.inspectedAt = inspectedAt
        self.createdAt = createdAt; self.odometerReading = odometerReading
        self.fuelLevelPct = fuelLevelPct; self.fuelReceiptUrl = fuelReceiptUrl
    }
}
