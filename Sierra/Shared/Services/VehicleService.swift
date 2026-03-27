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
// Includes id so the client-generated UUID is used by the DB.
// If id is omitted the DB auto-generates a different UUID and any
// subsequent trip/assignment using store.vehicle(for:) will get a
// trips_vehicle_id_fkey violation.
// Excludes: created_at, updated_at (auto-managed by DB)

struct VehicleInsertPayload: Encodable {
    let id: String               // must be included — see note above
    let name: String
    let manufacturer: String
    let model: String
    let year: Int
    let vin: String
    let licensePlate: String
    let color: String
    let fuelType: String
    let seatingCapacity: Int
    let fuelTankCapacityLiters: Double?
    let mileageKmPerLitre: Double?
    let status: String
    let assignedDriverId: String?
    let currentLatitude: Double?
    let currentLongitude: Double?
    let odometer: Double
    let totalTrips: Int
    let totalDistanceKm: Double

    enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, model, year, vin, color
        case licensePlate     = "license_plate"
        case fuelType         = "fuel_type"
        case seatingCapacity  = "seating_capacity"
        case fuelTankCapacityLiters = "fuel_tank_capacity_liters"
        case mileageKmPerLitre = "mileage_km_per_litre"
        case status
        case assignedDriverId = "assigned_driver_id"
        case currentLatitude  = "current_latitude"
        case currentLongitude = "current_longitude"
        case odometer
        case totalTrips       = "total_trips"
        case totalDistanceKm  = "total_distance_km"
    }

    init(from v: Vehicle) {
        id               = v.id.uuidString
        name             = v.name
        manufacturer     = v.manufacturer
        model            = v.model
        year             = v.year
        vin              = v.vin
        licensePlate     = v.licensePlate
        color            = v.color
        fuelType         = v.fuelType.rawValue
        seatingCapacity  = v.seatingCapacity
        fuelTankCapacityLiters = v.fuelTankCapacityLiters
        mileageKmPerLitre = v.mileageKmPerLitre
        status           = v.status.rawValue
        assignedDriverId = v.assignedDriverId
        currentLatitude  = v.currentLatitude
        currentLongitude = v.currentLongitude
        odometer         = v.odometer
        totalTrips       = v.totalTrips
        totalDistanceKm  = v.totalDistanceKm
    }
}

// MARK: - VehicleUpdatePayload (same fields as insert, id excluded from update body)

struct VehicleUpdatePayload: Encodable {
    let name: String
    let manufacturer: String
    let model: String
    let year: Int
    let vin: String
    let licensePlate: String
    let color: String
    let fuelType: String
    let seatingCapacity: Int
    let fuelTankCapacityLiters: Double?
    let mileageKmPerLitre: Double?
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
        case fuelTankCapacityLiters = "fuel_tank_capacity_liters"
        case mileageKmPerLitre = "mileage_km_per_litre"
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
        fuelTankCapacityLiters = v.fuelTankCapacityLiters
        mileageKmPerLitre = v.mileageKmPerLitre
        status           = v.status.rawValue
        assignedDriverId = v.assignedDriverId
        currentLatitude  = v.currentLatitude
        currentLongitude = v.currentLongitude
        odometer         = v.odometer
        totalTrips       = v.totalTrips
        totalDistanceKm  = v.totalDistanceKm
    }
}

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
        do {
            try await supabase
                .from("vehicles")
                .insert(VehicleInsertPayload(from: vehicle))
                .execute()
        } catch {
            print("[VehicleService] addVehicle failed: \(error)")
            throw error
        }
    }

    // MARK: Update

    static func updateVehicle(_ vehicle: Vehicle) async throws {
        do {
            try await supabase
                .from("vehicles")
                .update(VehicleUpdatePayload(from: vehicle))
                .eq("id", value: vehicle.id.uuidString)
                .execute()
        } catch {
            print("[VehicleService] updateVehicle failed: \(error)")
            throw error
        }
    }

    // MARK: Delete

    static func deleteVehicle(id: UUID) async throws {
        do {
            try await supabase
                .from("vehicles")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("[VehicleService] deleteVehicle failed: \(error)")
            throw error
        }
    }

    // MARK: Assign Driver

    static func assignDriver(vehicleId: UUID, driverId: UUID?) async throws {
        struct Payload: Encodable {
            let assigned_driver_id: String?
        }
        do {
            try await supabase
                .from("vehicles")
                .update(Payload(assigned_driver_id: driverId?.uuidString))
                .eq("id", value: vehicleId.uuidString)
                .execute()
        } catch {
            print("[VehicleService] assignDriver failed: \(error)")
            throw error
        }
    }

    static func setStatus(vehicleId: UUID, status: VehicleStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("vehicles")
            .update(Payload(status: status.rawValue))
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
