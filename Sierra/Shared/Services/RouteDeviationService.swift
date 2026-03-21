import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - RouteDeviationService

struct RouteDeviationService {

    // MARK: Record

    static func recordDeviation(
        tripId: UUID,
        driverId: UUID,
        vehicleId: UUID,
        latitude: Double,
        longitude: Double,
        deviationMetres: Double
    ) async throws {
        struct DeviationPayload: Encodable {
            let trip_id: String
            let driver_id: String
            let vehicle_id: String
            let latitude: Double
            let longitude: Double
            let deviation_distance_m: Double
            let is_acknowledged: Bool
            let detected_at: String
        }

        struct ActivityPayload: Encodable {
            let type: String
            let title: String
            let description: String
            let actor_id: String
            let entity_type: String
            let entity_id: String
            let severity: String
            let is_read: Bool
            let timestamp: String
        }

        let now = iso.string(from: Date())

        // 1. Insert route_deviation_events
        try await supabase
            .from("route_deviation_events")
            .insert(DeviationPayload(
                trip_id: tripId.uuidString,
                driver_id: driverId.uuidString,
                vehicle_id: vehicleId.uuidString,
                latitude: latitude,
                longitude: longitude,
                deviation_distance_m: deviationMetres,
                is_acknowledged: false,
                detected_at: now
            ))
            .execute()

        // 2. Insert activity_logs
        try await supabase
            .from("activity_logs")
            .insert(ActivityPayload(
                type: ActivityType.routeDeviation.rawValue,
                title: "Route Deviation",
                description: "Driver deviated \(Int(deviationMetres))m from planned route",
                actor_id: driverId.uuidString,
                entity_type: "trip",
                entity_id: tripId.uuidString,
                severity: ActivitySeverity.warning.rawValue,
                is_read: false,
                timestamp: now
            ))
            .execute()

        // 3. Notify ALL fleet managers (non-fatal)
        do {
            struct FMIdRow: Decodable { let id: UUID }
            let fmRows: [FMIdRow] = try await supabase
                .from("staff_members")
                .select("id")
                .eq("role", value: "fleetManager")
                .eq("status", value: "Active")
                .execute()
                .value
            for fm in fmRows {
                try await NotificationService.insertNotification(
                    recipientId: fm.id,
                    type: .routeDeviation,
                    title: "Route Deviation Detected",
                    body: "A driver deviated \(Int(deviationMetres))m from the planned route on trip \(tripId.uuidString.prefix(8)).",
                    entityType: "trip",
                    entityId: tripId
                )
            }
        } catch {
            print("[RouteDeviationService] Non-fatal: failed to notify fleet managers: \(error)")
        }
    }

    // MARK: Fetch — by trip (used during active trip context)

    static func fetchDeviations(for tripId: UUID) async throws -> [RouteDeviationEvent] {
        try await supabase
            .from("route_deviation_events")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("detected_at", ascending: false)
            .execute()
            .value
    }

    // MARK: Fetch — all (used by loadAll for fleet manager dashboard)
    // RLS policy rde_select: get_my_role() = 'fleetManager' OR driver_id = auth.uid()
    // so drivers only see their own events; fleet managers see all.

    static func fetchAllDeviations(limit: Int = 500) async throws -> [RouteDeviationEvent] {
        try await supabase
            .from("route_deviation_events")
            .select()
            .order("detected_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: Acknowledge

    static func acknowledgeDeviation(id: UUID, by adminId: UUID) async throws {
        struct Payload: Encodable {
            let is_acknowledged: Bool
            let acknowledged_by: String
            let acknowledged_at: String
        }
        try await supabase
            .from("route_deviation_events")
            .update(Payload(
                is_acknowledged: true,
                acknowledged_by: adminId.uuidString,
                acknowledged_at: iso.string(from: Date())
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
