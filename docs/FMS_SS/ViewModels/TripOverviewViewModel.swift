import Foundation
import Combine

@MainActor
final class TripOverviewViewModel: ObservableObject {
    @Published var showActiveNavigation: Bool = false
    @Published private(set) var loadState: ScreenLoadState = .idle
    @Published var fallbackErrorMessage: String?

    func load(trip: Trip) {
        loadState = .loading
        let failures = AppRuntimeTestCases.validateTrips([trip])
        if !failures.isEmpty {
            fallbackErrorMessage = "Trip data check failed. Showing fallback-safe values."
        }
        loadState = .loaded
    }

    func openNavigation() {
        showActiveNavigation = true
    }

    func clearError() {
        fallbackErrorMessage = nil
    }
}
