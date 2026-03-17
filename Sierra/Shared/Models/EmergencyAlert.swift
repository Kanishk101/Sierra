import Foundation

// MARK: - Emergency Alert Type
// Maps to PostgreSQL enum: emergency_alert_type

enum EmergencyAlertType: String, Codable, CaseIterable {
    case sos        = "SOS"
    case accident   = "Accident"
    case breakdown  = "Breakdown"
    case medical    = "Medical"
    case defect     = "Defect"
}

// MARK: - Emergency Alert Status
// Maps to PostgreSQL enum: emergency_alert_status

enum EmergencyAlertStatus: String, Codable, CaseIterable {
    case active       = "Active"
    case acknowledged = "Acknowledged"
    case resolved     = "Resolved"
}

// MARK: - EmergencyAlert
// Maps to table: emergency_alerts

struct EmergencyAlert: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var driverId: UUID                    // driver_id (FK → staff_members.id)
    var tripId: UUID?                     // trip_id (FK → trips.id)
    var vehicleId: UUID?                  // vehicle_id (FK → vehicles.id)

    // MARK: Location
    var latitude: Double                  // latitude
    var longitude: Double                 // longitude

    // MARK: Alert details
    var alertType: EmergencyAlertType     // alert_type (default 'SOS')
    var status: EmergencyAlertStatus      // status (default 'Active')
    var description: String?              // description

    // MARK: Resolution
    var acknowledgedBy: UUID?             // acknowledged_by (FK → staff_members.id)
    var acknowledgedAt: Date?             // acknowledged_at
    var resolvedAt: Date?                 // resolved_at

    // MARK: Timestamps
    var triggeredAt: Date                 // triggered_at
    var createdAt: Date                   // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case driverId        = "driver_id"
        case tripId          = "trip_id"
        case vehicleId       = "vehicle_id"
        case latitude
        case longitude
        case alertType       = "alert_type"
        case status
        case description
        case acknowledgedBy  = "acknowledged_by"
        case acknowledgedAt  = "acknowledged_at"
        case resolvedAt      = "resolved_at"
        case triggeredAt     = "triggered_at"
        case createdAt       = "created_at"
    }
}
