import SwiftUI
import MapKit

/// Admin fleet live map: vehicle annotations + geofence circle overlays.
struct FleetLiveMapView: View {

    @Environment(AppDataStore.self) private var store
    @Bindable var viewModel: FleetLiveMapViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasSetInitialRegion = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapContent

            VStack(spacing: 8) {
                mapToolButton(icon: "plus") { zoomIn() }
                mapToolButton(icon: "minus") { zoomOut() }
            }
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            .padding(.top, 16)
            .padding(.trailing, 12)
        }
        .onAppear {
            if !hasSetInitialRegion {
                hasSetInitialRegion = true
                fitAllVehicles()
            }
            Task { await viewModel.refreshFallbackCoordinates(for: store.vehicles) }
        }
        .sheet(isPresented: $viewModel.showVehicleDetail) {
            if let vehicleId = viewModel.selectedVehicleId,
               let vehicle = store.vehicles.first(where: { $0.id == vehicleId }) {
                VehicleMapDetailSheet(vehicle: vehicle) { viewModel.showVehicleDetail = false }
            }
        }
        .sheet(isPresented: $viewModel.showFilterPicker) { filterSheet }
        .onChange(of: viewModel.selectedVehicleId) { _, newId in
            guard let newId,
                  let vehicle = store.vehicles.first(where: { $0.id == newId }) else { return }
            if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        latitudinalMeters: 2000, longitudinalMeters: 2000
                    ))
                }
            } else {
                // No GPS - show vehicle detail sheet even without map movement
                viewModel.showVehicleDetail = true
            }
        }
        .onChange(of: store.vehicles.count) { _, _ in
            Task { await viewModel.refreshFallbackCoordinates(for: store.vehicles) }
        }
        .onChange(of: vehicleLocationSignature) { _, _ in
            Task { await viewModel.refreshFallbackCoordinates(for: store.vehicles) }
        }
    }

    // MARK: - Fit All Vehicles

    private func fitAllVehicles() {
        let active = store.vehicles.compactMap { viewModel.coordinate(for: $0) }
        if active.isEmpty {
            // Default to India centre if no live vehicles
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                latitudinalMeters: 3_000_000, longitudinalMeters: 3_000_000
            ))
            return
        }
        if active.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(center: active[0], latitudinalMeters: 5000, longitudinalMeters: 5000))
            return
        }
        let lats = active.map(\ .latitude)
        let lngs = active.map(\ .longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (lats.max()! - lats.min()!) * 1.4 + 0.01, longitudeDelta: (lngs.max()! - lngs.min()!) * 1.4 + 0.01)
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        let displayedVehicles = viewModel.filteredVehicles(from: store.vehicles, trips: store.trips)
        let displayedGeofences = viewModel.displayedGeofences(
            allGeofences: store.geofences,
            trips: store.trips,
            vehicles: displayedVehicles,
            visibleRegion: visibleRegion
        )

        Map(position: $cameraPosition) {
            ForEach(displayedVehicles) { vehicle in
                if let coordinate = viewModel.coordinate(for: vehicle) {
                    Annotation(vehicle.licensePlate, coordinate: coordinate) {
                        vehicleAnnotationView(vehicle)
                            .onTapGesture {
                                viewModel.selectedVehicleId = vehicle.id
                                viewModel.showVehicleDetail = true
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("\(vehicle.name), \(vehicle.licensePlate)")
                            .accessibilityHint("Opens vehicle details")
                    }
                }
            }

            ForEach(displayedGeofences) { geofence in
                MapCircle(
                    center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
                    radius: GeofenceScopeService.normalizedRadiusMeters(geofence.radiusMeters)
                )
                .foregroundStyle(geofenceColor(geofence.geofenceType).opacity(0.18))
                .stroke(geofenceColor(geofence.geofenceType).opacity(0.8), lineWidth: 1.5)
            }
            UserAnnotation()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            visibleRegion = context.region
        }
        .mapStyle(.standard)
        .mapControlVisibility(.visible)
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
    }

    private var vehicleLocationSignature: Int {
        var hasher = Hasher()
        hasher.combine(store.vehicles.count)
        for vehicle in store.vehicles {
            hasher.combine(vehicle.id)
            hasher.combine(vehicle.status.rawValue)
            if let lat = vehicle.currentLatitude {
                hasher.combine(Int((lat * 100_000).rounded()))
            }
            if let lng = vehicle.currentLongitude {
                hasher.combine(Int((lng * 100_000).rounded()))
            }
        }
        return hasher.finalize()
    }

    // MARK: - Vehicle Annotation

    private func vehicleAnnotationView(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 2) {
            Image(systemName: annotationIcon(for: vehicle.status))
                .font(SierraFont.scaled(16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32).background(annotationColor(for: vehicle.status), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Text(vehicle.licensePlate)
                .font(SierraFont.scaled(8, weight: .bold, design: .monospaced)).foregroundStyle(.primary)
                .padding(.horizontal, 4).padding(.vertical, 1).background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func annotationIcon(for status: VehicleStatus) -> String {
        switch status {
        case .inMaintenance: return "wrench.fill"
        default: return "truck.box.fill"
        }
    }

    private func annotationColor(for status: VehicleStatus) -> Color {
        switch status {
        case .active, .busy: return .blue
        case .idle: return .gray
        case .inMaintenance: return .orange
        case .outOfService, .decommissioned: return .red
        }
    }

    private func geofenceColor(_ type: GeofenceType) -> Color {
        switch type {
        case .warehouse: return .blue
        case .deliveryPoint: return .green
        case .restrictedZone: return .red
        case .custom: return .teal
        }
    }

    // MARK: - Floating Button

    private func mapToolButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(SierraFont.scaled(17, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(.primary)
    }

    private func zoomIn() {
        guard var region = visibleRegion else { return }
        let minDelta = 0.002
        let maxDelta = 90.0
        region.span.latitudeDelta = min(max(region.span.latitudeDelta * 0.55, minDelta), maxDelta)
        region.span.longitudeDelta = min(max(region.span.longitudeDelta * 0.55, minDelta), maxDelta)
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(region)
        }
    }

    private func zoomOut() {
        guard var region = visibleRegion else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                latitudinalMeters: 3_000_000,
                longitudinalMeters: 3_000_000
            ))
            return
        }
        let minDelta = 0.002
        let maxDelta = 90.0
        region.span.latitudeDelta = min(max(region.span.latitudeDelta * 1.8, minDelta), maxDelta)
        region.span.longitudeDelta = min(max(region.span.longitudeDelta * 1.8, minDelta), maxDelta)
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(region)
        }
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                ForEach(FleetLiveMapViewModel.VehicleFilter.allCases, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                        viewModel.showFilterPicker = false
                    } label: {
                        HStack {
                            Text(filter.rawValue).foregroundStyle(.primary)
                            Spacer()
                            if filter == viewModel.selectedFilter {
                                Image(systemName: "checkmark").foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Vehicles").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

}
