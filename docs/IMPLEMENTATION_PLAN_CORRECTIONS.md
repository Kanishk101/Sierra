# Implementation Plan — Corrections & Missing Items

Review of the implementation plan document against the full audit. Apply these
corrections before execution to avoid compile errors and incomplete fixes.

---

## Correction 1 — Fix 3 (AnyCancelable typo) is wrong and will not compile

**What the plan says:**
```swift
Set<MapboxMaps.AnyCancelable>
```

**Why it's wrong:** `MapboxMaps.AnyCancelable` is not a real public type in
the MapboxMaps SDK. Using it will produce a compile error: *"Type
'MapboxMaps.AnyCancelable' has no member 'AnyCancelable'"*.

**Correct fix:**
```swift
import Combine
// ...
private var cancellables = Set<AnyCancellable>()   // Combine's type, double-l
```

The issue in the codebase is a spelling error (`cancelables` / `AnyCancelable`
with single `l`) not a namespace error. Fix both the variable name and the type
to use Combine's `AnyCancellable`.

---

## Correction 2 — Fix 10 (speed limit): the API path is not `.maxSpeed`

**What the plan says:**
> Extract `maxSpeed` from the current `RouteLeg.Step` annotation.

**Why it needs clarification:** There is no `.maxSpeed` property on
`RouteStep` in MapboxDirections v2. The actual API is:

```swift
// On RouteStep:
step.speedLimitUnit          // SpeedLimitUnit? — mph or kph

// On the leg's Attributes (if .speed was requested in attributeOptions):
route.legs[0].segmentMaximumSpeedLimits  // [Measurement<UnitSpeed>?]
// One value per coordinate pair in the leg's shape
```

To assign `currentSpeedLimit` during navigation progress:
```swift
// In updateNavigationProgress(), after finding closestSegIndex:
if let speedLimits = routeEngine.currentRoute?.legs.first?.segmentMaximumSpeedLimits,
   closestSegIndex < speedLimits.count,
   let measurement = speedLimits[closestSegIndex] {
    currentSpeedLimit = Int(measurement.converted(to: .kilometersPerHour).value)
} else {
    currentSpeedLimit = nil
}
```

Also add `.maximumSpeed` to `RouteOptions.attributeOptions` in `RouteEngine.buildRoutes()`:
```swift
options.attributeOptions = [.congestionLevel, .expectedTravelTime, .speed, .maximumSpeed]
```

---

## Correction 3 — Fix 8 (RouteSelectionSheet): avoidance toggles must init from coordinator

**What the plan says:**
> When routes succeed and an alternative exists, set `showRouteSelection = true`.

**What's missing:** `RouteSelectionSheet`'s `avoidTolls`/`avoidHighways` toggles
must initialise from the coordinator's current state, not default to `false`.
Otherwise a re-navigation after the first trip will reset preferences silently.

```swift
// RouteSelectionSheet init should receive initial values:
RouteSelectionSheet(
    coordinator: coordinator,
    initialAvoidTolls: coordinator.avoidTolls,
    initialAvoidHighways: coordinator.avoidHighways
) { startTracking() }
```

Or bind the toggles directly to `coordinator.avoidTolls` / `coordinator.avoidHighways`
rather than local `@State` copies.

---

## Missing Item A — MKMapItem bad initializer (MapService.swift)

Not in the plan. Without this fix the MKDirections fallback crashes.

**File:** `Sierra/Shared/Services/MapService.swift`

```swift
// Replace:
request.source = MKMapItem(
    location: CLLocation(latitude: originLat, longitude: originLng),
    address: nil
)

// With:
request.source = MKMapItem(
    placemark: MKPlacemark(
        coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
    )
)
// Same pattern for request.destination
```

---

## Missing Item B — decodePolyline undefined free function (StartTripSheet.swift)

Not in the plan. The stored-polyline branch in `StartTripSheet` fails to
compile or crashes at runtime because `decodePolyline()` is called as a
free function that doesn't exist.

**File:** `Sierra/Driver/Views/StartTripSheet.swift`

```swift
// Replace:
let decoded = decodePolyline(encoded, precision: 1e6)
    ?? decodePolyline(encoded, precision: 1e5)

// With (requires import Turf at top of file):
import Turf

let coordinates: [CLLocationCoordinate2D]
if let data = try? JSONEncoder().encode(encoded),
   let line = try? JSONDecoder().decode(LineString.self, from: data) {
    coordinates = line.coordinates.map {
        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
    }
} else {
    coordinates = []
}
```

