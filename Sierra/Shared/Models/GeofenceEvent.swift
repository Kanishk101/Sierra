import Foundation

// MARK: - Geofence Event Type
// Maps to PostgreSQL enum: geofence_event_type

enum GeofenceEventType: String, Codable, CaseIterable {
    case entry = "Entry"
    case exit  = "Exit"
}

// MARK: - GeofenceEvent
// Maps to table: geofence_events

struct GeofenceEvent: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var geofenceId: UUID                // geofence_id (FK → geofences.id)
    var vehicleId: UUID                 // vehicle_id (FK → vehicles.id)
    var tripId: UUID?                   // trip_id (FK → trips.id)
    var driverId: UUID?                 // driver_id (FK → staff_members.id)

    // MARK: Event details
    var eventType: GeofenceEventType    // event_type
    var latitude: Double                // latitude
    var longitude: Double               // longitude

    // MARK: Timestamps
    var triggeredAt: Date               // triggered_at
    var createdAt: Date                 // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case geofenceId   = "geofence_id"
        case vehicleId    = "vehicle_id"
        case tripId       = "trip_id"
        case driverId     = "driver_id"
        case eventType    = "event_type"
        case latitude
        case longitude
        case triggeredAt  = "triggered_at"
        case createdAt    = "created_at"
    }
}
