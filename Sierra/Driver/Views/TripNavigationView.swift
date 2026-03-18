import SwiftUI
import MapboxNavigationCore
import MapboxDirections
import CoreLocation

/// Map view showing the route with a polyline overlay and live driver position.
/// MapboxMaps types (MapView, CameraOptions, PolylineAnnotation etc.) are
/// re-exported through MapboxNavigationCore in SDK v3 — no direct MapboxMaps link needed.
/// Safeguard 4: MapView is created ONCE in makeUIView, never recreated.
struct TripNavigationView: UIViewRepresentable {

    let coordinator: TripNavigationCoordinator

    func makeUIView(context: Context) -> MapView {
        let cameraOptions = CameraOptions(
            center: coordinator.currentLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            zoom: 14
        )
        let mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        mapView.location.options.puckType = .puck2D(.makeDefault(showBearing: true))
        mapView.location.options.puckBearing = .heading
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        // Add route line once, when available
        context.coordinator.addRouteIfNeeded(mapView: mapView, route: coordinator.currentRoute)

        // Follow driver location
        if let location = coordinator.currentLocation {
            let camera = CameraOptions(center: location.coordinate, zoom: 15, bearing: location.course)
            mapView.camera.ease(to: camera, duration: 1.0)
        }
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    class MapCoordinator {
        weak var mapView: MapView?
        private var routeAdded = false

        func addRouteIfNeeded(mapView: MapView, route: MapboxDirections.Route?) {
            guard !routeAdded, let route, let shape = route.shape else { return }

            let coordinates = shape.coordinates
            guard coordinates.count >= 2 else { return }

            routeAdded = true

            let annotationManager = mapView.annotations.makePolylineAnnotationManager()

            var annotation = PolylineAnnotation(lineCoordinates: coordinates)
            annotation.lineColor = StyleColor(.systemBlue)
            annotation.lineWidth = 6.0
            annotation.lineOpacity = 0.85

            annotationManager.annotations = [annotation]

            // Fit camera to route bounds
            let camera = mapView.mapboxMap.camera(
                for: coordinates,
                padding: UIEdgeInsets(top: 80, left: 40, bottom: 200, right: 40),
                bearing: nil,
                pitch: nil
            )
            mapView.camera.ease(to: camera, duration: 1.0)
        }
    }
}
