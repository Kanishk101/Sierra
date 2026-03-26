import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - FuelLogPayload

struct FuelLogPayload: Encodable {
    let driverId: String
    let vehicleId: String
    let tripId: String?
    let fuelQuantityLitres: Double
    let fuelCost: Double
    let pricePerLitre: Double
    let odometerAtFill: Double
    let fuelStation: String?
    let receiptImageUrl: String?
    let loggedAt: String

    enum CodingKeys: String, CodingKey {
        case driverId           = "driver_id"
        case vehicleId          = "vehicle_id"
        case tripId             = "trip_id"
        case fuelQuantityLitres = "fuel_quantity_litres"
        case fuelCost           = "fuel_cost"
        case pricePerLitre      = "price_per_litre"
        case odometerAtFill     = "odometer_at_fill"
        case fuelStation        = "fuel_station"
        case receiptImageUrl    = "receipt_image_url"
        case loggedAt           = "logged_at"
    }

    init(from log: FuelLog) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.driverId           = log.driverId.uuidString
        self.vehicleId          = log.vehicleId.uuidString
        self.tripId             = log.tripId?.uuidString
        self.fuelQuantityLitres = log.fuelQuantityLitres
        self.fuelCost           = log.fuelCost
        self.pricePerLitre      = log.pricePerLitre
        self.odometerAtFill     = log.odometerAtFill
        self.fuelStation        = log.fuelStation
        self.receiptImageUrl    = log.receiptImageUrl
        self.loggedAt           = fmt.string(from: log.loggedAt)
    }
}

// MARK: - FuelLogService

struct FuelLogService {

    static func fetchAllFuelLogs(limit: Int = 500) async throws -> [FuelLog] {
        return try await supabase
            .from("fuel_logs")
            .select()
            .order("logged_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchFuelLogs(driverId: UUID) async throws -> [FuelLog] {
        return try await supabase
            .from("fuel_logs")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    static func fetchFuelLogs(vehicleId: UUID) async throws -> [FuelLog] {
        return try await supabase
            .from("fuel_logs")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    static func fetchFuelLogs(tripId: UUID) async throws -> [FuelLog] {
        return try await supabase
            .from("fuel_logs")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    static func addFuelLog(_ log: FuelLog) async throws {
        let payload = FuelLogPayload(from: log)
        try await supabase
            .from("fuel_logs")
            .insert(payload)
            .execute()
    }

    static func deleteFuelLog(id: UUID) async throws {
        try await supabase
            .from("fuel_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
