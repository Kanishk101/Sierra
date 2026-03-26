import Foundation
import CoreLocation

// MARK: - DeviationDetector
// Pure computation class — no @Observable needed.
// Extracts route-deviation math from TripNavigationCoordinator
// for testability and single-responsibility compliance.

final class DeviationDetector {

    // MARK: - Configuration

    let deviationThresholdMetres: Double = 120
    let recoveryThresholdMetres: Double = 80
    let deviationRecordIntervalSeconds: TimeInterval = 20
    let minMovementForFollowupRecordMetres: Double = 18
    let minDistanceDeltaForFollowupRecordMetres: Double = 14

    enum Transition {
        case enteredDeviation
        case exitedDeviation
        case stayingOffRoute
        case stayingOnRoute
    }

    // MARK: - State

    private(set) var isDeviationActive: Bool = false
    private(set) var lastDeviationRecordedAt: Date = .distantPast
    private(set) var lastDeviationRecordedCoordinate: CLLocationCoordinate2D?
    private(set) var lastDeviationRecordedDistanceMetres: Double = 0

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

    func transition(for deviationMetres: Double) -> Transition {
        if isDeviationActive {
            if deviationMetres <= recoveryThresholdMetres {
                isDeviationActive = false
                return .exitedDeviation
            }
            return .stayingOffRoute
        }

        if deviationMetres > deviationThresholdMetres {
            isDeviationActive = true
            return .enteredDeviation
        }
        return .stayingOnRoute
    }

    func shouldRecordFollowupSample(
        at coordinate: CLLocationCoordinate2D,
        deviationMetres: Double,
        now: Date = Date()
    ) -> Bool {
        guard isDeviationActive else { return false }
        guard now.timeIntervalSince(lastDeviationRecordedAt) >= deviationRecordIntervalSeconds else { return false }

        guard let lastCoordinate = lastDeviationRecordedCoordinate else { return true }

        let moved = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude))
        let deviationDelta = abs(deviationMetres - lastDeviationRecordedDistanceMetres)

        return moved >= minMovementForFollowupRecordMetres
            || deviationDelta >= minDistanceDeltaForFollowupRecordMetres
    }

    /// Call after recording a deviation event sample.
    func markDeviationRecorded(
        at coordinate: CLLocationCoordinate2D,
        deviationMetres: Double,
        now: Date = Date()
    ) {
        lastDeviationRecordedAt = now
        lastDeviationRecordedCoordinate = coordinate
        lastDeviationRecordedDistanceMetres = deviationMetres
    }

    // MARK: - Private

    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> Double {
        let pLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let aLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let bLoc = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)

        let ab = bLoc.distance(from: aLoc)
        guard ab > 0 else { return pLoc.distance(from: aLoc) }

        let ap = pLoc.distance(from: aLoc)
        let bp = pLoc.distance(from: bLoc)

        // Heron's formula for geodesic perpendicular distance
        let s = (ab + ap + bp) / 2
        let area = sqrt(max(0, s * (s - ab) * (s - ap) * (s - bp)))
        return (2 * area) / ab
    }
}
