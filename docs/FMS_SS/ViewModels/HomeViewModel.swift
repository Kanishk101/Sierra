import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recentTrips: [Trip] = []
    @Published private(set) var loadState: ScreenLoadState = .idle
    @Published var fallbackErrorMessage: String?

    let sampleTrips: [Trip] = [
        Trip(id: "1", tripCode: "TRP-20260310-621", origin: "Chennai", destination: "Bengaluru", fleetNumber: "FL-4096", vehicleType: "Express Van Ford Transit", dateTime: "10 Mar at 11:13 PM", priority: .urgent, distanceKm: 346, scheduledDate: "10 March 2026", scheduledTime: "11:13 PM"),
        Trip(id: "2", tripCode: "TRP-20260310-622", origin: "Chennai", destination: "Bengaluru", fleetNumber: "FL-4096", vehicleType: "Express Van Ford Transit", dateTime: "10 Mar at 11:13 PM", priority: .high, distanceKm: 346, scheduledDate: "10 March 2026", scheduledTime: "11:13 PM"),
        Trip(id: "3", tripCode: "TRP-20260310-623", origin: "Chennai", destination: "Bengaluru", fleetNumber: "FL-4096", vehicleType: "Express Van Ford Transit", dateTime: "10 Mar at 11:13 PM", priority: .normal, distanceKm: 346, scheduledDate: "10 March 2026", scheduledTime: "11:13 PM")
    ]

    func load() {
        loadState = .loading
        let failures = AppRuntimeTestCases.validateTrips(sampleTrips)

        if !failures.isEmpty {
            fallbackErrorMessage = "Data validation failed. Showing safe fallback trips."
        }

        recentTrips = sampleTrips.filter {
            !$0.tripCode.isEmpty && !$0.origin.isEmpty && !$0.destination.isEmpty && $0.distanceKm > 0
        }

        if recentTrips.isEmpty {
            loadState = .empty
            if fallbackErrorMessage == nil {
                fallbackErrorMessage = "No trips available right now."
            }
        } else {
            loadState = .loaded
        }
    }

    func clearFallbackError() {
        fallbackErrorMessage = nil
    }
}
