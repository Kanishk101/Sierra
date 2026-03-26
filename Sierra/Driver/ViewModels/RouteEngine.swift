import Foundation
import CoreLocation
import MapboxDirections
import MapboxNavigationCore
import Turf

// MARK: - RouteEngine
// Owns all Mapbox Directions SDK interaction.
//
// NAVIGATION FIX: The original code had `guard !hasBuiltRoutes else { return }`
// which prevented any retry after a failure. Now it always attempts to build
// if currentRoute is nil. Also handles missing trip coordinates gracefully by
// falling back to the driver's current location as the origin.

@MainActor
@Observable
final class RouteEngine {
    struct RouteChoice: Identifiable {
        let id = UUID()
        let route: MapboxDirections.Route
        let sourceRouteIndex: Int
        let isFastest: Bool
        let isGreen: Bool
    }

    private struct RouteBuildSnapshot {
        let currentRoute: MapboxDirections.Route?
        let alternativeRoute: MapboxDirections.Route?
        let routeChoices: [RouteChoice]
        let selectedChoiceIndex: Int
        let decodedRouteCoordinates: [CLLocationCoordinate2D]
        let totalRouteDistanceMetres: Double
        let latestRouteResponse: RouteResponse?
        let selectedRouteIndex: Int?
        let currentStepInstruction: String
        let distanceRemainingMetres: Double
        let estimatedArrivalTime: Date?
        let hasDeviated: Bool
        let isUsingStoredRouteFallback: Bool

        var hasRenderableRoute: Bool {
            currentRoute != nil || decodedRouteCoordinates.count >= 2
        }
    }

    // MARK: - Public State
    var currentRoute: MapboxDirections.Route?
    var alternativeRoute: MapboxDirections.Route?
    var routeChoices: [RouteChoice] = []
    var selectedChoiceIndex: Int = 0
    var currentStepInstruction: String = ""
    var distanceRemainingMetres: Double = 0
    var estimatedArrivalTime: Date?
    var hasDeviated: Bool = false
    var avoidTolls: Bool = false
    var avoidHighways: Bool = false
    var lastBuildError: String? = nil
    var isUsingStoredRouteFallback: Bool = false

    // MARK: - Internal State
    private(set) var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    private(set) var totalRouteDistanceMetres: Double = 0
    private(set) var latestRouteResponse: RouteResponse?
    private(set) var selectedRouteIndex: Int?
    private var intermediateWaypoints: [(lat: Double, lng: Double, name: String)] = []
    private var rerouteFromCurrentLocation: Bool = false
    private var isBuilding: Bool = false  // CODE-33 FIX: prevent concurrent builds

    // MARK: - Route Building
    //
    // FIX 1: Removed `guard !hasBuiltRoutes` — now always retries if currentRoute is nil.
// FIX 2: Requires currentLocation as origin for driver navigation start.
// FIX 3: Uses locked trip destination coordinates from admin-created trip.

    func buildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        // Only skip if we already have a valid route AND we're not rerouting
        if currentRoute != nil && !rerouteFromCurrentLocation { return }
        // CODE-33 FIX: Prevent concurrent route calculations
        guard !isBuilding else { return }
        isBuilding = true
        defer { isBuilding = false }

        let isRerouting = rerouteFromCurrentLocation
        rerouteFromCurrentLocation = false
        _ = isRerouting  // consumed above; origin always uses currentLocation now
        let snapshot = captureSnapshot()
        lastBuildError = nil

        // --- Determine origin ---
        // Driver routes must start from live GPS (not stored trip origin).
        guard let originLocation = currentLocation else {
            lastBuildError = "Waiting for GPS fix. Move to an open area and retry navigation."
            restoreSnapshotIfNeeded(snapshot)
            print("[RouteEngine] \(lastBuildError!)")
            return
        }
        let originCoord = originLocation.coordinate

