import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - TripExpenseService

struct TripExpenseService {

    // MARK: Log Expense

    static func logExpense(
        tripId: UUID,
        driverId: UUID,
        vehicleId: UUID,
        type: TripExpenseType,
        amount: Double,
        receiptUrl: String?,
        notes: String?
    ) async throws {
        struct Payload: Encodable {
            let trip_id: String
            let driver_id: String
            let vehicle_id: String
            let expense_type: String
            let amount: Double
            let receipt_url: String?
            let notes: String?
            let logged_at: String
        }
        try await supabase
            .from("trip_expenses")
            .insert(Payload(
                trip_id: tripId.uuidString,
                driver_id: driverId.uuidString,
                vehicle_id: vehicleId.uuidString,
                expense_type: type.rawValue,
                amount: amount,
                receipt_url: receiptUrl,
                notes: notes,
                logged_at: iso.string(from: Date())
            ))
            .execute()
    }

    // MARK: Fetch

    static func fetchExpenses(for tripId: UUID) async throws -> [TripExpense] {
        try await supabase
            .from("trip_expenses")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }
}
