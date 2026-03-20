# Sierra — Map & Navigation Audit
_Generated: 2026-03-20_

---

## Verdict: Architecture is correct. SDK wiring is incomplete. Nothing renders yet.

The right choices were made (Mapbox for driver navigation, MapKit for admin fleet map, Supabase Realtime for live location). All the Swift files exist. But the app shows no map on either side because three critical wiring steps were never done:

1. **Mapbox token is missing from Info.plist** — MapView crashes silently at launch with a blank screen
2. **Supabase Realtime subscription for live vehicle positions was never added** — admin map never updates
3. **`AdminDashboardView` routes to `AdminDashboardView` (a stub) not `FleetManagerTabView`** — the entire fleet manager UI including the Live Map tab is never reached

Everything else (the coordinator, HUD, route building logic, geofencing, deviation detection, breadcrumbs) is implemented and correct.

---

## What Exists and Works (Code Quality ✅)

### Driver Side
| File | Status | Notes |
|---|---|---|
| `TripNavigationCoordinator.swift` | ✅ Complete | Route building, toll/highway avoidance, deviation detection (200m threshold with 60s cooldown), geofence monitoring via CLCircularRegion, location publishing every 5s, green route selection |
| `TripNavigationView.swift` | ✅ Complete | UIViewRepresentable wrapping Mapbox MapView, puck2D with bearing, route polyline drawn as PolylineAnnotation, camera follows driver |
| `NavigationHUDOverlay.swift` | ✅ Complete | Instruction banner, off-route warning, distance/ETA/remaining stats row, speed badge (km/h), SOS sheet, incident report, add-stop geocoding with 500ms debounce, end trip confirm |
| `TripNavigationContainerView.swift` | ✅ Complete | Composes map + HUD, voice guidance via AVSpeechSynthesizer, wires trip start/end lifecycle |
| `TripDetailDriverView.swift` | ✅ Complete | Navigation entry point — has Navigate button that pushes TripNavigationContainerView |

### Admin Side
| File | Status | Notes |
|---|---|---|
| `FleetLiveMapView.swift` | ✅ Complete | MapKit Map with vehicle annotations, geofence circles, breadcrumb polyline, filter sheet, create geofence button |
| `FleetLiveMapViewModel.swift` | ✅ Complete | Vehicle filtering, fleet centroid, breadcrumb fetch from vehicle_location_history |
| `VehicleMapDetailSheet.swift` | ✅ Complete | Tap vehicle → see driver, trip, speed, breadcrumb button |
| `FleetManagerTabView.swift` | ✅ Complete | Live Map tab wires to FleetLiveMapView |

### Services
| File | Status | Notes |
|---|---|---|
| `VehicleLocationService.swift` | ✅ Complete | publishLocation() writes to vehicles + vehicle_location_history; fetchLocationHistory() for breadcrumbs |
| `RouteDeviationService.swift` | ✅ Complete | Records deviation events to Supabase |
| `GeofenceEventService.swift` | ✅ Complete | Writes geofence entry/exit events |

---

## What Is Missing / Broken

### 🔴 BLOCKER 1 — Mapbox token not in Info.plist
**Symptom:** `TripNavigationView` shows a completely blank screen. No crash, no error visible, just black/white.

**Why:** `MapView(frame:mapInitOptions:)` reads `MBXAccessToken` from `Info.plist` at init time. If the key is absent or empty, Mapbox renders nothing and logs a silent auth failure.

**Fix:** In Xcode, open `Sierra/Info.plist` and add:
```xml
<key>MBXAccessToken</key>
<string>pk.YOUR_MAPBOX_PUBLIC_TOKEN_HERE</string>
```
Get a free token at https://account.mapbox.com — no billing required for free tier (50k map loads/month, 100k Directions API calls/month).

Also verify in `TripNavigationCoordinator.buildRoutes()` that `Directions.shared` is initialised. If you did not call `Directions.init(credentials:)` anywhere, add to `SierraApp.init()`:
```swift
// Mapbox Directions uses MBXAccessToken from Info.plist automatically
// No explicit init needed if MapboxNavigationCore is linked — it reads the plist key.
```

---

### 🔴 BLOCKER 2 — `AdminDashboardView` is a stub, never routes to `FleetManagerTabView`

**Symptom:** Fleet manager logs in and sees `AdminDashboardView` (a simple VStack with a sign-out button). The Live Map tab never appears.

**Why:** `ContentView.destinationView(for:)` routes `.fleetManagerDashboard` → `AdminDashboardView()`. But `AdminDashboardView` is a placeholder stub. The real UI is `FleetManagerTabView`, which contains the Live Map, Alerts, Vehicles, Drivers, Maintenance, Reports, Geofences, and Settings tabs.

**Fix:** In `ContentView.swift`, change:
```swift
case .fleetManagerDashboard: AdminDashboardView()
```
to:
```swift
case .fleetManagerDashboard: FleetManagerTabView()
    .environment(AppDataStore.shared)
```

`FleetManagerTabView` already exists and is fully implemented.

---

### 🔴 BLOCKER 3 — No Supabase Realtime subscription for live vehicle positions

**Symptom:** Admin map shows vehicle annotations in their last-known position but never moves. Vehicles are static even when a driver is actively navigating.

