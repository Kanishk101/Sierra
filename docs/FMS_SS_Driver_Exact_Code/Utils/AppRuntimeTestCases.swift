import Foundation

struct AppRuntimeTestCases {
    static func validateTrips(_ trips: [Trip]) -> [String] {
        var failures: [String] = []

        if trips.isEmpty {
            failures.append("No trip records found")
            return failures
        }

        for trip in trips {
            if trip.tripCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append("Missing trip code for id: \(trip.id)")
            }
            if trip.origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append("Invalid route values for trip: \(trip.tripCode)")
            }
            if trip.fleetNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || trip.vehicleType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append("Invalid vehicle details for trip: \(trip.tripCode)")
            }
            if trip.distanceKm <= 0 {
                failures.append("Distance must be > 0 for trip: \(trip.tripCode)")
            }
        }

        return failures
    }
}
