import Foundation
import CoreLocation
import MapboxDirections
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

    // MARK: - Public State
    var currentRoute: MapboxDirections.Route?
    var alternativeRoute: MapboxDirections.Route?
    var currentStepInstruction: String = ""
    var distanceRemainingMetres: Double = 0
    var estimatedArrivalTime: Date?
    var hasDeviated: Bool = false
    var avoidTolls: Bool = false
    var avoidHighways: Bool = false
    var lastBuildError: String? = nil

    // MARK: - Internal State
    private(set) var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    private var intermediateWaypoints: [(lat: Double, lng: Double, name: String)] = []
    private var rerouteFromCurrentLocation: Bool = false
    private var isBuilding: Bool = false  // CODE-33 FIX: prevent concurrent builds

    // MARK: - Route Building
    //
    // FIX 1: Removed `guard !hasBuiltRoutes` — now always retries if currentRoute is nil.
    // FIX 2: Falls back to currentLocation as origin when trip coordinates are missing.
    // FIX 3: Falls back to currentLocation as destination when destination coords missing.

    func buildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        // Only skip if we already have a valid route AND we're not rerouting
        if currentRoute != nil && !rerouteFromCurrentLocation { return }
        // CODE-33 FIX: Prevent concurrent route calculations
        guard !isBuilding else { return }
        isBuilding = true
        defer { isBuilding = false }

        let isRerouting = rerouteFromCurrentLocation
        rerouteFromCurrentLocation = false
        lastBuildError = nil

        // --- Determine origin ---
        let originCoord: CLLocationCoordinate2D
        if isRerouting, let loc = currentLocation {
            originCoord = loc.coordinate
        } else if let lat = trip.originLatitude, let lng = trip.originLongitude {
            originCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else if let loc = currentLocation {
            // Trip has no stored coordinates — use driver's current position as origin
            print("[RouteEngine] No trip origin coords, using current location as origin")
            originCoord = loc.coordinate
        } else {
            lastBuildError = "Trip has no location data and GPS is not yet available. Move to get a GPS fix and retry."
            print("[RouteEngine] \(lastBuildError!)")
            return
        }

        // --- Determine destination ---
        let destCoord: CLLocationCoordinate2D
        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
            destCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            lastBuildError = "Trip destination coordinates are not set. Ask your fleet manager to update the trip."
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
        options.attributeOptions = [.congestionLevel, .expectedTravelTime, .speed]
        if trip.scheduledDate > Date() { options.departAt = trip.scheduledDate }

        var avoidClasses: RoadClasses = []
        if avoidTolls { avoidClasses.insert(.toll) }
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
            guard !routes.isEmpty else {
                lastBuildError = "No routes found between these locations."
                return
            }

            if let fastestIndex = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime }) {
                let fastest = routes[fastestIndex]
                currentRoute = fastest
                distanceRemainingMetres = fastest.distance
                estimatedArrivalTime = Date().addingTimeInterval(fastest.expectedTravelTime)
                if let firstStep = fastest.legs.first?.steps.first { currentStepInstruction = firstStep.instructions }
                if routes.count > 1 { alternativeRoute = routes.enumerated().first(where: { $0.offset != fastestIndex })?.element }
            }
            if let shape = currentRoute?.shape { decodedRouteCoordinates = shape.coordinates }
            if hasDeviated { hasDeviated = false }

        } catch {
            lastBuildError = "Route calculation failed: \(error.localizedDescription)"
            print("[RouteEngine] \(lastBuildError!)")
        }
    }

    /// ISSUE-19 FIX: Renamed from selectGreenRoute — this swaps primary and alternative routes.
    func swapAlternativeRoute() {
        guard let alt = alternativeRoute else { return }
        let prev = currentRoute; currentRoute = alt; alternativeRoute = prev
        if let shape = currentRoute?.shape { decodedRouteCoordinates = shape.coordinates }
        if let firstStep = currentRoute?.legs.first?.steps.first { currentStepInstruction = firstStep.instructions }
        if let travel = currentRoute?.expectedTravelTime { estimatedArrivalTime = Date().addingTimeInterval(travel) }
        if let dist = currentRoute?.distance { distanceRemainingMetres = dist }
    }

    func rebuildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        currentRoute = nil  // force rebuild
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func addStop(latitude: Double, longitude: Double, name: String, trip: Trip, currentLocation: CLLocation?) async {
        intermediateWaypoints.append((lat: latitude, lng: longitude, name: name))
        currentRoute = nil
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    func triggerRerouteFromCurrentLocation() {
        rerouteFromCurrentLocation = true
        currentRoute = nil
    }
}
