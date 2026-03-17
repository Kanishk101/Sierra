# Phase 6 Safeguards — Admin Fleet Map
## Attach these instructions at the END of your Phase 6 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Map view must not be destroyed on tab switch

The MapKit Map view is expensive to initialise. If FleetLiveMapView is inside a TabView and uses the default SwiftUI lifecycle, the view gets destroyed and recreated every time the admin switches tabs — each recreation is a new map load counted by Mapbox (if MapboxMaps is used here) or an expensive MapKit reinitialisation.

FleetLiveMapView must be kept alive using one of these patterns:
  Option A (preferred): Wrap in a @StateObject FleetLiveMapViewModel at the TabView level, so the view model and its data persist even when the tab is not visible
  Option B: Use UIViewControllerRepresentable for the map so UIKit lifecycle rules apply (UIKit controllers are not destroyed on tab switch)

Verify the Map view is not re-initialised on every tab switch by checking there is no new Map() constructor inside the view body (only in .onAppear for initial region setup).

## SAFEGUARD 2 — Vehicle annotations must update IN PLACE, not replace the entire annotation set

If the implementation replaces the entire annotations array every time a vehicle moves, MapKit re-renders all annotations causing visible flicker for every other vehicle. Update the specific vehicle's annotation coordinate only.

For UIViewControllerRepresentable approach: in updateUIViewController, find the existing annotation for the updated vehicle by comparing IDs and update its coordinate.

For the SwiftUI Map approach: use @State var vehicleAnnotations: [VehicleAnnotation] and update individual elements:
  if let index = vehicleAnnotations.firstIndex(where: { $0.id == updatedVehicle.id }) {
    vehicleAnnotations[index].coordinate = CLLocationCoordinate2D(
      latitude: updatedVehicle.currentLatitude ?? 0,
      longitude: updatedVehicle.currentLongitude ?? 0
    )
  }

Never do: vehicleAnnotations = buildAllAnnotationsFromScratch() on every Realtime update.

## SAFEGUARD 3 — Geofence address geocoding in CreateGeofenceSheet must be debounced

Same 500ms debounce rule as Phases 4 and 5. The Mapbox Geocoding API call fires only after the user stops typing for 500ms. One address lookup = one API call.

## SAFEGUARD 4 — Geofence MKCircle overlays must not be re-added on every view update

MKCircle overlays for geofences should be added once when geofences are first loaded and only updated when a geofence is added or removed. Never clear and re-add all overlays in a loop triggered by any view state change.

Pattern:
  func loadGeofences() {
    let geofences = await GeofenceService.shared.fetchAll()
    let newOverlays = geofences.map { MKCircle(center: ..., radius: $0.radiusMeters) }
    mapView.addOverlays(newOverlays)  // add once, not on every update
  }

## SAFEGUARD 5 — FleetLiveMapViewModel must fetch breadcrumb only when a vehicle is selected

fetchBreadcrumb(vehicleId:tripId:) should ONLY be called when the admin taps a vehicle annotation — not on view load, not for all vehicles, not on a timer.

The breadcrumb fetch returns potentially thousands of rows (if a trip has been running for hours). Loading breadcrumbs for all vehicles simultaneously would be a large number of expensive DB queries. Load on-demand only.

## SAFEGUARD 6 — CreateGeofenceView must not allow saving without valid coordinates

Before calling GeofenceService.createGeofence(), validate:
  - latitude is not 0.0 and longitude is not 0.0 (default CLLocationCoordinate2D values)
  - radius is between 100 and 5000 (the slider bounds)
  - name is not empty

If the admin accidentally saves a geofence at (0,0) with radius 0, it pollutes the geofences table and registers false entry/exit events for vehicles near the equator/prime meridian.

## SAFEGUARD 7 — Only filter liveVehicleLocations for map display — never mutate the source array

AppDataStore.liveVehicleLocations is the source of truth. FleetLiveMapViewModel.activeVehicles is a filtered computed property derived from it. Never modify or sort liveVehicleLocations directly from the map view model. The map view model is read-only with respect to AppDataStore state.

## VERIFICATION CHECKLIST — Before committing

- [ ] Map view not re-created on tab switch (StateObject at parent level or UIKit lifecycle)
- [ ] Vehicle annotations updated in-place, not replaced wholesale
- [ ] Geocoding in CreateGeofenceSheet has 500ms debounce
- [ ] Geofence MKCircle overlays added once, not on every state change
- [ ] fetchBreadcrumb only called on vehicle annotation tap
- [ ] Geofence save validates non-zero coordinates and non-empty name
- [ ] liveVehicleLocations never mutated from FleetLiveMapViewModel
