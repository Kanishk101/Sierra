import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - VehicleInsertPayload
// Excludes: id, created_at, updated_at

struct VehicleInsertPayload: Encodable {
    let name: String
    let manufacturer: String
    let model: String
    let year: Int
    let vin: String
    let licensePlate: String
    let color: String
    let fuelType: String
    let seatingCapacity: Int
    let status: String
    let assignedDriverId: String?
    let currentLatitude: Double?
    let currentLongitude: Double?
    let odometer: Double
    let totalTrips: Int
    let totalDistanceKm: Double

    enum CodingKeys: String, CodingKey {
        case name, manufacturer, model, year, vin, color
        case licensePlate     = "license_plate"
        case fuelType         = "fuel_type"
        case seatingCapacity  = "seating_capacity"
        case status
        case assignedDriverId = "assigned_driver_id"
        case currentLatitude  = "current_latitude"
        case currentLongitude = "current_longitude"
        case odometer
        case totalTrips       = "total_trips"
        case totalDistanceKm  = "total_distance_km"
    }

    init(from v: Vehicle) {
        name             = v.name
        manufacturer     = v.manufacturer
        model            = v.model
        year             = v.year
        vin              = v.vin
        licensePlate     = v.licensePlate
        color            = v.color
        fuelType         = v.fuelType.rawValue
        seatingCapacity  = v.seatingCapacity
        status           = v.status.rawValue
        assignedDriverId = v.assignedDriverId   // already String?
        currentLatitude  = v.currentLatitude
        currentLongitude = v.currentLongitude
        odometer         = v.odometer
        totalTrips       = v.totalTrips
        totalDistanceKm  = v.totalDistanceKm
    }
}

// MARK: - VehicleUpdatePayload (same fields as insert)

typealias VehicleUpdatePayload = VehicleInsertPayload

// MARK: - VehicleService

struct VehicleService {

    // MARK: Fetch

    static func fetchAllVehicles() async throws -> [Vehicle] {
        try await supabase
            .from("vehicles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchVehicle(id: UUID) async throws -> Vehicle? {
        let rows: [Vehicle] = try await supabase
            .from("vehicles")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func fetchVehicles(status: VehicleStatus) async throws -> [Vehicle] {
        try await supabase
            .from("vehicles")
            .select()
            .eq("status", value: status.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: Insert

    static func addVehicle(_ vehicle: Vehicle) async throws {
        try await supabase
            .from("vehicles")
            .insert(VehicleInsertPayload(from: vehicle))
            .execute()
    }

    // MARK: Update

    static func updateVehicle(_ vehicle: Vehicle) async throws {
        try await supabase
            .from("vehicles")
            .update(VehicleUpdatePayload(from: vehicle))
            .eq("id", value: vehicle.id.uuidString)
            .execute()
    }

    // MARK: Delete

    static func deleteVehicle(id: UUID) async throws {
        try await supabase
            .from("vehicles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Assign Driver

    static func assignDriver(vehicleId: UUID, driverId: UUID?) async throws {
        struct Payload: Encodable {
            let assigned_driver_id: String?
        }
        try await supabase
            .from("vehicles")
            .update(Payload(assigned_driver_id: driverId?.uuidString))
            .eq("id", value: vehicleId.uuidString)
            .execute()
    }

    // MARK: Update Location

    static func updateLocation(vehicleId: UUID, latitude: Double, longitude: Double) async throws {
        struct Payload: Encodable {
            let current_latitude: Double
            let current_longitude: Double
        }
        try await supabase
            .from("vehicles")
            .update(Payload(current_latitude: latitude, current_longitude: longitude))
            .eq("id", value: vehicleId.uuidString)
            .execute()
    }
}
