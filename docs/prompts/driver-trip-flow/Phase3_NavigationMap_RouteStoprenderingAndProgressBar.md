# Sierra — Driver Trip Flow: Phase 3
## Navigation Map: Admin-Specified Route + Stops Rendering + Live Progress Bar

---

## Context & Background

This is Phase 3. Phases 1 and 2 must be complete first. By this point:
- Admin dispatches trips via `dispatchTrip(tripId:)` → status changes to `pendingAcceptance`
- Driver accepts → pre-inspection → starts trip → map opens
- The "Add Stop" button is removed from the driver HUD

This phase fixes the map screen itself. The navigation map currently:
1. Says "Waiting for Assignment" or shows a blank error banner when coordinates are missing
2. Does NOT render the stops that the admin has pre-specified on `trip.routeStops`
3. Does NOT show a live route-progress bar within the navigation screen
4. Shows a `RouteSelectionSheet` requiring the driver to manually confirm a route — this flow needs to be streamlined since the admin has already defined the route

The Supabase backend `trips` table schema (confirmed):
- `origin_latitude`, `origin_longitude` — Double nullable
- `destination_latitude`, `destination_longitude` — Double nullable
- `route_stops` — JSONB array, default `[]`, maps to `[RouteStop]` in Swift
- `route_polyline` — TEXT nullable (a stored encoded polyline if pre-generated)

---

## Files to Read First (Required)

Read every one of these files fully before writing any code:

1. `Sierra/Driver/Views/TripNavigationContainerView.swift` — the fullscreen navigation host
2. `Sierra/Driver/Views/TripNavigationView.swift` — the `UIViewRepresentable` wrapping Mapbox MapView
3. `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` — the orchestration class
4. `Sierra/Driver/ViewModels/RouteEngine.swift` — route building, stop handling, deviation
5. `Sierra/Driver/Views/NavigationHUDOverlay.swift` — the HUD shown on top of the map
6. `Sierra/Driver/Views/RouteSelectionSheet.swift` — what happens after route is built
7. `Sierra/Shared/Models/RouteStop.swift` — the stop model; understand its fields (latitude, longitude, name, order)
8. `Sierra/Shared/Models/Trip.swift` — understand `routeStops: [RouteStop]?`, `originLatitude`, `destinationLatitude`

Do NOT start writing code until all eight files are read and understood.

---

## Part A: Fix Route Building for Trips With Missing Coordinates

### Current Behavior

`RouteEngine.buildRoutes(trip:currentLocation:)` correctly handles missing destination coordinates by setting `lastBuildError` and returning early. `TripNavigationContainerView` shows a "Route unavailable" error banner with a Retry button. This is functionally correct.

However, the error message "Trip destination coordinates are not set. Ask your fleet manager to update the trip." is the correct behavior for an improperly configured trip. **Do not change this error handling.** It is correct.

The **real fix** needed here is: in `CreateTripView.swift` (admin side), the geocoding that converts the origin/destination address strings into lat/lng coordinates must be working. Verify by checking whether `CreateTripView` populates `originLatitude`, `originLongitude`, `destinationLatitude`, `destinationLongitude` before inserting the trip. Read `CreateTripView.swift` to confirm. If it is already geocoding correctly, do nothing here. If it is NOT populating coordinates, that is a separate bug that blocks all navigation and must be noted in a comment in the phase prompt output — but it is OUT OF SCOPE for this phase (fixing it requires a separate Phase 4 prompt).

---

## Part B: Render Admin-Specified Route Stops as Map Annotations

### Current State

`RouteEngine.buildRoutes()` already handles `trip.routeStops` correctly — it iterates `trip.routeStops` sorted by `.order` and adds each as a `Waypoint` to the Mapbox `RouteOptions`. This means the calculated route correctly passes through all stops. However, **the map does NOT display visual markers for each stop** — the driver sees only the orange route polyline with no indication of where intermediate stops are.

### What To Add

In `TripNavigationView.swift`, the `MapCoordinator` (the `UIViewRepresentable` coordinator) must add point annotations for each intermediate stop.

Extend the `makeUIView(context:)` function and the `updateUIView(_:context:)` function to render stop annotations. Specifically:

**Add to `MapCoordinator`:**

