# Phase 16 — Deep Mapbox + MapKit SDK Implementation

## Scope
The current navigation is stub-level: Mapbox renders a map, route is drawn, location
updates are published. But almost none of the Mapbox SDK's capabilities are used.
This phase goes deep into both SDKs to deliver a genuinely capable navigation and
fleet map experience.

---

## Part 1 — Mapbox Navigation: Replace Stub with Real Navigation

### Current State (Stubs)
- `TripNavigationView.swift` (3KB) — just renders a `MapboxMaps.MapView` with a basic route layer
- Step instructions from `route.legs[0].steps[0].instructions` (static first step only)
- Haversine deviation detection (no map matching)
- No turn-by-turn rendering on map
- No current position tracking snapped to road
- No maneuver arrows
- No distance-to-next-turn HUD
- `AVSpeechSynthesizer` present but triggered only on `currentStepInstruction` change

### MapboxNavigationCore Integration

**Required imports:**
```swift
import MapboxNavigationCore    // NavigationProvider, NavigationRoutes
import MapboxMaps              // MapView (transitive)
import MapboxDirections        // Route, RouteOptions
```

**A. Create `SierraNavigationProvider.swift`**

Wrap `MapboxNavigationCore.NavigationProvider` to drive the actual navigation:

```swift
// Sierra/Driver/Services/SierraNavigationProvider.swift
import MapboxNavigationCore
import MapboxDirections
import Foundation

@MainActor
@Observable
final class SierraNavigationProvider {
    private var navProvider: NavigationProvider?
    private var navSession: NavigationSession?

    // Live navigation state
    var currentStep: RouteStep?
    var distanceToNextTurn: CLLocationDistance = 0
    var eta: Date?
    var remainingDistance: CLLocationDistance = 0
    var snappedLocation: CLLocation?
    var isNavigating = false
    var routeProgress: RouteProgress?

    // Start navigation with a pre-built NavigationRoutes object
    func startNavigation(routes: NavigationRoutes) {
        let config = CoreConfig(
            credentials: .init(),  // Uses MBXAccessToken from Info.plist
            locationSource: .liveUpdate
        )
        navProvider = NavigationProvider(coreConfig: config)
        guard let provider = navProvider else { return }

        navSession = provider.createNavigationSession()
        navSession?.startActiveGuidance(with: routes, startLegIndex: 0)
        isNavigating = true

        // Subscribe to route progress updates
        provider.mapboxNavigation.tripSession().session
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleSessionState(state)
                }
            }
        // NOTE: full sink/combine integration depends on SDK version
        // Use provider.mapboxNavigation.tripSession().routeProgress
        // or delegate callbacks per SDK docs
    }

    func stopNavigation() {
        navSession?.stopActiveGuidance()
        navProvider = nil
        navSession = nil
        isNavigating = false
        routeProgress = nil
    }

    private func handleSessionState(_ state: TripSessionState) {
        switch state {
        case .activeGuidance(let progress):
            routeProgress = progress
            currentStep = progress.currentLegProgress.currentStep
            distanceToNextTurn = progress.currentLegProgress.currentStepProgress.distanceRemaining
            remainingDistance = progress.distanceRemaining
            eta = Date().addingTimeInterval(progress.durationRemaining)
        case .freeDrive:
            break
        }
    }
}
```

**B. Update `TripNavigationView.swift` to use NavigationCore**

`TripNavigationView` currently uses `MapboxMaps.MapView` directly. Replace the route
drawing with the `NavigationMapView` from `MapboxNavigationUIKit`:

```swift
import SwiftUI
import MapboxNavigationUIKit
import MapboxNavigationCore

struct TripNavigationView: View {
    let coordinator: TripNavigationCoordinator
    let navigationProvider: SierraNavigationProvider

    var body: some View {
        // NavigationMapView handles:
        // - Route polyline rendering (active + alternative)
        // - Turn arrow overlays at junctions  
        // - Current position with road-snapped puck
        // - Recenter button
        // - Route progress visualization (traveled section grayed out)
        NavigationMapView(
            navigationProvider: navigationProvider.navProvider
        )
        .ignoresSafeArea()
    }
}
```

