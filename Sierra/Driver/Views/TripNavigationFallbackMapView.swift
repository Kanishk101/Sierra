import SwiftUI
import MapKit

/// Native fallback renderer used when Mapbox is unavailable.
/// It keeps the driver route line and live breadcrumb trail visible even if
/// Mapbox token/configuration is broken.
struct TripNavigationFallbackMapView: View {

    let coordinator: TripNavigationCoordinator

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if coordinator.displayedRouteCoordinates.count >= 2 {
                MapPolyline(coordinates: coordinator.displayedRouteCoordinates)
                    .stroke(.orange, lineWidth: 7)
            }

            if coordinator.breadcrumbCoordinates.count >= 2 {
                MapPolyline(coordinates: coordinator.breadcrumbCoordinates)
                    .stroke(.teal, lineWidth: 4)
            }

            if let originLatitude = coordinator.trip.originLatitude,
               let originLongitude = coordinator.trip.originLongitude {
                Annotation(coordinator.trip.origin, coordinate: CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)) {
                    endpointMarker(systemImage: "location.fill", color: .green)
                }
            }

            if let destinationLatitude = coordinator.trip.destinationLatitude,
               let destinationLongitude = coordinator.trip.destinationLongitude {
                Annotation(coordinator.trip.destination, coordinate: CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)) {
                    endpointMarker(systemImage: "mappin", color: .red)
                }
            }

            ForEach((coordinator.trip.routeStops ?? []).sorted { $0.order < $1.order }) { stop in
                Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)) {
                    endpointMarker(systemImage: "circle.fill", color: .orange)
                }
            }

            if let current = coordinator.currentLocation?.coordinate {
                Annotation("You", coordinate: current) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 18, height: 18)
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 22, height: 22)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
        .onAppear(perform: updateCamera)
        .onChange(of: coordinator.displayedRouteCoordinates.count) { _, _ in
            updateCamera()
        }
    }

    private func endpointMarker(systemImage: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }

    private func updateCamera() {
        var coordinates = coordinator.displayedRouteCoordinates

        if let current = coordinator.currentLocation?.coordinate {
            coordinates.append(current)
        }

        if let originLatitude = coordinator.trip.originLatitude,
           let originLongitude = coordinator.trip.originLongitude {
            coordinates.append(CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude))
        }

        if let destinationLatitude = coordinator.trip.destinationLatitude,
           let destinationLongitude = coordinator.trip.destinationLongitude {
            coordinates.append(CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude))
        }

        guard !coordinates.isEmpty else { return }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLng = longitudes.min(),
              let maxLng = longitudes.max() else {
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.02)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
