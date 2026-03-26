import Foundation
import CoreLocation

/// Shared geofence scoping + normalization logic used by admin and driver maps.
enum GeofenceScopeService {

    static func normalizedLatitude(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }

    static func normalizedLongitude(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }

    static func normalizedRadiusMeters(_ value: Double) -> Double {
        min(5_000, max(100, value))
    }

    static func tripToken(in text: String) -> String? {
        let lower = text.lowercased()
        guard let range = lower.range(of: #"trip\s+([a-z0-9-]+)"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(lower[range])
        return matched.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func matchesTrip(_ geofence: Geofence, taskId: String) -> Bool {
        let token = "trip \(taskId.lowercased())"
        let haystacks = [geofence.name, geofence.description].map { $0.lowercased() }
        return haystacks.contains { $0.contains(token) }
    }

    static func anchorCoordinates(for trip: Trip) -> [CLLocationCoordinate2D] {
        var anchors: [CLLocationCoordinate2D] = []
        if let lat = trip.originLatitude, let lng = trip.originLongitude {
            anchors.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        for stop in (trip.routeStops ?? []).sorted(by: { $0.order < $1.order }) {
            anchors.append(CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
        }
        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
            anchors.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return anchors
    }

    static func geofencesNearAnchors(
        _ geofences: [Geofence],
        anchors: [CLLocationCoordinate2D],
        extraPaddingMeters: Double = 120
    ) -> [Geofence] {
        guard !anchors.isEmpty else { return [] }
        return geofences.filter { geofence in
            let center = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
            return anchors.contains { anchor in
                let point = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
                let threshold = max(geofence.radiusMeters, extraPaddingMeters)
                return center.distance(from: point) <= threshold
            }
        }
    }

    /// Collapses near-identical circles into one representative so map overlays stay readable.
    static func collapseOverlappingCenters(
        _ geofences: [Geofence],
        centerToleranceMeters: Double = 35
    ) -> [Geofence] {
        guard geofences.count > 1 else { return geofences }

        let sorted = geofences.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var selected: [Geofence] = []
        for candidate in sorted {
            let candidateLocation = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
            let overlapsExisting = selected.contains { existing in
                let existingLocation = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                return candidateLocation.distance(from: existingLocation) <= centerToleranceMeters
            }
            if !overlapsExisting {
                selected.append(candidate)
            }
        }

        return selected.sorted {
            if $0.geofenceType.rawValue != $1.geofenceType.rawValue {
                return $0.geofenceType.rawValue < $1.geofenceType.rawValue
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
