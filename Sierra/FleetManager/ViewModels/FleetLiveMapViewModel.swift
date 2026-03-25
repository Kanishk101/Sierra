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
    var breadcrumbHistory: [VehicleLocationHistory] = []
    var isFetchingBreadcrumb = false
    var fallbackCoordinates: [UUID: CLLocationCoordinate2D] = [:]

    // MARK: - Speed Segments

    struct SpeedSegment: Identifiable {
        let id = UUID()
        let coordinates: [CLLocationCoordinate2D]
        let avgSpeedKmh: Double
        var speedColor: Color {
            switch avgSpeedKmh {
            case 0..<20: return .red
            case 20..<60: return .orange
            case 60..<100: return .yellow
            default: return .green
            }
        }
    }

    var speedSegments: [SpeedSegment] {
        guard breadcrumbHistory.count >= 2 else { return [] }
        var segments: [SpeedSegment] = []
        var currentCoords: [CLLocationCoordinate2D] = []
        var currentSpeedSum: Double = 0
        var currentCount: Int = 0
        var lastBucket: Int = -1

        for entry in breadcrumbHistory {
            let speed = entry.speedKmh ?? 0
            let bucket: Int
            switch speed {
            case 0..<20: bucket = 0
            case 20..<60: bucket = 1
            case 60..<100: bucket = 2
            default: bucket = 3
            }
            let coord = CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)

            if bucket != lastBucket && !currentCoords.isEmpty {
                // Close previous segment
                let avgSpeed = currentCount > 0 ? currentSpeedSum / Double(currentCount) : 0
                segments.append(SpeedSegment(coordinates: currentCoords, avgSpeedKmh: avgSpeed))
                // Start new segment from last point of previous for continuity
                currentCoords = [currentCoords.last!]
                currentSpeedSum = 0
                currentCount = 0
            }

            currentCoords.append(coord)
            currentSpeedSum += speed
            currentCount += 1
            lastBucket = bucket
        }

        // Close final segment
        if currentCoords.count >= 2 {
            let avgSpeed = currentCount > 0 ? currentSpeedSum / Double(currentCount) : 0
            segments.append(SpeedSegment(coordinates: currentCoords, avgSpeedKmh: avgSpeed))
        }

        return segments
    }

    // MARK: - Filtered Vehicles (Safeguard 7: computed, never mutates source)

    func filteredVehicles(from vehicles: [Vehicle]) -> [Vehicle] {
        switch selectedFilter {
        case .all: return vehicles
        case .active: return vehicles.filter { $0.status == .active || $0.status == .busy }
        case .idle: return vehicles.filter { $0.status == .idle }
        case .inMaintenance: return vehicles.filter { $0.status == .inMaintenance }
        }
    }

    func coordinate(for vehicle: Vehicle) -> CLLocationCoordinate2D? {
        if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return fallbackCoordinates[vehicle.id]
    }

    func sanitizedBreadcrumbCoordinates(maxJumpKm: Double = 25) -> [CLLocationCoordinate2D] {
        guard !breadcrumbCoordinates.isEmpty else { return [] }
        let maxJumpMetres = maxJumpKm * 1000
        var sanitized: [CLLocationCoordinate2D] = [breadcrumbCoordinates[0]]
        for coordinate in breadcrumbCoordinates.dropFirst() {
            guard let last = sanitized.last else {
                sanitized.append(coordinate)
                continue
            }
            let a = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if a.distance(from: b) <= maxJumpMetres {
                sanitized.append(coordinate)
            }
        }
        return sanitized
    }

    func refreshFallbackCoordinates(for vehicles: [Vehicle]) async {
        let missingLive = vehicles.filter { $0.currentLatitude == nil || $0.currentLongitude == nil }
        guard !missingLive.isEmpty else {
            fallbackCoordinates = [:]
            return
        }
        for vehicle in missingLive {
            do {
                let history = try await VehicleLocationService.fetchRecentLocationHistory(vehicleId: vehicle.id, limit: 1)
                if let last = history.last {
                    fallbackCoordinates[vehicle.id] = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
                }
            } catch {
                continue
            }
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

    // MARK: - Dynamic Camera Framing

    func fitAllActiveVehicles(vehicles: [Vehicle]) -> MapCameraPosition {
        let active = vehicles.compactMap { v -> CLLocationCoordinate2D? in
            guard let lat = v.currentLatitude, let lng = v.currentLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !active.isEmpty else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                latitudinalMeters: 2_000_000, longitudinalMeters: 2_000_000
            ))
        }
        if active.count == 1 {
            return .region(MKCoordinateRegion(
                center: active[0], latitudinalMeters: 5000, longitudinalMeters: 5000
            ))
        }
        let lats = active.map { $0.latitude }
        let lngs = active.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                latitudinalMeters: 2_000_000, longitudinalMeters: 2_000_000
            ))
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLng - minLng) * 1.4)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Breadcrumb (Safeguard 5: only on vehicle tap)

    func fetchBreadcrumb(vehicleId: UUID, tripId: UUID) async {
        isFetchingBreadcrumb = true
        do {
            let history = try await VehicleLocationService.fetchLocationHistory(vehicleId: vehicleId, tripId: tripId)
            breadcrumbHistory = history
            breadcrumbCoordinates = history.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
        } catch {
            print("[FleetMapVM] Breadcrumb fetch error: \(error)")
        }
        isFetchingBreadcrumb = false
    }

    func fetchRecentBreadcrumb(vehicleId: UUID, limit: Int = 200) async {
        isFetchingBreadcrumb = true
        do {
            let history = try await VehicleLocationService.fetchRecentLocationHistory(vehicleId: vehicleId, limit: limit)
            breadcrumbHistory = history
            breadcrumbCoordinates = history.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
        } catch {
            print("[FleetMapVM] Recent breadcrumb fetch error: \(error)")
        }
        isFetchingBreadcrumb = false
    }

    func clearBreadcrumb() {
        breadcrumbCoordinates = []
        breadcrumbHistory = []
        selectedVehicleId = nil
    }
}
