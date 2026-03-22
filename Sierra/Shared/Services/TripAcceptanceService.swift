import Foundation
import Supabase

// MARK: - TripAcceptanceService
// ⚠️ DEPRECATED — DO NOT USE.
// This service previously handled accept/reject trip DB updates directly.
// All call sites now route through:
//   AppDataStore+TripAcceptance.acceptTrip() / .rejectTrip()
//   which internally call TripService.acceptTrip() / TripService.rejectTrip()
//   with the same driver_id equality filter and RLS enforcement.
//
// Kept here (not deleted) to avoid requiring Xcode project file edits.
// The @available deprecation attribute will surface a build warning if
// anyone accidentally attempts to call this directly.

private let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

@available(*, deprecated, renamed: "TripService", message: "Use TripService via AppDataStore+TripAcceptance instead.")
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
