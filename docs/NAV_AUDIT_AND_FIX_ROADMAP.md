# Sierra — Navigation Audit & Complete Fix Roadmap

This document synthesises the three-round audit (Issues 1–25 from Prompt 1, root-cause diagnosis from Prompt 2, Codex review, and live repo inspection) into a single actionable source of truth. Nothing has been omitted.

---

## Part 1 — Strategic Question: Switch to MapboxNavigation SDK or Fix Custom?

### The short answer: Stay custom. Fix the bugs.

Here is the honest case for both sides.

**Why switching to `NavigationViewController` sounds attractive:**
- Built-in road snapping (map matching), step advancement, voice, rerouting, speed limits, lane guidance, incident banners — all free with `MapboxNavigationCore`.
- Would auto-fix Issues 3, 4, 8, 17 from the audit (step detection, deviation math, permissions re-engagement, recenter button).

**Why switching is the wrong call for Sierra specifically:**

1. **SRS requirements changed.** Drivers do not choose destinations — admin assigns trips. `NavigationViewController` is designed for user-initiated nav (the user types where they want to go). It is opinionated about the UX flow around that. Sierra's flow is: load admin-assigned trip → build route from stored coordinates → follow it. A custom coordinator wired to `MapboxDirections` is architecturally *more correct* for this model, not less.

2. **Sierra's HUD is fleet-specific.** SOS alert, incident report → Supabase, geofence monitoring, deviation recording, POD trigger, Supabase real-time publishing — none of this exists in `NavigationViewController`'s delegate surface. Integrating it would require more custom wiring than fixing the current code.

3. **Every current bug is a fixable bug, not an architectural failure.** The coordinator/engine/detector decomposition is sound. The issues are: empty token, one missing `= true` assignment, wrong initializer, duplicate synthesizer, missing backend calls, and flat-earth math. These are implementation defects, not design defects.

4. **Binary size and startup.** `MapboxNavigationCore` adds ~40MB and a significant cold-start penalty. `MapboxMaps` + `MapboxDirections` (already present) is substantially lighter.

5. **`MapboxNavigationCore` is already imported and doing nothing.** Remove it.

**Recommendation:** Remove `MapboxNavigationCore` from SPM dependencies. Fix the 14 ordered items in Part 3 below. Implement the 5 SRS gaps in Part 4. The result will be a fully functional fleet nav stack that meets every SRS requirement without the constraints of `NavigationViewController`.

---

## Part 2 — Complete Bug Inventory (all 25 issues + root causes)

### Root Causes (kill first — these cascade into everything)

| # | Bug | File | What it breaks |
|---|-----|------|----------------|
| RC-0 | **Mapbox token empty string in Info.plist** | `Sierra/Info.plist` | Everything. No map tiles, no Directions call, no geocoding, no address search, no polyline, no voice, no steps. Single most impactful fix in the entire codebase. |
| RC-1 | `Directions.shared.accessToken` never assigned | `RouteEngine.swift` | SDK ignores `Info.plist` entry in some init paths; explicit assignment is required. |
| RC-2 | `showRouteSelection` never set to `true` | `TripNavigationContainerView.swift` | Route selection sheet is dead code. Driver always auto-starts. Toll/highway preferences never applied. |
| RC-3 | `routePolyline: nil` on every created trip | `CreateTripViewModel.swift` | Stored-polyline fallback always empty. No polyline even if token is fixed later. |
| RC-4 | Wrong `MKMapItem(location:address:)` initializer | `MapService.swift` | MKDirections fallback path doesn't compile / crashes. No-token fallback is broken. |
| RC-5 | `decodePolyline()` called as free function, undefined | `StartTripSheet.swift` | Stored-polyline branch in StartTripSheet fails at compile or runtime. |

### Navigation Logic Bugs

