import SwiftUI
import Combine
import MapboxMaps
import MapboxDirections
import Turf
import CoreLocation

// MARK: - TripNavigationView
//
// UIViewRepresentable wrapping Mapbox Maps v3 MapView.
// The route/trail overlays are installed only after the style is ready so the
// line sources do not silently fail during startup.

struct TripNavigationView: UIViewRepresentable {

    let coordinator: TripNavigationCoordinator
    var simulate: Bool = false


    func makeUIView(context: Context) -> MapView {
        let cameraOptions = CameraOptions(
            center: coordinator.currentLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            zoom: 16,
            bearing: coordinator.currentLocation?.course,
            pitch: 45
        )
        let mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        var puck = Puck2DConfiguration.makeDefault(showBearing: true)
        puck.pulsing = .init(color: .orange)
        mapView.location.options.puckType = .puck2D(puck)
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.puckBearing = .course

        let followPuck = mapView.viewport.makeFollowPuckViewportState(
            options: FollowPuckViewportStateOptions(
                padding: UIEdgeInsets(top: 240, left: 40, bottom: 320, right: 40),
                zoom: 16.5,
                bearing: .course,
                pitch: 50
            )
        )
        // Set immediately so the first scheduleRender skips the overview camera
        context.coordinator.isFollowingPuck = true
        mapView.viewport.transition(to: followPuck)

        // Detect when user manually drags/pinches the map → break follow-puck
        mapView.viewport.addStatusObserver(context.coordinator)

        context.coordinator.attach(to: mapView)
        context.coordinator.scheduleRender(
            mapView: mapView,
            trip: coordinator.trip,
            routeCoordinates: coordinator.remainingRouteCoordinates,
            breadcrumbCoordinates: coordinator.breadcrumbCoordinates,
            congestionLevels: nil,
            travelerCoordinate: coordinator.currentRouteCoordinate ?? coordinator.currentLocation?.coordinate,
            headingTargetCoordinate: coordinator.nextRouteCoordinate,
            geofences: coordinator.activeGeofences
        )
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        // Handle explicit recenter request from HUD
        if coordinator.requestRecenter {
            coordinator.requestRecenter = false

            // Cancel any competing camera animation, then re-engage follow-puck
            mapView.viewport.idle()
            let followState = mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 240, left: 40, bottom: 320, right: 40),
                    zoom: 16.5,
                    bearing: .course,
                    pitch: 50
                )
            )
            mapView.viewport.transition(to: followState) { success in
                if success {
                    context.coordinator.isFollowingPuck = true
                }
            }
        }

        let congestion = coordinator.currentRoute?.legs.first?.segmentCongestionLevels
        context.coordinator.scheduleRender(
            mapView: mapView,
            trip: coordinator.trip,
            routeCoordinates: coordinator.remainingRouteCoordinates,
            breadcrumbCoordinates: coordinator.breadcrumbCoordinates,
            congestionLevels: congestion,
            travelerCoordinate: coordinator.currentRouteCoordinate ?? coordinator.currentLocation?.coordinate,
            headingTargetCoordinate: coordinator.nextRouteCoordinate,
            geofences: coordinator.activeGeofences
        )
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    // MARK: - Map Coordinator

    final class MapCoordinator: ViewportStatusObserver {
        weak var mapView: MapView?

        var isFollowingPuck = false
        private var routeCameraApplied = false
        private var styleIsReady = false
        private var cancellables = Set<AnyCancellable>()

        // Change-detection: skip GeoJSON uploads when data hasn't changed
        private var lastRouteHash: Int = 0
        private var lastBreadcrumbCount: Int = 0
        private var lastTravelerLat: Double = 0
        private var lastTravelerLon: Double = 0
        private var lastGeofenceCount: Int = 0
        private var lastStopCount: Int = -1
        private var lastEndpointHash: Int = 0

        // Cached geofence circle polygons keyed by (lat, lon, radius)
        private var geofenceCircleCache: [String: [CLLocationCoordinate2D]] = [:]
        // MARK: ViewportStatusObserver
        func viewportStatusDidChange(from fromStatus: ViewportStatus,
                                     to toStatus: ViewportStatus,
                                     reason: ViewportStatusChangeReason) {
            // When the user drags/pinches the map, Mapbox moves the viewport to
            // idle.  Mark isFollowingPuck false so the next SwiftUI render (or
            // recenter tap) will re-engage follow-puck.
            if reason == .userInteraction {
                isFollowingPuck = false
            }
        }

        private var pendingTrip: Trip?
        private var pendingRouteCoordinates: [CLLocationCoordinate2D] = []
        private var pendingBreadcrumbCoordinates: [CLLocationCoordinate2D] = []
        private var pendingCongestionLevels: [MapboxDirections.CongestionLevel]?
        private var pendingTravelerCoordinate: CLLocationCoordinate2D?
        private var pendingHeadingTargetCoordinate: CLLocationCoordinate2D?
        private var pendingGeofences: [Geofence] = []

        func attach(to mapView: MapView) {
            guard self.mapView !== mapView else { return }
            self.mapView = mapView

            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self, weak mapView] _ in
                guard let self, let mapView else { return }
                self.styleIsReady = true
                self.ensureOverlayInfrastructure(on: mapView)
                self.renderPending(on: mapView)
            }
            .store(in: &cancellables)
        }

        func scheduleRender(
            mapView: MapView,
            trip: Trip,
            routeCoordinates: [CLLocationCoordinate2D],
            breadcrumbCoordinates: [CLLocationCoordinate2D],
            congestionLevels: [MapboxDirections.CongestionLevel]?,
            travelerCoordinate: CLLocationCoordinate2D?,
            headingTargetCoordinate: CLLocationCoordinate2D?,
            geofences: [Geofence]
        ) {
            pendingTrip = trip
            pendingRouteCoordinates = routeCoordinates
            pendingBreadcrumbCoordinates = breadcrumbCoordinates
            pendingCongestionLevels = congestionLevels
            pendingTravelerCoordinate = travelerCoordinate
            pendingHeadingTargetCoordinate = headingTargetCoordinate
            pendingGeofences = geofences

            guard styleIsReady else { return }
            renderPending(on: mapView)
        }

        private func renderPending(on mapView: MapView) {
            ensureOverlayInfrastructure(on: mapView)
            updateRoute(mapView: mapView, coordinates: pendingRouteCoordinates, congestionLevels: pendingCongestionLevels)
            updateBreadcrumbTrail(mapView: mapView, coordinates: pendingBreadcrumbCoordinates)
            updateTravelerPuck(
                mapView: mapView,
                coordinate: pendingTravelerCoordinate,
                headingTarget: pendingHeadingTargetCoordinate
            )
            renderGeofences(mapView: mapView, geofences: pendingGeofences)

            if let trip = pendingTrip {
                renderStops(mapView: mapView, trip: trip)
                renderEndpoints(mapView: mapView, trip: trip)
            }
        }

        // MARK: - Base Route / Breadcrumb Layers

        private func ensureOverlayInfrastructure(on mapView: MapView) {
            ensureLineSource(on: mapView, id: "route-source")
            ensureLineLayer(
                on: mapView,
                id: "route-casing",
                sourceId: "route-source",
                color: UIColor.orange.withAlphaComponent(0.28),
                width: 14
            )
            ensureLineLayer(
                on: mapView,
                id: "route-layer",
                sourceId: "route-source",
                color: .orange,
                width: 8
            )

            ensureLineSource(on: mapView, id: "breadcrumb-source")
            ensureLineLayer(
                on: mapView,
                id: "breadcrumb-casing",
                sourceId: "breadcrumb-source",
                color: UIColor.black.withAlphaComponent(0.2),
                width: 10
            )
            ensureLineLayer(
                on: mapView,
                id: "breadcrumb-layer",
                sourceId: "breadcrumb-source",
                color: UIColor.systemTeal,
                width: 5
            )

            ensureLineSource(on: mapView, id: "traveler-heading-source")
            ensureLineLayer(
                on: mapView,
                id: "traveler-heading-layer",
                sourceId: "traveler-heading-source",
                color: UIColor.systemBlue.withAlphaComponent(0.65),
                width: 3
            )

            ensurePointSource(on: mapView, id: "traveler-source")
            ensureTravelerLayers(on: mapView)

            ensureFillSource(on: mapView, id: "geofence-source")
            ensureGeofenceLayers(on: mapView)
        }

        private func ensureLineSource(on mapView: MapView, id: String) {
            guard (try? mapView.mapboxMap.source(withId: id)) == nil else { return }
            var source = GeoJSONSource(id: id)
            source.data = .geometry(.lineString(.init([])))
            try? mapView.mapboxMap.addSource(source)
        }

        private func ensurePointSource(on mapView: MapView, id: String) {
            guard (try? mapView.mapboxMap.source(withId: id)) == nil else { return }
            var source = GeoJSONSource(id: id)
            source.data = .geometry(.point(.init(CLLocationCoordinate2D(latitude: 0, longitude: 0))))
            try? mapView.mapboxMap.addSource(source)
        }

        private func ensureFillSource(on mapView: MapView, id: String) {
            guard (try? mapView.mapboxMap.source(withId: id)) == nil else { return }
            var source = GeoJSONSource(id: id)
            source.data = .featureCollection(FeatureCollection(features: []))
            try? mapView.mapboxMap.addSource(source)
        }

        private func ensureLineLayer(
            on mapView: MapView,
            id: String,
            sourceId: String,
            color: UIColor,
            width: Double
        ) {
            guard (try? mapView.mapboxMap.layer(withId: id)) == nil else { return }
            var layer = LineLayer(id: id, source: sourceId)
            layer.lineColor = .constant(StyleColor(color))
            layer.lineWidth = .constant(width)
            layer.lineCap = .constant(.round)
            layer.lineJoin = .constant(.round)
            try? mapView.mapboxMap.addLayer(layer)
        }

        private func ensureTravelerLayers(on mapView: MapView) {
            if (try? mapView.mapboxMap.layer(withId: "traveler-layer")) == nil {
                var layer = CircleLayer(id: "traveler-layer", source: "traveler-source")
                layer.circleRadius = .constant(8)
                layer.circleColor = .constant(StyleColor(.systemBlue))
                layer.circleStrokeColor = .constant(StyleColor(.white))
                layer.circleStrokeWidth = .constant(3)
                try? mapView.mapboxMap.addLayer(layer)
            }

            if (try? mapView.mapboxMap.layer(withId: "traveler-halo-layer")) == nil {
                var layer = CircleLayer(id: "traveler-halo-layer", source: "traveler-source")
                layer.circleRadius = .constant(14)
                layer.circleColor = .constant(StyleColor(UIColor.systemBlue.withAlphaComponent(0.18)))
                try? mapView.mapboxMap.addLayer(layer, layerPosition: .below("traveler-layer"))
            }
        }

        private func ensureGeofenceLayers(on mapView: MapView) {
            if (try? mapView.mapboxMap.layer(withId: "geofence-fill-layer")) == nil {
                var fillLayer = FillLayer(id: "geofence-fill-layer", source: "geofence-source")
                fillLayer.fillColor = .constant(StyleColor(UIColor.systemTeal.withAlphaComponent(0.18)))
                fillLayer.fillOutlineColor = .constant(StyleColor(UIColor.systemTeal.withAlphaComponent(0.45)))
                try? mapView.mapboxMap.addLayer(fillLayer, layerPosition: .below("route-casing"))
            }

            if (try? mapView.mapboxMap.layer(withId: "geofence-line-layer")) == nil {
                var lineLayer = LineLayer(id: "geofence-line-layer", source: "geofence-source")
                lineLayer.lineColor = .constant(StyleColor(UIColor.systemTeal.withAlphaComponent(0.7)))
                lineLayer.lineWidth = .constant(2)
                lineLayer.lineDasharray = .constant([2, 2])
                try? mapView.mapboxMap.addLayer(lineLayer, layerPosition: .below("route-casing"))
            }
        }

        // MARK: - Route / Breadcrumb Rendering

        private func updateRoute(mapView: MapView, coordinates: [CLLocationCoordinate2D], congestionLevels: [MapboxDirections.CongestionLevel]?) {
            // Skip if route data hasn't meaningfully changed (count + first coord)
            var hasher = Hasher()
            hasher.combine(coordinates.count)
            if let first = coordinates.first {
                hasher.combine(Int(first.latitude * 100_000))
                hasher.combine(Int(first.longitude * 100_000))
            }
            let newHash = hasher.finalize()
            guard newHash != lastRouteHash else { return }
            lastRouteHash = newHash

            // Fix 11: Use per-segment congestion colors when available
            if let levels = congestionLevels, coordinates.count >= 2 {
                updateCongestionColoredRoute(mapView: mapView, coordinates: coordinates, levels: levels)
            } else {
                updateLineSource(mapView: mapView, sourceId: "route-source", coordinates: coordinates)
            }

            guard coordinates.count >= 2 else {
                routeCameraApplied = false
                return
            }

            // Skip overview camera when follow-puck is active — the viewport
            // is already tracking the driver's location.
            guard !routeCameraApplied, !isFollowingPuck else { return }
            routeCameraApplied = true

            let camera: CameraOptions
            do {
                camera = try mapView.mapboxMap.camera(
                    for: coordinates,
                    camera: CameraOptions(),
                    coordinatesPadding: UIEdgeInsets(top: 80, left: 40, bottom: 200, right: 40),
                    maxZoom: nil,
                    offset: nil
                )
            } catch {
                camera = CameraOptions(center: coordinates.first, zoom: 14)
            }
            mapView.camera.ease(to: camera, duration: 1.0)
        }

        // Fix 11: Congestion-colored route rendering
        private func updateCongestionColoredRoute(
            mapView: MapView,
            coordinates: [CLLocationCoordinate2D],
            levels: [MapboxDirections.CongestionLevel]
        ) {
            let segmentCount = min(levels.count, max(0, coordinates.count - 1))
            guard segmentCount > 0 else {
                updateLineSource(mapView: mapView, sourceId: "route-source", coordinates: coordinates)
                return
            }

            // Build per-segment features with congestion color properties
            var features: [Feature] = []
            var groupStart = 0

            for i in 0..<segmentCount {
                let isLast = (i == segmentCount - 1)
                let levelChanged = !isLast && levels[i] != levels[i + 1]

                if isLast || levelChanged {
                    let end = i + 1
                    guard groupStart <= end, end < coordinates.count else {
                        groupStart = end
                        continue
                    }
                    let segCoords = Array(coordinates[groupStart...end])
                    guard segCoords.count >= 2 else { groupStart = i + 1; continue }

                    var feature = Feature(geometry: .lineString(LineString(segCoords)))
                    feature.properties = ["congestionColor": .string(congestionHexColor(levels[i]))]
                    features.append(feature)
                    groupStart = end
                }
            }

            guard !features.isEmpty else {
                updateLineSource(mapView: mapView, sourceId: "route-source", coordinates: coordinates)
                return
            }

            let collection = FeatureCollection(features: features)
            mapView.mapboxMap.updateGeoJSONSource(
                withId: "route-source",
                geoJSON: .featureCollection(collection)
            )

            // Update route-layer to use data-driven color from feature properties
            if var layer = try? mapView.mapboxMap.layer(withId: "route-layer", type: LineLayer.self) {
                layer.lineColor = .expression(
                    Exp(.get) { "congestionColor" }
                )
                try? mapView.mapboxMap.updateLayer(withId: "route-layer", type: LineLayer.self) { l in
                    l.lineColor = layer.lineColor
                }
            }
        }

        private func congestionHexColor(_ level: MapboxDirections.CongestionLevel) -> String {
            switch level {
            case .low:      return "#34C759"  // green
            case .moderate: return "#FFCC00"  // yellow
            case .heavy:    return "#FF9500"  // orange
            case .severe:   return "#FF3B30"  // red
            case .unknown:  return "#FF9500"  // default orange
            @unknown default: return "#FF9500"
            }
        }

        private func updateBreadcrumbTrail(mapView: MapView, coordinates: [CLLocationCoordinate2D]) {
            // Skip if breadcrumb count hasn't changed (grows monotonically during navigation)
            guard coordinates.count != lastBreadcrumbCount else { return }
            lastBreadcrumbCount = coordinates.count
            updateLineSource(mapView: mapView, sourceId: "breadcrumb-source", coordinates: coordinates)
        }

        private func updateTravelerPuck(
            mapView: MapView,
            coordinate: CLLocationCoordinate2D?,
            headingTarget: CLLocationCoordinate2D?
        ) {
            guard let coordinate else { return }

            // Skip if puck hasn't moved noticeably (~1m ≈ 0.00001°)
            let dLat = abs(coordinate.latitude - lastTravelerLat)
            let dLon = abs(coordinate.longitude - lastTravelerLon)
            guard dLat > 0.00001 || dLon > 0.00001 else { return }
            lastTravelerLat = coordinate.latitude
            lastTravelerLon = coordinate.longitude

            let feature = Feature(geometry: .point(Point(coordinate)))
            mapView.mapboxMap.updateGeoJSONSource(withId: "traveler-source", geoJSON: .feature(feature))

            if let headingTarget {
                updateLineSource(
                    mapView: mapView,
                    sourceId: "traveler-heading-source",
                    coordinates: [coordinate, headingTarget]
                )
            } else {
                updateLineSource(mapView: mapView, sourceId: "traveler-heading-source", coordinates: [])
            }
        }

        private func renderGeofences(mapView: MapView, geofences: [Geofence]) {
            // Skip if geofence set hasn't changed
            guard geofences.count != lastGeofenceCount else { return }
            lastGeofenceCount = geofences.count

            let features: [Feature] = geofences.compactMap { geofence in
                let center = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
                let cacheKey = "\(geofence.latitude),\(geofence.longitude),\(geofence.radiusMeters)"
                let ring: [CLLocationCoordinate2D]
                if let cached = geofenceCircleCache[cacheKey] {
                    ring = cached
                } else {
                    ring = geodesicCircleCoordinates(center: center, radiusMeters: geofence.radiusMeters)
                    geofenceCircleCache[cacheKey] = ring
                }
                guard ring.count >= 4 else { return nil }
                return Feature(geometry: .polygon(Polygon([ring])))
            }
            let collection = FeatureCollection(features: features)
            mapView.mapboxMap.updateGeoJSONSource(withId: "geofence-source", geoJSON: .featureCollection(collection))
        }

        private func geodesicCircleCoordinates(
            center: CLLocationCoordinate2D,
            radiusMeters: Double,
            segments: Int = 60
        ) -> [CLLocationCoordinate2D] {
            guard radiusMeters > 0, segments >= 12 else { return [] }

            let earthRadius = 6_378_137.0
            let angularDistance = radiusMeters / earthRadius
            let lat1 = center.latitude * .pi / 180
            let lon1 = center.longitude * .pi / 180

            return (0...segments).map { index in
                let bearing = (2 * .pi * Double(index)) / Double(segments)
                let sinLat1 = sin(lat1)
                let cosLat1 = cos(lat1)
                let sinAD = sin(angularDistance)
                let cosAD = cos(angularDistance)

                let lat2 = asin(sinLat1 * cosAD + cosLat1 * sinAD * cos(bearing))
                let lon2 = lon1 + atan2(
                    sin(bearing) * sinAD * cosLat1,
                    cosAD - sinLat1 * sin(lat2)
                )
                return CLLocationCoordinate2D(
                    latitude: lat2 * 180 / .pi,
                    longitude: lon2 * 180 / .pi
                )
            }
        }

        private func updateLineSource(
            mapView: MapView,
            sourceId: String,
            coordinates: [CLLocationCoordinate2D]
        ) {
            let feature = Feature(
                geometry: .lineString(LineString(coordinates.count >= 2 ? coordinates : []))
            )
            mapView.mapboxMap.updateGeoJSONSource(
                withId: sourceId,
                geoJSON: .feature(feature)
            )
        }

        // MARK: - Render Stops

        private func renderStops(mapView: MapView, trip: Trip) {
            let stops = (trip.routeStops ?? []).sorted { $0.order < $1.order }
            // Skip if stop count hasn't changed (stops are static during a trip)
            guard stops.count != lastStopCount else { return }
            lastStopCount = stops.count

            if (try? mapView.mapboxMap.source(withId: "stops-source")) != nil {
                try? mapView.mapboxMap.removeLayer(withId: "stops-labels")
                try? mapView.mapboxMap.removeLayer(withId: "stops-circles")
                try? mapView.mapboxMap.removeSource(withId: "stops-source")
            }
            guard !stops.isEmpty else { return }

            var features: [Feature] = []
            for (index, stop) in stops.enumerated() {
                let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                var feature = Feature(geometry: .point(Point(coord)))
                var props = JSONObject()
                props["name"] = JSONValue(stop.name)
                props["order"] = JSONValue(Double(index + 1))
                feature.properties = props
                features.append(feature)
            }

            let collection = FeatureCollection(features: features)
            var source = GeoJSONSource(id: "stops-source")
            source.data = .featureCollection(collection)
            try? mapView.mapboxMap.addSource(source)

            var circleLayer = CircleLayer(id: "stops-circles", source: "stops-source")
            circleLayer.circleRadius = .constant(8)
            circleLayer.circleColor = .constant(StyleColor(UIColor.orange))
            circleLayer.circleStrokeWidth = .constant(2)
            circleLayer.circleStrokeColor = .constant(StyleColor(.white))
            try? mapView.mapboxMap.addLayer(circleLayer)

            var textLayer = SymbolLayer(id: "stops-labels", source: "stops-source")
            textLayer.textField = .expression(Exp(.get) { "name" })
            textLayer.textSize = .constant(11)
            textLayer.textColor = .constant(StyleColor(.white))
            textLayer.textHaloColor = .constant(StyleColor(.black))
            textLayer.textHaloWidth = .constant(1.5)
            textLayer.textOffset = .constant([0, 1.5])
            textLayer.textAllowOverlap = .constant(true)
            try? mapView.mapboxMap.addLayer(textLayer)
        }

        // MARK: - Render Origin + Destination Markers

        private func renderEndpoints(mapView: MapView, trip: Trip) {
            // Endpoints are static for a given trip — skip if already rendered
            let hash = trip.id.hashValue
            guard hash != lastEndpointHash else { return }
            lastEndpointHash = hash

            if (try? mapView.mapboxMap.source(withId: "endpoints-source")) != nil {
                try? mapView.mapboxMap.removeLayer(withId: "endpoints-labels")
                try? mapView.mapboxMap.removeLayer(withId: "endpoints-circles")
                try? mapView.mapboxMap.removeSource(withId: "endpoints-source")
            }

            var features: [Feature] = []

            if let oLat = trip.originLatitude, let oLng = trip.originLongitude {
                let coord = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
                var feature = Feature(geometry: .point(Point(coord)))
                var props = JSONObject()
                props["name"] = JSONValue(trip.origin)
                props["type"] = JSONValue("origin")
                feature.properties = props
                features.append(feature)
            }

            if let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {
                let coord = CLLocationCoordinate2D(latitude: dLat, longitude: dLng)
                var feature = Feature(geometry: .point(Point(coord)))
                var props = JSONObject()
                props["name"] = JSONValue(trip.destination)
                props["type"] = JSONValue("destination")
                feature.properties = props
                features.append(feature)
            }

            guard !features.isEmpty else { return }

            let collection = FeatureCollection(features: features)
            var source = GeoJSONSource(id: "endpoints-source")
            source.data = .featureCollection(collection)
            try? mapView.mapboxMap.addSource(source)

            var circleLayer = CircleLayer(id: "endpoints-circles", source: "endpoints-source")
            circleLayer.circleRadius = .constant(10)
            circleLayer.circleColor = .expression(
                Exp(.match) {
                    Exp(.get) { "type" }
                    "origin"
                    UIColor(red: 0.2, green: 0.82, blue: 0.55, alpha: 1.0)
                    UIColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 1.0)
                }
            )
            circleLayer.circleStrokeWidth = .constant(3)
            circleLayer.circleStrokeColor = .constant(StyleColor(.white))
            try? mapView.mapboxMap.addLayer(circleLayer)

            var labelLayer = SymbolLayer(id: "endpoints-labels", source: "endpoints-source")
            labelLayer.textField = .expression(Exp(.get) { "name" })
            labelLayer.textSize = .constant(12)
            labelLayer.textColor = .constant(StyleColor(.white))
            labelLayer.textHaloColor = .constant(StyleColor(.black))
            labelLayer.textHaloWidth = .constant(1.5)
            labelLayer.textOffset = .constant([0, 2.0])
            labelLayer.textAllowOverlap = .constant(true)
            try? mapView.mapboxMap.addLayer(labelLayer)
        }
    }
}
