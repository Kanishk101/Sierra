import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - GeofenceEventInsertPayload
// Events are append-only. Excludes: id, created_at

struct GeofenceEventInsertPayload: Encodable {
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
        case latitude, longitude
        case triggeredAt = "triggered_at"
    }

    init(from e: GeofenceEvent) {
        geofenceId  = e.geofenceId.uuidString
        vehicleId   = e.vehicleId.uuidString
        tripId      = e.tripId?.uuidString
        driverId    = e.driverId?.uuidString
        eventType   = e.eventType.rawValue
        latitude    = e.latitude
        longitude   = e.longitude
        triggeredAt = iso.string(from: e.triggeredAt)
    }
}

// MARK: - GeofenceEventService

struct GeofenceEventService {

    static func fetchAllGeofenceEvents(limit: Int = 500) async throws -> [GeofenceEvent] {
        try await supabase
            .from("geofence_events")
            .select()
            .order("triggered_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchGeofenceEvents(vehicleId: UUID) async throws -> [GeofenceEvent] {
        try await supabase
            .from("geofence_events")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchGeofenceEvents(geofenceId: UUID) async throws -> [GeofenceEvent] {
        try await supabase
            .from("geofence_events")
            .select()
            .eq("geofence_id", value: geofenceId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func addGeofenceEvent(_ event: GeofenceEvent) async throws {
        try await supabase
            .from("geofence_events")
            .insert(GeofenceEventInsertPayload(from: event))
            .execute()
    }

    static func deleteGeofenceEvent(id: UUID) async throws {
        try await supabase
            .from("geofence_events")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
