import SwiftUI
import MapKit

/// Admin fleet live map: vehicle annotations + geofence circle overlays.
struct FleetLiveMapView: View {

    @Environment(AppDataStore.self) private var store
    @Bindable var viewModel: FleetLiveMapViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialRegion = false
    @State private var showVehicleSearch = false
    @State private var vehicleSearchText = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapContent

            // Floating controls — search + filter only (no geofence create here)
            VStack(spacing: 12) {
                floatingButton(icon: "magnifyingglass.circle.fill") { showVehicleSearch = true }
                floatingButton(icon: "line.3.horizontal.decrease.circle.fill") { viewModel.showFilterPicker = true }
                floatingButton(icon: "arrow.up.left.and.arrow.down.right.circle.fill") { fitAllVehicles() }
            }
            .padding(.top, 60).padding(.trailing, 16)
        }
        .navigationTitle("Fleet Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasSetInitialRegion {
                hasSetInitialRegion = true
                fitAllVehicles()
            }
        }
        .sheet(isPresented: $viewModel.showVehicleDetail) {
            if let vehicleId = viewModel.selectedVehicleId,
               let vehicle = store.vehicles.first(where: { $0.id == vehicleId }) {
                VehicleMapDetailSheet(vehicle: vehicle, viewModel: viewModel) { viewModel.showVehicleDetail = false }
            }
        }
        .sheet(isPresented: $viewModel.showFilterPicker) { filterSheet }
        .sheet(isPresented: $showVehicleSearch) { vehicleSearchSheet }
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
                // No GPS — show vehicle detail sheet even without map movement
                viewModel.showVehicleDetail = true
            }
        }
    }

    // MARK: - Fit All Vehicles

    private func fitAllVehicles() {
        let active = store.vehicles.compactMap { v -> CLLocationCoordinate2D? in
            guard let lat = v.currentLatitude, let lng = v.currentLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
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
        let lats = active.map(\.latitude)
        let lngs = active.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (lats.max()! - lats.min()!) * 1.4 + 0.01, longitudeDelta: (lngs.max()! - lngs.min()!) * 1.4 + 0.01)
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        let displayedVehicles = viewModel.filteredVehicles(from: store.vehicles)

        Map(position: $cameraPosition) {
            ForEach(displayedVehicles) { vehicle in
                if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
                    Annotation(vehicle.licensePlate, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                        vehicleAnnotationView(vehicle)
                            .onTapGesture {
                                viewModel.selectedVehicleId = vehicle.id
                                viewModel.showVehicleDetail = true
                            }
                    }
                }
            }

            ForEach(store.geofences.filter { $0.isActive }) { geofence in
                MapCircle(
                    center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
                    radius: geofence.radiusMeters
                )
                .foregroundStyle(geofenceColor(geofence.geofenceType).opacity(0.18))
                .stroke(geofenceColor(geofence.geofenceType).opacity(0.8), lineWidth: 1.5)
            }

            if viewModel.breadcrumbCoordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.breadcrumbCoordinates)
                    .stroke(.orange, lineWidth: 3)
            }
        }
        .mapStyle(.standard)
        .mapControls { MapCompass(); MapScaleView() }
    }

    // MARK: - Vehicle Annotation

    private func vehicleAnnotationView(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 2) {
            Image(systemName: annotationIcon(for: vehicle.status))
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32).background(annotationColor(for: vehicle.status), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Text(vehicle.licensePlate)
                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.primary)
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

    private func floatingButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { viewModel.showFilterPicker = false } }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Vehicle Search Sheet

    private var vehicleSearchSheet: some View {
        NavigationStack {
            let matches = store.vehicles.filter {
                guard !vehicleSearchText.isEmpty else { return true }
                return $0.name.localizedCaseInsensitiveContains(vehicleSearchText)
                    || $0.licensePlate.localizedCaseInsensitiveContains(vehicleSearchText)
                    || $0.model.localizedCaseInsensitiveContains(vehicleSearchText)
            }
            List {
                if matches.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "car.fill").font(.title2).foregroundStyle(.tertiary)
                            Text(vehicleSearchText.isEmpty ? "No vehicles in fleet" : "No matches for \"\(vehicleSearchText)\"")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 30)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(matches) { vehicle in
                        Button {
                            viewModel.selectedVehicleId = vehicle.id
                            showVehicleSearch = false
                            // Camera will snap in onChange(of: selectedVehicleId)
                            viewModel.showVehicleDetail = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(annotationColor(for: vehicle.status))
                                    .frame(width: 36, height: 36)
                                    .background(annotationColor(for: vehicle.status).opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(vehicle.licensePlate).font(.caption).foregroundStyle(.secondary)
                                    if vehicle.currentLatitude == nil {
                                        Text("No live location").font(.caption2).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                SierraBadge(vehicle.status, size: .compact)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Find Vehicle").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vehicleSearchText, prompt: "Name, plate or model…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { showVehicleSearch = false } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
