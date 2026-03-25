import Foundation
import Combine

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var filterMode: TripFilterMode = .all
    @Published var fallbackErrorMessage: String?
    @Published private(set) var loadState: ScreenLoadState = .idle

    private let allTrips: [Trip] = [
        Trip(id: "1", tripCode: "TRP-20260310-621", origin: "Chennai", destination: "Bengaluru", fleetNumber: "FL-4096", vehicleType: "Express Van Ford Transit", dateTime: "10 Mar at 11:13 PM", priority: .urgent, distanceKm: 346, scheduledDate: "10 March 2026", scheduledTime: "11:13 PM"),
        Trip(id: "2", tripCode: "TRP-20260312-734", origin: "Bengaluru", destination: "Mysuru", fleetNumber: "FL-2081", vehicleType: "Express Van Ford Transit", dateTime: "12 Mar at 6:30 AM", priority: .high, distanceKm: 150, scheduledDate: "12 March 2026", scheduledTime: "6:30 AM"),
        Trip(id: "3", tripCode: "TRP-20260313-455", origin: "Chennai", destination: "Coimbatore", fleetNumber: "FL-3312", vehicleType: "Mini Bus Tata Starbus", dateTime: "13 Mar at 2:00 PM", priority: .normal, distanceKm: 505, scheduledDate: "13 March 2026", scheduledTime: "2:00 PM"),
        Trip(id: "4", tripCode: "TRP-20260314-889", origin: "Hyderabad", destination: "Bengaluru", fleetNumber: "FL-1567", vehicleType: "Express Van Ford Transit", dateTime: "14 Mar at 9:45 PM", priority: .medium, distanceKm: 570, scheduledDate: "14 March 2026", scheduledTime: "9:45 PM"),
        Trip(id: "5", tripCode: "TRP-20260315-102", origin: "Bengaluru", destination: "Hubli", fleetNumber: "FL-4096", vehicleType: "Sleeper Coach Volvo", dateTime: "15 Mar at 7:00 AM", priority: .urgent, distanceKm: 420, scheduledDate: "15 March 2026", scheduledTime: "7:00 AM"),
        Trip(id: "6", tripCode: "TRP-20260316-290", origin: "Mysuru", destination: "Chennai", fleetNumber: "FL-2081", vehicleType: "Express Van Ford Transit", dateTime: "16 Mar at 4:15 PM", priority: .high, distanceKm: 482, scheduledDate: "16 March 2026", scheduledTime: "4:15 PM"),
        Trip(id: "7", tripCode: "TRP-20260317-411", origin: "Coimbatore", destination: "Bengaluru", fleetNumber: "FL-3312", vehicleType: "Mini Bus Tata Starbus", dateTime: "17 Mar at 11:30 AM", priority: .normal, distanceKm: 365, scheduledDate: "17 March 2026", scheduledTime: "11:30 AM")
    ]

    var selectedPriority: TripPriority? {
        if case .priority(let priority) = filterMode {
            return priority
        }
        return nil
    }

    var showCompletedOnly: Bool {
        if case .completed = filterMode {
            return true
        }
        return false
    }

    var filteredTrips: [Trip] {
        let base: [Trip]
        switch filterMode {
        case .all:
            base = trips
        case .priority(let priority):
            base = trips.filter { $0.priority == priority }
        case .completed:
            base = trips.filter { $0.isTripEnded }
        }
        return base.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var tripStats: (total: Int, urgent: Int, accepted: Int) {
        let urgent = trips.filter { $0.priority == .urgent && !$0.isTripEnded }.count
        let accepted = trips.filter { $0.isAccepted }.count
        return (trips.count, urgent, accepted)
    }

    func loadIfNeeded() {
        guard trips.isEmpty else { return }
        loadState = .loading

        let failures = AppRuntimeTestCases.validateTrips(allTrips)
        if !failures.isEmpty {
            fallbackErrorMessage = "Data test cases failed. Showing sanitized fallback list."
        }

        trips = allTrips.filter {
            !$0.tripCode.isEmpty && !$0.origin.isEmpty && !$0.destination.isEmpty && $0.distanceKm > 0
        }

        loadState = trips.isEmpty ? .empty : .loaded
        if trips.isEmpty && fallbackErrorMessage == nil {
            fallbackErrorMessage = "Unable to load trips right now."
        }
    }

    func sortByPriority() {
        trips.sort { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    func applyFilter(_ priority: TripPriority?) {
        if let priority {
            filterMode = .priority(priority)
        } else {
            filterMode = .all
        }
    }

    func applyCompletedFilter() {
        filterMode = .completed
    }

    func clearFilter() {
        filterMode = .all
    }

    func clearFallbackError() {
        fallbackErrorMessage = nil
    }

    func trip(for id: String) -> Trip? {
        trips.first(where: { $0.id == id })
    }

    func acceptTrip(id: String) {
        guard let idx = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[idx].isAccepted = true
    }

    func markInspectionComplete(id: String, mode: TripsView.InspectionMode) {
        guard let idx = trips.firstIndex(where: { $0.id == id }) else { return }
        if mode == .pre {
            trips[idx].isInspectionCompleted = true
        } else {
            trips[idx].isPostTripInspectionCompleted = true
        }
    }

    func markTripEnded(id: String) {
        guard let idx = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[idx].isTripEnded = true
    }

    func markVehicleChangeRequested(id: String) {
        guard let idx = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[idx].vehicleStatus = .waitingReallocation
        trips[idx].isInspectionCompleted = false
    }
}
