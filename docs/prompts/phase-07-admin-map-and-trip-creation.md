# Phase 07 — Fleet Live Map Search Fix + Uber-Style Route Creation in CreateTripView

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `FleetLiveMapView.swift`, `CreateTripView.swift`, possibly `TripService.swift`
- **SRS Reference:** §4.1.2 — Administrator shall create delivery tasks with origin, destination, and instructions; §4.1.5 — Live Vehicle Tracking on map; §4.1.2.6 — Assign vehicles to trips; §4.2.4 — Drivers navigate assigned routes

---

## Part 1: Fleet Live Map — Fix the Search Button

### Current State
`FleetLiveMapView.swift` has a search button in the toolbar but the search functionality either doesn't work or produces incorrect/empty results.

### Required Fix
The Live Map search should allow the fleet manager to search for a **vehicle by name or plate number** and centre the map on that vehicle's current location.

**Implementation approach:**
1. Add `@State private var searchText = ""` and `@State private var showSearchResults = false`
2. The search results pop up as a sheet (`.presentationDetents([.medium])`) listing vehicles that match the search — filtered by `name.localizedCaseInsensitiveContains(searchText) || licensePlate.localizedCaseInsensitiveContains(searchText)`
3. Each result row shows: vehicle name, plate, status badge, "On Trip" indicator if active
4. Tapping a result sets `mapViewModel.selectedVehicleId = vehicle.id` and dismisses the sheet — the map should already handle centering on the selected vehicle via the `selectedVehicleId` binding in `FleetLiveMapViewModel`

If `FleetLiveMapViewModel` does not have a `selectedVehicleId` mechanism, add it:
```swift
var selectedVehicleId: UUID? = nil  // setting this animates map to that vehicle
```
And in the map's `onReceive` or `onChange`, use `MKMapView.setRegion` or `MapCamera` to center on the vehicle's `currentLatitude`/`currentLongitude` when `selectedVehicleId` changes.

---

## Part 2: CreateTripView — Uber-Style Origin/Destination/Stops Route Planning

### Current State
`CreateTripView.swift` (27.5KB) has text fields for `origin` and `destination` that accept free-form strings. These strings feed into the map preview in `TripDetailDriverView` and into the Mapbox navigation in `TripNavigationContainerView`. However:
- There is no visual route-building UX
- The origin/destination don't resolve to actual GPS coordinates at creation time in a user-friendly way
- There is no concept of "stops" in the trip creation UI (even though `intermediateWaypoints` exists in `TripNavigationCoordinator`)

### Conceptual Model — Route vs Trip
Per the user's requirement: "a trip is one single journey from point A to point B while a route can comprise many trips". For this implementation, a **Trip** = one journey with an origin, optional stops, and a destination. Multi-trip routes are a future feature. Focus on making **single trip creation with optional stops** work correctly with real geocoded coordinates.

### Required UX: Address Autocomplete + Stops

Replace the current plain `TextField` origin/destination fields with a **Mapbox Geocoding-powered address autocomplete** flow:

#### Step 1: Origin Field
```swift
// When user taps "Origin" field, open address search sheet:
.sheet(isPresented: $showOriginSearch) {
    AddressSearchSheet(placeholder: "Search origin address...") { result in
        selectedOrigin = result  // GeocodedAddress struct with name, lat, lng
        trip.origin = result.displayName
        trip.originLatitude = result.latitude
        trip.originLongitude = result.longitude
    }
}
```

#### Step 2: Destination Field  
Same pattern as origin. The destination field is a tappable row that opens `AddressSearchSheet`.

#### Step 3: Stops (Optional)
Between origin and destination, show a `ForEach` of intermediate stops:
```swift
ForEach(stops.indices, id: \.self) { i in
    stopRow(stops[i], index: i)
}
// Add Stop button:
Button { showAddStopSearch = true } label: {
    Label("Add Stop", systemImage: "plus.circle")
        .font(.subheadline)
}
```
Stops are persisted in a local `@State var stops: [GeocodedAddress]` array. They are NOT stored in the `trips` table directly (the `trips` schema has no stops column). Instead, they influence the `route_polyline` field and are stored as JSON in a new `route_stops` text column if needed. For now, store the stops as a JSON-encoded string in `trip.notes` or a new column — **discuss with Kanishk before adding DB columns**. The simplest approach for v1: store stops in a `trip.deliveryInstructions` structured format, or simply pass them to the coordinator at navigation start.

#### Step 4: Map Preview
After origin + destination are set, show an interactive `MapKit` map preview in the creation form:
- Origin pin (green)
- Destination pin (red)
- Stop pins (orange, numbered)
- When all points are set, call Mapbox Directions API to fetch the route polyline and draw it on the map preview

```swift
Map {
    Annotation(origin.name, coordinate: originCoord) { originPin }
    ForEach(stops) { stop in Annotation(stop.name, coordinate: stop.coordinate) { stopPin } }
    Annotation(destination.name, coordinate: destCoord) { destinationPin }
    if let polyline { MapPolyline(polyline).stroke(.blue, lineWidth: 3) }
}
.frame(height: 200)
.clipShape(RoundedRectangle(cornerRadius: 14))
```

#### `AddressSearchSheet` — Reusable Component
Create `Sierra/Shared/Views/AddressSearchSheet.swift` — a reusable address search view:
- Uses Mapbox Geocoding API (existing `MBXAccessToken`)
- 500ms debounce on text input
- Returns `GeocodedAddress(displayName: String, shortName: String, latitude: Double, longitude: Double)`
- Reused by both `CreateTripView` and `NavigationHUDOverlay`'s add-stop sheet (Phase 08)

```swift
struct GeocodedAddress: Identifiable, Hashable {
    let id = UUID()
    let displayName: String   // full address for display
    let shortName: String     // short place name
    let latitude: Double
    let longitude: Double
}

struct AddressSearchSheet: View {
    let placeholder: String
    let onSelect: (GeocodedAddress) -> Void
    // ... Mapbox geocoding implementation using existing pattern from NavigationHUDOverlay.geocodeAddress()
}
```

---

## Constraints
- Use existing Mapbox token pattern: `Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String`
- All geocoding must be async with debounce — no blocking UI
- `CreateTripView` must still compile and produce a valid `Trip` object for `store.addTrip(_:)`
- `origin`, `originLatitude`, `originLongitude`, `destination`, `destinationLatitude`, `destinationLongitude`, `routePolyline` all already exist in the `Trip` model and DB — no schema changes needed
- The stops mechanism (for now) is UI-only during navigation — stored in `deliveryInstructions` as JSON if persistence is needed
- `@Observable` only, no `@Published`
- `AddressSearchSheet` must be a new file, not inline

## Verification Checklist
- [ ] Fleet live map search field finds vehicles by name or plate
- [ ] Tapping a search result centres the map on that vehicle
- [ ] `CreateTripView` origin field opens address search sheet
- [ ] `CreateTripView` destination field opens address search sheet
- [ ] Selected address populates lat/lng fields on `Trip`
- [ ] Map preview shows origin + destination pins
- [ ] "Add Stop" button appears and works
- [ ] Stop pins render on map preview
- [ ] Trip saved to Supabase with `origin_latitude`, `origin_longitude`, `destination_latitude`, `destination_longitude` populated
- [ ] Build clean, zero warnings
