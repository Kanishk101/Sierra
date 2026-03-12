import Foundation

// MARK: - Fuel Type

enum FuelType: String, Codable, CaseIterable, CustomStringConvertible {
    case diesel   = "Diesel"
    case petrol   = "Petrol"
    case electric = "Electric"
    case cng      = "CNG"

    var description: String { rawValue }
}

// MARK: - Vehicle


struct Vehicle: Identifiable, Codable {
    let id: UUID
    var name: String
    var model: String
    var licensePlate: String
    var status: VehicleStatus
    var year: Int
    var vin: String
    var color: String
    var fuelType: FuelType
    var seatingCapacity: Int
    var registrationExpiry: Date
    var insuranceExpiry: Date
    var assignedDriverId: String?
    var manufacturer: String?
    var latitude: Double?
    var longitude: Double?
    var mileage: Double
    var numberOfTrips: Int
    var distanceTravelled: Int
    var insuranceId: String?
    var createdAt: Date

    var documentsExpiringSoon: Bool {
        let now = Date()
        let thirtyDays: TimeInterval = 30 * 86400
        return registrationExpiry.timeIntervalSince(now) < thirtyDays
            || insuranceExpiry.timeIntervalSince(now) < thirtyDays
    }

    // MARK: - Mock Data

    static let mockData: [Vehicle] = {
        let cal = Calendar.current
        let now = Date()

        return [
            // Active — assigned to driver_demo, registration expiring in 18 days
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
                name: "Hauler Alpha",
                model: "Volvo FH16",
                licensePlate: "FL-1024",
                status: .active,
                year: 2024,
                vin: "YV2A4C2A8RB123456",
                color: "White",
                fuelType: .diesel,
                seatingCapacity: 3,
                registrationExpiry: cal.date(byAdding: .day, value: 18, to: now) ?? now,
                insuranceExpiry: cal.date(byAdding: .month, value: 8, to: now) ?? now,
                assignedDriverId: "D0000000-0000-0000-0000-000000000001",
                manufacturer: "Volvo",
                latitude: nil,
                longitude: nil,
                mileage: 87500.0,
                numberOfTrips: 245,
                distanceTravelled: 78200,
                insuranceId: "INS-2024-FL001",
                createdAt: Date().addingTimeInterval(-86400 * 400)
            ),
            // Active — no driver assigned
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
                name: "City Runner",
                model: "Mercedes Sprinter",
                licensePlate: "FL-2048",
                status: .active,
                year: 2023,
                vin: "WDB9066331S987654",
                color: "Silver",
                fuelType: .diesel,
                seatingCapacity: 2,
                registrationExpiry: cal.date(byAdding: .month, value: 6, to: now) ?? now,
                insuranceExpiry: cal.date(byAdding: .month, value: 4, to: now) ?? now,
                assignedDriverId: nil,
                manufacturer: "Mercedes-Benz",
                latitude: nil,
                longitude: nil,
                mileage: 52300.0,
                numberOfTrips: 156,
                distanceTravelled: 43800,
                insuranceId: "INS-2023-FL002",
                createdAt: Date().addingTimeInterval(-86400 * 550)
            ),
            // In Maintenance
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
                name: "Cargo One",
                model: "MAN TGX",
                licensePlate: "FL-3072",
                status: .inMaintenance,
                year: 2022,
                vin: "WMAN08ZZZ3Y112233",
                color: "Blue",
                fuelType: .diesel,
                seatingCapacity: 3,
                registrationExpiry: cal.date(byAdding: .month, value: 3, to: now) ?? now,
                insuranceExpiry: cal.date(byAdding: .month, value: 2, to: now) ?? now,
                assignedDriverId: nil,
                manufacturer: "MAN",
                latitude: nil,
                longitude: nil,
                mileage: 118400.0,
                numberOfTrips: 298,
                distanceTravelled: 94500,
                insuranceId: "INS-2022-FL003",
                createdAt: Date().addingTimeInterval(-86400 * 900)
            ),
            // Idle — insurance expiring in 8 days
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
                name: "Express Van",
                model: "Ford Transit",
                licensePlate: "FL-4096",
                status: .idle,
                year: 2025,
                vin: "1FTBW2CM5JKA44556",
                color: "Red",
                fuelType: .petrol,
                seatingCapacity: 5,
                registrationExpiry: cal.date(byAdding: .month, value: 10, to: now) ?? now,
                insuranceExpiry: cal.date(byAdding: .day, value: 8, to: now) ?? now,
                assignedDriverId: nil,
                manufacturer: "Ford",
                latitude: nil,
                longitude: nil,
                mileage: 15200.0,
                numberOfTrips: 42,
                distanceTravelled: 12800,
                insuranceId: "INS-2025-FL004",
                createdAt: Date().addingTimeInterval(-86400 * 120)
            ),
            // Idle — electric
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
                name: "Green Mile",
                model: "BYD T3",
                licensePlate: "FL-5120",
                status: .idle,
                year: 2025,
                vin: "LGXCE4EB2P0667788",
                color: "Green",
                fuelType: .electric,
                seatingCapacity: 2,
                registrationExpiry: cal.date(byAdding: .year, value: 1, to: now) ?? now,
                insuranceExpiry: cal.date(byAdding: .month, value: 11, to: now) ?? now,
                assignedDriverId: nil,
                manufacturer: "BYD",
                latitude: nil,
                longitude: nil,
                mileage: 22100.0,
                numberOfTrips: 67,
                distanceTravelled: 18900,
                insuranceId: "INS-2025-FL005",
                createdAt: Date().addingTimeInterval(-86400 * 90)
            ),
        ]
    }()

    // Keep backward compat — some views still use .samples
    static let samples: [Vehicle] = mockData
}
