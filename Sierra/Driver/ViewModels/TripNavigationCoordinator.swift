import Foundation
import CoreLocation
import MapboxDirections
import MapboxMaps

// MARK: - TripNavigationCoordinator
// Orchestrator — delegates to RouteEngine, DeviationDetector, GeofenceMonitor.
// All public properties + methods stay identical to the pre-refactor API
// so that views (NavigationHUDOverlay, TripNavigationContainerView,
// RouteSelectionSheet) compile with zero changes.

@MainActor
@Observable
final class TripNavigationCoordinator: NSObject, CLLocationManagerDelegate {

    // MARK: - Sub-components

    private let routeEngine = RouteEngine()
    private let deviationDetector = DeviationDetector()
    private let geofenceMonitor = GeofenceMonitor()

    // MARK: - Forwarded Public State (from RouteEngine)

    var currentRoute: MapboxDirections.Route? { routeEngine.currentRoute }
    var alternativeRoute: MapboxDirections.Route? { routeEngine.alternativeRoute }
    var currentStepInstruction: String { routeEngine.currentStepInstruction }
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
    let trip: Trip
    private(set) var currentLocation: CLLocation?
    private var locationManager: CLLocationManager?
    private var locationPublishTimer: Timer?
    private let locationPublishInterval: TimeInterval = 5.0
    private var currentStepIndex: Int = 0

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
        }
    }

    // MARK: - Delegated Route Methods

    func buildRoutes() async {
        await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func selectGreenRoute() {
        routeEngine.selectGreenRoute()
        currentStepIndex = 0
    }

    func rebuildRoutes() async {
        await routeEngine.rebuildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func addStop(latitude: Double, longitude: Double, name: String) async {
        await routeEngine.addStop(
            latitude: latitude, longitude: longitude, name: name,
            trip: trip, currentLocation: currentLocation
        )
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
        geofenceMonitor.register(
            AppDataStore.shared.geofences,
            locationManager: manager,
            currentLocation: currentLocation
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.updateLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NavCoordinator] Location error: \(error)")
    }

    // MARK: - Location Publishing

    func startLocationPublishing(vehicleId: UUID, driverId: UUID) {
        guard locationPublishTimer == nil else { return }
        locationPublishTimer = Timer.scheduledTimer(
            withTimeInterval: locationPublishInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let location = self.currentLocation else { return }
                let lat   = location.coordinate.latitude
                let lng   = location.coordinate.longitude
                let speed = location.speed > 0 ? location.speed * 3.6 : nil
                Task {
                    try? await VehicleLocationService.shared.publishLocation(
                        vehicleId: vehicleId, tripId: self.trip.id,
                        driverId: driverId, latitude: lat, longitude: lng, speedKmh: speed
                    )
                }
            }
        }
    }

    func stopLocationPublishing() {
        locationPublishTimer?.invalidate()
        locationPublishTimer = nil
        if let manager = locationManager {
            geofenceMonitor.stopMonitoring(locationManager: manager)
        }
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }

    // MARK: - Location Update

    func updateLocation(_ location: CLLocation) {
        currentLocation = location
        currentSpeedKmh = max(0, location.speed * 3.6)
        updateNavigationProgress(location: location)
        checkDeviation(from: location)
    }

    // MARK: - Navigation Progress

    private func updateNavigationProgress(location: CLLocation) {
        guard let route = routeEngine.currentRoute,
              let leg = route.legs.first else { return }

        let routeCoords = routeEngine.decodedRouteCoordinates
        if let lastCoord = routeCoords.last {
            let destLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let distToDest = location.distance(from: destLoc)
            routeEngine.distanceRemainingMetres = distToDest

            // Arrival detection: within 50m of destination
            if distToDest < 50 && !hasArrived {
                hasArrived = true
                NotificationCenter.default.post(name: .tripArrivedAtDestination, object: nil)
            }
        }
        let avgSpeed = route.distance / route.expectedTravelTime
        let remainingTime = avgSpeed > 0 ? routeEngine.distanceRemainingMetres / avgSpeed : 0
        routeEngine.estimatedArrivalTime = Date().addingTimeInterval(remainingTime)

        let steps = leg.steps
        for (idx, step) in steps.enumerated() {
            if let shape = step.shape, let firstCoord = shape.coordinates.first {
                let stepLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
                let distToStep = stepLoc.distance(from: location)
                if distToStep < 100 && idx >= currentStepIndex {
                    let wasNewStep = idx > currentStepIndex
                    currentStepIndex = idx
                    routeEngine.currentStepInstruction = step.instructions
                    currentStepManeuver = step.maneuverType.rawValue
                    if idx + 1 < steps.count {
                        nextStepInstruction = steps[idx + 1].instructions
                    } else {
                        nextStepInstruction = ""
                    }
                    currentSpeedLimit = nil
                    if wasNewStep || distToStep < 200 {
                        VoiceNavigationService.shared.announce(step.instructions)
                    }
                    break
                }
            }
        }
    }

    // MARK: - Deviation Check (delegates math to DeviationDetector)

    private func checkDeviation(from location: CLLocation) {
        let routeCoords = routeEngine.decodedRouteCoordinates
        guard routeCoords.count >= 2 else { return }

        let deviationMetres = deviationDetector.distanceFromRoute(
            location: location.coordinate,
            routeCoords: routeCoords
        )

        guard deviationMetres > deviationDetector.deviationThresholdMetres else {
            if routeEngine.hasDeviated { routeEngine.hasDeviated = false }
            return
        }

        routeEngine.hasDeviated = true

        guard deviationDetector.shouldRecordDeviation() else { return }
        deviationDetector.markDeviationRecorded()

        let driverId  = AuthManager.shared.currentUser?.id ?? UUID()
        let vehicleId = UUID(uuidString: trip.vehicleId ?? "") ?? UUID()
        Task {
            try? await RouteDeviationService.recordDeviation(
                tripId: trip.id, driverId: driverId, vehicleId: vehicleId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                deviationMetres: deviationMetres
            )
        }

        routeEngine.triggerRerouteFromCurrentLocation()
        Task { await routeEngine.buildRoutes(trip: trip, currentLocation: currentLocation) }
    }

    // MARK: - Geofence Delegates

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            await geofenceMonitor.handleGeofenceEvent(
                geofenceId: geofenceId, eventType: "Entry",
                vehicleIdStr: trip.vehicleId ?? "",
                tripId: trip.id, currentLocation: currentLocation
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in
            await geofenceMonitor.handleGeofenceEvent(
                geofenceId: geofenceId, eventType: "Exit",
                vehicleIdStr: trip.vehicleId ?? "",
                tripId: trip.id, currentLocation: currentLocation
            )
        }
    }
}

// MARK: - Notification.Name extension
extension Notification.Name {
    static let locationPermissionDenied = Notification.Name("locationPermissionDenied")
    static let tripArrivedAtDestination = Notification.Name("tripArrivedAtDestination")
}
