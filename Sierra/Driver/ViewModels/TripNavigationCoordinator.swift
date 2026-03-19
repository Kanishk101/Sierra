import Foundation
import CoreLocation
import MapboxDirections
import MapboxMaps

// MARK: - TripNavigationCoordinator

@MainActor
@Observable
final class TripNavigationCoordinator: NSObject, CLLocationManagerDelegate {

    // MARK: - Public state

    var currentRoute: MapboxDirections.Route?
    var alternativeRoute: MapboxDirections.Route?
    var isNavigating: Bool = false
    var currentStepInstruction: String = ""
    var distanceRemainingMetres: Double = 0
    var estimatedArrivalTime: Date?
    var currentSpeedKmh: Double = 0
    var hasDeviated: Bool = false
    var avoidTolls: Bool = false
    var avoidHighways: Bool = false
    let trip: Trip

    // MARK: - Private

    private var locationPublishTimer: Timer?
    private let locationPublishInterval: TimeInterval = 5.0
    // hasBuiltRoutes is only set to true AFTER a successful route assignment,
    // not at the start of the build attempt. This allows retry after transient
    // network/API failures without requiring a new TripNavigationCoordinator instance.
    private var hasBuiltRoutes: Bool = false
    private var lastDeviationRecordedAt: Date = .distantPast
    private let deviationCooldownSeconds: TimeInterval = 60.0
    private var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    private(set) var currentLocation: CLLocation?
    private var locationManager: CLLocationManager?
    private var currentStepIndex: Int = 0

    // MARK: - Init / deinit

    init(trip: Trip) {
        self.trip = trip
        super.init()
    }

    deinit {
        MainActor.assumeIsolated {
            // Always invalidate the timer to prevent retain cycle and battery drain
            // even if stopLocationPublishing() was not called (app kill, forced dismiss).
            locationPublishTimer?.invalidate()
            locationPublishTimer = nil
            locationManager?.stopUpdatingLocation()
            locationManager = nil
        }
    }

    // MARK: - Add Stop

    func addStop(latitude: Double, longitude: Double, name: String) async {
        hasBuiltRoutes = false
        await buildRoutes()
    }

    // MARK: - Route Building
    // hasBuiltRoutes is set to true ONLY on success so retries work.