If `NavigationMapView` is unavailable in the version used, manually configure `MapView`:

```swift
struct TripNavigationView: UIViewRepresentable {
    let coordinator: TripNavigationCoordinator

    func makeUIView(context: Context) -> MapView {
        let mapInitOptions = MapInitOptions(
            styleURI: .navigationDay
        )
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        // 1. Enable route layer
        addRouteLayer(to: mapView)
        // 2. Add location puck
        var puck = Puck2DConfiguration.makeDefault(showBearing: true)
        puck.pulsing = .init(color: .orange)
        mapView.location.options.puckType = .puck2D(puck)
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.puckBearing = .course
        // 3. Set viewport to follow
        mapView.viewport.transition(to:
            mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 200, left: 20, bottom: 280, right: 20),
                    zoom: 16,
                    bearing: .course,
                    pitch: 45  // 3D tilt for navigation feel
                )
            )
        )
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        // Update route polyline when route changes
        updateRoutePolyline(on: mapView)
    }

    private func addRouteLayer(to mapView: MapView) {
        var source = GeoJSONSource(id: "route-source")
        source.data = .geometry(.lineString(.init([])))

        var layer = LineLayer(id: "route-layer", source: "route-source")
        layer.lineColor = .constant(StyleColor(.orange))
        layer.lineWidth = .constant(8)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)
        // Casing line underneath
        var casingLayer = LineLayer(id: "route-casing", source: "route-source")
        casingLayer.lineColor = .constant(StyleColor(UIColor.orange.withAlphaComponent(0.3)))
        casingLayer.lineWidth = .constant(14)
        casingLayer.lineJoin = .constant(.round)

        try? mapView.mapboxMap.addSource(source)
        try? mapView.mapboxMap.addLayer(casingLayer, layerPosition: .below("route-layer"))
        try? mapView.mapboxMap.addLayer(layer)
    }

    private func updateRoutePolyline(on mapView: MapView) {
        guard let route = coordinator.currentRoute,
              let shape = route.shape else { return }
        let feature = Feature(geometry: .lineString(shape))
        let geoJSON = GeoJSONSourceData.featureCollection(.init(features: [feature]))
        try? mapView.mapboxMap.updateGeoJSONSource(withId: "route-source", data: geoJSON)
    }
}
```

**C. NavigationHUDOverlay — Add Maneuver Arrow + Lane Guidance**

In `NavigationHUDOverlay.swift`, add a maneuver banner above the existing HUD:

```swift
// In NavigationHUDOverlay, add at top:
private var maneuverBanner: some View {
    HStack(spacing: 14) {
        // Maneuver icon
        Image(systemName: maneuverIcon(for: coordinator.currentStepManeuver))
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))

        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: "%.0f m", coordinator.distanceRemainingMetres > 1000
                ? coordinator.distanceRemainingMetres / 1000
                : coordinator.distanceRemainingMetres))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(coordinator.currentStepInstruction)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
        }
        Spacer()
    }
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    .padding(.horizontal, 16)
    .padding(.top, 60)
}

private func maneuverIcon(for instruction: String) -> String {
    let lower = instruction.lowercased()
    if lower.contains("left")    { return "arrow.turn.up.left" }
    if lower.contains("right")   { return "arrow.turn.up.right" }
    if lower.contains("u-turn")  { return "arrow.uturn.left" }
    if lower.contains("merge")   { return "arrow.merge" }
    if lower.contains("exit")    { return "arrow.triangle.turn.up.right.circle" }
    if lower.contains("arrive")  { return "mappin.circle.fill" }
    if lower.contains("depart")  { return "arrow.up.circle.fill" }
    return "arrow.up"
}
```

Add a `currentStepManeuver: String` property to `TripNavigationCoordinator` that extracts
the maneuver type string from `route.legs.first?.steps[currentStepIndex].maneuverType?.rawValue`.

---

## Part 2 — MapKit Fleet Live Map: Deep Feature Implementation

### 2A: Vehicle Clustering

With many vehicles, individual annotations overlap. Add clustering:

