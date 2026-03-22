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
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.updateRoute(mapView: mapView, route: coordinator.currentRoute)
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
    }
}
