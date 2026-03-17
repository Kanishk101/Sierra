# Phase 6 — Admin Fleet Live Map (MapKit + Supabase Realtime)

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Fleet Manager views live in Sierra/FleetManager/Views/ and Sierra/FleetManager/ViewModels/.
MapKit is used here (NOT Mapbox) — admin only needs to see vehicles on a map, not navigate.
AppDataStore.liveVehicleLocations holds the real-time updated vehicle array (set up in Phase 3).
AppDataStore.subscribeToLiveVehicleLocations() is already wired in Phase 3.

## What to build
The admin fleet overview map. Shows all active vehicles as moving annotations in real time. Shows geofence zones as circles. Tapping a vehicle shows trip details. Supports creating geofences directly on the map.

## Task 1 — FleetLiveMapView (Sierra/FleetManager/Views/FleetLiveMapView.swift)

A Map view using MapKit's Map(coordinateRegion:) or the newer Map {} syntax (use iOS 17 Map API if Xcode target is iOS 17+).

Features:
  - Shows all vehicles from AppDataStore.liveVehicleLocations as custom annotations
    - Active/Busy vehicles: truck icon in blue with vehicle plate number label
    - Idle vehicles: truck icon in grey
    - In Maintenance vehicles: wrench icon in orange
  - Shows all geofences from AppDataStore.geofences as MKCircle overlays with semi-transparent fill
    - Warehouse type: blue fill
    - Delivery Point type: green fill
    - Restricted Zone type: red fill
    - Custom type: grey fill
  - Shows breadcrumb trail (polyline) for each active vehicle from AppDataStore.activeTripLocationHistory when that vehicle is selected
  - Auto-centers map on fleet centroid on first load
  - Tapping a vehicle annotation presents VehicleMapDetailSheet
  - "Create Geofence" floating button in top-right presents CreateGeofenceSheet
  - "Filter" button presents a filter sheet (show only Active, show only Idle, show all)

ViewModel: FleetLiveMapViewModel in Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift
  - Computed property: activeVehicles — filters liveVehicleLocations to only those with a current lat/lng
  - Method: loadGeofences() — fetches from GeofenceService
  - Method: fetchBreadcrumb(vehicleId, tripId) — calls VehicleLocationService.fetchLocationHistory(...)
  - Annotation update: observes AppDataStore.liveVehicleLocations changes and updates map annotations

## Task 2 — VehicleMapDetailSheet (Sierra/FleetManager/Views/VehicleMapDetailSheet.swift)
A bottom sheet (.sheet) shown when admin taps a vehicle annotation. Shows:
  - Vehicle name, plate, model, status badge
  - If on active trip:
    - Trip task_id, origin → destination
    - Driver name and phone number
    - Current speed (from latest vehicle_location_history row)
    - Distance from planned route (deviation_distance_m from latest route_deviation_events if any)
    - ETA (from trip.scheduled_end_date or calculated)
    - "View Full Trip" button → navigates to TripDetailView
    - "Send Alert to Driver" button → inserts notification for driver
  - If idle: "Assign to Trip" button → navigates to CreateTripView pre-filled with this vehicle

## Task 3 — CreateGeofenceSheet (Sierra/FleetManager/Views/CreateGeofenceSheet.swift)
A sheet for creating a geofence. Admin can either:
  a) Tap on the map to set center point, then adjust radius with a slider
  b) Enter an address and geocode it using Mapbox Geocoding API (same token from Info.plist)
     URL: https://api.mapbox.com/geocoding/v5/mapbox.places/{encoded_address}.json?access_token={token}

Fields:
  - Name (text field)
  - Type picker: Warehouse / Delivery Point / Restricted Zone / Custom
  - Radius slider: 100m to 5000m, labeled
  - Alert on Entry toggle
  - Alert on Exit toggle
  - Map preview showing the circle at selected location
  - Save button: calls GeofenceService.createGeofence(...) with the geofence_type field set

## Task 4 — GeofenceService update
Read the existing GeofenceService.swift and add:
  - createGeofence(name, description, latitude, longitude, radiusMeters, geofenceType, alertOnEntry, alertOnExit, createdByAdminId) async throws

## Task 5 — Wire FleetLiveMapView into existing FM navigation
Read FleetManagerTabView.swift and DashboardHomeView.swift.
Add FleetLiveMapView as a tab in FleetManagerTabView with a map.fill icon labeled "Live Map".
It should be the second tab, after the Dashboard tab.

## Output
Create all new files and update FleetManagerTabView.swift and GeofenceService.swift.
Commit all to main branch.