```swift
func renderStops(mapView: MapView, trip: Trip) {
    // Remove existing stop annotations source if present
    if (try? mapView.mapboxMap.source(withId: "stops-source")) != nil {
        try? mapView.mapboxMap.removeLayer(withId: "stops-layer")
        try? mapView.mapboxMap.removeSource(withId: "stops-source")
    }

    let stops = (trip.routeStops ?? []).sorted { $0.order < $1.order }
    guard !stops.isEmpty else { return }

    var features: [Feature] = []
    for (i, stop) in stops.enumerated() {
        let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        var feature = Feature(geometry: .point(Point(coord)))
        var props = JSONObject()
        props["name"] = JSONValue(stop.name)
        props["order"] = JSONValue(Double(i + 1))
        feature.properties = props
        features.append(feature)
    }

    let collection = FeatureCollection(features: features)
    var source = GeoJSONSource(id: "stops-source")
    source.data = .featureCollection(collection)
    try? mapView.mapboxMap.addSource(source)

    var symbolLayer = SymbolLayer(id: "stops-layer", source: "stops-source")
    symbolLayer.iconImage = .constant(.name("marker-15")) // built-in Mapbox sprite
    symbolLayer.iconColor = .constant(StyleColor(UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0))) // Sierra orange
    symbolLayer.iconSize = .constant(1.5)
    symbolLayer.textField = .expression(Exp(.get) { "name" })
    symbolLayer.textSize = .constant(11)
    symbolLayer.textColor = .constant(StyleColor(.white))
    symbolLayer.textHaloColor = .constant(StyleColor(.black))
    symbolLayer.textHaloWidth = .constant(1.5)
    symbolLayer.textOffset = .constant([0, 1.5])
    symbolLayer.iconAllowOverlap = .constant(true)
    symbolLayer.textAllowOverlap = .constant(true)
    try? mapView.mapboxMap.addLayer(symbolLayer)
}
```

Call `context.coordinator.renderStops(mapView: mapView, trip: coordinator.trip)` at the end of `makeUIView(context:)` and also at the end of `updateUIView(_:context:)` (so stops re-render if the trip changes).

Also render the **origin** and **destination** markers. These may already be rendered via `Annotation` views if the map is used in a SwiftUI Map context, but since this is a `UIViewRepresentable` wrapping a `MapView` directly, you must add them as GeoJSON sources as well, OR use `PointAnnotationManager`. Use the same GeoJSON + SymbolLayer pattern and a separate source ID (`"origin-dest-source"`) to keep them separate from the stops.

- Origin marker: green circle, label from `trip.origin`
- Destination marker: red/ember circle, label from `trip.destination`
- Use distinct icon names or tintable SF symbols if Mapbox's built-in sprites support it. If not, use the built-in `"marker-15"` with color overrides.

**Important:** Use `try? mapView.mapboxMap.source(withId:)` to check existence before adding, to avoid crash on `updateUIView` re-calls.

---

## Part C: Streamline Route Selection — Auto-Select Fastest Route

### Current State

After `buildAndShowRoutes()` succeeds, `TripNavigationContainerView` shows `RouteSelectionSheet` — a separate modal that lets the driver pick between the fastest route and an alternative "green" route. The driver must tap a button in this sheet before navigation tracking begins.

### What To Change

Since stops are admin-defined and the route is pre-specified, the driver should not need to choose a route. **Auto-select the fastest route** and begin tracking immediately.

In `TripNavigationContainerView.swift`, change the `buildAndShowRoutes()` method:

After `coordinator.buildRoutes()` succeeds (i.e., `coordinator.currentRoute != nil`):
- Do NOT show `RouteSelectionSheet`
- Instead, immediately call `startTracking()` which starts location publishing
- Keep the `showRouteSelection` state and its `.sheet(isPresented:)` but never set `showRouteSelection = true` from `buildAndShowRoutes()`; remove that line
- The `RouteSelectionSheet` file itself does not need to be deleted — just bypass it in the normal flow. Keeping it unused is fine.

**Rationale:** The admin defines the route including all stops. The driver does not choose a route. Auto-selecting fastest is correct behavior.

---

## Part D: Live Route Progress Bar in NavigationHUDOverlay

### What To Add

Add a horizontal progress bar to `NavigationHUDOverlay` that fills as the driver moves along the route. This is distinct from the lifecycle progress bar in `TripDetailDriverView` (Phase 2) — this one is a **live route progress** based on distance remaining vs total route distance.

Add a computed property to `TripNavigationCoordinator`:

