# Fix E — TripNavigationCoordinator Decomposition 🟡 MEDIUM

**Audit ID:** H-18  
**Priority:** Medium — compiles and works, but violates SRP and is hard to test/modify safely

---

## The Problem

`TripNavigationCoordinator.swift` is 19.7KB and handles six distinct responsibilities in one class:

1. Route building (Mapbox SDK, waypoints, alternatives)
2. Route selection (green route swap, avoidance preferences)
3. Location tracking (CLLocationManager, background, permissions)
4. Navigation progress (step tracking, voice, ETA, arrival detection)
5. Deviation detection (perpendicular distance math, rerouting)
6. Geofence monitoring (CLRegion registration, entry/exit, notification insert)

This makes it untestable (can't test deviation math without a full CLLocationManager), fragile (changes to geofence logic risk breaking route building), and hard to reason about.

---

## Target Architecture

```
TripNavigationCoordinator (orchestrator, ~6KB)
├── RouteEngine (route fetch + selection, ~5KB)
├── DeviationDetector (pure math, ~2KB)
└── GeofenceMonitor (CLRegion + notifications, ~4KB)
```

All public properties and methods on `TripNavigationCoordinator` stay identical — Views must compile unchanged.

---

## Tasks

### Task 1 — Create `RouteEngine.swift`

Create `Sierra/Driver/ViewModels/RouteEngine.swift`:

**Extract into this file:**
- `buildRoutes() async` — full Mapbox SDK route fetch logic
- `selectGreenRoute()` — swap currentRoute/alternativeRoute
- `rebuildRoutes() async` — reset flag + rebuild
- `addStop(latitude:longitude:name:) async`
- All private route-building helpers: `intermediateWaypoints`, `rerouteFromCurrentLocation`, `hasBuiltRoutes`
- `decodedRouteCoordinates` (shared between RouteEngine and DeviationDetector — expose as a property)

**Type:** `@Observable final class RouteEngine`

**Interface:**
```swift
@Observable
final class RouteEngine {
    var currentRoute: MapboxDirections.Route?
    var alternativeRoute: MapboxDirections.Route?
    var currentStepInstruction: String = ""
    var distanceRemainingMetres: Double = 0
    var estimatedArrivalTime: Date?
    var hasBuiltRoutes: Bool = false
    var hasDeviated: Bool = false
    private(set) var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    var avoidTolls: Bool = false
    var avoidHighways: Bool = false

    func buildRoutes(trip: Trip, currentLocation: CLLocation?) async
    func selectGreenRoute()
    func rebuildRoutes(trip: Trip, currentLocation: CLLocation?) async
    func addStop(latitude: Double, longitude: Double, name: String, trip: Trip) async
    func triggerRerouteFromCurrentLocation()
}
```

---

### Task 2 — Create `DeviationDetector.swift`

Create `Sierra/Driver/ViewModels/DeviationDetector.swift`:

**Extract into this file:**
- `computeMinDistanceToRoute(location:routeCoords:) -> Double`
- `perpendicularDistance(point:segStart:segEnd:) -> Double`
- `lastDeviationRecordedAt` state
- `deviationCooldownSeconds` constant
- The deviation threshold constant (200m)

**Type:** `final class DeviationDetector` (no `@Observable` needed — pure computation)

**Interface:**
```swift
final class DeviationDetector {
    private(set) var lastDeviationRecordedAt: Date = .distantPast
    let deviationThresholdMetres: Double = 200
    let deviationCooldownSeconds: TimeInterval = 60

    // Returns deviation in metres from the nearest route segment
    func distanceFromRoute(
        location: CLLocationCoordinate2D,
        routeCoords: [CLLocationCoordinate2D]
    ) -> Double

    // Returns true if cooldown has elapsed and deviation should be recorded
    func shouldRecordDeviation() -> Bool

    // Call after recording a deviation to reset the cooldown
    func markDeviationRecorded()
}
```

---

### Task 3 — Create `GeofenceMonitor.swift`

Create `Sierra/Driver/ViewModels/GeofenceMonitor.swift`:

**Extract into this file:**
- `registerGeofences(_ geofences: [Geofence])` — all CLRegion setup
- `handleGeofenceEvent(geofenceId:eventType:vehicleIdStr:tripId:currentLocation:) async` — notification insert + GeofenceEventService call
- `locationManager(_:didEnterRegion:)` and `locationManager(_:didExitRegion:)` delegates

**Type:** `@MainActor final class GeofenceMonitor: NSObject, CLLocationManagerDelegate`

Note: Only the geofence-related delegate methods move here. The location update delegate stays in the coordinator (since it drives navigation progress).

**Interface:**
```swift
@MainActor
final class GeofenceMonitor: NSObject {
    func register(_ geofences: [Geofence], locationManager: CLLocationManager, currentLocation: CLLocation?)
    func stopMonitoring(locationManager: CLLocationManager)
}
```

---

### Task 4 — Refactor `TripNavigationCoordinator.swift`

Keep the coordinator as the orchestrator:

```swift
@MainActor
@Observable
final class TripNavigationCoordinator: NSObject, CLLocationManagerDelegate {

    // Sub-components
    private let routeEngine = RouteEngine()
    private let deviationDetector = DeviationDetector()
    private let geofenceMonitor = GeofenceMonitor()

    // Forward public properties from routeEngine
    var currentRoute: MapboxDirections.Route? { routeEngine.currentRoute }
    var alternativeRoute: MapboxDirections.Route? { routeEngine.alternativeRoute }
    var currentStepInstruction: String { routeEngine.currentStepInstruction }
    var distanceRemainingMetres: Double { routeEngine.distanceRemainingMetres }
    var estimatedArrivalTime: Date? { routeEngine.estimatedArrivalTime }
    var hasDeviated: Bool { routeEngine.hasDeviated }

    // Coordinator-owned state
    var isNavigating: Bool = false
    var currentSpeedKmh: Double = 0
    var hasArrived: Bool = false
    var currentSpeedLimit: Int?
    var currentStepManeuver: String = ""
    var nextStepInstruction: String = ""
    var avoidTolls: Bool {
        get { routeEngine.avoidTolls }
        set { routeEngine.avoidTolls = newValue }
    }
    var avoidHighways: Bool {
        get { routeEngine.avoidHighways }
        set { routeEngine.avoidHighways = newValue }
    }
    let trip: Trip
    private(set) var currentLocation: CLLocation?
    private var locationManager: CLLocationManager?
    private var locationPublishTimer: Timer?
    private let locationPublishInterval: TimeInterval = 5.0
    private var currentStepIndex: Int = 0

    // Delegate to sub-components
    func buildRoutes() async { await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation) }
    func selectGreenRoute() { routeEngine.selectGreenRoute() }
    func rebuildRoutes() async { await routeEngine.rebuildRoutes(trip: trip, currentLocation: currentLocation) }
    func addStop(latitude: Double, longitude: Double, name: String) async {
        await routeEngine.addStop(latitude: latitude, longitude: longitude, name: name, trip: trip)
    }

    // ... location tracking, navigation progress, publish timer stay here
}
```

---

### Task 5 — Verify Views compile unchanged

After the refactor, confirm these files compile without modification:
- `TripNavigationContainerView.swift`
- `NavigationHUDOverlay.swift`
- `RouteSelectionSheet.swift`
- Any other file that references `TripNavigationCoordinator`

All public property accesses and method calls on the coordinator must continue to work identically.

---

## Target File Sizes

| File | Target |
|---|---|
| `TripNavigationCoordinator.swift` | < 8KB |
| `RouteEngine.swift` | < 6KB |
| `DeviationDetector.swift` | < 2.5KB |
| `GeofenceMonitor.swift` | < 5KB |

---

## Acceptance Criteria

- All four files exist at the target paths
- `TripNavigationCoordinator.swift` is under 8KB
- `TripNavigationContainerView.swift`, `NavigationHUDOverlay.swift`, and `RouteSelectionSheet.swift` compile without changes
- Route building, deviation detection, geofence monitoring, and voice navigation all still work at runtime
- `DeviationDetector.distanceFromRoute` is a pure function (no side effects) and could be unit tested without a CLLocationManager
