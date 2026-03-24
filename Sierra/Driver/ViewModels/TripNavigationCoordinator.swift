import Foundation
import CoreLocation
import MapboxDirections
import MapboxMaps

// MARK: - TripNavigationCoordinator
// Orchestrator — delegates to RouteEngine, DeviationDetector, GeofenceMonitor.

@MainActor
@Observable
final class TripNavigationCoordinator: NSObject, CLLocationManagerDelegate {

    // MARK: - Sub-components
    private let routeEngine        = RouteEngine()
    private let deviationDetector  = DeviationDetector()
    private let geofenceMonitor    = GeofenceMonitor()
    let trafficService      = TrafficIncidentService()

    // MARK: - Forwarded Public State (from RouteEngine)
    var currentRoute: MapboxDirections.Route?   { routeEngine.currentRoute }
    var alternativeRoute: MapboxDirections.Route? { routeEngine.alternativeRoute }
    var currentStepInstruction: String          { routeEngine.currentStepInstruction }
    var displayedRouteCoordinates: [CLLocationCoordinate2D] { routeEngine.decodedRouteCoordinates }
    var hasRenderableRoute: Bool                { routeEngine.decodedRouteCoordinates.count >= 2 }
    var isUsingStoredRouteFallback: Bool        { routeEngine.isUsingStoredRouteFallback }
    var routeEngineError: String?               { routeEngine.lastBuildError }
    var activeIncidents: [TrafficIncident]      { trafficService.activeIncidents }

    var distanceRemainingMetres: Double {
        get { routeEngine.distanceRemainingMetres }
        set { routeEngine.distanceRemainingMetres = newValue }
    }
    var estimatedArrivalTime: Date? {
        get { routeEngine.estimatedArrivalTime }
        set { routeEngine.estimatedArrivalTime = newValue }
    }
    var hasDeviated: Bool {
        get { routeEngine.hasDeviated }
        set { routeEngine.hasDeviated = newValue }
    }
    var avoidTolls: Bool {
        get { routeEngine.avoidTolls }
        set { routeEngine.avoidTolls = newValue }
    }
    var avoidHighways: Bool {
        get { routeEngine.avoidHighways }
        set { routeEngine.avoidHighways = newValue }
    }
    // MARK: - Coordinator-owned State
    var isNavigating: Bool = false
    var currentSpeedKmh: Double = 0
    var hasArrived: Bool = false
    var currentSpeedLimit: Int?
    var currentStepManeuver: String = ""
    var nextStepInstruction: String = ""

    /// Returns a value in [0.0, 1.0] representing how far along the route the driver is.
    /// 0.0 = at origin, 1.0 = arrived at destination.
    var routeProgressFraction: Double {
        guard routeEngine.totalRouteDistanceMetres > 0 else { return 0 }
        let distanceTraveled = routeEngine.totalRouteDistanceMetres - distanceRemainingMetres
        return max(0, min(1, distanceTraveled / routeEngine.totalRouteDistanceMetres))
    }

    let trip: Trip
    private(set) var currentLocation: CLLocation?
    private(set) var breadcrumbCoordinates: [CLLocationCoordinate2D] = []
    private var locationManager: CLLocationManager?
    private var locationPublishTimer: Timer?
    private let locationPublishInterval: TimeInterval = 5.0
    private var currentStepIndex: Int = 0
    private var lastStepChangeLocation: CLLocation?  // ISSUE-13 FIX: hysteresis tracking
    private var lastRerouteRequestedAt: Date = .distantPast  // Fix 9: reroute cooldown

    // MARK: - Init / deinit
    init(trip: Trip) {
        self.trip = trip
        super.init()
    }

    deinit {
        MainActor.assumeIsolated {
            locationPublishTimer?.invalidate()
            locationPublishTimer = nil
            locationManager?.stopUpdatingLocation()
            locationManager = nil
            trafficService.stopPolling()
        }
    }

