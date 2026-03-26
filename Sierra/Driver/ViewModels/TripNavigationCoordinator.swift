        import Foundation
import CoreLocation
import MapboxDirections
import MapboxMaps

// MARK: - TripNavigationCoordinator
// Orchestrator — delegates to RouteEngine, DeviationDetector, GeofenceMonitor.

@MainActor
@Observable
final class TripNavigationCoordinator: NSObject, CLLocationManagerDelegate {
    private static var cachedSessions: [UUID: TripNavigationCoordinator] = [:]
    private static let persistedProgressDefaultsKey = "trip_navigation_progress_v2"

    private static var persistedProgressByTrip: [String: Double] {
        get {
            UserDefaults.standard.dictionary(forKey: persistedProgressDefaultsKey) as? [String: Double] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: persistedProgressDefaultsKey)
        }
    }

    static func session(for trip: Trip) -> TripNavigationCoordinator {
        if let existing = cachedSessions[trip.id] { return existing }
        let created = TripNavigationCoordinator(trip: trip)
        cachedSessions[trip.id] = created
        return created
    }

    static func sessionProgress(for tripId: UUID) -> Double? {
        if let session = cachedSessions[tripId], session.hasRenderableRoute {
            return max(session.routeProgressFraction, persistedProgress(for: tripId))
        }
        let persisted = persistedProgress(for: tripId)
        return persisted > 0 ? persisted : nil
    }

    static func sessionRouteCoordinates(for tripId: UUID) -> [CLLocationCoordinate2D]? {
        guard let session = cachedSessions[tripId], session.hasRenderableRoute else { return nil }
        let coords = session.displayedRouteCoordinates
        return coords.count >= 2 ? coords : nil
    }

    static func clearSession(for tripId: UUID) {
        cachedSessions[tripId]?.stopLocationPublishing()
        cachedSessions[tripId]?.stopSimulation()
        cachedSessions[tripId] = nil
    }

    private static func persistedProgress(for tripId: UUID) -> Double {
        persistedProgressByTrip[tripId.uuidString.lowercased()] ?? 0
    }

    private static func savePersistedProgress(_ progress: Double, for tripId: UUID) {
        let key = tripId.uuidString.lowercased()
        let current = persistedProgressByTrip[key] ?? 0
        guard progress > current else { return }
        var updated = persistedProgressByTrip
        updated[key] = min(max(progress, 0), 1)
        persistedProgressByTrip = updated
    }

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
    var remainingRouteCoordinates: [CLLocationCoordinate2D] {
        let coords = routeEngine.decodedRouteCoordinates
        guard !coords.isEmpty else { return [] }
        let idx = min(max(routeCursorIndex, 0), max(0, coords.count - 1))
        return Array(coords.dropFirst(idx))
    }
    var hasRenderableRoute: Bool                { routeEngine.decodedRouteCoordinates.count >= 2 }
    var isUsingStoredRouteFallback: Bool        { routeEngine.isUsingStoredRouteFallback }
    var routeEngineError: String?               { routeEngine.lastBuildError }
    var activeIncidents: [TrafficIncident]      { trafficService.activeIncidents }
    // Cached geofences — recomputed only when the trip's stops change.
    private var _cachedGeofences: [Geofence]?
    private var _geofenceAnchorCount: Int = -1
    var activeGeofences: [Geofence] {
        let stops = trip.routeStops ?? []
        let anchorCount = stops.count + 2  // origin + stops + destination
        if let cached = _cachedGeofences, anchorCount == _geofenceAnchorCount {
            return cached
        }
        var anchors: [CLLocationCoordinate2D] = []
        if let lat = trip.originLatitude, let lng = trip.originLongitude {
            anchors.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        for stop in stops.sorted(by: { $0.order < $1.order }) {
            anchors.append(CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
        }
        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
            anchors.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        guard !anchors.isEmpty else {
            _cachedGeofences = []
            _geofenceAnchorCount = anchorCount
            return []
        }

        let result = AppDataStore.shared.geofences
            .filter(\.isActive)
            .filter { geofence in
                anchors.contains { anchor in
                    let a = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
                    let g = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
                    return a.distance(from: g) <= max(geofence.radiusMeters, 80)
                }
            }
        _cachedGeofences = result
        _geofenceAnchorCount = anchorCount
        return result
    }
    var currentRouteCoordinate: CLLocationCoordinate2D? {
        guard routeEngine.decodedRouteCoordinates.indices.contains(routeCursorIndex) else { return currentLocation?.coordinate }
        return routeEngine.decodedRouteCoordinates[routeCursorIndex]
    }
    var nextRouteCoordinate: CLLocationCoordinate2D? {
        let nextIndex = routeCursorIndex + 1
        guard routeEngine.decodedRouteCoordinates.indices.contains(nextIndex) else { return nil }
        return routeEngine.decodedRouteCoordinates[nextIndex]
    }

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
    /// Distance from driver's current location to the end of the current step (i.e. start of the next maneuver).
    /// Uses route-following distance along the current step's shape when possible,
    /// otherwise falls back to straight-line distance, then total remaining.
    var distanceToNextManeuverMetres: Double {
        guard let route = routeEngine.currentRoute,
              let leg = route.legs.first,
              let location = currentLocation else {
            return distanceToEndOfCurrentSegment
        }
        let steps = leg.steps
        guard currentStepIndex < steps.count else { return distanceToEndOfCurrentSegment }

        let currentStep = steps[currentStepIndex]

        if let shape = currentStep.shape {
            let coords = shape.coordinates
            guard coords.count >= 2 else {
                if let last = coords.last {
                    return location.distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
                }
                return currentStep.distance
            }

            var bestSegIdx = 0
            var bestDist = Double.greatestFiniteMagnitude
            for i in 0 ..< coords.count {
                let segLoc = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
                let d = location.distance(from: segLoc)
                if d < bestDist { bestDist = d; bestSegIdx = i }
            }

            var dist: Double = 0
            for i in bestSegIdx ..< coords.count - 1 {
                let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
                let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
                dist += a.distance(from: b)
            }
            return max(0, dist)
        }

        return currentStep.distance
    }

    /// Distance from current position to the end of the next ~2 km segment of route
    /// coordinates. Used as fallback when no Mapbox Route object is available.
    private var distanceToEndOfCurrentSegment: Double {
        let coords = routeEngine.decodedRouteCoordinates
        guard coords.count >= 2, let location = currentLocation else { return distanceRemainingMetres }
        let start = min(max(routeCursorIndex, 0), coords.count - 1)
        var dist: Double = 0
        let driverLoc = CLLocation(latitude: coords[start].latitude, longitude: coords[start].longitude)
        dist += location.distance(from: driverLoc)
        for i in start ..< coords.count - 1 {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
            dist += a.distance(from: b)
            if dist > 2000 { return dist }
        }
        return max(0, min(dist, distanceRemainingMetres))
    }
    // MARK: - Coordinator-owned State
    var isNavigating: Bool = false
    var currentSpeedKmh: Double = 0
    var hasArrived: Bool = false
    var currentSpeedLimit: Int?
    var currentStepManeuver: String = ""
    var nextStepInstruction: String = ""
    var requestRecenter: Bool = false

    /// Returns a value in [0.0, 1.0] representing how far along the route the driver is.
    /// 0.0 = at origin, 1.0 = arrived at destination.
    var routeProgressFraction: Double {
        guard routeEngine.totalRouteDistanceMetres > 0 else { return 0 }
        let distanceTraveled = routeEngine.totalRouteDistanceMetres - distanceRemainingMetres
        let raw = max(0, min(1, distanceTraveled / routeEngine.totalRouteDistanceMetres))
        return max(maxRouteProgressFraction, raw)
    }
    var simulated: Bool = false
    var hasConfirmedRouteSelection: Bool = false
    private var simulationTimer: Timer?
    private var simulationIndex: Int = 0
    private var routeCursorIndex: Int = 0
    private var maxRouteProgressFraction: Double = 0
    private var stopRouteIndices: [Int] = []
    private var reachedStopIndices: Set<Int> = []

    let trip: Trip
    private(set) var currentLocation: CLLocation?
    private(set) var breadcrumbCoordinates: [CLLocationCoordinate2D] = []
    private var locationManager: CLLocationManager?
    private var locationPublishTimer: Timer?
    private let locationPublishInterval: TimeInterval = 5.0
    private var currentStepIndex: Int = 0
    private var lastStepChangeLocation: CLLocation?  // ISSUE-13 FIX: hysteresis tracking
    private var lastRerouteRequestedAt: Date = .distantPast  // Fix 9: reroute cooldown
    private var lastTrafficUpdateAt: Date = .distantPast     // throttle traffic service
    private var didAnnounceInitialInstruction = false

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
        _cumulativeRouteCount = 0  // invalidate distance cache
        recomputeStopRouteAnchors()
        routeCursorIndex = min(max(routeCursorIndex, 0), max(0, routeEngine.decodedRouteCoordinates.count - 1))
        maxRouteProgressFraction = max(maxRouteProgressFraction, Self.persistedProgress(for: trip.id))
        if let location = currentLocation {
            updateNavigationProgress(location: location)
        }
    }
    // ISSUE-19 FIX: Renamed from selectGreenRoute
    func swapAlternativeRoute() {
        routeEngine.swapAlternativeRoute()
        currentStepIndex = 0
        hasConfirmedRouteSelection = true
    }
    func rebuildRoutes() async {
        await routeEngine.rebuildRoutes(trip: trip, currentLocation: currentLocation)
    }
    func setSimulationEnabled(_ enabled: Bool) {
        if enabled { startSimulation() }
        else { stopSimulation() }
    }
    func addStop(latitude: Double, longitude: Double, name: String) async {
        await routeEngine.addStop(latitude: latitude, longitude: longitude, name: name,
                                   trip: trip, currentLocation: currentLocation)
    }

    // MARK: - Location Manager
    func startEarlyLocationUpdates() {
        guard locationManager == nil, !simulated else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5

        let status = manager.authorizationStatus
        if status == .notDetermined || status == .authorizedWhenInUse {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        locationManager = manager
    }

    func startLocationTracking() {
        guard !simulated else { return }
        if locationManager == nil {
            startEarlyLocationUpdates()
        }
        guard let manager = locationManager else { return }
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
        hasConfirmedRouteSelection = true
        announceInitialInstructionIfNeeded()

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

    private func announceInitialInstructionIfNeeded() {
        guard !didAnnounceInitialInstruction else { return }
        if !routeEngine.currentStepInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VoiceNavigationService.shared.announce(routeEngine.currentStepInstruction)
            didAnnounceInitialInstruction = true
            return
        }
        if let firstInstruction = routeEngine.currentRoute?.legs.first?.steps.first?.instructions,
           !firstInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            routeEngine.currentStepInstruction = firstInstruction
            VoiceNavigationService.shared.announce(firstInstruction)
            didAnnounceInitialInstruction = true
            return
        }
        VoiceNavigationService.shared.announce("Navigation started. Follow the highlighted route.")
        didAnnounceInitialInstruction = true
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
        let now = Date()
        if now.timeIntervalSince(lastTrafficUpdateAt) >= 15 {
            lastTrafficUpdateAt = now
            trafficService.updateLocation(location)
        }
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

        // Stop-safe progression: search forward window and never move cursor backwards.
        let lastSegmentIndex = routeCoords.count - 2
        let forwardStart = min(max(routeCursorIndex - 8, 0), lastSegmentIndex)
        let forwardEnd = min(routeCursorIndex + 40, lastSegmentIndex)
        let candidateRange = forwardStart...forwardEnd

        let driverLat = location.coordinate.latitude
        let driverLon = location.coordinate.longitude

        var minDist = Double.greatestFiniteMagnitude
        var closestSegIndex = routeCursorIndex
        for i in candidateRange {
            let dist = fastSegmentDistance(
                pLat: driverLat, pLon: driverLon,
                aLat: routeCoords[i].latitude, aLon: routeCoords[i].longitude,
                bLat: routeCoords[i + 1].latitude, bLon: routeCoords[i + 1].longitude
            )
            if dist < minDist {
                minDist = dist
                closestSegIndex = i
            }
        }
        routeCursorIndex = max(routeCursorIndex, closestSegIndex)

        let remaining = cumulativeRemainingDistance(from: routeCursorIndex, driverLocation: location, routeCoords: routeCoords)
        routeEngine.distanceRemainingMetres = max(0, remaining)
        maxRouteProgressFraction = max(maxRouteProgressFraction, routeProgressFraction)
        Self.savePersistedProgress(maxRouteProgressFraction, for: trip.id)

        updateStopArrivalState(using: location, routeCoordinates: routeCoords)

        // Fix 10: Extract speed limit from route annotations
        if let speedLimits = routeEngine.currentRoute?.legs.first?.segmentMaximumSpeedLimits,
           routeCursorIndex < speedLimits.count,
           let measurement = speedLimits[routeCursorIndex] {
            currentSpeedLimit = Int(measurement.converted(to: .kilometersPerHour).value)
        } else {
            currentSpeedLimit = nil
        }

        // Arrival check using route distance, not crow-fly
        if remaining < 50 && !hasArrived {
            hasArrived = true
            routeEngine.distanceRemainingMetres = 0
            maxRouteProgressFraction = 1.0
            Self.savePersistedProgress(1.0, for: trip.id)
            routeCursorIndex = routeCoords.count - 1
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
        let remainingTime = avgSpeed > 0 ? remaining / avgSpeed : 0
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

    private func appendBreadcrumbCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D, force: Bool = false) {
        guard let last = breadcrumbCoordinates.last else {
            breadcrumbCoordinates = [coordinate]
            return
        }

        if force {
            breadcrumbCoordinates.append(coordinate)
            return
        }

        let previous = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard current.distance(from: previous) >= 2 else { return }
        breadcrumbCoordinates.append(coordinate)
    }

    private func recomputeStopRouteAnchors() {
        let routeCoords = routeEngine.decodedRouteCoordinates
        let stops = (trip.routeStops ?? []).sorted(by: { $0.order < $1.order })
        guard !routeCoords.isEmpty, !stops.isEmpty else {
            stopRouteIndices = []
            reachedStopIndices = []
            return
        }

        stopRouteIndices = stops.map { stop in
            let stopCoord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            var best = 0
            var bestDist = Double.greatestFiniteMagnitude
            for (idx, coord) in routeCoords.enumerated() {
                let a = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let b = CLLocation(latitude: stopCoord.latitude, longitude: stopCoord.longitude)
                let dist = a.distance(from: b)
                if dist < bestDist {
                    bestDist = dist
                    best = idx
                }
            }
            return best
        }
        reachedStopIndices = reachedStopIndices.filter { $0 < stopRouteIndices.count }
    }

    private func updateStopArrivalState(using location: CLLocation, routeCoordinates: [CLLocationCoordinate2D]) {
        guard !stopRouteIndices.isEmpty else { return }
        let stops = (trip.routeStops ?? []).sorted(by: { $0.order < $1.order })
        guard stops.count == stopRouteIndices.count else { return }

        for (idx, stop) in stops.enumerated() where !reachedStopIndices.contains(idx) {
            let stopLoc = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            let dist = stopLoc.distance(from: location)
            // Route can momentarily pause near a stop; snap cursor to stop anchor so progress continues.
            if dist <= 45 {
                reachedStopIndices.insert(idx)
                routeCursorIndex = max(routeCursorIndex, min(stopRouteIndices[idx], max(0, routeCoordinates.count - 1)))
            }
        }
    }

    // MARK: - Fast Geometry Helpers (avoid CLLocation allocation on every tick)

    private var _cumulativeDistFromEnd: [Double] = []
    private var _cumulativeRouteCount: Int = 0

    private func cumulativeRemainingDistance(from fromIndex: Int, driverLocation: CLLocation, routeCoords: [CLLocationCoordinate2D]) -> Double {
        if _cumulativeRouteCount != routeCoords.count {
            rebuildCumulativeDistances(routeCoords)
        }
        guard !_cumulativeDistFromEnd.isEmpty else { return 0 }
        let idx = min(max(fromIndex, 0), routeCoords.count - 1)
        var dist: Double = 0
        if idx + 1 < routeCoords.count {
            dist += haversineDistance(
                lat1: driverLocation.coordinate.latitude, lon1: driverLocation.coordinate.longitude,
                lat2: routeCoords[idx + 1].latitude, lon2: routeCoords[idx + 1].longitude
            )
        }
        if idx + 1 < _cumulativeDistFromEnd.count {
            dist += _cumulativeDistFromEnd[idx + 1]
        }
        return dist
    }

    private func rebuildCumulativeDistances(_ coords: [CLLocationCoordinate2D]) {
        let n = coords.count
        _cumulativeRouteCount = n
        guard n >= 2 else { _cumulativeDistFromEnd = []; return }
        var arr = [Double](repeating: 0, count: n)
        for i in stride(from: n - 2, through: 0, by: -1) {
            arr[i] = arr[i + 1] + haversineDistance(
                lat1: coords[i].latitude, lon1: coords[i].longitude,
                lat2: coords[i + 1].latitude, lon2: coords[i + 1].longitude
            )
        }
        _cumulativeDistFromEnd = arr
    }

    private func fastSegmentDistance(pLat: Double, pLon: Double,
                                     aLat: Double, aLon: Double,
                                     bLat: Double, bLon: Double) -> Double {
        let ab = haversineDistance(lat1: aLat, lon1: aLon, lat2: bLat, lon2: bLon)
        guard ab > 0 else { return haversineDistance(lat1: pLat, lon1: pLon, lat2: aLat, lon2: aLon) }
        let ap = haversineDistance(lat1: pLat, lon1: pLon, lat2: aLat, lon2: aLon)
        let bp = haversineDistance(lat1: pLat, lon1: pLon, lat2: bLat, lon2: bLon)
        let s = (ab + ap + bp) / 2
        let area = sqrt(max(0, s * (s - ab) * (s - ap) * (s - bp)))
        return (2 * area) / ab
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    // MARK: - Simulation
    /// DEBUG: Current index in the decoded route coordinate array.
    var simulationProgress: Double {
        let total = routeEngine.decodedRouteCoordinates.count
        guard total > 1 else { return 0 }
        return Double(simulationIndex) / Double(total - 1)
    }

    func startSimulation() {
        let coords = routeEngine.decodedRouteCoordinates
        guard coords.count > 1 else { return }
        simulated = true
        if simulationIndex >= coords.count - 1 || simulationIndex < 0 {
            simulationIndex = 0
        }
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let coords = self.routeEngine.decodedRouteCoordinates
                guard coords.count > 1 else {
                    self.simulationTimer?.invalidate()
                    self.simulationTimer = nil
                    self.simulated = false
                    return
                }
                self.simulationIndex = min(max(self.simulationIndex, 0), coords.count - 1)
                let coord = coords[self.simulationIndex]
                self.applySimulatedCoordinate(coord)
                self.routeCursorIndex = self.simulationIndex
                self.breadcrumbCoordinates = Array(coords.prefix(self.simulationIndex + 1))
                if self.simulationIndex >= coords.count - 1 {
                    self.simulationTimer?.invalidate()
                    self.simulationTimer = nil
                    self.simulated = false
                    self.maxRouteProgressFraction = 1.0
                    Self.savePersistedProgress(1.0, for: self.trip.id)
                    return
                }
                self.simulationIndex += 1
            }
        }
    }

    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulated = false
    }

    func resetSimulation() {
        stopSimulation()
        simulationIndex = 0
    }

    /// Scrub the simulation puck to a specific progress fraction [0-1].
    func scrubSimulation(to fraction: Double) {
        let coords = routeEngine.decodedRouteCoordinates
        guard coords.count > 1 else { return }
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulated = false

        let clamped = min(max(fraction, 0), 1)
        let idx = Int(clamped * Double(coords.count - 1))
        if idx == simulationIndex { return }
        simulationIndex = min(max(idx, 0), coords.count - 1)
        routeCursorIndex = simulationIndex
        breadcrumbCoordinates = Array(coords.prefix(simulationIndex + 1))
        applySimulatedCoordinate(coords[simulationIndex])
    }

    private func applySimulatedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        currentLocation = location
        currentSpeedKmh = max(currentSpeedKmh, 18)
        appendBreadcrumbCoordinateIfNeeded(coordinate, force: true)
        updateNavigationProgress(location: location)
    }
}

// MARK: - Notification.Name extension
extension Notification.Name {
    static let locationPermissionDenied = Notification.Name("locationPermissionDenied")
    static let tripArrivedAtDestination = Notification.Name("tripArrivedAtDestination")
}