| # | Bug | File | Impact |
|---|-----|------|--------|
| I-1 | Duplicate `AVSpeechSynthesizer` — double voice + broken mute | `TripNavigationContainerView.swift`, `VoiceNavigationService.swift` | Every instruction spoken twice; mute button only silences one synthesizer. |
| I-3 | Step detection uses first-coord 100m proximity, not route progress | `TripNavigationCoordinator.swift` | Instructions update too late on highways; wrong step on complex geometry. |
| I-4 | Remaining distance/ETA overestimated (segment-start, not projected point) | `TripNavigationCoordinator.swift` | ETA always pessimistic; distance remaining inflated. |
| I-8 | No `locationManagerDidChangeAuthorization` handler | `TripNavigationCoordinator.swift` | Geofences never register if permission granted after app launch. |
| I-9 | Flat-earth (degree-space) dot-product in `DeviationDetector` | `DeviationDetector.swift` | Deviation distance slightly wrong on diagonal segments; false alerts on sweeping curves. |
| I-12 | Reroute triggers double route build | `TripNavigationCoordinator.swift` | Route flickers twice on reroute. |
| I-17 | No recenter button after manual map pan | `TripNavigationView.swift` | Driver must exit/re-enter navigation to re-follow puck. |
| I-19 | Geofence registration uses India-centroid fallback when GPS cold | `GeofenceMonitor.swift` | Wrong 20 geofences registered; correct ones never fire. |
| I-25 | Double 5-second throttle on location publish (timer + internal check) | `TripNavigationCoordinator.swift`, `VehicleLocationService.swift` | Effective publish rate degrades to 10s due to jitter. |

### Data & Backend Bugs

| # | Bug | File | Impact |
|---|-----|------|--------|
| I-11 | `FleetLiveMapView` not subscribed to Supabase Realtime | `FleetLiveMapView.swift` | Admin fleet map shows launch-time positions; vehicles appear frozen. |
| I-23 | `submitIssue()` in HUD discards report, shows fake toast | `NavigationHUDOverlay.swift` | Incident reports silently lost. Fleet manager receives nothing. |
| I-24 | `currentSpeedLimit` always `nil`, never assigned | `TripNavigationCoordinator.swift` | Speed limit sign in HUD never renders. |

### Architecture & Dead Code

| # | Issue | File | Impact |
|---|-------|------|--------|
| I-2 | `MapboxNavigationCore` imported, zero symbols used | `TripNavigationView.swift` | ~40MB dead binary weight; misleads developers. |
| I-5 | Two parallel route type systems (`MapService.MapRoute` + `MapboxDirections.Route`) | `MapService.swift`, `RouteEngine.swift` | Bug fixes in one not reflected in other; dead code. |
| I-6 | `RouteSelectionSheet` dead code (see RC-2) | `TripNavigationContainerView.swift` | — |
| I-7 | "Green Route" label fabricated — shortest ≠ lowest fuel | `RouteSelectionSheet.swift` | Misleading UI claim. |
| I-10 | `AVAudioSession` not configured — no audio ducking | `VoiceNavigationService.swift` | Nav voice competes with music at equal volume; inaudible. |
| I-13 | `cancelables` typo (`AnyCancelable` vs `AnyCancellable`) | `TripNavigationView.swift` | Compile-time or type mismatch error. |
| I-14 | Mapbox geocoding URL uses legacy v5 endpoint, no token sanitization | `CreateGeofenceSheet.swift` | Worse geocoding results; broken URL on whitespace token. |
| I-15 | `CreateTripView` route preview has no polyline | `CreateTripView.swift` | Admin sees pins only, no route path. |
| I-16 | `MKMapItem(location:address:)` bad init (see RC-4) | `MapService.swift` | — |
| I-18 | Congestion data requested but rendered as solid color | `RouteEngine.swift`, `TripNavigationView.swift` | Traffic-colored route line never shown despite API cost. |
| I-20 | No offline tile/route caching | `RouteEngine.swift` | Blank map + no route in low-connectivity areas. |
| I-21 | `MapboxDirections.decodePolyline` may not be public API | `RouteEngine.swift` | Stored-polyline fallback may fail to compile. |
| I-22 | `Polyline` type in `MapService` may be unimported | `MapService.swift` | MapKit fallback encode step fails. |

