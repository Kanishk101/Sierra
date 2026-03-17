import SwiftUI
import MapKit

/// ViewModel for the admin fleet live map.
/// Safeguard 7: read-only w.r.t. AppDataStore — never mutates source arrays.
@MainActor
@Observable
final class FleetLiveMapViewModel {

    // MARK: - Filter

    enum VehicleFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case idle = "Idle"
        case inMaintenance = "Maintenance"
    }

    var selectedFilter: VehicleFilter = .all
    var selectedVehicleId: UUID?
    var showVehicleDetail = false
    var showCreateGeofence = false
    var showFilterPicker = false

    // Breadcrumb for selected vehicle
    var breadcrumbCoordinates: [CLLocationCoordinate2D] = []
    var isFetchingBreadcrumb = false

    // MARK: - Filtered Vehicles (Safeguard 7: computed, never mutates source)

    func filteredVehicles(from vehicles: [Vehicle]) -> [Vehicle] {
        let withLocation = vehicles.filter { $0.currentLatitude != nil && $0.currentLongitude != nil }
        switch selectedFilter {
        case .all: return withLocation
        case .active: return withLocation.filter { $0.status == .active || $0.status == .busy }
        case .idle: return withLocation.filter { $0.status == .idle }
        case .inMaintenance: return withLocation.filter { $0.status == .inMaintenance }
        }
    }

    // MARK: - Fleet Centroid

    func fleetCentroid(vehicles: [Vehicle]) -> CLLocationCoordinate2D {
        let located = vehicles.filter { $0.currentLatitude != nil && $0.currentLongitude != nil }
        guard !located.isEmpty else {
            return CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629) // India center
        }
        let avgLat = located.compactMap(\.currentLatitude).reduce(0, +) / Double(located.count)
        let avgLng = located.compactMap(\.currentLongitude).reduce(0, +) / Double(located.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
    }

    // MARK: - Breadcrumb (Safeguard 5: only on vehicle tap)

    func fetchBreadcrumb(vehicleId: UUID, tripId: UUID) async {
        isFetchingBreadcrumb = true
        breadcrumbCoordinates = []
        do {
            let history = try await VehicleLocationService.fetchLocationHistory(vehicleId: vehicleId, tripId: tripId)
            breadcrumbCoordinates = history.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
        } catch {
            print("[FleetMapVM] Breadcrumb fetch error: \(error)")
        }
        isFetchingBreadcrumb = false
    }

    func clearBreadcrumb() {
        breadcrumbCoordinates = []
        selectedVehicleId = nil
    }
}
