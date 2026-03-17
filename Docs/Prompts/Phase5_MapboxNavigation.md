# Phase 5 — Mapbox In-App Navigation (Driver)

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Mapbox SPM packages are already installed: MapboxMaps, MapboxNavigation, MapboxCoreNavigation.
The Mapbox public access token is stored in Info.plist under key "MBXAccessToken".
Background Location and Background Fetch capabilities are enabled.

This phase builds the complete in-app navigation experience for the driver. Everything happens inside the Sierra app. No external map app is ever launched.

## Architecture
TripNavigationView is a UIViewControllerRepresentable that wraps Mapbox's NavigationViewController. This is the correct approach because NavigationViewController is a UIKit view controller, not a SwiftUI view. The wrapper bridges it into SwiftUI.

## Task 1 — TripNavigationCoordinator (Sierra/Driver/ViewModels/TripNavigationCoordinator.swift)
An ObservableObject that manages all navigation state:

Properties:
  var currentRoute: Route?
  var alternativeRoute: Route?
  var selectedRouteIndex: Int = 0  // 0 = fastest, 1 = green
  var isNavigating: Bool = false
  var currentStepInstruction: String = ""
  var distanceRemainingMetres: Double = 0
  var estimatedTimeRemainingSeconds: Double = 0
  var estimatedArrivalTime: Date?
  var currentSpeedKmh: Double = 0
  var hasDeviated: Bool = false
  var deviationDistanceMetres: Double = 0
  var waypoints: [Waypoint] = []
  var avoidTolls: Bool = false
  var avoidHighways: Bool = false
  var trip: Trip  // injected

Methods:
  func buildRoutes() async — builds RouteOptions from trip.originLatitude/Longitude to trip.destinationLatitude/Longitude, adds any waypoints, sets roadClassesToAvoid based on avoidTolls and avoidHighways, requests routes from Mapbox, assigns currentRoute (fastest) and alternativeRoute (shortest distance = green)

  func startLocationPublishing(vehicleId: UUID, driverId: UUID) — starts a Timer every 5 seconds that calls AppDataStore.publishDriverLocation(...) with current GPS position

  func stopLocationPublishing() — invalidates the timer

  func checkDeviation(from location: CLLocation) — computes distance from location to currentRoute's polyline. If > 200m and more than 60s since last deviation recorded, calls RouteDeviationService.recordDeviation(...)

## Task 2 — TripNavigationView (Sierra/Driver/Views/TripNavigationView.swift)
A UIViewControllerRepresentable wrapping NavigationViewController.

Implementation:
  - makeUIViewController: create NavigationService with the selected route (from TripNavigationCoordinator.currentRoute), create NavigationViewController(navigationService:), set the delegate to the Coordinator
  - Coordinator class implements NavigationViewControllerDelegate:
    - navigationViewController(_:didUpdate:with:routeProgress:) — update TripNavigationCoordinator properties: currentStepInstruction, distanceRemainingMetres, estimatedTimeRemainingSeconds, estimatedArrivalTime, currentSpeedKmh. Also call checkDeviation(from: location)
    - navigationViewControllerDidDismiss — call stopLocationPublishing(), set isNavigating = false
    - navigationViewController(_:didArriveAt:) — set isNavigating = false, call stopLocationPublishing(), post notification to show ProofOfDeliveryView
  - The NavigationViewController must have:
    showsEndOfRouteFeedback = false (we handle trip completion ourselves)
    navigationService set up with MapboxNavigationService

The view must fill the full screen. No navigation bars from SwiftUI should overlay it.

## Task 3 — NavigationHUDOverlay (Sierra/Driver/Views/NavigationHUDOverlay.swift)
A SwiftUI overlay view shown on top of TripNavigationView that Sierra controls (not Mapbox's default HUD). Shown as a ZStack overlay.

Shows:
  - Top banner: current step instruction text (large, readable)
  - Left panel: distance remaining (formatted as "1.2 km" or "340 m"), ETA time (formatted as "2:45 PM"), time remaining ("12 min")
  - Speed indicator: current speed in km/h with a subtle circle
  - Bottom bar: "SOS" button (red), "Report Incident" button, "Add Stop" button, "End Trip" button
  - If hasDeviated: yellow banner "Off Route — Recalculating..."

SOS button: presents SOSAlertSheet (built in Phase 8)
Report Incident: presents IncidentReportSheet (built in Phase 8)
Add Stop: text field sheet to enter a new waypoint address, geocodes it using Mapbox Geocoding API, adds Waypoint to coordinator, rebuilds route
End Trip: confirmation alert, then calls ProofOfDeliveryView flow

## Task 4 — TripNavigationContainerView (Sierra/Driver/Views/TripNavigationContainerView.swift)
The parent view that composes TripNavigationView + NavigationHUDOverlay:
  ZStack {
    TripNavigationView(coordinator: coordinator)
    NavigationHUDOverlay(coordinator: coordinator)
  }
  .ignoresSafeArea()
  .onAppear { coordinator.buildRoutes(); coordinator.startLocationPublishing(...) }
  .onDisappear { coordinator.stopLocationPublishing() }

## Important
- Everything is 100% in-app. Never call UIApplication.shared.open() with a maps URL.
- Voice guidance is provided automatically by NavigationViewController — do not add custom voice
- Mapbox handles rerouting, incident overlays, and traffic automatically once NavigationViewController is running
- The green route is determined by picking the route alternative with the shortest total distance from the Mapbox response alternatives array

## Output
Create all files listed above. Commit to main branch. The code must compile with the Mapbox SPM dependencies installed.