---

## Part 3 — Ordered Fix List (do in this sequence)

### Fix 1 — Populate Mapbox token (manual step — you must do this)

```
Sierra/Info.plist
  MBXAccessToken  →  <your-mapbox-public-token>
  MGLMapboxAccessToken  →  <your-mapbox-public-token>
```

Get the token from mapbox.com → Account → Access Tokens. Use the **public** token (starts with `pk.`). This single change unblocks: map tiles, Directions API, geocoding in AddressSearchSheet and CreateGeofenceSheet, voice, steps, polyline. Everything else below assumes this is done.

---

### Fix 2 — Wire `Directions.shared.accessToken` explicitly

In `RouteEngine.swift`, at the top of `buildRoutes()` or in `init`:

```swift
// At init or before first buildRoutes call:
if let token = MapService.accessToken {
    Directions.shared.credentials = Credentials(accessToken: token)
}
```

This ensures the SDK uses your token even if the global credentials manager has a different initialization order.

---

### Fix 3 — Present RouteSelectionSheet after successful build

In `TripNavigationContainerView.buildAndShowRoutes()`:

```swift
// Replace:
if coordinator.hasRenderableRoute {
    startTracking()
}

// With:
if coordinator.hasRenderableRoute {
    showRouteSelection = true  // ← this one line was missing
}
```

The `RouteSelectionSheet` already has all the UI (Fastest/Green cards, toll/highway toggles, ETA display). It was built but never reachable. This one assignment fixes it.

---

### Fix 4 — Remove duplicate AVSpeechSynthesizer

In `TripNavigationContainerView.swift`:

1. Delete `private let speechSynthesizer = AVSpeechSynthesizer()`
2. Delete the entire `.onChange(of: coordinator.currentStepInstruction)` block — `VoiceNavigationService.shared` already handles this in the coordinator.
3. In `dismissView()`, replace `speechSynthesizer.stopSpeaking(at: .immediate)` with `VoiceNavigationService.shared.stopSpeaking()`
4. Add a `stopSpeaking()` method to `VoiceNavigationService` if not present:
```swift
func stopSpeaking() { synthesizer.stopSpeaking(at: .immediate) }
```

This also makes the mute button work — it gates `VoiceNavigationService.shared`, and that's now the only synthesizer.

---

### Fix 5 — Fix MKMapItem initializer

In `MapService.fetchRoutesWithMapKit()`:

```swift
// Replace:
request.source = MKMapItem(location: CLLocation(latitude: originLat, longitude: originLng), address: nil)
request.destination = MKMapItem(location: CLLocation(latitude: destLat, longitude: destLng), address: nil)

// With:
request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng)))
request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng)))
```

---

### Fix 6 — Fix decodePolyline in StartTripSheet

Replace the undefined `decodePolyline()` call with Turf:

```swift
// Replace:
let decoded: [CLLocationCoordinate2D]? = decodePolyline(encoded, precision: 1e6)
    ?? decodePolyline(encoded, precision: 1e5)

// With:
import Turf
// ...
let coordinates: [CLLocationCoordinate2D]
if let line = try? JSONDecoder().decode(LineString.self,
    from: Data(("\"" + encoded + "\"").utf8)) {
    coordinates = line.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
} else {
    coordinates = []
}
```

Or use `MapboxDirections`'s internal decoder via the route object geometry. The safest approach: store and decode as `[CLLocationCoordinate2D]` in JSON directly rather than polyline6.

---

### Fix 7 — Save route polyline during trip creation

In `CreateTripViewModel.createTrip()`, after computing origin/destination coordinates, call `MapService.fetchRoutes()` and save the resulting polyline into the `Trip` struct before upserting to Supabase:

```swift
var polyline: String? = nil
if let originCoord = originCoords, let destCoord = destCoords {
    let routes = try? await MapService.shared.fetchRoutes(
        from: originCoord, to: destCoord, waypoints: stopCoords)
    polyline = routes?.first?.geometry  // fastest route polyline6
}
// then pass routePolyline: polyline when building Trip
```

