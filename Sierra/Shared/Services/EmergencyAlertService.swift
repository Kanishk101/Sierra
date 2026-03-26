import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - EmergencyAlertInsertPayload
// Excludes: id, created_at, acknowledged_by, acknowledged_at, resolved_at

struct EmergencyAlertInsertPayload: Encodable {
    let driverId: String
    let tripId: String?
    let vehicleId: String?
    let latitude: Double
    let longitude: Double
    let alertType: String
    let status: String
    let description: String?
    let triggeredAt: String

    enum CodingKeys: String, CodingKey {
        case driverId    = "driver_id"
        case tripId      = "trip_id"
        case vehicleId   = "vehicle_id"
        case latitude, longitude
        case alertType   = "alert_type"
        case status, description
        case triggeredAt = "triggered_at"
    }

    init(from a: EmergencyAlert) {
        driverId    = a.driverId.uuidString
        tripId      = a.tripId?.uuidString
        vehicleId   = a.vehicleId?.uuidString
        latitude    = a.latitude
        longitude   = a.longitude
        alertType   = a.alertType.rawValue
        status      = a.status.rawValue
        description = a.description
        triggeredAt = iso.string(from: a.triggeredAt)
    }
}

// MARK: - EmergencyAlertService

struct EmergencyAlertService {

    static func fetchAllEmergencyAlerts(limit: Int = 500) async throws -> [EmergencyAlert] {
        try await supabase
            .from("emergency_alerts")
            .select()
            .order("triggered_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchActiveAlerts() async throws -> [EmergencyAlert] {
        try await supabase
            .from("emergency_alerts")
            .select()
            .eq("status", value: EmergencyAlertStatus.active.rawValue)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchEmergencyAlerts(driverId: UUID) async throws -> [EmergencyAlert] {
        try await supabase
            .from("emergency_alerts")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchActiveDefectAlerts(
        vehicleId: UUID,
        tripId: UUID? = nil
    ) async throws -> [EmergencyAlert] {
        if let tripId {
            return try await supabase
                .from("emergency_alerts")
                .select()
                .eq("status", value: EmergencyAlertStatus.active.rawValue)
                .eq("alert_type", value: EmergencyAlertType.defect.rawValue)
                .eq("vehicle_id", value: vehicleId.uuidString)
                .eq("trip_id", value: tripId.uuidString)
                .order("triggered_at", ascending: false)
                .execute()
                .value
        }

        return try await supabase
            .from("emergency_alerts")
            .select()
            .eq("status", value: EmergencyAlertStatus.active.rawValue)
            .eq("alert_type", value: EmergencyAlertType.defect.rawValue)
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func addEmergencyAlert(_ alert: EmergencyAlert) async throws {
        try await supabase
            .from("emergency_alerts")
            .insert(EmergencyAlertInsertPayload(from: alert))
            .execute()
    }

    static func acknowledgeAlert(id: UUID, acknowledgedBy: UUID) async throws {
        struct Payload: Encodable {
            let acknowledged_by: String
            let acknowledged_at: String
            let status: String
        }
        try await supabase
            .from("emergency_alerts")
            .update(Payload(
                acknowledged_by: acknowledgedBy.uuidString,
                acknowledged_at: iso.string(from: Date()),
                status: EmergencyAlertStatus.acknowledged.rawValue
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func resolveAlert(id: UUID) async throws {
        struct Payload: Encodable {
            let resolved_at: String
            let status: String
        }
        try await supabase
            .from("emergency_alerts")
            .update(Payload(
                resolved_at: iso.string(from: Date()),
                status: EmergencyAlertStatus.resolved.rawValue
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func deleteEmergencyAlert(id: UUID) async throws {
        try await supabase
            .from("emergency_alerts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