---

## Missing Item C — Route polyline never saved on trip creation (CRITICAL)

Not in the plan. This is the single most impactful missing fix after the
Mapbox token itself.

Every trip is created with `routePolyline: nil` in `CreateTripViewModel.createTrip()`.
This means:
- The stored-polyline fallback in `RouteEngine` always finds nothing
- The stored-polyline fallback in `StartTripSheet` always finds nothing  
- Trips that were created before a token was added can never fall back to a
  stored route — they always hit the full Directions API call

**File:** `Sierra/FleetManager/ViewModels/CreateTripViewModel.swift`

After geocoding origin/destination coordinates and before inserting the trip
into Supabase, fetch and store the route polyline:

```swift
// After originCoords and destCoords are resolved:
var routePolyline: String? = nil
if let origin = originCoords, let dest = destCoords {
    // Use MapService HTTP fetch (not the SDK) so this works without a running
    // CLLocationManager or active coordinator:
    if let routes = try? await MapService.shared.fetchRoutes(
        from: origin,
        to: dest,
        waypoints: stopCoords   // intermediate stop coordinates if any
    ) {
        routePolyline = routes.first?.geometry  // polyline6 encoded string
    }
}
// Pass routePolyline into the Trip struct / Supabase upsert
```

---

## Missing Item D — submitIssue() has no backend call

Not in the plan. The "Report Issue" button in the HUD shows a toast that says
"Issue sent to admin" but never writes to Supabase. Fleet manager receives nothing.

**File:** `Sierra/Driver/Views/NavigationHUDOverlay.swift`

```swift
private func submitIssue() {
    let text = issueText
    issueText = ""
    withAnimation { showIncidentReport = false }
    Task {
        do {
            // Insert into emergency_alerts
            try await SupabaseManager.shared.client
                .from("emergency_alerts")
                .insert([
                    "trip_id": coordinator.trip.id.uuidString,
                    "alert_type": "Incident",
                    "description": text,
                    "latitude": coordinator.currentLocation?.coordinate.latitude as Any,
                    "longitude": coordinator.currentLocation?.coordinate.longitude as Any
                ])
                .execute()
            withAnimation { showIssueSentToast = true }
        } catch {
            // Show error state instead of success toast
        }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { showIssueSentToast = false }
    }
}
```

---

## Missing Item E — DeviationDetector uses flat-earth math

Not in the plan. Low urgency but causes incorrect deviation alerts on diagonal
road segments at India's latitude (~6% aspect ratio distortion).

**File:** `Sierra/Driver/ViewModels/DeviationDetector.swift`

Replace the raw degree-space dot-product with Heron's formula using
`CLLocation.distance(from:)` for all measurements:

```swift
static func perpendicularDistance(
    from point: CLLocationCoordinate2D,
    segStart: CLLocationCoordinate2D,
    segEnd: CLLocationCoordinate2D
) -> CLLocationDistance {
    let pLoc = CLLocation(latitude: point.latitude,    longitude: point.longitude)
    let aLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
    let bLoc = CLLocation(latitude: segEnd.latitude,   longitude: segEnd.longitude)

    let ab = bLoc.distance(from: aLoc)
    guard ab > 0 else { return pLoc.distance(from: aLoc) }

    let ap = pLoc.distance(from: aLoc)
    let bp = pLoc.distance(from: bLoc)

    let s    = (ab + ap + bp) / 2
    let area = sqrt(max(0, s * (s - ab) * (s - ap) * (s - bp)))
    return (2 * area) / ab
}
```

---

## Priority order for missing items

```
C  — Route polyline on trip creation    CRITICAL — affects every trip ever created
A  — MKMapItem initializer              HIGH     — MapService MKDirections fallback crashes
D  — submitIssue() backend call         HIGH     — silent data loss masquerading as a feature  
B  — decodePolyline free function       MEDIUM   — compile/runtime error in fallback path
E  — DeviationDetector geodesic math    LOW      — accuracy improvement, not a crash
```

Items C, A, and D should be added to Phase 4 of the implementation plan
before the plan is executed.