This ensures every trip has a stored polyline from the moment of creation, making the fallback chain functional.

---

### Fix 8 — Implement locationManagerDidChangeAuthorization

In `TripNavigationCoordinator`, add:

```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways:
        // Re-register geofences now that Always permission is confirmed
        if let trip = self.trip {
            geofenceMonitor.register(trip: trip, currentLocation: manager.location)
        }
        manager.startUpdatingLocation()
    case .authorizedWhenInUse:
        // Location works, but geofences won't. Start location but skip geofence registration.
        manager.startUpdatingLocation()
    case .denied, .restricted:
        // Surface error to driver
        break
    default:
        break
    }
}
```

And in `startLocationTracking()`, move `manager.startUpdatingLocation()` and `geofenceMonitor.register()` inside this delegate — do NOT call them immediately after `requestAlwaysAuthorization()` since the dialog is asynchronous.

---

### Fix 9 — Wire FleetLiveMapView to Supabase Realtime

In `FleetLiveMapViewModel` (or `FleetLiveMapView` directly), add a Realtime subscription:

```swift
private func subscribeToVehicleLocations() {
    let channel = supabase.realtimeV2.channel("fleet-live-map")
    channel.onPostgresChanges(
        AnyAction.self,
        schema: "public",
        table: "vehicles"
    ) { [weak self] change in
        Task { @MainActor in
            await self?.store.loadVehicles()  // or patch in-memory
        }
    }
    Task { await channel.subscribe() }
    self.liveChannel = channel
}
```

Call `subscribeToVehicleLocations()` in `.onAppear` and cancel in `.onDisappear`.

---

### Fix 10 — Wire submitIssue() to backend

In `NavigationHUDOverlay.submitIssue()`, replace the toast-only stub with a real call:

```swift
private func submitIssue() {
    let text = issueText
    issueText = ""
    withAnimation { showIncidentReport = false }
    Task {
        do {
            try await supabase.from("emergency_alerts").insert([
                "trip_id": coordinator.trip.id.uuidString,
                "alert_type": "Incident",
                "description": text,
                "latitude": coordinator.lastKnownLocation?.coordinate.latitude,
                "longitude": coordinator.lastKnownLocation?.coordinate.longitude,
                "created_by_id": driverId
            ]).execute()
            // also insert notification row for FM
            withAnimation { showIssueSentToast = true }
        } catch {
            // show error toast instead
        }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { showIssueSentToast = false }
    }
}
```

---

### Fix 11 — Configure AVAudioSession in VoiceNavigationService

```swift
func announce(_ instruction: String) {
    guard !isMuted, !instruction.isEmpty else { return }
    // Duck other audio
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
    try? AVAudioSession.sharedInstance().setActive(true)
    
    let utterance = AVSpeechUtterance(string: instruction)
    utterance.rate = 0.52
    utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
    synthesizer.speak(utterance)
}
```

Also fix the silent-switch detection: replace `session.outputVolume < 0.05` with the correct check or simply remove the volume gate — the mute button is the right UX control, not a volume threshold.

---

### Fix 12 — Fix DeviationDetector flat-earth math

Replace the degree-space dot-product with metre-space math using `CLLocation.distance(from:)`:

```swift
// Convert segment endpoints and position to CLLocation
// Project using actual distances, not raw degrees
static func perpendicularDistance(
    from point: CLLocationCoordinate2D,
    segStart: CLLocationCoordinate2D,
    segEnd: CLLocationCoordinate2D
) -> CLLocationDistance {
    let pLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
    let aLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
    let bLoc = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)
    
    let ab = bLoc.distance(from: aLoc)
    guard ab > 0 else { return pLoc.distance(from: aLoc) }
    
    let ap = pLoc.distance(from: aLoc)
    let bp = pLoc.distance(from: bLoc)
    
    // Heron's formula for triangle area, then h = 2A / base
    let s = (ab + ap + bp) / 2
    let area = sqrt(max(0, s * (s - ab) * (s - ap) * (s - bp)))
    return (2 * area) / ab
}
```

