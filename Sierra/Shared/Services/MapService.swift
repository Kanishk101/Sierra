import Foundation
import MapKit
import MapboxDirections

let mapboxTokenSetupMessage = "Mapbox access token is missing. Add a valid MBXAccessToken to Sierra/Info.plist or MAPBOX_TOKEN to the run scheme environment."

// MARK: - MapServiceError

enum MapServiceError: LocalizedError {
    case tokenMissing
    case noRoutesFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .tokenMissing:
            return mapboxTokenSetupMessage
        case .noRoutesFound:
            return "No routes found between the selected locations."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - MapRoute

struct MapRoute: Identifiable {
    let id = UUID()
    let label: String
    let distanceKm: Double
    let durationMinutes: Double
    let geometry: String   // polyline6 encoded
    let steps: [RouteStep]
    let isGreen: Bool
}

// MARK: - RouteStep

struct RouteStep {
    let instruction: String
    let distanceM: Double
    let maneuverType: String
    let maneuverModifier: String?
}

// MARK: - MapService
// Centralises all Mapbox Directions API calls.
// Token is read from Info.plist (MBXAccessToken) or env var for testing.
// Phase 10: steps=true + voice/banner instructions enabled.

struct MapService {

    /// Mapbox access token — tries env (unit tests), then Info.plist.
    /// NEVER print this value to logs.
    static var accessToken: String? {
        sanitizedToken(ProcessInfo.processInfo.environment["MAPBOX_TOKEN"])
            ?? sanitizedToken(Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String)
            ?? sanitizedToken(Bundle.main.object(forInfoDictionaryKey: "MGLMapboxAccessToken") as? String)
    }

    static var hasValidToken: Bool { accessToken != nil }

    static var configurationErrorDescription: String { mapboxTokenSetupMessage }

    private static func sanitizedToken(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Fetch driving routes between two coordinate pairs.
    /// Returns up to 3 alternative routes with turn-by-turn steps.
    static func fetchRoutes(
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        avoidTolls: Bool = false,
        avoidHighways: Bool = false
    ) async throws -> [MapRoute] {
        guard let token = accessToken else {
            return try await fetchRoutesWithMapKit(
                originLat: originLat,
                originLng: originLng,
                destLat: destLat,
                destLng: destLng
            )
        }

        var components = URLComponents(string: "https://api.mapbox.com/directions/v5/mapbox/driving/\(originLng),\(originLat);\(destLng),\(destLat)")!
        components.queryItems = [
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "geometries",   value: "polyline6"),
            URLQueryItem(name: "overview",      value: "full"),
            URLQueryItem(name: "steps",         value: "true"),
            URLQueryItem(name: "voice_instructions", value: "true"),
            URLQueryItem(name: "banner_instructions", value: "true"),
            URLQueryItem(name: "access_token",  value: token)
        ]
        if avoidTolls || avoidHighways {
            let exclusions = [avoidTolls ? "toll" : nil, avoidHighways ? "motorway" : nil]
                .compactMap { $0 }.joined(separator: ",")
            components.queryItems?.append(URLQueryItem(name: "exclude", value: exclusions))
        }

        guard let url = components.url else { throw MapServiceError.noRoutesFound }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Sierra-FMS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MapServiceError.networkError(error)
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MapServiceError.networkError(URLError(.badServerResponse))
        }

        return try parseMapboxResponse(data)
    }

