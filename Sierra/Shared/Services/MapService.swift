import Foundation

// MARK: - MapServiceError

enum MapServiceError: LocalizedError {
    case tokenMissing
    case noRoutesFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .tokenMissing:
            return "Navigation configuration error. Please contact your fleet manager."
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
    private static var token: String? {
        ProcessInfo.processInfo.environment["MAPBOX_TOKEN"]
            ?? Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String
    }

    /// Fetch driving routes between two coordinate pairs.
    /// Returns up to 3 alternative routes with turn-by-turn steps.
    static func fetchRoutes(
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        avoidTolls: Bool = false,
        avoidHighways: Bool = false
    ) async throws -> [MapRoute] {
        guard let token else { throw MapServiceError.tokenMissing }

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
                        }
                    }
                }
            }

            mapRoutes.append(MapRoute(
                label: index == 0 ? "Fastest Route" : "Alternative \(index)",
                distanceKm: distance / 1000.0,
                durationMinutes: duration / 60.0,
                geometry: geometry,
                steps: steps,
                isGreen: false
            ))
        }

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
}
