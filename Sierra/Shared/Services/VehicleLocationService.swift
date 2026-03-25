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

        struct HistoryPayload: Encodable {
            let vehicle_id: String
            let trip_id: String
            let driver_id: String
            let latitude: Double
            let longitude: Double
            let speed_kmh: Double?
            let recorded_at: String
        }

        struct LocationPayload: Encodable {
            let current_latitude: Double
            let current_longitude: Double
        }

        let now = VehicleLocationService.iso.string(from: Date())

        // 1. Insert into vehicle_location_history
        try await supabase
            .from("vehicle_location_history")
            .insert(HistoryPayload(
                vehicle_id: vehicleId.uuidString,
                trip_id: tripId.uuidString,
                driver_id: driverId.uuidString,
                latitude: latitude,
                longitude: longitude,
                speed_kmh: speedKmh,
                recorded_at: now
            ))
            .execute()

        // 2. Update vehicle's current position
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