This is geodesically consistent — all distances are in metres.

---

### Fix 13 — Fix double publish throttle

In `TripNavigationCoordinator.startLocationPublishing()`, remove the `Timer` wrapper and let `VehicleLocationService`'s internal 5-second throttle be the sole rate limiter:

```swift
// Replace Timer-based call with location-update-driven publish:
// In locationManager(_ manager:, didUpdateLocations:)
publishLocation(location)  // VehicleLocationService throttles internally
```

This ensures publish rate is exactly 5 seconds regardless of scheduling jitter.

---

### Fix 14 — Fix reroute double-build guard

In `TripNavigationCoordinator.checkDeviation()`, add a time-based cooldown before triggering reroute to prevent two consecutive off-route updates spawning two builds:

```swift
private var lastRerouteTime: Date = .distantPast
private let rerouteCooldown: TimeInterval = 10

func checkDeviation(location: CLLocation) {
    // ... existing deviation check ...
    guard Date().timeIntervalSince(lastRerouteTime) >= rerouteCooldown else { return }
    lastRerouteTime = Date()
    routeEngine.triggerRerouteFromCurrentLocation()
    Task { await routeEngine.buildRoutes(trip: trip, currentLocation: location) }
}
```

---

## Part 4 — SRS Requirements Gaps

These are features required by the SRS that are structurally absent (not just bugs in existing code).

### Gap 1 — Traffic/incident alerts ahead

Mapbox provides traffic congestion data via `attributeOptions: [.congestionLevel]` — already requested in `RouteEngine`. Two things need to happen:

**A. Render congestion colors on route line** in `TripNavigationView.MapCoordinator`:
```swift
// Split route into segments by congestion level from route.legs[0].segmentCongestionLevels
// Render each segment as a separate LineLayer with color:
// .unknown/.low → orange, .moderate → yellow, .heavy/.severe → red
```

**B. Incident banner in HUD** — poll Mapbox Incidents API for incidents along the route corridor. On detection, show a dismissible banner in `NavigationHUDOverlay` and trigger `routeEngine.buildRoutes()` to reroute. A 60-second poll interval on a background task is sufficient.

```swift
// In TripNavigationCoordinator:
private func startIncidentPolling() {
    incidentTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await checkForIncidentsAhead()
        }
    }
}
```

### Gap 2 — Avoid tolls / avoid highways (admin-set, not driver-set)

Since drivers don't configure routes, these preferences must be set by the FM when creating the trip. Add two `Bool` columns to the `trips` table (`avoid_tolls`, `avoid_highways`) and expose them in `CreateTripView`. Pass them into `RouteEngine.buildRoutes()` → `RouteOptions.roadClasses`:

```swift
var exclude: RoadClasses = []
if trip.avoidTolls == true { exclude.insert(.toll) }
if trip.avoidHighways == true { exclude.insert(.motorway) }
options.roadClasses = exclude
```

### Gap 3 — Stops/waypoints displayed in driver nav HUD

The trip model already supports waypoints (stops). `RouteEngine.buildRoutes()` already adds them as intermediate `Waypoint` objects. What's missing is surfacing them in the HUD:

- Add a "Stops" section to `NavigationHUDOverlay` showing the next stop name and distance.
- When the driver arrives within 100m of a stop, show a confirmation prompt ("Confirm stop delivery?") before advancing to the next leg.

### Gap 4 — Admin can see routes on fleet map

`FleetLiveMapView` currently shows vehicle annotations but no route lines. After Fix 9 (Realtime subscription) is in, also fetch each active trip's `route_polyline` and render it as an `MKPolyline` overlay on the fleet map per vehicle.

### Gap 5 — Green Route definition

Current code labels whatever Mapbox returns as the second alternative as "Green". Proper labeling:

```swift
// After getting alternatives from Directions.shared.calculate:
let fastest = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })
let greenest = routes.min(by: { $0.distance < $1.distance })
// If fastest == greenest (same route), only show one card
```