```swift
// In FleetLiveMapView, inside Map(...) content:
ForEach(displayedVehicles) { vehicle in
    if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
        // Use .clusteringIdentifier for automatic MapKit clustering
        Annotation(
            vehicle.licensePlate,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            anchor: .bottom
        ) {
            vehicleAnnotationView(vehicle)
                .onTapGesture {
                    viewModel.selectedVehicleId = vehicle.id
                    viewModel.showVehicleDetail = true
                }
        }
        .clusteringIdentifier("fleet-vehicles")  // enables clustering
    }
}

// Cluster annotation:
AnnotationGroup("fleet-vehicles") { cluster in
    ZStack {
        Circle().fill(Color.orange.opacity(0.85))
            .frame(width: 44, height: 44)
        Text("\(cluster.count)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
    }
}
```

### 2B: Live Vehicle Trail / Breadcrumb Polyline

Currently the breadcrumb uses `MapPolyline(coordinates:)`. Enhance with:
1. Gradient coloring based on speed (green=fast, yellow=medium, red=slow)
2. Directional arrows at waypoints
3. Timestamp markers at 5-minute intervals

```swift
// In FleetLiveMapView.mapContent:
if viewModel.breadcrumbCoordinates.count >= 2 {
    // Base trail
    MapPolyline(coordinates: viewModel.breadcrumbCoordinates)
        .stroke(.orange.opacity(0.6), lineWidth: 4)

    // Speed-colored segments (if speed data available)
    ForEach(Array(viewModel.speedSegments.enumerated()), id: \.offset) { i, segment in
        MapPolyline(coordinates: segment.coordinates)
            .stroke(segment.speedColor, lineWidth: 5)
    }
}
```

In `FleetLiveMapViewModel`, add `speedSegments` computed from `activeTripLocationHistory`:
```swift
struct SpeedSegment {
    let coordinates: [CLLocationCoordinate2D]
    let avgSpeedKmh: Double
    var speedColor: Color {
        switch avgSpeedKmh {
        case 0..<20: return .red
        case 20..<60: return .orange
        case 60..<100: return .yellow
        default: return .green
        }
    }
}
```

### 2C: Geofence Rendering Enhancement

Currently geofences are `MapCircle`. Enhance with:
1. Different border styles per type (dashed for restricted zones)
2. Pulsing animation for newly triggered geofences
3. Name label overlay in center

```swift
// In mapContent:
ForEach(store.geofences.filter { $0.isActive }) { geofence in
    let center = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
    let isViolated = store.geofenceEvents.contains {
        $0.geofenceId == geofence.id &&
        $0.triggeredAt > Date().addingTimeInterval(-300)  // triggered in last 5 min
    }
    MapCircle(center: center, radius: geofence.radiusMeters)
        .foregroundStyle(geofenceColor(geofence.geofenceType).opacity(isViolated ? 0.35 : 0.15))
        .stroke(
            geofenceColor(geofence.geofenceType).opacity(0.8),
            style: StrokeStyle(
                lineWidth: isViolated ? 3 : 1.5,
                dash: geofence.geofenceType == .restrictedZone ? [8, 4] : []
            )
        )
    // Geofence label
    Annotation("", coordinate: center) {
        Text(geofence.name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(geofenceColor(geofence.geofenceType))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 2)
    }
    .annotationTitles(.hidden)
}
```

### 2D: Trip Route Preview on Map

When the admin taps a vehicle on the fleet map, `VehicleMapDetailSheet` currently shows
basic info. Add a live route preview:

1. Fetch the active trip's `originLatitude/Longitude` and `destinationLatitude/Longitude`
2. Draw a dashed polyline from origin → current vehicle position → destination
3. Show estimated remaining distance

