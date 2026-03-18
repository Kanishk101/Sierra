# PhaseMap2 - Driver Geofencing + Trip Detail Flow

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
CoreLocation is used for geofencing (CLCircularRegion). No Mapbox needed for this feature.
AppDataStore.geofences already contains all geofence data loaded at login.

## Read these files first — mandatory
- Sierra/Driver/Views/TripDetailDriverView.swift
- Sierra/Driver/Views/TripNavigationContainerView.swift
- Sierra/Driver/ViewModels/TripNavigationCoordinator.swift
- Sierra/Shared/Services/AppDataStore.swift

## Task 1 — CLCircularRegion Geofence Monitoring at Trip Start

When the driver starts navigation, all active geofences from AppDataStore.geofences must be
registered as CLCircularRegion objects with the existing CLLocationManager in TripNavigationCoordinator.

In TripNavigationCoordinator.swift, add this method:
  func registerGeofences(_ geofences: [Geofence]) {
    guard let manager = locationManager else { return }
    // Clear any existing monitored regions first
    for region in manager.monitoredRegions {
      manager.stopMonitoring(for: region)
    }
    // Register each active geofence
    for geofence in geofences where geofence.isActive {
      let center = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
      let region = CLCircularRegion(center: center, radius: geofence.radiusMeters, identifier: geofence.id.uuidString)
      region.notifyOnEntry = geofence.alertOnEntry
      region.notifyOnExit = geofence.alertOnExit
      manager.startMonitoring(for: region)
    }
  }

Add CLLocationManagerDelegate methods to TripNavigationCoordinator for region events:
  nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard let geofenceId = UUID(uuidString: region.identifier) else { return }
    Task { @MainActor in
      await self.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Entry")
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard let geofenceId = UUID(uuidString: region.identifier) else { return }
    Task { @MainActor in
      await self.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Exit")
    }
  }

  private func handleGeofenceEvent(geofenceId: UUID, eventType: String) async {
    guard let vehicleIdStr = trip.vehicleId, let vehicleId = UUID(uuidString: vehicleIdStr) else { return }
    let driverId = AuthManager.shared.currentUser?.id ?? UUID()
    // Insert geofence event to Supabase
    do {
      try await GeofenceEventService.addGeofenceEvent(GeofenceEvent(
        id: UUID(),
        geofenceId: geofenceId,
        vehicleId: vehicleId,
        tripId: trip.id,
        driverId: driverId,
        eventType: eventType == "Entry" ? .entry : .exit,
        latitude: currentLocation?.coordinate.latitude ?? 0,
        longitude: currentLocation?.coordinate.longitude ?? 0,
        triggeredAt: Date(),
        createdAt: Date()
      ))
    } catch {
      print("[NavCoordinator] Geofence event insert failed (non-fatal): \(error)")
    }
    // Insert notification for fleet managers (non-fatal)
    let fmIds = AppDataStore.shared.staff.filter { $0.role == .fleetManager && $0.status == .active }.map { $0.id }
    for fmId in fmIds {
      try? await NotificationService.shared.insertNotification(
        recipientId: fmId,
        type: .geofenceViolation,
        title: "Geofence \(eventType)",
        body: "Vehicle \(vehicleIdStr) \(eventType == \"Entry\" ? \"entered\" : \"exited\") a monitored zone",
        entityType: "geofence",
        entityId: geofenceId
      )
    }
  }

In startLocationTracking(), after manager.startUpdatingLocation():
  registerGeofences(AppDataStore.shared.geofences)

In stopLocationPublishing(), after stopping updates:
  // Unregister all monitored regions
  if let manager = locationManager {
    for region in manager.monitoredRegions {
      manager.stopMonitoring(for: region)
    }
  }

Check GeofenceEvent model in Sierra/Shared/Models/GeofenceEvent.swift for exact init signature.
Check GeofenceEventService for the exact method signature (may be addGeofenceEvent or similar).

## Task 2 — Wire TripDetailDriverView to StartTripSheet and Navigation

Read TripDetailDriverView.swift completely.

The view shows the trip details. Verify these flows are correctly wired:
- If trip.status == .scheduled AND trip.preInspectionId != nil: show "Start Trip" button that presents StartTripSheet
- If trip.status == .scheduled AND trip.preInspectionId == nil: show "Begin Pre-Trip Inspection" button
- If trip.status == .active: show "Navigate" button that presents TripNavigationContainerView
- If trip.status == .completed: read-only

If any of these navigation flows are missing or broken in the file, implement them.

The StartTripSheet needs:
  StartTripSheet(tripId: trip.id) {
    // dismiss sheet and navigate to TripNavigationContainerView
  }

The TripNavigationContainerView needs to be presented as fullScreenCover:
  .fullScreenCover(isPresented: $showNavigation) {
    TripNavigationContainerView(trip: trip)
  }

## Task 3 — DriverHomeView: Show Active and Scheduled Trips

Read Sierra/Driver/Views/DriverHomeView.swift.

Verify that the driver's home screen correctly shows:
1. Their currently assigned Scheduled or Active trip prominently at the top
2. A "View Trip" or "Navigate" button that opens TripDetailDriverView
3. An availability toggle (Available / Unavailable) that calls AppDataStore.updateDriverAvailability

AppDataStore has: func activeTrip(forDriverId:) -> Trip? for fetching the active trip.
The current user's ID is AuthManager.shared.currentUser?.id.

If TripDetailDriverView is not navigated to from DriverHomeView, add the navigation link.

## Rules
- GeofenceEvent and GeofenceEventService: read the actual files before using — check exact property names
- NotificationService: wrap all calls in non-fatal try? (geofence notifications should never block the flow)
- CLCircularRegion monitoring: max 20 regions enforced by iOS — if more than 20 geofences, register only the 20 closest to the driver's current location
- Do NOT remove or change anything existing in any file
- Read every file before modifying

## Output
Update TripNavigationCoordinator.swift, TripDetailDriverView.swift, DriverHomeView.swift.
Commit to main branch.
