import XCTest
@testable import Sierra

extension Vehicle {
    static func makeTest(
        id: UUID = UUID(),
        name: String = "Test Vehicle",
        manufacturer: String = "TestMfg",
        model: String = "TestModel",
        year: Int = 2024,
        vin: String = "VIN000000000000000",
        licensePlate: String = "TEST-001",
        color: String = "White",
        fuelType: FuelType = .diesel,
        seatingCapacity: Int = 3,
        status: VehicleStatus = .active,
        assignedDriverId: String? = nil,
        currentLatitude: Double? = nil,
        currentLongitude: Double? = nil,
        odometer: Double = 10000.0,
        totalTrips: Int = 50,
        totalDistanceKm: Double = 8000.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Vehicle {
        Vehicle(
            id: id,
            name: name,
            manufacturer: manufacturer,
            model: model,
            year: year,
            vin: vin,
            licensePlate: licensePlate,
            color: color,
            fuelType: fuelType,
            seatingCapacity: seatingCapacity,
            status: status,
            assignedDriverId: assignedDriverId,
            currentLatitude: currentLatitude,
            currentLongitude: currentLongitude,
            odometer: odometer,
            totalTrips: totalTrips,
            totalDistanceKm: totalDistanceKm,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