    private static func fetchRoutesWithMapKit(
        originLat: Double,
        originLng: Double,
        destLat: Double,
        destLng: Double
    ) async throws -> [MapRoute] {
        let request = MKDirections.Request()
        request.source = mapItem(
            latitude: originLat,
            longitude: originLng
        )
        request.destination = mapItem(
            latitude: destLat,
            longitude: destLng
        )
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let response: MKDirections.Response
        do {
            response = try await withCheckedThrowingContinuation { continuation in
                MKDirections(request: request).calculate { response, error in
                    if let response {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    }
                }
            }
        } catch {
            throw MapServiceError.networkError(error)
        }

        let routes = response.routes.prefix(3)
        guard !routes.isEmpty else { throw MapServiceError.noRoutesFound }

        var mapRoutes: [MapRoute] = routes.enumerated().map { index, route in
            let coordinates = route.polyline.coordinates
            let geometry = Polyline(coordinates: coordinates, precision: 1e6).encodedPolyline
            let steps = route.steps.compactMap { step -> RouteStep? in
                guard step.distance > 0 else { return nil }
                let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                return RouteStep(
                    instruction: instruction.isEmpty ? "Continue" : instruction,
                    distanceM: step.distance,
                    maneuverType: "",
                    maneuverModifier: nil
                )
            }

            return MapRoute(
                label: index == 0 ? "Fastest Route" : "Alternative \(index)",
                distanceKm: route.distance / 1000.0,
                durationMinutes: route.expectedTravelTime / 60.0,
                geometry: geometry,
                steps: steps,
                isGreen: false
            )
        }

        if mapRoutes.count > 1,
           let greenOffset = mapRoutes.dropFirst().enumerated().min(by: { $0.element.distanceKm < $1.element.distanceKm })?.offset {
            let greenIndex = greenOffset + 1
            let greenRoute = mapRoutes[greenIndex]
            mapRoutes[greenIndex] = MapRoute(
                label: "Green Route",
                distanceKm: greenRoute.distanceKm,
                durationMinutes: greenRoute.durationMinutes,
                geometry: greenRoute.geometry,
                steps: greenRoute.steps,
                isGreen: true
            )
        }

        return mapRoutes
    }

    // MARK: - JSON Parsing

    private static func parseMapboxResponse(_ data: Data) throws -> [MapRoute] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]],
              !routes.isEmpty else {
            throw MapServiceError.noRoutesFound
        }

        var mapRoutes: [MapRoute] = []

        for (index, route) in routes.prefix(3).enumerated() {
            guard let distance = route["distance"] as? Double,
                  let duration = route["duration"] as? Double,
                  let geometry = route["geometry"] as? String else { continue }

            // Parse steps from legs
            var steps: [RouteStep] = []
            if let legs = route["legs"] as? [[String: Any]] {
                for leg in legs {
                    if let legSteps = leg["steps"] as? [[String: Any]] {
                        for step in legSteps {
                            let instruction = (step["name"] as? String) ?? ""
                            let stepDistance = (step["distance"] as? Double) ?? 0
                            var maneuverType = ""
                            var maneuverMod: String?

                            if let maneuver = step["maneuver"] as? [String: Any] {
                                maneuverType = (maneuver["type"] as? String) ?? ""
                                maneuverMod  = maneuver["modifier"] as? String
                                // Use the maneuver instruction if available (more descriptive)
                                if let mi = maneuver["instruction"] as? String, !mi.isEmpty {
                                    steps.append(RouteStep(
                                        instruction: mi,
                                        distanceM: stepDistance,
                                        maneuverType: maneuverType,
                                        maneuverModifier: maneuverMod
                                    ))
                                    continue
                                }
                            }

                            steps.append(RouteStep(
                                instruction: instruction.isEmpty ? "Continue" : instruction,
                                distanceM: stepDistance,
                                maneuverType: maneuverType,
                                maneuverModifier: maneuverMod
                            ))
                        }  // for step
                    }  // if legSteps
                }  // for leg
            }  // if legs

            mapRoutes.append(MapRoute(
                label: index == 0 ? "Fastest Route" : "Alternative \(index)",
                distanceKm: distance / 1000.0,
                durationMinutes: duration / 60.0,
                geometry: geometry,
                steps: steps,
                isGreen: false
            ))
        }  // for route

        guard !mapRoutes.isEmpty else { throw MapServiceError.noRoutesFound }

        // Mark the shortest-distance non-fastest route as "Green"
        if mapRoutes.count > 1 {
            let fastestGeo = mapRoutes[0].geometry
            if let greenIdx = mapRoutes.dropFirst()
                .enumerated()
                .filter({ $0.element.geometry != fastestGeo })
                .min(by: { $0.element.distanceKm < $1.element.distanceKm })?
                .offset {
                let g = mapRoutes[greenIdx + 1]
                mapRoutes[greenIdx + 1] = MapRoute(
                    label: "Green Route",
                    distanceKm: g.distanceKm,
                    durationMinutes: g.durationMinutes,
                    geometry: g.geometry,
                    steps: g.steps,
                    isGreen: true
                )
            }
        }

        return mapRoutes
    }

    // MARK: - MKMapItem helper

    private static func mapItem(latitude: Double, longitude: Double) -> MKMapItem {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if #available(iOS 26.0, *) {
            return MKMapItem(
                location: CLLocation(latitude: coord.latitude, longitude: coord.longitude),
                address: nil
            )
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coord))
        }
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
