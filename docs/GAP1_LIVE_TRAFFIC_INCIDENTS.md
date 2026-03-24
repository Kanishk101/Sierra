# Gap 1 — Live Traffic Incident Alerts with Auto-Reroute

> Addendum to `NAV_AUDIT_AND_FIX_ROADMAP.md` — Gap 1 full implementation spec.
>
> This is the Google Maps / Waze equivalent: collisions ahead, road closures, heavy
> congestion, construction — reported by other users or from live traffic feeds —
> surfaced to the driver mid-navigation with the option to reroute automatically.

---

## What Mapbox provides for free

The **Mapbox Traffic Events API** (`/events/v1`) returns live incidents as GeoJSON
features along a corridor: accidents, hazards, congestion zones, road closures,
construction. Each feature carries a type, severity (0–4), description, and
coordinates. This is included in Mapbox's free tier and is the same data source
used by navigation apps globally.

Additionally, `RouteOptions.attributeOptions` already includes `.congestionLevel`
in `RouteEngine.buildRoutes()` — so every route response already carries
per-segment congestion annotations (unknown / low / moderate / heavy / severe).
This data is currently fetched but silently discarded.

---

## Layer A — Congestion colouring on the route line (passive)

In `TripNavigationView.MapCoordinator.ensureLineLayer()`, the route is drawn as a
single solid orange `LineLayer`. Replace this with a data-driven expression that
colours each segment by its congestion level:

```swift
// When building the GeoJSON source for the route, attach congestion
// as a property on each feature:
// route.legs[0].segmentCongestionLevels → [CongestionLevel]
// Map each coordinate pair to a Feature with property "congestion"

// Then use a Mapbox expression on the LineLayer:
let congestionExpression = Exp(.match) {
    Exp(.get) { "congestion" }
    "low";      "#FF6B00"   // orange  — normal
    "moderate"; "#FFD600"   // yellow  — slow
    "heavy";    "#FF3B30"   // red     — heavy
    "severe";   "#8B0000"   // dark red — standstill
    "#FF6B00"               // default
}
lineLayer.lineColor = .expression(congestionExpression)
```

No additional API cost — the congestion data is already in the route response.

---

## Layer B — Incident alert banner + auto-reroute (active)

### New file: `Sierra/Shared/Services/TrafficIncidentService.swift`

```swift
import Foundation
import CoreLocation

// MARK: - TrafficIncident

struct TrafficIncident: Identifiable {
    let id: String
    let type: IncidentType
    let shortDescription: String
    let coordinate: CLLocationCoordinate2D
    let severity: Int   // 0 (unknown) – 4 (critical)

    enum IncidentType {
        case accident, congestion, construction, roadClosed, hazard, other

        var icon: String {
            switch self {
            case .accident:     return "car.2.fill"
            case .congestion:   return "arrow.up.arrow.down"
            case .construction: return "hammer.fill"
            case .roadClosed:   return "exclamationmark.octagon.fill"
            case .hazard:       return "exclamationmark.triangle.fill"
            case .other:        return "info.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .accident:     return "Accident Ahead"
            case .congestion:   return "Heavy Traffic Ahead"
            case .construction: return "Road Works Ahead"
            case .roadClosed:   return "Road Closed Ahead"
            case .hazard:       return "Hazard Ahead"
            case .other:        return "Traffic Alert"
            }
        }
    }
}

// MARK: - TrafficIncidentService

@MainActor
final class TrafficIncidentService {

    static let shared = TrafficIncidentService()

    /// Called on the main actor whenever a new incident is detected ahead.
    var onNewIncident: ((TrafficIncident) -> Void)?

    private var pollTask: Task<Void, Never>?
    private var seenIds: Set<String> = []
    private let lookAheadMetres: Double = 5_000   // 5 km ahead

    func startPolling(routeCoords: [CLLocationCoordinate2D], token: String) {
        stopPolling()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchIncidents(routeCoords: routeCoords, token: token)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        seenIds = []
    }

    // MARK: - Fetch

    private func fetchIncidents(
        routeCoords: [CLLocationCoordinate2D],
        token: String
    ) async {
        guard !routeCoords.isEmpty else { return }
        let lats = routeCoords.map { $0.latitude }
        let lngs = routeCoords.map { $0.longitude }
        // Pad bbox slightly so edge incidents aren't missed
        let bbox = "\(lngs.min()! - 0.01),\(lats.min()! - 0.01),"
               + "\(lngs.max()! + 0.01),\(lats.max()! + 0.01)"

        let urlStr = "https://events.mapbox.com/traffic-events/v1"
                   + "?access_token=\(token)&bbox=\(bbox)&language=en"
        guard let url = URL(string: urlStr) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else { return }

        for feature in features {
            guard
                let props    = feature["properties"] as? [String: Any],
                let id       = props["id"] as? String,
                !seenIds.contains(id),
                let geometry = feature["geometry"]   as? [String: Any],
                let coords   = geometry["coordinates"] as? [Double],
                coords.count >= 2
            else { continue }

            let coord = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
            guard isAheadOnRoute(coord, routeCoords: routeCoords) else { continue }

            seenIds.insert(id)
            let incident = TrafficIncident(
                id: id,
                type: parseType(props),
                shortDescription: props["description"] as? String ?? "Traffic incident ahead",
                coordinate: coord,
                severity: props["congestion_numeric"] as? Int ?? 0
            )
            onNewIncident?(incident)
        }
    }

    // MARK: - Helpers

    private func isAheadOnRoute(
        _ coord: CLLocationCoordinate2D,
        routeCoords: [CLLocationCoordinate2D]
    ) -> Bool {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return routeCoords.contains {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: loc) < lookAheadMetres
        }
    }

    private func parseType(_ props: [String: Any]) -> TrafficIncident.IncidentType {
        let t = ((props["type"] as? String) ?? "").lowercased()
        if t.contains("accident") || t.contains("collision") { return .accident }
        if t.contains("congestion") || t.contains("traffic")  { return .congestion }
        if t.contains("construction") || t.contains("works")  { return .construction }
        if t.contains("closed") || t.contains("closure")      { return .roadClosed }
        if t.contains("hazard")                                { return .hazard }
        return .other
    }
}
```

