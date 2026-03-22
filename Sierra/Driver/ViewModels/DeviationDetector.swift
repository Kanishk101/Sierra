import Foundation
import CoreLocation

// MARK: - DeviationDetector
// Pure computation class — no @Observable needed.
// Extracts route-deviation math from TripNavigationCoordinator
// for testability and single-responsibility compliance.

final class DeviationDetector {

    // MARK: - Configuration

    let deviationThresholdMetres: Double = 200
    let deviationCooldownSeconds: TimeInterval = 60

    // MARK: - State

    private(set) var lastDeviationRecordedAt: Date = .distantPast

    // MARK: - Distance from Route

    /// Returns the perpendicular distance (in metres) from `location`
    /// to the nearest segment of the decoded route polyline.
    func distanceFromRoute(
        location: CLLocationCoordinate2D,
        routeCoords: [CLLocationCoordinate2D]
    ) -> Double {
        guard routeCoords.count >= 2 else { return .greatestFiniteMagnitude }
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<(routeCoords.count - 1) {
            let dist = perpendicularDistance(
                point: location,
                segStart: routeCoords[i],
                segEnd: routeCoords[i + 1]
            )
            if dist < minDist { minDist = dist }
        }
        return minDist
    }

    // MARK: - Cooldown

    /// Returns `true` if the cooldown has elapsed and a new deviation should be recorded.
    func shouldRecordDeviation() -> Bool {
        Date().timeIntervalSince(lastDeviationRecordedAt) > deviationCooldownSeconds
    }

    /// Call after recording a deviation event to reset the cooldown timer.
    func markDeviationRecorded() {
        lastDeviationRecordedAt = Date()
    }

    // MARK: - Private

    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let endLoc   = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)
        let segLength = startLoc.distance(from: endLoc)
        guard segLength > 0 else { return pointLoc.distance(from: startLoc) }
        let dx = endLoc.coordinate.longitude - startLoc.coordinate.longitude
        let dy = endLoc.coordinate.latitude  - startLoc.coordinate.latitude
        let px = point.longitude - startLoc.coordinate.longitude
        let py = point.latitude  - startLoc.coordinate.latitude
        let t = max(0, min(1, (px * dx + py * dy) / (dx * dx + dy * dy)))
        let projLat = segStart.latitude  + t * (segEnd.latitude  - segStart.latitude)
        let projLng = segStart.longitude + t * (segEnd.longitude - segStart.longitude)
        return pointLoc.distance(from: CLLocation(latitude: projLat, longitude: projLng))
    }
}