        // --- Determine destination ---
        let destCoord: CLLocationCoordinate2D
        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
            destCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            lastBuildError = "Trip destination coordinates are not set. Ask your fleet manager to update the trip."
            restoreSnapshotIfNeeded(snapshot)
            print("[RouteEngine] \(lastBuildError!)")
            return
        }

        // --- Build waypoints ---
        var waypoints: [Waypoint] = [Waypoint(coordinate: originCoord)]
        let modelStops = (trip.routeStops ?? []).sorted { $0.order < $1.order }
        for stop in modelStops {
            waypoints.append(Waypoint(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude), name: stop.name))
        }
        for stop in intermediateWaypoints {
            waypoints.append(Waypoint(coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng), name: stop.name))
        }
        waypoints.append(Waypoint(coordinate: destCoord))

        let options = RouteOptions(waypoints: waypoints)
        options.includesAlternativeRoutes = true
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6
        options.profileIdentifier = .automobileAvoidingTraffic
        options.attributeOptions = [.congestionLevel, .expectedTravelTime, .speed, .maximumSpeedLimit]
        if trip.scheduledDate > Date() { options.departAt = trip.scheduledDate }

        var avoidClasses: RoadClasses = []
        if avoidTolls { avoidClasses.insert(.toll) }
        if avoidHighways { avoidClasses.insert(.motorway) }
        if !avoidClasses.isEmpty { options.roadClassesToAvoid = avoidClasses }

        guard MapService.hasValidToken else {
            if applyStoredPolylineFallback(from: trip) {
                lastBuildError = "Mapbox token missing. Showing the saved trip path only."
            } else {
                lastBuildError = MapService.configurationErrorDescription
                restoreSnapshotIfNeeded(snapshot)
            }
            print("[RouteEngine] \(lastBuildError!)")
            return
        }

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
            guard !routes.isEmpty else {
                lastBuildError = "No routes found between these locations."
                restoreSnapshotIfNeeded(snapshot)
                return
            }

            if let fastestIndex = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }) {
                let remaining = routes.indices.filter { $0 != fastestIndex }
                let greenIndex = remaining.min(by: { routes[$0].distance < routes[$1].distance })
                let extras = remaining
                    .filter { $0 != greenIndex }
                    .sorted { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }
                var rankedIndices: [Int] = [fastestIndex]
                if let greenIndex {
                    rankedIndices.append(greenIndex)
                }
                rankedIndices.append(contentsOf: extras)
                rankedIndices = Array(rankedIndices.prefix(3))

                routeChoices = rankedIndices.enumerated().map { _, sourceIndex in
                    RouteChoice(
                        route: routes[sourceIndex],
                        sourceRouteIndex: sourceIndex,
                        isFastest: sourceIndex == fastestIndex,
                        isGreen: sourceIndex == greenIndex
                    )
                }
                selectedChoiceIndex = 0
                let fastest = routeChoices.first?.route ?? routes[fastestIndex]
                latestRouteResponse = response
                selectedRouteIndex = fastestIndex
                currentRoute = fastest
                isUsingStoredRouteFallback = false
                distanceRemainingMetres = fastest.distance
                totalRouteDistanceMetres = fastest.distance
                estimatedArrivalTime = Date().addingTimeInterval(fastest.expectedTravelTime)
                if let firstStep = fastest.legs.first?.steps.first { currentStepInstruction = firstStep.instructions }

                alternativeRoute = routeChoices.dropFirst().first?.route
            }
            if let shape = currentRoute?.shape { decodedRouteCoordinates = shape.coordinates }
            if hasDeviated { hasDeviated = false }

        } catch {
            if await applyMapServiceFallbackRoute(origin: originCoord, destination: destCoord) {
                lastBuildError = nil
                return
            }
            if applyStoredPolylineFallback(from: trip) {
                lastBuildError = "Live route unavailable: \(error.localizedDescription). Showing the saved trip path."
            } else {
                lastBuildError = "Route calculation failed: \(error.localizedDescription)"
                restoreSnapshotIfNeeded(snapshot)
            }
            print("[RouteEngine] \(lastBuildError!)")
        }
    }

    /// ISSUE-19 FIX: Renamed from selectGreenRoute — this swaps primary and alternative routes.
    func swapAlternativeRoute() {
        guard routeChoices.count >= 2 else { return }
        let newIndex = selectedChoiceIndex == 0 ? 1 : 0
        selectRouteChoice(at: newIndex)
    }

    func selectRouteChoice(at index: Int) {
        guard routeChoices.indices.contains(index) else { return }
        selectedChoiceIndex = index
        let choice = routeChoices[index]
        currentRoute = choice.route
        alternativeRoute = routeChoices.enumerated()
            .first(where: { $0.offset != index })?
            .element.route
        selectedRouteIndex = choice.sourceRouteIndex
        if let shape = choice.route.shape {
            decodedRouteCoordinates = shape.coordinates
            totalRouteDistanceMetres = choice.route.distance
        } else {
            decodedRouteCoordinates = []
            totalRouteDistanceMetres = choice.route.distance
        }
        distanceRemainingMetres = choice.route.distance
        estimatedArrivalTime = Date().addingTimeInterval(choice.route.expectedTravelTime)
        currentStepInstruction = choice.route.legs.first?.steps.first?.instructions ?? "Follow the highlighted route"
        isUsingStoredRouteFallback = false
        hasDeviated = false
    }

    func rebuildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        rerouteFromCurrentLocation = true
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func addStop(latitude: Double, longitude: Double, name: String, trip: Trip, currentLocation: CLLocation?) async {
        intermediateWaypoints.append((lat: latitude, lng: longitude, name: name))
        rerouteFromCurrentLocation = true
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func triggerRerouteFromCurrentLocation() {
        rerouteFromCurrentLocation = true
    }

    func applyNavigationRoutes(_ navigationRoutes: NavigationRoutes) {
        let mainRoute = navigationRoutes.mainRoute.route
        let alternatives = navigationRoutes.alternativeRoutes.map(\.route)
        let ranked = Array(([mainRoute] + alternatives).prefix(3))
        routeChoices = ranked
            .enumerated()
            .map { offset, route in
                RouteChoice(
                    route: route,
                    sourceRouteIndex: offset,
                    isFastest: offset == 0,
                    isGreen: false
                )
            }
        selectedChoiceIndex = 0
        currentRoute = mainRoute
        alternativeRoute = alternatives.first
        decodedRouteCoordinates = mainRoute.shape?.coordinates ?? []
        totalRouteDistanceMetres = mainRoute.distance
        distanceRemainingMetres = mainRoute.distance
        estimatedArrivalTime = Date().addingTimeInterval(mainRoute.expectedTravelTime)
        currentStepInstruction = mainRoute.legs.first?.steps.first?.instructions ?? "Follow the highlighted route"
        isUsingStoredRouteFallback = false
        hasDeviated = false
    }

    private func clearDerivedRouteState() {
        currentRoute = nil
        alternativeRoute = nil
        routeChoices = []
        selectedChoiceIndex = 0
        decodedRouteCoordinates = []
        totalRouteDistanceMetres = 0
        latestRouteResponse = nil
        selectedRouteIndex = nil
        currentStepInstruction = ""
        distanceRemainingMetres = 0
        estimatedArrivalTime = nil
        isUsingStoredRouteFallback = false
    }

    private func captureSnapshot() -> RouteBuildSnapshot {
        RouteBuildSnapshot(
            currentRoute: currentRoute,
            alternativeRoute: alternativeRoute,
            routeChoices: routeChoices,
            selectedChoiceIndex: selectedChoiceIndex,
            decodedRouteCoordinates: decodedRouteCoordinates,
            totalRouteDistanceMetres: totalRouteDistanceMetres,
            latestRouteResponse: latestRouteResponse,
            selectedRouteIndex: selectedRouteIndex,
            currentStepInstruction: currentStepInstruction,
            distanceRemainingMetres: distanceRemainingMetres,
            estimatedArrivalTime: estimatedArrivalTime,
            hasDeviated: hasDeviated,
            isUsingStoredRouteFallback: isUsingStoredRouteFallback
        )
    }

    private func restoreSnapshotIfNeeded(_ snapshot: RouteBuildSnapshot) {
        guard snapshot.hasRenderableRoute else { return }
        currentRoute = snapshot.currentRoute
        alternativeRoute = snapshot.alternativeRoute
        routeChoices = snapshot.routeChoices
        selectedChoiceIndex = snapshot.selectedChoiceIndex
        decodedRouteCoordinates = snapshot.decodedRouteCoordinates
        totalRouteDistanceMetres = snapshot.totalRouteDistanceMetres
        latestRouteResponse = snapshot.latestRouteResponse
        selectedRouteIndex = snapshot.selectedRouteIndex
        currentStepInstruction = snapshot.currentStepInstruction
        distanceRemainingMetres = snapshot.distanceRemainingMetres
        estimatedArrivalTime = snapshot.estimatedArrivalTime
        hasDeviated = snapshot.hasDeviated
        isUsingStoredRouteFallback = snapshot.isUsingStoredRouteFallback
    }

    private func applyStoredPolylineFallback(from trip: Trip) -> Bool {
        guard let encoded = trip.routePolyline?.trimmingCharacters(in: .whitespacesAndNewlines),
              !encoded.isEmpty else {
            return false
        }

        let decoded: [CLLocationCoordinate2D]? = MapboxDirections.decodePolyline(encoded, precision: 1e6)
            ?? MapboxDirections.decodePolyline(encoded, precision: 1e5)
        guard let decoded, decoded.count >= 2 else { return false }

        decodedRouteCoordinates = decoded
        totalRouteDistanceMetres = routeLength(for: decoded)
        distanceRemainingMetres = totalRouteDistanceMetres
        estimatedArrivalTime = estimateArrival(forRemainingDistance: totalRouteDistanceMetres)
        currentStepInstruction = "Follow the highlighted trip route"
        currentRoute = nil
        alternativeRoute = nil
        routeChoices = []
        selectedChoiceIndex = 0
        latestRouteResponse = nil
        selectedRouteIndex = nil
        hasDeviated = false
        isUsingStoredRouteFallback = true
        return true
    }

    private func routeLength(for coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { partialResult, pair in
            let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partialResult + start.distance(from: end)
        }
    }

    private func estimateArrival(forRemainingDistance distance: Double) -> Date? {
        guard distance > 0 else { return nil }
        let assumedSpeedMetresPerSecond = 35.0 / 3.6
        return Date().addingTimeInterval(distance / assumedSpeedMetresPerSecond)
    }

    private func applyMapServiceFallbackRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async -> Bool {
        do {
            let routes = try await MapService.fetchRoutes(
                originLat: origin.latitude,
                originLng: origin.longitude,
                destLat: destination.latitude,
                destLng: destination.longitude,
                avoidTolls: avoidTolls,
                avoidHighways: avoidHighways
            )
            guard let fastest = routes.first else { return false }
            let decoded: [CLLocationCoordinate2D]? = MapboxDirections.decodePolyline(fastest.geometry, precision: 1e6)
                ?? MapboxDirections.decodePolyline(fastest.geometry, precision: 1e5)
            guard let decoded, decoded.count >= 2 else { return false }

            decodedRouteCoordinates = decoded
            totalRouteDistanceMetres = fastest.distanceKm * 1000
            distanceRemainingMetres = totalRouteDistanceMetres
            estimatedArrivalTime = estimateArrival(forRemainingDistance: totalRouteDistanceMetres)
            currentStepInstruction = fastest.steps.first?.instruction ?? "Follow the highlighted route"
            currentRoute = nil
            alternativeRoute = nil
            routeChoices = []
            selectedChoiceIndex = 0
            latestRouteResponse = nil
            selectedRouteIndex = nil
            hasDeviated = false
            isUsingStoredRouteFallback = false
            return true
        } catch {
            #if DEBUG
            print("[RouteEngine] MapService fallback failed: \(error)")
            #endif
            return false
        }
    }
}
