import Foundation

// MARK: - FuelLog
// Maps to table: fuel_logs

struct FuelLog: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var driverId: UUID                   // driver_id (FK → staff_members.id)
    var vehicleId: UUID                  // vehicle_id (FK → vehicles.id)
    var tripId: UUID?                    // trip_id (FK → trips.id)

    // MARK: Fuel details
    var fuelQuantityLitres: Double       // fuel_quantity_litres
    var fuelCost: Double                 // fuel_cost
    var pricePerLitre: Double            // price_per_litre
    var odometerAtFill: Double           // odometer_at_fill
    var fuelStation: String?             // fuel_station
    var receiptImageUrl: String?         // receipt_image_url

    // MARK: Timestamps
    var loggedAt: Date                   // logged_at (default now())
    var createdAt: Date                  // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
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
        case createdAt          = "created_at"
    }
}
