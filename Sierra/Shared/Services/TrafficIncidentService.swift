import Foundation
import CoreLocation
import MapboxDirections

// MARK: - TrafficIncidentService
// GAP-1: Polls Mapbox Incidents API v3 for active incidents near the current route.
// Exposes published incidents consumed by TripNavigationCoordinator and NavigationHUDOverlay.

@MainActor
@Observable
final class TrafficIncidentService {

    // MARK: - Published State
    var activeIncidents: [TrafficIncident] = []
    var nearestIncident: TrafficIncident? {
        activeIncidents
            .sorted { ($0.distanceAheadMetres ?? .greatestFiniteMagnitude) < ($1.distanceAheadMetres ?? .greatestFiniteMagnitude) }
            .first
    }

    // MARK: - Private
    private var pollTimer: Timer?
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var currentLocation: CLLocation?
    private var isFetching = false

    // MARK: - Lifecycle

    func startPolling(routeCoordinates: [CLLocationCoordinate2D]) {
        self.routeCoordinates = routeCoordinates
        stopPolling()

        // Initial fetch
        Task { await fetchIncidents() }

        // Periodic poll
        pollTimer = Timer.scheduledTimer(withTimeInterval: TripConstants.incidentPollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchIncidents()
            }
        }
    }

    func updateLocation(_ location: CLLocation) {
        currentLocation = location
    }

    func updateRoute(_ coordinates: [CLLocationCoordinate2D]) {
        routeCoordinates = coordinates
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        activeIncidents = []
    }

    // MARK: - Fetch

    private func fetchIncidents() async {
        guard !routeCoordinates.isEmpty, !isFetching else { return }
        guard let token = MapService.accessToken else { return }

        isFetching = true
        defer { isFetching = false }

        // Compute bounding box from route + buffer
        let bufferDeg = TripConstants.incidentBufferKm / 111.0  // rough km→deg
        let lats = routeCoordinates.map(\.latitude)
        let lngs = routeCoordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }

        let bbox = "\(minLng - bufferDeg),\(minLat - bufferDeg),\(maxLng + bufferDeg),\(maxLat + bufferDeg)"

        let urlString = "https://api.mapbox.com/incidents/v1/mapbox/traffic/\(bbox)?access_token=\(token)"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]] ?? []

            var incidents: [TrafficIncident] = []
            for feature in features {
                guard let properties = feature["properties"] as? [String: Any],
                      let geometry = feature["geometry"] as? [String: Any],
                      let coordinate = extractCoordinate(from: geometry) else { continue }

                let id = properties["id"] as? String ?? UUID().uuidString
                let desc = properties["description"] as? String ?? "Traffic incident"
                let severity = parseSeverity(from: properties["severity"])
                let roadName = properties["street"] as? String

                var incident = TrafficIncident(
                    id: id, description: desc, severity: severity,
                    coordinate: coordinate, roadName: roadName,
                    startTime: nil, endTime: nil
                )

                // Compute distance ahead on route
                if let loc = currentLocation {
                    incident.distanceAheadMetres = distanceAlongRoute(
                        from: loc.coordinate, to: coordinate.clCoordinate
                    )
                }

                incidents.append(incident)
            }

            activeIncidents = incidents
                .sorted { ($0.distanceAheadMetres ?? .greatestFiniteMagnitude) < ($1.distanceAheadMetres ?? .greatestFiniteMagnitude) }
        } catch {
            print("[TrafficIncidentService] Fetch failed: \(error)")
        }
    }

    // MARK: - Helpers

    /// Approximate distance along the route from one coordinate to another.
    private func distanceAlongRoute(
        from origin: CLLocationCoordinate2D, to target: CLLocationCoordinate2D
    ) -> Double? {
        guard routeCoordinates.count >= 2 else { return nil }

        let originLoc = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)

        // Find closest segment to origin
        var minDistOrigin = Double.greatestFiniteMagnitude
        var originSegIdx = 0
        for i in 0..<routeCoordinates.count {
            let seg = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let d = originLoc.distance(from: seg)
            if d < minDistOrigin { minDistOrigin = d; originSegIdx = i }
        }

        // Find closest segment to target
        var minDistTarget = Double.greatestFiniteMagnitude
        var targetSegIdx = 0
        for i in 0..<routeCoordinates.count {
            let seg = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let d = targetLoc.distance(from: seg)
            if d < minDistTarget { minDistTarget = d; targetSegIdx = i }
        }

        // Target behind us on route
        guard targetSegIdx > originSegIdx else { return nil }

        // Sum route segments
        var dist: Double = 0
        for i in originSegIdx..<targetSegIdx {
            let a = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let b = CLLocation(latitude: routeCoordinates[i + 1].latitude, longitude: routeCoordinates[i + 1].longitude)
            dist += a.distance(from: b)
        }
        return dist
    }

    /// Whether there's a severe/critical incident within auto-reroute proximity.
    func hasSevereIncidentNearby(thresholdMetres: Double = TripConstants.autoRerouteProximityMetres) -> Bool {
        activeIncidents.contains { incident in
            incident.severity >= .major &&
            (incident.distanceAheadMetres ?? .greatestFiniteMagnitude) < thresholdMetres
        }
    }

    private func extractCoordinate(from geometry: [String: Any]) -> TrafficIncident.IncidentCoordinate? {
        if let coords = geometry["coordinates"] as? [Double], coords.count >= 2 {
            return TrafficIncident.IncidentCoordinate(latitude: coords[1], longitude: coords[0])
        }
        if let segments = geometry["coordinates"] as? [[Double]],
           let first = segments.first,
           first.count >= 2 {
            return TrafficIncident.IncidentCoordinate(latitude: first[1], longitude: first[0])
        }
        return nil
    }

    private func parseSeverity(from raw: Any?) -> TrafficIncident.IncidentSeverity {
        if let severityString = raw as? String {
            switch severityString.lowercased() {
            case "critical", "severe":
                return .critical
            case "major", "serious":
                return .major
            case "moderate", "medium":
                return .moderate
            default:
                return .minor
            }
        }
        if let severityInt = raw as? Int {
            switch severityInt {
            case 4...: return .critical
            case 3:    return .major
            case 2:    return .moderate
            default:   return .minor
            }
        }
        if let severityDouble = raw as? Double {
            return parseSeverity(from: Int(severityDouble.rounded()))
        }
        return .minor
    }
}