    // MARK: - Route Methods
    func buildRoutes() async {
        await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation)
    }
    // ISSUE-19 FIX: Renamed from selectGreenRoute
    func swapAlternativeRoute() {
        routeEngine.swapAlternativeRoute()
        currentStepIndex = 0
    }
    func rebuildRoutes() async {
        await routeEngine.rebuildRoutes(trip: trip, currentLocation: currentLocation)
    }
    func addStop(latitude: Double, longitude: Double, name: String) async {
        await routeEngine.addStop(latitude: latitude, longitude: longitude, name: name,
                                   trip: trip, currentLocation: currentLocation)
    }

    // MARK: - Location Manager
    func startLocationTracking() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = 5

        let status = manager.authorizationStatus
        switch status {
        case .denied, .restricted:
            NotificationCenter.default.post(name: .locationPermissionDenied, object: nil)
            return
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }

        manager.startUpdatingLocation()
        locationManager = manager
        isNavigating = true

        // GAP-1: Start traffic incident polling
        trafficService.startPolling(routeCoordinates: routeEngine.decodedRouteCoordinates)
        geofenceMonitor.register(AppDataStore.shared.geofences,
                                  locationManager: manager,
                                  currentLocation: currentLocation)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.updateLocation(location) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NavCoordinator] Location error: \(error)")
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways:
                // Re-register geofences now that we have full permission
                self.geofenceMonitor.register(
                    AppDataStore.shared.geofences,
                    locationManager: manager,
                    currentLocation: self.currentLocation
                )
            case .denied, .restricted:
                NotificationCenter.default.post(name: .locationPermissionDenied, object: nil)
            case .authorizedWhenInUse:
                // Prompt upgrade to Always for background tracking
                manager.requestAlwaysAuthorization()
            default:
                break
            }
        }
    }

    // MARK: - Location Publishing
    // BUG-11 FIX: Removed nested Task, BUG-23 FIX: Skip publish when stationary
    private var lastPublishedLocation: CLLocation?
    func startLocationPublishing(vehicleId: UUID, driverId: UUID) {
        guard locationPublishTimer == nil else { return }
        locationPublishTimer = Timer.scheduledTimer(withTimeInterval: locationPublishInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let location = self.currentLocation else { return }
                // ISSUE-23 FIX: Only publish if moving (>1 m/s) or >10m from last published
                if let last = self.lastPublishedLocation,
                   location.speed < 1.0,
                   location.distance(from: last) < 10 { return }
                self.lastPublishedLocation = location
                let lat   = location.coordinate.latitude
                let lng   = location.coordinate.longitude
                let speed = location.speed > 0 ? location.speed * 3.6 : nil
                try? await VehicleLocationService.shared.publishLocation(
                    vehicleId: vehicleId, tripId: self.trip.id,
                    driverId: driverId, latitude: lat, longitude: lng, speedKmh: speed
                )
            }
        }
    }

    func stopLocationPublishing() {
        locationPublishTimer?.invalidate()
        locationPublishTimer = nil
        if let manager = locationManager { geofenceMonitor.stopMonitoring(locationManager: manager) }
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }

    // MARK: - Location Update
    func updateLocation(_ location: CLLocation) {
        currentLocation = location
        appendBreadcrumbCoordinateIfNeeded(location.coordinate)
        currentSpeedKmh = max(0, location.speed * 3.6)
        trafficService.updateLocation(location)
        updateNavigationProgress(location: location)
        checkDeviation(from: location)

        // GAP-1: Auto-reroute on severe incident nearby
        if trafficService.hasSevereIncidentNearby(),
           Date().timeIntervalSince(lastRerouteRequestedAt) > TripConstants.rerouteCooldownSeconds {
            lastRerouteRequestedAt = Date()
            Task { await rebuildRoutes() }
        }
    }

    // MARK: - Navigation Progress
    // BUG-06 FIX: Use polyline-walking distance instead of crow-fly for route remaining
    // ISSUE-36 FIX: Only announce on new step transitions
    private func updateNavigationProgress(location: CLLocation) {
        let routeCoords = routeEngine.decodedRouteCoordinates
        guard routeCoords.count >= 2 else { return }

        // BUG-06 FIX: Find closest point on polyline and sum remaining segment lengths
        var minDist = Double.greatestFiniteMagnitude
        var closestSegIndex = 0
        for i in 0..<(routeCoords.count - 1) {
            let segStart = CLLocation(latitude: routeCoords[i].latitude, longitude: routeCoords[i].longitude)
            let dist = location.distance(from: segStart)
            if dist < minDist {
                minDist = dist
                closestSegIndex = i
            }
        }

        // Sum remaining segment lengths from closest point forward
        var remainingDist: Double = 0
        for i in closestSegIndex..<(routeCoords.count - 1) {
            let a = CLLocation(latitude: routeCoords[i].latitude, longitude: routeCoords[i].longitude)
            let b = CLLocation(latitude: routeCoords[i + 1].latitude, longitude: routeCoords[i + 1].longitude)
            remainingDist += a.distance(from: b)
        }
        routeEngine.distanceRemainingMetres = remainingDist

        // Fix 10: Extract speed limit from route annotations
        if let speedLimits = routeEngine.currentRoute?.legs.first?.segmentMaximumSpeedLimits,
           closestSegIndex < speedLimits.count,
           let measurement = speedLimits[closestSegIndex] {
            currentSpeedLimit = Int(measurement.converted(to: .kilometersPerHour).value)
        } else {
            currentSpeedLimit = nil
        }

        // Arrival check using route distance, not crow-fly
        if remainingDist < 50 && !hasArrived {
            hasArrived = true
            NotificationCenter.default.post(name: .tripArrivedAtDestination, object: nil)
        }

        // ETA using route-average speed when available, otherwise current speed / a sane fallback.
        let avgSpeed: Double
        if let route = routeEngine.currentRoute, route.expectedTravelTime > 0 {
            avgSpeed = route.distance / route.expectedTravelTime
        } else if location.speed > 1 {
            avgSpeed = location.speed
        } else {
            avgSpeed = 35.0 / 3.6
        }
        let remainingTime = avgSpeed > 0 ? remainingDist / avgSpeed : 0
        routeEngine.estimatedArrivalTime = Date().addingTimeInterval(remainingTime)

        guard let route = routeEngine.currentRoute, let leg = route.legs.first else {
            if routeEngine.currentStepInstruction.isEmpty {
                routeEngine.currentStepInstruction = "Follow the highlighted trip route"
            }
            return
        }

        // Step detection
        let steps = leg.steps
        for (idx, step) in steps.enumerated() {
            if let shape = step.shape, let firstCoord = shape.coordinates.first {
                let stepLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
                let distToStep = stepLoc.distance(from: location)
                if distToStep < 100 && idx >= currentStepIndex {
                    let wasNewStep = idx > currentStepIndex
                    // ISSUE-13 FIX: Require minimum travel distance before accepting new step
                    if wasNewStep, let lastChange = lastStepChangeLocation,
                       location.distance(from: lastChange) < TripConstants.stepChangeHysteresisMetres {
                        continue  // Too close to last step change — likely oscillation
                    }
                    currentStepIndex = idx
                    if wasNewStep { lastStepChangeLocation = location }
                    routeEngine.currentStepInstruction = step.instructions
                    currentStepManeuver = step.maneuverType.rawValue
                    nextStepInstruction = idx + 1 < steps.count ? steps[idx + 1].instructions : ""
                    // ISSUE-36 FIX: Only announce on new step transitions
                    if wasNewStep {
                        VoiceNavigationService.shared.announce(step.instructions)
                    }
                    break
                }
            }
        }
    }

    // MARK: - Deviation Check
    private func checkDeviation(from location: CLLocation) {
        let routeCoords = routeEngine.decodedRouteCoordinates
        guard routeCoords.count >= 2 else { return }
        let deviationMetres = deviationDetector.distanceFromRoute(
            location: location.coordinate, routeCoords: routeCoords
        )
        guard deviationMetres > deviationDetector.deviationThresholdMetres else {
            if routeEngine.hasDeviated { routeEngine.hasDeviated = false }
            return
        }
        routeEngine.hasDeviated = true
        guard deviationDetector.shouldRecordDeviation() else { return }
        deviationDetector.markDeviationRecorded()
        // BUG-10 FIX: Don't generate random UUIDs for safety-critical records
        guard let driverId = AuthManager.shared.currentUser?.id else {
            print("[NavCoordinator] No auth user — skipping deviation record")
            return
        }
        guard let vehicleIdStr = trip.vehicleId, let vehicleId = UUID(uuidString: vehicleIdStr) else { return }
        Task {
            try? await RouteDeviationService.recordDeviation(
                tripId: trip.id, driverId: driverId, vehicleId: vehicleId,
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                deviationMetres: deviationMetres
            )
        }
        // Fix 9: Cooldown — don't reroute more than once every 30 seconds
        guard Date().timeIntervalSince(lastRerouteRequestedAt) > TripConstants.rerouteCooldownSeconds else {
            return
        }
        lastRerouteRequestedAt = Date()
        routeEngine.triggerRerouteFromCurrentLocation()
        Task { await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation) }
    }

    // MARK: - Geofence Delegates
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            await geofenceMonitor.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Entry",
                                                       vehicleIdStr: trip.vehicleId ?? "",
                                                       tripId: trip.id, currentLocation: currentLocation)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            await geofenceMonitor.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Exit",
                                                       vehicleIdStr: trip.vehicleId ?? "",
                                                       tripId: trip.id, currentLocation: currentLocation)
        }
    }

    private func appendBreadcrumbCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        guard let last = breadcrumbCoordinates.last else {
            breadcrumbCoordinates = [coordinate]
            return
        }

        let previous = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard current.distance(from: previous) >= 8 else { return }
        breadcrumbCoordinates.append(coordinate)
    }
}

// MARK: - Notification.Name extension
extension Notification.Name {
    static let locationPermissionDenied = Notification.Name("locationPermissionDenied")
    static let tripArrivedAtDestination = Notification.Name("tripArrivedAtDestination")
}
