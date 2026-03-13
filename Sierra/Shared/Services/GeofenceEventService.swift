import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - GeofenceEventPayload

/// Events are INSERT-only; update and delete are not supported.
struct GeofenceEventPayload: Encodable {
    let geofenceId: String
    let vehicleId: String
    let tripId: String?
    let driverId: String?
    let eventType: String
    let latitude: Double
    let longitude: Double
    let triggeredAt: String

    enum CodingKeys: String, CodingKey {
        case geofenceId  = "geofence_id"
        case vehicleId   = "vehicle_id"
        case tripId      = "trip_id"
        case driverId    = "driver_id"
        case eventType   = "event_type"
        case latitude
        case longitude
        case triggeredAt = "triggered_at"
    }

    init(from event: GeofenceEvent) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.geofenceId  = event.geofenceId.uuidString
        self.vehicleId   = event.vehicleId.uuidString
        self.tripId      = event.tripId?.uuidString
        self.driverId    = event.driverId?.uuidString
        self.eventType   = event.eventType.rawValue
        self.latitude    = event.latitude
        self.longitude   = event.longitude
        self.triggeredAt = fmt.string(from: event.triggeredAt)
    }
}

// MARK: - GeofenceEventService

struct GeofenceEventService {

    static func fetchEvents(vehicleId: UUID) async throws -> [GeofenceEvent] {
        return try await supabase
            .from("geofence_events")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchEvents(geofenceId: UUID) async throws -> [GeofenceEvent] {
        return try await supabase
            .from("geofence_events")
            .select()
            .eq("geofence_id", value: geofenceId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    /// Records a new geofence crossing event. Events are append-only.
    static func addEvent(_ event: GeofenceEvent) async throws {
        let payload = GeofenceEventPayload(from: event)
        try await supabase
            .from("geofence_events")
            .insert(payload)
            .execute()
    }
}
