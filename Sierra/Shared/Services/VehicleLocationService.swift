import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - VehicleLocationService
// Publishes GPS pings to vehicle_location_history and updates vehicle position.
// Uses a class to hold throttle state and channel reference.

final class VehicleLocationService {

    static let shared = VehicleLocationService()
    private init() {}

    // MARK: - Throttle

    private var lastPublishTime: Date = .distantPast
    private let minimumPublishIntervalSeconds: TimeInterval = 5.0

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Publish Location

    func publishLocation(
        vehicleId: UUID,
        tripId: UUID,
        driverId: UUID,
        latitude: Double,
        longitude: Double,
        speedKmh: Double?
    ) async throws {
        // Belt-and-suspenders throttle gate
        guard Date().timeIntervalSince(lastPublishTime) >= minimumPublishIntervalSeconds else { return }
        lastPublishTime = Date()

        let now = VehicleLocationService.iso.string(from: Date())
        let rpcParams: [String: AnyJSON] = [
            "p_vehicle_id": .string(vehicleId.uuidString),
            "p_trip_id": .string(tripId.uuidString),
            "p_driver_id": .string(driverId.uuidString),
            "p_latitude": .double(latitude),
            "p_longitude": .double(longitude),
            "p_speed_kmh": speedKmh.map(AnyJSON.double) ?? .null,
            "p_recorded_at": .string(now),
        ]

        // Preferred path: security-definer RPC performs atomic history insert + vehicle location update.
        do {
            try await supabase
                .rpc("driver_publish_vehicle_location", params: rpcParams)
                .execute()
            return
        } catch {
            #if DEBUG
            print("[VehicleLocationService] RPC publish failed, attempting legacy fallback: \(error)")
            #endif
        }

        try await publishLocationLegacy(
            vehicleId: vehicleId,
            tripId: tripId,
            driverId: driverId,
            latitude: latitude,
            longitude: longitude,
            speedKmh: speedKmh,
            recordedAt: now
        )
    }

    private func publishLocationLegacy(
        vehicleId: UUID,
        tripId: UUID,
        driverId: UUID,
        latitude: Double,
        longitude: Double,
        speedKmh: Double?,
        recordedAt: String
    ) async throws {
        struct HistoryPayload: Encodable, Sendable {
            let vehicle_id: String
            let trip_id: String
            let driver_id: String
            let latitude: Double
            let longitude: Double
            let speed_kmh: Double?
            let recorded_at: String
        }

        struct LocationPayload: Encodable, Sendable {
            let current_latitude: Double
            let current_longitude: Double
        }

        try await supabase
            .from("vehicle_location_history")
            .insert(HistoryPayload(
                vehicle_id: vehicleId.uuidString,
                trip_id: tripId.uuidString,
                driver_id: driverId.uuidString,
                latitude: latitude,
                longitude: longitude,
                speed_kmh: speedKmh,
                recorded_at: recordedAt
            ))
            .execute()

        try await supabase
            .from("vehicles")
            .update(LocationPayload(current_latitude: latitude, current_longitude: longitude))
            .eq("id", value: vehicleId.uuidString)
            .execute()
    }

    // MARK: - Fetch History

    static func fetchLocationHistory(vehicleId: UUID, tripId: UUID) async throws -> [VehicleLocationHistory] {
        try await supabase
            .from("vehicle_location_history")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .order("recorded_at", ascending: true)
            .execute()
            .value
    }

    static func fetchRecentLocationHistory(vehicleId: UUID, limit: Int = 200) async throws -> [VehicleLocationHistory] {
        let rows: [VehicleLocationHistory] = try await supabase
            .from("vehicle_location_history")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("recorded_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.sorted { $0.recordedAt < $1.recordedAt }
    }
}