Update `RouteSelectionSheet` to use these computed values. The savings label should read "−X km vs fastest" (distance comparison), not "Saves fuel" (unsubstantiated).

---

## Part 5 — AnyCancelable Typo Fix

In `TripNavigationView.MapCoordinator`:

```swift
// Replace:
private var cancelables = Set<AnyCancelable>()

// With:
private var cancellables = Set<AnyCancellable>()
```

(Combine's type is `AnyCancellable` with double `l`. All `.store(in:)` references must match.)

---

## Part 6 — Remove Dead Code

In order of priority:

1. **Remove `import MapboxNavigationCore`** from `TripNavigationView.swift` and remove the package from SPM dependencies. No symbols from it are used.
2. **Remove `MapService.fetchRoutes()` and `MapService.MapRoute`/`MapService.RouteStep` types** — these are legacy from a pre-`RouteEngine` implementation and are never called in the active nav flow. Keep only `MapService.hasValidToken`, `MapService.accessToken`, `MapService.sanitizedToken()`, `MapService.fetchRoutesWithMapKit()` (after Fix 5).
3. **Remove `MapService.fetchRoutesWithMapKit()`** if you decide not to support the no-token fallback path (simplifies the codebase).
4. **Remove `MapboxNavigationCore`** SPM dependency entry.

---

## Part 7 — Implementation Order (quick reference)

```
Priority 1 (unblocks everything):
  Fix 1 — Populate MBXAccessToken in Info.plist        [manual]
  Fix 2 — Directions.shared.credentials assignment     [RouteEngine.swift]
  Fix 3 — showRouteSelection = true                    [TripNavigationContainerView.swift]
  Fix 4 — Remove duplicate AVSpeechSynthesizer          [TripNavigationContainerView.swift]
  Fix 5 — MKMapItem initializer                        [MapService.swift]
  Fix 6 — decodePolyline replacement                   [StartTripSheet.swift]

Priority 2 (correctness):
  Fix 7 — Save route polyline on trip creation          [CreateTripViewModel.swift]
  Fix 8 — locationManagerDidChangeAuthorization         [TripNavigationCoordinator.swift]
  Fix 9 — FleetLiveMap Supabase Realtime                [FleetLiveMapViewModel.swift]
  Fix 10 — submitIssue() backend call                   [NavigationHUDOverlay.swift]
  Fix 11 — AVAudioSession duckOthers                    [VoiceNavigationService.swift]

Priority 3 (polish and accuracy):
  Fix 12 — DeviationDetector geodesic math              [DeviationDetector.swift]
  Fix 13 — Double publish throttle                      [TripNavigationCoordinator.swift]
  Fix 14 — Reroute double-build cooldown                [TripNavigationCoordinator.swift]
  Part 5 — AnyCancellable typo                         [TripNavigationView.swift]
  Part 6 — Remove dead code                            [multiple files]

Priority 4 (SRS gaps):
  Gap 1 — Traffic/incident alerts + congestion line     [TripNavigationView + Coordinator]
  Gap 2 — Avoid tolls/highways (DB columns + UI)        [CreateTripView + RouteEngine]
  Gap 3 — Stops in driver HUD                          [NavigationHUDOverlay]
  Gap 4 — Route polyline on admin fleet map             [FleetLiveMapView]
  Gap 5 — Green route proper computation               [RouteSelectionSheet + RouteEngine]
```

---

## Summary

The navigation stack is architecturally correct and well-decomposed. Its failure in production is caused by a cascade of concrete, fixable bugs — foremost the empty Mapbox token, which kills everything downstream. After populating the token and applying Fixes 2–14, the app will have functional:

- In-app Mapbox map with route polyline
- Turn-by-turn steps and voice guidance  
- Route selection (fastest vs green)
- Toll/highway avoidance
- Geofence entry/exit
- Route deviation detection and Supabase recording
- Real-time fleet map for admin
- Working incident reporting
- Proper mute functionality

The remaining SRS gaps (Gaps 1–5) are new feature additions, not bug fixes, and can be implemented incrementally after the bug fixes are in place.