```swift
// In VehicleMapDetailSheet, add map section:
if let trip = activeTrip {
    Map {
        // Origin marker
        if let oLat = trip.originLatitude, let oLng = trip.originLongitude {
            Annotation("Origin", coordinate: CLLocationCoordinate2D(latitude: oLat, longitude: oLng)) {
                Image(systemName: "circle.fill").foregroundStyle(.green).font(.title3)
            }
        }
        // Current vehicle position
        if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
            Annotation(vehicle.licensePlate, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                Image(systemName: "truck.box.fill").foregroundStyle(.orange).font(.title3)
            }
        }
        // Destination marker
        if let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {
            Annotation("Destination", coordinate: CLLocationCoordinate2D(latitude: dLat, longitude: dLng)) {
                Image(systemName: "mappin.circle.fill").foregroundStyle(.red).font(.title3)
            }
        }
        // Breadcrumb trail
        if viewModel.breadcrumbCoordinates.count >= 2 {
            MapPolyline(coordinates: viewModel.breadcrumbCoordinates)
                .stroke(.orange, lineWidth: 3)
        }
    }
    .frame(height: 220)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .allowsHitTesting(false)
}
```

### 2E: Automatic Camera Framing

Currently `cameraPosition = .region(MKCoordinateRegion(...))` with fixed 50km radius.
Replace with dynamic framing that fits all currently active vehicles:

```swift
private func fitAllActiveVehicles(in mapView: MKMapView? = nil) {
    let active = store.vehicles.filter {
        $0.currentLatitude != nil && $0.currentLongitude != nil
    }.compactMap { v -> CLLocationCoordinate2D? in
        guard let lat = v.currentLatitude, let lng = v.currentLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    guard !active.isEmpty else {
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 2_000_000, longitudinalMeters: 2_000_000
        ))
        return
    }
    if active.count == 1 {
        cameraPosition = .region(MKCoordinateRegion(
            center: active[0], latitudinalMeters: 5000, longitudinalMeters: 5000
        ))
        return
    }
    let lats = active.map { $0.latitude }
    let lngs = active.map { $0.longitude }
    let minLat = lats.min()!, maxLat = lats.max()!
    let minLng = lngs.min()!, maxLng = lngs.max()!
    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
    let span = MKCoordinateSpan(
        latitudeDelta: (maxLat - minLat) * 1.4,
        longitudeDelta: (maxLng - minLng) * 1.4
    )
    cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
}
```

Call `fitAllActiveVehicles()` in `.onAppear` and add a "Fit All" button to the floating controls.

---

## Part 3 — Mapbox Route Building Improvements

### 3A: Traffic-Aware Routing

In `TripNavigationCoordinator.buildRoutes()`, add traffic annotation:
```swift
options.profileIdentifier = .automobileAvoidingTraffic  // Use traffic-aware profile
options.includesAlternativeRoutes = true
// Request congestion annotation for each step
options.attributeOptions = [.congestionLevel, .expectedTravelTime, .speed]
```

### 3B: Multiple Alternative Route Display in RouteSelectionSheet

Currently only shows Fastest + Green (1 alternative). If the API returns 2+ alternatives,
show all of them sorted by travel time. Label the first as "Fastest", the shortest by
distance as "Green", and any others as "Via [key road name]".

### 3C: Arrival Detection

Add arrival detection in `TripNavigationCoordinator.updateNavigationProgress()`:
```swift
// Arrival: within 50m of destination
if let lastCoord = decodedRouteCoordinates.last {
    let dest = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
    if let loc = currentLocation, loc.distance(from: dest) < 50 {
        if !hasArrived {
            hasArrived = true
            NotificationCenter.default.post(name: .tripArrivedAtDestination, object: nil)
        }
    }
}
```

Post the notification in `TripNavigationContainerView.onChange(of: coordinator.hasArrived)`
to automatically trigger the ProofOfDelivery flow.

### 3D: Speed Limit Display

In `TripNavigationCoordinator`, parse speed limit from route steps:
```swift
// In updateNavigationProgress()
if let step = leg.steps[safe: currentStepIndex],
   let maxSpeed = step.maximumSpeedLimit {
    currentSpeedLimit = Int(maxSpeed.value)  // new @Observable property
}
```

Show a speed limit sign in `NavigationHUDOverlay`:
```swift
if let limit = coordinator.currentSpeedLimit {
    VStack(spacing: 2) {
        Circle()
            .stroke(.red, lineWidth: 4)
            .frame(width: 52, height: 52)
            .overlay(
                Text("\(limit)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
            )
        Text("km/h").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
    }
}
```