```swift
/// Returns a value in [0.0, 1.0] representing how far along the route the driver is.
/// 0.0 = at origin, 1.0 = arrived at destination.
var routeProgressFraction: Double {
    guard let route = currentRoute, route.distance > 0 else { return 0 }
    let distanceTraveled = route.distance - distanceRemainingMetres
    return max(0, min(1, distanceTraveled / route.distance))
}
```

This property must be added to `TripNavigationCoordinator.swift`.

In `NavigationHUDOverlay.swift`, add the progress bar **above** the `statsRow`, displayed as a thin full-width strip:

```swift
private func routeProgressBar() -> some View {
    let progress = coordinator.routeProgressFraction
    let pct = Int(progress * 100)
    return VStack(spacing: 4) {
        HStack {
            Text("Route Progress")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text("\(pct)%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.85, blue: 0.55), Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 16)
    }
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.3))
}
```

Insert `routeProgressBar()` in the `NavigationHUDOverlay` body's VStack, immediately before `statsRow`.

The progress bar should only show when `coordinator.currentRoute != nil` and `coordinator.isNavigating`. Wrap it:

```swift
if coordinator.currentRoute != nil && coordinator.isNavigating {
    routeProgressBar()
}
```

---

## Part E: Fix "Waiting for Assignment" Message

Search the entire codebase for the string `"Waiting for Assignment"` or `"waiting for assignment"`. Identify every location it appears. Replace it with context-appropriate messaging:

- In `TripDetailDriverView.swift` (case `.scheduled`): Already fixed in Phase 2 to say "Awaiting Dispatch"
- In any navigation or map view: If the message appears because `coordinator.currentRoute == nil` before route building completes, it should instead show a `ProgressView` spinner with label "Calculating route…"
- In any HUD or stats view: If it appears because `coordinator.estimatedArrivalTime == nil`, change the ETA stat to show `"--:--"` (already the case in the existing `statsRow` code)

If the string exists in `DriverHomeView.swift` or anywhere else, replace it appropriately based on context. Read those files as needed.

---

## Part F: Verify CreateTripView Geocoding (Read-Only Audit)

Read `Sierra/FleetManager/Views/CreateTripView.swift` fully. Determine:
1. Does the admin-facing trip creation form geocode the origin and destination text fields to populate `originLatitude`, `originLongitude`, `destinationLatitude`, `destinationLongitude` before saving?
2. If NO: Note this explicitly at the top of your response as "BLOCKING ISSUE: CreateTripView does not geocode coordinates. Navigation will fail for all new trips until this is fixed."
3. If YES: Confirm it is working and move on.

Do NOT fix `CreateTripView` in this phase. This is an audit step only. If geocoding is missing, it will be addressed in a separate prompt.

---

## Compile Requirements

- `import MapboxNavigationCore` for all direct Mapbox imports (NOT `import MapboxMaps` as a direct import — it is transitive only)
- All Mapbox MapView operations (addSource, addLayer, updateGeoJSONSource) must be wrapped in `try?` — they can fail silently
- All store reads are on `@MainActor`
- No force unwraps
- No new SPM packages
- All new coordinator properties must use `@Observable` — no `@Published`

---

## Files To Modify

1. `Sierra/Driver/Views/TripNavigationView.swift` — add stop markers + origin/dest markers
2. `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` — add `routeProgressFraction` property
3. `Sierra/Driver/Views/NavigationHUDOverlay.swift` — add route progress bar (Add Stop already removed in Phase 2)
4. `Sierra/Driver/Views/TripNavigationContainerView.swift` — auto-select route, bypass RouteSelectionSheet
5. Any file containing the string "Waiting for Assignment" that has not already been fixed in Phase 2

## Files To NOT Touch
- `Sierra/Driver/ViewModels/RouteEngine.swift` — it already handles stops correctly as Mapbox waypoints
- `Sierra/Driver/Views/RouteSelectionSheet.swift` — keep the file, just don't show it from the normal flow
- `Sierra/Shared/Models/RouteStop.swift`
- `Sierra/Shared/Models/Trip.swift`
- Any FleetManager views (unless auditing CreateTripView)
- Any auth or maintenance views

---

## Output Requirements

Produce full, ready-to-compile file content for every modified file. No diffs, no partial snippets. Include the CreateTripView geocoding audit finding at the top of your response before any code. Commit all changes to `main` on `Kanishk101/Sierra` using `github:push_files` with commit message: `feat(driver): Phase 3 — route stops rendering + auto-route selection + live progress bar`.
