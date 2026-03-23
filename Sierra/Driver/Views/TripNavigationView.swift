import SwiftUI
import MapboxNavigationCore
import MapboxMaps
import MapboxDirections
import Turf
import CoreLocation

// MARK: - TripNavigationView
//
// UIViewRepresentable wrapping Mapbox Maps v3 MapView.
// MapboxDirections is linked separately for Route / RouteStep types.
//
// Safeguard: MapView is created ONCE in makeUIView, never recreated.

struct TripNavigationView: UIViewRepresentable {

    let coordinator: TripNavigationCoordinator

    func makeUIView(context: Context) -> MapView {
        let cameraOptions = CameraOptions(
            center: coordinator.currentLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            zoom: 16,
            bearing: coordinator.currentLocation?.course,
            pitch: 45  // 3D tilt for navigation feel
        )
        let mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        // Puck config: road-snapped with course bearing and orange pulse
        var puck = Puck2DConfiguration.makeDefault(showBearing: true)
        puck.pulsing = .init(color: .orange)
        mapView.location.options.puckType = .puck2D(puck)
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.puckBearing = .course

        // Set viewport to follow puck with navigation padding and tilt
        mapView.viewport.transition(to:
            mapView.viewport.makeFollowPuckViewportState(
                options: FollowPuckViewportStateOptions(
                    padding: UIEdgeInsets(top: 200, left: 20, bottom: 280, right: 20),
                    zoom: 16,
                    bearing: .course,
                    pitch: 45
                )
            )
        )

        context.coordinator.mapView = mapView
        addRouteLayer(to: mapView)
        context.coordinator.renderStops(mapView: mapView, trip: coordinator.trip)
        context.coordinator.renderEndpoints(mapView: mapView, trip: coordinator.trip)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.updateRoute(mapView: mapView, route: coordinator.currentRoute)
        context.coordinator.renderStops(mapView: mapView, trip: coordinator.trip)
        context.coordinator.renderEndpoints(mapView: mapView, trip: coordinator.trip)
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    // MARK: - Route Layer Setup

    private func addRouteLayer(to mapView: MapView) {
        var source = GeoJSONSource(id: "route-source")
        source.data = .geometry(.lineString(.init([])))

        // Casing line underneath
        var casingLayer = LineLayer(id: "route-casing", source: "route-source")
        casingLayer.lineColor = .constant(StyleColor(UIColor.orange.withAlphaComponent(0.3)))
        casingLayer.lineWidth = .constant(14)
        casingLayer.lineCap = .constant(.round)
        casingLayer.lineJoin = .constant(.round)

        // Active route line on top
        var layer = LineLayer(id: "route-layer", source: "route-source")
        layer.lineColor = .constant(StyleColor(.orange))
        layer.lineWidth = .constant(8)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)

        try? mapView.mapboxMap.addSource(source)
        try? mapView.mapboxMap.addLayer(casingLayer)
        try? mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Map Coordinator

    class MapCoordinator {
        weak var mapView: MapView?
        private var routeAdded = false

        func updateRoute(mapView: MapView, route: MapboxDirections.Route?) {
            guard let route, let shape = route.shape else { return }
            let coordinates = shape.coordinates
            guard coordinates.count >= 2 else { return }

            let feature = Feature(geometry: .lineString(LineString(coordinates)))
            let geoJSON = GeoJSONObject.feature(feature)
            mapView.mapboxMap.updateGeoJSONSource(withId: "route-source", geoJSON: geoJSON)

            // Only zoom-to-fit on first route display
            if !routeAdded {
                routeAdded = true
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
        }

        // MARK: - Render Stops (intermediate waypoints)

        func renderStops(mapView: MapView, trip: Trip) {
            // Remove existing stop source if present to avoid duplicate adds
            if (try? mapView.mapboxMap.source(withId: "stops-source")) != nil {
                try? mapView.mapboxMap.removeLayer(withId: "stops-labels")
                try? mapView.mapboxMap.removeLayer(withId: "stops-circles")
                try? mapView.mapboxMap.removeSource(withId: "stops-source")
            }

            let stops = (trip.routeStops ?? []).sorted { $0.order < $1.order }
            guard !stops.isEmpty else { return }

            var features: [Feature] = []
            for (i, stop) in stops.enumerated() {
                let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                var feature = Feature(geometry: .point(Point(coord)))
                var props = JSONObject()
                props["name"] = JSONValue(stop.name)
                props["order"] = JSONValue(Double(i + 1))
                feature.properties = props
                features.append(feature)
            }

            let collection = FeatureCollection(features: features)
            var source = GeoJSONSource(id: "stops-source")
            source.data = .featureCollection(collection)
            try? mapView.mapboxMap.addSource(source)

            // Circle markers for stops
            var circleLayer = CircleLayer(id: "stops-circles", source: "stops-source")
            circleLayer.circleRadius = .constant(8)
            circleLayer.circleColor = .constant(StyleColor(UIColor.orange))
            circleLayer.circleStrokeWidth = .constant(2)
            circleLayer.circleStrokeColor = .constant(StyleColor(.white))
            try? mapView.mapboxMap.addLayer(circleLayer)

            // Text labels for stops
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

        func renderEndpoints(mapView: MapView, trip: Trip) {
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

            // Circles — green for origin, red for destination
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

            // Labels
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