---

## Part 4 — AddressSearchSheet: Real Mapbox Geocoding

`AddressSearchSheet.swift` currently uses `MKLocalSearch`. Replace with Mapbox Search API
for better Indian address coverage:

```swift
// Sierra/Shared/Views/AddressSearchSheet.swift
import SwiftUI
import MapKit

struct GeocodedAddress: Identifiable, Equatable {
    let id = UUID()
    let displayName: String
    let shortName: String
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct AddressSearchSheet: View {
    let placeholder: String
    let onSelect: (GeocodedAddress) -> Void

    @State private var query = ""
    @State private var results: [GeocodedAddress] = []
    @State private var isSearching = false
    @State private var debounceTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(results) { addr in
                Button {
                    onSelect(addr)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(addr.shortName).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                        Text(addr.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if isSearching {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: placeholder)
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    results = []
                    return
                }
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await searchMapbox(query: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func searchMapbox(query: String) async {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
              !token.isEmpty else {
            // Fallback to MKLocalSearch if no token
            await searchAppleMaps(query: query)
            return
        }
        isSearching = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: """
            https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json\
            ?access_token=\(token)&limit=8&country=IN&language=en\
            &proximity=77.2090,28.6139
            """)!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]] ?? []
            results = features.compactMap { f -> GeocodedAddress? in
                guard let geom = f["geometry"] as? [String: Any],
                      let coords = geom["coordinates"] as? [Double],
                      coords.count >= 2 else { return nil }
                let placeName = f["place_name"] as? String ?? ""
                let text = f["text"] as? String ?? placeName
                return GeocodedAddress(
                    displayName: placeName, shortName: text,
                    latitude: coords[1], longitude: coords[0]
                )
            }
        } catch {
            await searchAppleMaps(query: query)
        }
        isSearching = false
    }

    private func searchAppleMaps(query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 3_000_000, longitudinalMeters: 3_000_000
        )
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            results = response.mapItems.map { item in
                GeocodedAddress(
                    displayName: item.name ?? "",
                    shortName: item.name ?? "",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
        }
        isSearching = false
    }
}
```

---

## Part 5 — Collection[safe:] Extension

Add to avoid crashes on array index access:
```swift
// Sierra/Shared/Extensions/Collection+Safe.swift
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

---

## Files to Create or Modify

| File | Change |
|---|---|
| `Sierra/Driver/Services/SierraNavigationProvider.swift` | NEW — NavigationCore wrapper |
| `Sierra/Driver/Views/TripNavigationView.swift` | Replace stub with real MapView + NavigationCore |
| `Sierra/Driver/Views/NavigationHUDOverlay.swift` | Add maneuver banner, speed limit sign |
| `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` | Add hasArrived, currentSpeedLimit, currentStepManeuver, traffic profile |
| `Sierra/FleetManager/Views/FleetLiveMapView.swift` | Add clustering, gradient trail, dynamic camera, Fit All button |
| `Sierra/FleetManager/Views/VehicleMapDetailSheet.swift` | Add mini map with route preview |
| `Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift` | Add speedSegments, fitAllVehicles |
| `Sierra/Shared/Views/AddressSearchSheet.swift` | Mapbox geocoding with MKLocalSearch fallback |
| `Sierra/Shared/Extensions/Collection+Safe.swift` | NEW — safe subscript |

---

## Acceptance Criteria

- [ ] Navigation map shows current position puck snapped to road with correct bearing
- [ ] Maneuver banner shows distance to next turn + turn icon (left/right/straight)
- [ ] Speed limit sign appears when route step has speed limit data
- [ ] Fleet map clusters vehicle annotations when zoomed out
- [ ] Breadcrumb trail shows speed-colored segments (green/yellow/red)
- [ ] Geofence circles show dashed border for restricted zones, pulse on recent violation
- [ ] VehicleMapDetailSheet shows mini map with origin → current → destination trail
- [ ] AddressSearchSheet returns real Indian addresses via Mapbox geocoding
- [ ] Arrival within 50m of destination auto-triggers POD sheet
- [ ] Fit All button on fleet map frames all active vehicles
