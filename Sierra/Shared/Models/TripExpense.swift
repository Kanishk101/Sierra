import Foundation

// MARK: - Trip Expense Type
// Maps to PostgreSQL enum: trip_expense_type

enum TripExpenseType: String, Codable, CaseIterable {
    case toll    = "Toll"
    case parking = "Parking"
    case other   = "Other"
}

// MARK: - TripExpense
// Maps to table: trip_expenses

struct TripExpense: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var tripId: UUID                      // trip_id (FK → trips.id)
    var driverId: UUID                    // driver_id (FK → staff_members.id)
    var vehicleId: UUID                   // vehicle_id (FK → vehicles.id)

    // MARK: Expense details
    var expenseType: TripExpenseType      // expense_type
    var amount: Double                    // amount
    var receiptUrl: String?               // receipt_url
    var notes: String?                    // notes

    // MARK: Timestamps
    var loggedAt: Date                    // logged_at
    var createdAt: Date                   // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case tripId      = "trip_id"
        case driverId    = "driver_id"
        case vehicleId   = "vehicle_id"
        case expenseType = "expense_type"
        case amount
        case receiptUrl  = "receipt_url"
        case notes
        case loggedAt    = "logged_at"
        case createdAt   = "created_at"
    }
}