---

## Wiring into TripNavigationCoordinator

Add these properties and methods to `TripNavigationCoordinator`:

```swift
// New published state
var activeTrafficIncident: TrafficIncident? = nil
var showingIncidentBanner: Bool = false

// Call this from startLocationTracking(), AFTER route coords are populated:
func startTrafficMonitoring() {
    guard let token = MapService.accessToken else { return }
    let coords = routeEngine.decodedRouteCoordinates
    guard coords.count >= 2 else { return }

    TrafficIncidentService.shared.onNewIncident = { [weak self] incident in
        guard let self else { return }
        self.activeTrafficIncident = incident
        self.showingIncidentBanner = true
        // Voice announce
        VoiceNavigationService.shared.announce(incident.type.label)
        // Auto-reroute for high-severity events
        if incident.severity >= 3 || incident.type == .roadClosed {
            self.triggerIncidentReroute()
        }
    }
    TrafficIncidentService.shared.startPolling(routeCoords: coords, token: token)
}

func triggerIncidentReroute() {
    routeEngine.triggerRerouteFromCurrentLocation()
    Task { await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation) }
}

func dismissIncidentBanner() {
    showingIncidentBanner = false
    activeTrafficIncident = nil
}

// Add to stopLocationPublishing():
// TrafficIncidentService.shared.stopPolling()
```

---

## HUD banner in NavigationHUDOverlay

Insert between the instruction banner and the deviation banner:

```swift
// In NavigationHUDOverlay.body, inside VStack, after instructionBanner:
if coordinator.showingIncidentBanner, let incident = coordinator.activeTrafficIncident {
    incidentAlertBanner(incident)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35), value: coordinator.showingIncidentBanner)
}

// New sub-view:
private func incidentAlertBanner(_ incident: TrafficIncident) -> some View {
    HStack(spacing: 12) {
        Image(systemName: incident.type.icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.red.opacity(0.85)))

        VStack(alignment: .leading, spacing: 2) {
            Text(incident.type.label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(incident.shortDescription)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }

        Spacer()

        VStack(spacing: 4) {
            Button("Reroute") {
                coordinator.triggerIncidentReroute()
                coordinator.dismissIncidentBanner()
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.red))

            Button("Dismiss") { coordinator.dismissIncidentBanner() }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    .padding(14)
    .background(
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.18, green: 0.05, blue: 0.05).opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
            )
    )
    .padding(.horizontal, 16)
}
```

---

## Behaviour table

| Situation | What happens |
|-----------|--------------|
| Moderate congestion (severity 1–2) | Banner shown, voice announces type. Driver taps Reroute or Dismiss. No auto-reroute. |
| Heavy congestion or accident (severity 3–4) | Banner shown **and** auto-reroute triggered immediately. |
| Road closed | Banner shown **and** auto-reroute triggered. Voice: "Road Closed Ahead". |
| Driver taps Reroute | `triggerIncidentReroute()` — route rebuilt from current position. |
| Driver taps Dismiss | Banner hidden. Incident ID remembered so same event doesn't re-surface. |
| Navigation ends | `TrafficIncidentService.shared.stopPolling()` in `stopLocationPublishing()`. |

---

## Files touched

| File | Change |
|------|--------|
| `Sierra/Shared/Services/TrafficIncidentService.swift` | **New file** — incident model + polling service |
| `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` | Add `activeTrafficIncident`, `showingIncidentBanner`, `startTrafficMonitoring()`, `triggerIncidentReroute()`, `dismissIncidentBanner()`. Call `startTrafficMonitoring()` from `startLocationTracking()`. Add `TrafficIncidentService.shared.stopPolling()` to `stopLocationPublishing()`. |
| `Sierra/Driver/Views/NavigationHUDOverlay.swift` | Add `incidentAlertBanner(_:)` view. Insert it in `body` between instruction banner and deviation banner. |
| `Sierra/Driver/Views/TripNavigationView.swift` | Replace solid orange `LineLayer` with congestion-colour data-driven expression (Layer A). |

---

## API cost

The Mapbox Traffic Events API is billed under **Map Loads**, not Directions API calls.
At 1 request/minute during a 2-hour trip that is 120 requests per trip — well within
the 50,000 free monthly map load events on Mapbox's free tier.
