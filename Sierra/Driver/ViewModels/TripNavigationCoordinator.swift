import Foundation
import CoreLocation
import MapboxDirections
import Turf

// MARK: - TripNavigationCoordinator

/// Manages navigation state: route building, location publishing,
/// and local deviation detection. @Observable (matching existing app patterns).
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
    private var hasBuiltRoutes: Bool = false
    private var lastDeviationRecordedAt: Date = .distantPast
    private let deviationCooldownSeconds: TimeInterval = 60.0
    private var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    private(set) var currentLocation: CLLocation?
    private var locationManager: CLLocationManager?
    private var currentStepIndex: Int = 0

    // MARK: - Init

    init(trip: Trip) {
        self.trip = trip
        super.init()
    }

    // MARK: - Add Stop

    func addStop(latitude: Double, longitude: Double, name: String) async {
        // Reset so buildRoutes() will run again
        hasBuiltRoutes = false
        // TODO: In a full implementation, waypoints would be stored and passed to buildRoutes
        await buildRoutes()
    }

    // MARK: - Route Building (Safeguard 2: exactly once)

    func buildRoutes() async {
        guard !hasBuiltRoutes else { return }
        hasBuiltRoutes = true

        guard let originLat = trip.originLatitude,
              let originLng = trip.originLongitude,
              let destLat = trip.destinationLatitude,
              let destLng = trip.destinationLongitude else {
            print("[NavCoordinator] Missing trip coordinates, cannot build routes")
            return
        }

        let originWP = Waypoint(coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng))
        let destWP = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng))

        let options = RouteOptions(waypoints: [originWP, destWP])
        options.includesAlternativeRoutes = true
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6

        var avoidClasses: RoadClasses = []
        if avoidTolls { avoidClasses.insert(.toll) }
        if avoidHighways { avoidClasses.insert(.motorway) }
        if !avoidClasses.isEmpty { options.roadClassesToAvoid = avoidClasses }

        do {
            let response: RouteResponse = try await withCheckedThrowingContinuation { continuation in
                Directions.shared.calculate(options) { _, result in
                    switch result {
                    case .success(let resp):
                        continuation.resume(returning: resp)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            let routes = response.routes ?? []

            if let fastest = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) {
                currentRoute = fastest
                distanceRemainingMetres = fastest.distance
                estimatedArrivalTime = Date().addingTimeInterval(fastest.expectedTravelTime)

                if let firstStep = fastest.legs.first?.steps.first {
                    currentStepInstruction = firstStep.instructions
                }
            }
            if routes.count > 1 {
                alternativeRoute = routes.first { $0 !== currentRoute }
            }

            // Decode route geometry for local deviation math
            if let shape = currentRoute?.shape {
                decodedRouteCoordinates = shape.coordinates
            }
        } catch {
            print("[NavCoordinator] Route build failed: \(error)")
        }
    }

    // MARK: - Location Manager Setup

    func startLocationTracking() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = 5

        // Safeguard 8: Check authorization
        let status = manager.authorizationStatus
        if status == .notDetermined || status == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }

        manager.startUpdatingLocation()
        locationManager = manager
        isNavigating = true

        // Register geofences for monitoring (iOS max 20 regions)
        registerGeofences(AppDataStore.shared.geofences)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.updateLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NavCoordinator] Location error: \(error)")
    }

    // MARK: - Location Publishing (Safeguard 1: single Timer, 5s interval)

    func startLocationPublishing(vehicleId: UUID, driverId: UUID) {
        guard locationPublishTimer == nil else { return } // prevent double-start
        locationPublishTimer = Timer.scheduledTimer(
            withTimeInterval: locationPublishInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            // Capture location on the main actor before crossing into the nonisolated closure
            Task { @MainActor in
                guard let location = self.currentLocation else { return }
                let lat = location.coordinate.latitude
                let lng = location.coordinate.longitude
                let speed = location.speed > 0 ? location.speed * 3.6 : nil
                Task {
                    try? await VehicleLocationService.shared.publishLocation(
                        vehicleId: vehicleId,
                        tripId: self.trip.id,
                        driverId: driverId,
                        latitude: lat,
                        longitude: lng,
                        speedKmh: speed
                    )
                }
            }
        }
    }

    func stopLocationPublishing() {
        locationPublishTimer?.invalidate()
        locationPublishTimer = nil
        // Unregister all monitored geofence regions
        if let manager = locationManager {
            for region in manager.monitoredRegions {
                manager.stopMonitoring(for: region)
            }
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
        guard let route = currentRoute,
              let leg = route.legs.first else { return }

        // Compute remaining distance from current position to destination
        if let lastCoord = decodedRouteCoordinates.last {
            let destLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            distanceRemainingMetres = location.distance(from: destLoc)
        }

        // Update ETA based on average route speed
        let avgSpeed = route.distance / route.expectedTravelTime
        let remainingTime = avgSpeed > 0 ? distanceRemainingMetres / avgSpeed : 0
        estimatedArrivalTime = Date().addingTimeInterval(remainingTime)

        // Find current step
        let steps = leg.steps
        for (idx, step) in steps.enumerated() {
            if let shape = step.shape, let firstCoord = shape.coordinates.first {
                let stepLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
                let distToStep = location.distance(from: stepLoc)
                if distToStep < 100 && idx >= currentStepIndex {
                    currentStepIndex = idx
                    currentStepInstruction = step.instructions
                    break
                }
            }
        }
    }

    // MARK: - Deviation Check (Safeguard 3: pure local math, zero network calls)

    func checkDeviation(from location: CLLocation) {
        guard decodedRouteCoordinates.count >= 2 else { return }

        let deviationMetres = computeMinDistanceToRoute(
            location: location.coordinate,
            routeCoords: decodedRouteCoordinates
        )

        guard deviationMetres > 200 else {
            if hasDeviated { hasDeviated = false }
            return
        }

        hasDeviated = true

        guard Date().timeIntervalSince(lastDeviationRecordedAt) > deviationCooldownSeconds else { return }
        lastDeviationRecordedAt = Date()

        let driverId = AuthManager.shared.currentUser?.id ?? UUID()
        let vehicleIdStr = trip.vehicleId ?? ""
        let vehicleId = UUID(uuidString: vehicleIdStr) ?? UUID()

        Task {
            try? await RouteDeviationService.recordDeviation(
                tripId: trip.id,
                driverId: driverId,
                vehicleId: vehicleId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                deviationMetres: deviationMetres
            )
        }
    }

    // MARK: - Local Math Helpers

    /// Minimum perpendicular distance from point to polyline.
    private func computeMinDistanceToRoute(location: CLLocationCoordinate2D, routeCoords: [CLLocationCoordinate2D]) -> Double {
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<(routeCoords.count - 1) {
            let dist = perpendicularDistance(point: location, segStart: routeCoords[i], segEnd: routeCoords[i + 1])
            if dist < minDist { minDist = dist }
        }
        return minDist
    }

    /// Distance from a point to a line segment on the Earth's surface.
    private func perpendicularDistance(point: CLLocationCoordinate2D, segStart: CLLocationCoordinate2D, segEnd: CLLocationCoordinate2D) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: segStart.latitude, longitude: segStart.longitude)
        let endLoc = CLLocation(latitude: segEnd.latitude, longitude: segEnd.longitude)

        let segLength = startLoc.distance(from: endLoc)
        guard segLength > 0 else { return pointLoc.distance(from: startLoc) }

        let dx = endLoc.coordinate.longitude - startLoc.coordinate.longitude
        let dy = endLoc.coordinate.latitude - startLoc.coordinate.latitude
        let px = point.longitude - startLoc.coordinate.longitude
        let py = point.latitude - startLoc.coordinate.latitude

        let t = max(0, min(1, (px * dx + py * dy) / (dx * dx + dy * dy)))

        let projLat = segStart.latitude + t * (segEnd.latitude - segStart.latitude)
        let projLng = segStart.longitude + t * (segEnd.longitude - segStart.longitude)
        let projLoc = CLLocation(latitude: projLat, longitude: projLng)

        return pointLoc.distance(from: projLoc)
    }

    // MARK: - Geofence Monitoring

    /// Registers CLCircularRegion monitors for active geofences.
    /// iOS enforces a max of 20 monitored regions; only the 20 closest are registered.
    func registerGeofences(_ geofences: [Geofence]) {
        guard let manager = locationManager else { return }
        // Clear existing
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        // Sort by distance from driver (closest first) and take 20
        let driverCoord = currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629)
        let driverLoc = CLLocation(latitude: driverCoord.latitude, longitude: driverCoord.longitude)
        let active = geofences.filter { $0.isActive }
        let sorted = active.sorted {
            let loc0 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            let loc1 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
            return driverLoc.distance(from: loc0) < driverLoc.distance(from: loc1)
        }
        for geofence in sorted.prefix(20) {
            let center = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
            let region = CLCircularRegion(center: center, radius: geofence.radiusMeters, identifier: geofence.id.uuidString)
            region.notifyOnEntry = geofence.alertOnEntry
            region.notifyOnExit = geofence.alertOnExit
            manager.startMonitoring(for: region)
        }
    }

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
        // Insert geofence event (non-fatal)
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
        // Notify fleet managers (non-fatal — all wrapped in try?)
        let fmIds = AppDataStore.shared.staff.filter { $0.role == .fleetManager && $0.status == .active }.map { $0.id }
        for fmId in fmIds {
            try? await NotificationService.insertNotification(
                recipientId: fmId,
                type: .geofenceViolation,
                title: "Geofence \(eventType)",
                body: "Vehicle \(vehicleIdStr) \(eventType == "Entry" ? "entered" : "exited") a monitored zone",
                entityType: "geofence",
                entityId: geofenceId
            )
        }
    }
}
