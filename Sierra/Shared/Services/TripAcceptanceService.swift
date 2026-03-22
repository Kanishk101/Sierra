import Foundation
import Supabase

// MARK: - TripAcceptanceService
// Handles direct DB updates for trip accept/reject.
// NOTE: AppDataStore+TripAcceptance.swift uses these internally.
// Both acceptTrip and rejectTrip include a server-side driver_id equality
// filter so a driver can only accept/reject trips assigned to them.
// RLS on the trips table enforces the same constraint at the DB level.

private let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

struct TripAcceptanceService {

    static func acceptTrip(tripId: UUID, driverId: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let accepted_at: String
        }
        let rows: [Trip] = try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.accepted.rawValue,
                accepted_at: iso8601.string(from: Date())
            ))
            .eq("id",        value: tripId.uuidString)
            .eq("driver_id", value: driverId.uuidString.lowercased())
            .select()
            .execute()
            .value
        guard !rows.isEmpty else { throw TripAcceptanceError.driverMismatch }
    }

    static func rejectTrip(tripId: UUID, driverId: UUID, reason: String) async throws {
        struct Payload: Encodable {
            let status: String
            let rejected_reason: String
        }
        let rows: [Trip] = try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.rejected.rawValue,
                rejected_reason: reason
            ))
            .eq("id",        value: tripId.uuidString)
            .eq("driver_id", value: driverId.uuidString.lowercased())
            .select()
            .execute()
            .value
        guard !rows.isEmpty else { throw TripAcceptanceError.driverMismatch }
    }
}

// MARK: - TripAcceptanceError

enum TripAcceptanceError: LocalizedError {
    case driverMismatch
    case reasonRequired

    var errorDescription: String? {
        switch self {
        case .driverMismatch:
            return "You are not assigned to this trip or it is no longer available."
        case .reasonRequired:
            return "Please provide a reason for rejecting the trip (minimum 10 characters)."
        }
    }
}