    func buildRoutes() async {
        guard !hasBuiltRoutes else { return }

        guard let originLat = trip.originLatitude,
              let originLng = trip.originLongitude,
              let destLat = trip.destinationLatitude,
              let destLng = trip.destinationLongitude else {
            print("[NavCoordinator] Missing trip coordinates")
            return
        }

        let originWP = Waypoint(coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng))
        let destWP   = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng))

        let options = RouteOptions(waypoints: [originWP, destWP])
        options.includesAlternativeRoutes = true
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6

        var avoidClasses: RoadClasses = []
        if avoidTolls    { avoidClasses.insert(.toll) }
        if avoidHighways { avoidClasses.insert(.motorway) }
        if !avoidClasses.isEmpty { options.roadClassesToAvoid = avoidClasses }

        do {
            let response: RouteResponse = try await withCheckedThrowingContinuation { continuation in
                Directions.shared.calculate(options) { result in
                    switch result {
                    case .success(let resp): continuation.resume(returning: resp)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
            }

            let routes = response.routes ?? []

            if let fastestIndex = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }) {
                let fastest = routes[fastestIndex]
                currentRoute = fastest
                distanceRemainingMetres = fastest.distance
                estimatedArrivalTime = Date().addingTimeInterval(fastest.expectedTravelTime)
                if let firstStep = fastest.legs.first?.steps.first {
                    currentStepInstruction = firstStep.instructions
                }
                if routes.count > 1 {
                    alternativeRoute = routes.enumerated().first(where: { $0.offset != fastestIndex })?.element
                }
            }

            if let shape = currentRoute?.shape {
                decodedRouteCoordinates = shape.coordinates
            }

            // Only mark built AFTER successful route assignment
            hasBuiltRoutes = true

        } catch {
            // Do NOT set hasBuiltRoutes = true — leaves retry open
            print("[NavCoordinator] Route build failed (will retry on next buildRoutes() call): \(error)")
        }
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
            // Post notification so UI can show a settings alert
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
        registerGeofences(AppDataStore.shared.geofences)
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
            for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
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
        guard let route = currentRoute, let leg = route.legs.first else { return }
        if let lastCoord = decodedRouteCoordinates.last {
            let destLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            distanceRemainingMetres = location.distance(from: destLoc)
        }
        let avgSpeed = route.distance / route.expectedTravelTime
        let remainingTime = avgSpeed > 0 ? distanceRemainingMetres / avgSpeed : 0
        estimatedArrivalTime = Date().addingTimeInterval(remainingTime)
        let steps = leg.steps
        for (idx, step) in steps.enumerated() {
            if let shape = step.shape, let firstCoord = shape.coordinates.first {
                let stepLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
                if stepLoc.distance(from: location) < 100 && idx >= currentStepIndex {
                    currentStepIndex = idx
                    currentStepInstruction = step.instructions
                    break
                }
            }
        }
    }

    // MARK: - Deviation Check

    func checkDeviation(from location: CLLocation) {
        guard decodedRouteCoordinates.count >= 2 else { return }
        let deviationMetres = computeMinDistanceToRoute(
            location: location.coordinate, routeCoords: decodedRouteCoordinates
        )
        guard deviationMetres > 200 else { if hasDeviated { hasDeviated = false }; return }
        hasDeviated = true
        guard Date().timeIntervalSince(lastDeviationRecordedAt) > deviationCooldownSeconds else { return }
        lastDeviationRecordedAt = Date()
        let driverId    = AuthManager.shared.currentUser?.id ?? UUID()
        let vehicleId   = UUID(uuidString: trip.vehicleId ?? "") ?? UUID()
        Task {
            try? await RouteDeviationService.recordDeviation(
                tripId: trip.id, driverId: driverId, vehicleId: vehicleId,
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                deviationMetres: deviationMetres
            )
        }
    }

    private func computeMinDistanceToRoute(location: CLLocationCoordinate2D, routeCoords: [CLLocationCoordinate2D]) -> Double {
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<(routeCoords.count - 1) {
            let dist = perpendicularDistance(point: location, segStart: routeCoords[i], segEnd: routeCoords[i + 1])
            if dist < minDist { minDist = dist }
        }
        return minDist
    }

    private func perpendicularDistance(point: CLLocationCoordinate2D, segStart: CLLocationCoordinate2D, segEnd: CLLocationCoordinate2D) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let endLoc   = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)
        let segLength = startLoc.distance(from: endLoc)
        guard segLength > 0 else { return pointLoc.distance(from: startLoc) }
        let dx = endLoc.coordinate.longitude - startLoc.coordinate.longitude
        let dy = endLoc.coordinate.latitude  - startLoc.coordinate.latitude
        let px = point.longitude - startLoc.coordinate.longitude
        let py = point.latitude  - startLoc.coordinate.latitude
        let t = max(0, min(1, (px * dx + py * dy) / (dx * dx + dy * dy)))
        let projLat = segStart.latitude  + t * (segEnd.latitude  - segStart.latitude)
        let projLng = segStart.longitude + t * (segEnd.longitude - segStart.longitude)
        return pointLoc.distance(from: CLLocation(latitude: projLat, longitude: projLng))
    }

    // MARK: - Geofence Monitoring

    func registerGeofences(_ geofences: [Geofence]) {
        guard let manager = locationManager else { return }
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
        let driverCoord = currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629)
        let driverLoc   = CLLocation(latitude: driverCoord.latitude, longitude: driverCoord.longitude)
        let active = geofences.filter { $0.isActive }.sorted {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: driverLoc)
            < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: driverLoc)
        }
        for geofence in active.prefix(20) {
            let center = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
            let region = CLCircularRegion(center: center, radius: geofence.radiusMeters, identifier: geofence.id.uuidString)
            region.notifyOnEntry = geofence.alertOnEntry
            region.notifyOnExit  = geofence.alertOnExit
            manager.startMonitoring(for: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in await self.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Entry") }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let geofenceId = UUID(uuidString: region.identifier) else { return }
        Task { @MainActor in await self.handleGeofenceEvent(geofenceId: geofenceId, eventType: "Exit") }
    }

    private func handleGeofenceEvent(geofenceId: UUID, eventType: String) async {
        guard let vehicleIdStr = trip.vehicleId, let vehicleId = UUID(uuidString: vehicleIdStr) else { return }
        let driverId = AuthManager.shared.currentUser?.id ?? UUID()
        do {
            try await GeofenceEventService.addGeofenceEvent(GeofenceEvent(
                id: UUID(), geofenceId: geofenceId, vehicleId: vehicleId, tripId: trip.id, driverId: driverId,
                eventType: eventType == "Entry" ? .entry : .exit,
                latitude: currentLocation?.coordinate.latitude ?? 0,
                longitude: currentLocation?.coordinate.longitude ?? 0,
                triggeredAt: Date(), createdAt: Date()
            ))
        } catch { print("[NavCoordinator] Geofence event insert failed: \(error)") }
        let fmIds = AppDataStore.shared.staff.filter { $0.role == .fleetManager && $0.status == .active }.map { $0.id }
        for fmId in fmIds {
            try? await NotificationService.insertNotification(
                recipientId: fmId, type: .geofenceViolation,
                title: "Geofence \(eventType)",
                body: "Vehicle \(vehicleIdStr) \(eventType == "Entry" ? "entered" : "exited") a monitored zone",
                entityType: "geofence", entityId: geofenceId
            )
        }
    }
}

// MARK: - Notification.Name extension
extension Notification.Name {
    static let locationPermissionDenied = Notification.Name("locationPermissionDenied")
}