**Why:** `FleetLiveMapViewModel` reads from `AppDataStore.shared.vehicles` which is populated once on `loadAll()`. There is no Realtime channel subscribing to `vehicles` table changes. The driver publishes location every 5s to Supabase via `VehicleLocationService.publishLocation()`, but the admin side never receives those updates.

**Fix:** Add a Realtime subscription in `AppDataStore.loadAll()` (or a dedicated method). In `AppDataStore.swift`, inside the fleet manager load path, add:

```swift
// In AppDataStore — call this after initial vehicles load
func subscribeToVehicleLocations() {
    let channel = supabase.channel("vehicle-locations")
    channel.on(.postgresChanges,
        filter: ChannelFilter(event: .update, schema: "public", table: "vehicles")
    ) { [weak self] payload in
        guard let self else { return }
        // Decode the changed row and update the vehicle in self.vehicles
        if let record = payload.decodeRecord(as: Vehicle.self) {
            Task { @MainActor in
                if let idx = self.vehicles.firstIndex(where: { $0.id == record.id }) {
                    self.vehicles[idx] = record
                }
            }
        }
    }
    Task { await channel.subscribe() }
    // Store channel reference in a property so it isn't deallocated
}
```

`FleetLiveMapView` already reads `store.vehicles` and uses SwiftUI's `Map` with `ForEach(displayedVehicles)` — once `AppDataStore.vehicles` updates, the annotation positions update automatically via SwiftUI's diffing. No other change needed on the view side.

---

### 🟡 GAP 4 — Route options UI (Fastest vs Green) is not shown to driver before navigation starts

**What exists:** `TripNavigationCoordinator` correctly fetches two route alternatives and labels them — `currentRoute` gets the fastest (lowest duration), `alternativeRoute` gets the other (shortest distance = green). The logic is correct.

**What's missing:** There is no pre-navigation screen showing the driver both routes with their labels, ETA, and distance so they can choose. Navigation starts immediately with the fastest route. The driver never sees the green option.

**Fix needed:** Before `TripNavigationContainerView` goes full-screen, show a `RouteSelectionSheet` with two cards:
- Card 1: "Fastest — 42 min · 28 km" 
- Card 2: "Green Route 🌿 — 48 min · 24 km · saves ~0.8L fuel"

When the driver picks one, set `coordinator.currentRoute` accordingly and dismiss the sheet. This is a one-screen addition to `StartTripSheet.swift` or a new `RouteSelectionSheet.swift`.

---

### 🟡 GAP 5 — Toll/Highway avoidance toggles exist in coordinator but no UI exposes them

**What exists:** `TripNavigationCoordinator` has `avoidTolls: Bool` and `avoidHighways: Bool` which are passed to `RouteOptions.roadClassesToAvoid`. The logic is wired.

**What's missing:** No UI lets the driver set these before departure. They are always `false`.

**Fix needed:** Add two toggle rows to `StartTripSheet.swift` before the "Start Navigation" button:
```swift
Toggle("Avoid Tolls", isOn: $coordinator.avoidTolls)
Toggle("Avoid Highways", isOn: $coordinator.avoidHighways)
```

---

### 🟡 GAP 6 — Departure date/time not wired to Mapbox RouteOptions

**What exists:** `CreateTripView` has a `scheduledDate` field saved to the trips table.

**What's missing:** `TripNavigationCoordinator.buildRoutes()` never reads `trip.scheduledAt` and never sets `RouteOptions.departAt`. This means routing always assumes departure now, which affects traffic-based ETA.

**Fix:** In `buildRoutes()`, after creating `options`:
```swift
if let scheduledAt = trip.scheduledAt, scheduledAt > Date() {
    options.departAt = scheduledAt
}
```

---

### 🟡 GAP 7 — No SPM package list or `.swift-package` file in the repo

The Mapbox packages (`MapboxMaps`, `MapboxNavigationCore`, `MapboxDirections`) are referenced in Swift files but there is no `Package.swift` or `Package.resolved` committed to the repo. A developer cloning the repo cold will not know which packages to add or which versions to pin.

**Fix:** Commit `Sierra.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` so package versions are reproducible. Also add a setup section to README.md listing the three SPM URLs:
- `https://github.com/mapbox/mapbox-maps-ios` (≥ 11.0.0)
- `https://github.com/mapbox/mapbox-navigation-ios` (≥ 3.0.0) — provides MapboxNavigationCore + MapboxDirections
- `https://github.com/mapbox/turf-swift` (≥ 4.0.0) — already imported in TripNavigationView

---

## Summary: What to Do in Order

| Priority | Action | Time Estimate |
|---|---|---|
| 🔴 1 | Add `MBXAccessToken` to `Info.plist` | 5 min |
| 🔴 2 | Change `ContentView` to route fleet manager → `FleetManagerTabView` | 2 min |
| 🔴 3 | Add Supabase Realtime vehicle subscription in `AppDataStore` | 30 min |
| 🟡 4 | Add `RouteSelectionSheet` to show Fastest vs Green before navigation | 2 hrs |
| 🟡 5 | Add toll/highway avoidance toggles to `StartTripSheet` | 30 min |
| 🟡 6 | Wire `trip.scheduledAt` to `RouteOptions.departAt` | 10 min |
| 🟡 7 | Commit `Package.resolved` to repo | 5 min |

Items 1–3 are the only things preventing anything from rendering. Everything else is already implemented correctly.
