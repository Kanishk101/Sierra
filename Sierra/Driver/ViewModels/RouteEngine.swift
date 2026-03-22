import Foundation
import CoreLocation
import MapboxDirections
import Turf

// MARK: - RouteEngine
// Extracted from TripNavigationCoordinator. Owns all Mapbox Directions SDK
// interaction: building routes, selecting the green route, adding mid-trip
// stops, and re-routing after deviations.

@MainActor
@Observable
final class RouteEngine {

    // MARK: - Public State (read by views via coordinator forwarding)

    var currentRoute: MapboxDirections.Route?
    var alternativeRoute: MapboxDirections.Route?
    var currentStepInstruction: String = ""
    var distanceRemainingMetres: Double = 0
    var estimatedArrivalTime: Date?
    var hasDeviated: Bool = false
    var avoidTolls: Bool = false
    var avoidHighways: Bool = false

    // MARK: - Internal State (accessed by coordinator)

    private(set) var decodedRouteCoordinates: [CLLocationCoordinate2D] = []
    private(set) var hasBuiltRoutes: Bool = false

    // Waypoints added by the driver mid-trip via the HUD stop picker.
    private var intermediateWaypoints: [(lat: Double, lng: Double, name: String)] = []

    // When true, buildRoutes() uses currentLocation as the route origin.
    private var rerouteFromCurrentLocation: Bool = false

    // MARK: - Route Building

    func buildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        guard !hasBuiltRoutes else { return }

        // --- Determine effective origin ---
        let startLat: Double
        let startLng: Double
        let isRerouting = rerouteFromCurrentLocation

        if isRerouting, let loc = currentLocation {
            startLat = loc.coordinate.latitude
            startLng = loc.coordinate.longitude
            rerouteFromCurrentLocation = false
        } else {
            rerouteFromCurrentLocation = false
            guard let originLat = trip.originLatitude,
                  let originLng = trip.originLongitude else {
                print("[RouteEngine] Missing trip coordinates")
                return
            }
            startLat = originLat
            startLng = originLng
        }

        guard let destLat = trip.destinationLatitude,
              let destLng = trip.destinationLongitude else {
            print("[RouteEngine] Missing trip destination coordinates")
            return
        }

        // --- Build waypoint array: origin → stops → destination ---
        let originWP = Waypoint(coordinate: CLLocationCoordinate2D(latitude: startLat, longitude: startLng))
        var waypoints: [Waypoint] = [originWP]

        // Inject any stops from the Trip model's route_stops field
        let modelStops = (trip.routeStops ?? []).sorted { $0.order < $1.order }
        for stop in modelStops {
            waypoints.append(Waypoint(
                coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                name: stop.name
            ))
        }

        // Plus any stops added mid-trip via addStop()
        for stop in intermediateWaypoints {
            waypoints.append(Waypoint(
                coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng),
                name: stop.name
            ))
        }

        waypoints.append(Waypoint(coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng)))

        let options = RouteOptions(waypoints: waypoints)
        options.includesAlternativeRoutes = true
        options.routeShapeResolution = .full
        options.shapeFormat = .polyline6
        options.profileIdentifier = .automobileAvoidingTraffic
        options.attributeOptions = [.congestionLevel, .expectedTravelTime, .speed]
        if trip.scheduledDate > Date() {
            options.departAt = trip.scheduledDate
        }

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

            hasBuiltRoutes = true
            if hasDeviated { hasDeviated = false }

        } catch {
            print("[RouteEngine] Route build failed (will retry on next buildRoutes() call): \(error)")
        }
    }

    // MARK: - Select Green Route

    func selectGreenRoute() {
        guard let alt = alternativeRoute else { return }
        let prev         = currentRoute
        currentRoute     = alt
        alternativeRoute = prev

        // Re-decode the newly selected route's shape for deviation detection
        if let shape = currentRoute?.shape {
            decodedRouteCoordinates = shape.coordinates
        }

        // Refresh HUD state for the new route
        if let firstStep = currentRoute?.legs.first?.steps.first {
            currentStepInstruction = firstStep.instructions
        }
        if let travel = currentRoute?.expectedTravelTime {
            estimatedArrivalTime = Date().addingTimeInterval(travel)
        }
        if let dist = currentRoute?.distance {
            distanceRemainingMetres = dist
        }
    }

    // MARK: - Rebuild Routes

    func rebuildRoutes(trip: Trip, currentLocation: CLLocation?) async {
        hasBuiltRoutes = false
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    // MARK: - Add Stop

    func addStop(latitude: Double, longitude: Double, name: String, trip: Trip, currentLocation: CLLocation?) async {
        intermediateWaypoints.append((lat: latitude, lng: longitude, name: name))
        hasBuiltRoutes = false
        await buildRoutes(trip: trip, currentLocation: currentLocation)
    }

    // MARK: - Reroute Flag

    func triggerRerouteFromCurrentLocation() {
        rerouteFromCurrentLocation = true
        hasBuiltRoutes = false
    }
}
