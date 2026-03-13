import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - EmergencyAlertPayload

struct EmergencyAlertPayload: Encodable {
    let driverId: String
    let tripId: String?
    let vehicleId: String?
    let latitude: Double
    let longitude: Double
    let alertType: String
    let status: String
    let description: String?
    let acknowledgedBy: String?
    let acknowledgedAt: String?
    let resolvedAt: String?
    let triggeredAt: String

    enum CodingKeys: String, CodingKey {
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
    }

    init(from alert: EmergencyAlert) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.driverId        = alert.driverId.uuidString
        self.tripId          = alert.tripId?.uuidString
        self.vehicleId       = alert.vehicleId?.uuidString
        self.latitude        = alert.latitude
        self.longitude       = alert.longitude
        self.alertType       = alert.alertType.rawValue
        self.status          = alert.status.rawValue
        self.description     = alert.description
        self.acknowledgedBy  = alert.acknowledgedBy?.uuidString
        self.acknowledgedAt  = alert.acknowledgedAt.map { fmt.string(from: $0) }
        self.resolvedAt      = alert.resolvedAt.map { fmt.string(from: $0) }
        self.triggeredAt     = fmt.string(from: alert.triggeredAt)
    }
}

// MARK: - EmergencyAlertService

struct EmergencyAlertService {

    static func fetchAllAlerts() async throws -> [EmergencyAlert] {
        return try await supabase
            .from("emergency_alerts")
            .select()
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchActiveAlerts() async throws -> [EmergencyAlert] {
        return try await supabase
            .from("emergency_alerts")
            .select()
            .eq("status", value: EmergencyAlertStatus.active.rawValue)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func fetchAlerts(driverId: UUID) async throws -> [EmergencyAlert] {
        return try await supabase
            .from("emergency_alerts")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("triggered_at", ascending: false)
            .execute()
            .value
    }

    static func addAlert(_ alert: EmergencyAlert) async throws {
        let payload = EmergencyAlertPayload(from: alert)
        try await supabase
            .from("emergency_alerts")
            .insert(payload)
            .execute()
    }

    static func updateAlert(_ alert: EmergencyAlert) async throws {
        let payload = EmergencyAlertPayload(from: alert)
        try await supabase
            .from("emergency_alerts")
            .update(payload)
            .eq("id", value: alert.id.uuidString)
            .execute()
    }

    static func deleteAlert(id: UUID) async throws {
        try await supabase
            .from("emergency_alerts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
