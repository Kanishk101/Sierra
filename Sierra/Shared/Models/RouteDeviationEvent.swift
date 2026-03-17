import Foundation

// MARK: - RouteDeviationEvent
// Maps to table: route_deviation_events

struct RouteDeviationEvent: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var tripId: UUID                      // trip_id (FK → trips.id)
    var driverId: UUID                    // driver_id (FK → staff_members.id)
    var vehicleId: UUID                   // vehicle_id (FK → vehicles.id)

    // MARK: Deviation details
    var latitude: Double                  // latitude
    var longitude: Double                 // longitude
    var deviationDistanceM: Double        // deviation_distance_m

    // MARK: Acknowledgement
    var isAcknowledged: Bool              // is_acknowledged (default false)
    var acknowledgedBy: UUID?             // acknowledged_by (FK → staff_members.id)
    var acknowledgedAt: Date?             // acknowledged_at

    // MARK: Timestamps
    var detectedAt: Date                  // detected_at
    var createdAt: Date                   // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case tripId              = "trip_id"
        case driverId            = "driver_id"
        case vehicleId           = "vehicle_id"
        case latitude
        case longitude
        case deviationDistanceM  = "deviation_distance_m"
        case isAcknowledged      = "is_acknowledged"
        case acknowledgedBy      = "acknowledged_by"
        case acknowledgedAt      = "acknowledged_at"
        case detectedAt          = "detected_at"
        case createdAt           = "created_at"
    }
}
