import SwiftUI
import MapKit

/// Admin fleet live map: vehicle annotations + geofence circle overlays.
/// Safeguard 1: ViewModel persisted at parent level (AdminDashboardView).
/// Safeguard 2: annotations updated in-place via identifiable struct array.
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

            // Floating buttons
            VStack(spacing: 12) {
                floatingButton(icon: "magnifyingglass.circle.fill") {
                    showVehicleSearch = true
                }
                floatingButton(icon: "line.3.horizontal.decrease.circle.fill") {
                    viewModel.showFilterPicker = true
                }
                floatingButton(icon: "plus.circle.fill") {
                    viewModel.showCreateGeofence = true
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        .navigationTitle("Fleet Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasSetInitialRegion {
                hasSetInitialRegion = true
                let center = viewModel.fleetCentroid(vehicles: store.vehicles)
                cameraPosition = .region(MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: 50000,
                    longitudinalMeters: 50000
                ))
            }
        }
        .sheet(isPresented: $viewModel.showVehicleDetail) {
            if let vehicleId = viewModel.selectedVehicleId,
               let vehicle = store.vehicles.first(where: { $0.id == vehicleId }) {
                VehicleMapDetailSheet(vehicle: vehicle, viewModel: viewModel) {
                    viewModel.showVehicleDetail = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreateGeofence) {
            CreateGeofenceSheet()
        }
        .sheet(isPresented: $viewModel.showFilterPicker) {
            filterSheet
        }
        .sheet(isPresented: $showVehicleSearch) {
            vehicleSearchSheet
        }
        .onChange(of: viewModel.selectedVehicleId) { _, newId in
            guard let newId,
                  let vehicle = store.vehicles.first(where: { $0.id == newId }),
                  let lat = vehicle.currentLatitude,
                  let lng = vehicle.currentLongitude else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    latitudinalMeters: 2000,
                    longitudinalMeters: 2000
                ))
            }
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        let displayedVehicles = viewModel.filteredVehicles(from: store.vehicles)

        Map(position: $cameraPosition) {
            // Vehicle annotations (Safeguard 2: using Identifiable, updated in-place by MapKit)
            ForEach(displayedVehicles) { vehicle in
                if let lat = vehicle.currentLatitude, let lng = vehicle.currentLongitude {
                    Annotation(vehicle.licensePlate,
                               coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                        vehicleAnnotationView(vehicle)
                            .onTapGesture {
                                viewModel.selectedVehicleId = vehicle.id
                                viewModel.showVehicleDetail = true
                            }
                    }
                }
            }

            // Geofence circle overlays (Safeguard 4: only rendered from store.geofences, not re-added per state change)
            ForEach(store.geofences) { geofence in
                MapCircle(center: CLLocationCoordinate2D(
                    latitude: geofence.latitude,
                    longitude: geofence.longitude
                ), radius: geofence.radiusMeters)
                .foregroundStyle(geofenceColor(geofence.geofenceType).opacity(0.2))
                .stroke(geofenceColor(geofence.geofenceType), lineWidth: 1.5)
            }

            // Breadcrumb polyline for selected vehicle
            if viewModel.breadcrumbCoordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.breadcrumbCoordinates)
                    .stroke(SierraTheme.Colors.ember, lineWidth: 3)
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Vehicle Annotation

    private func vehicleAnnotationView(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 2) {
            Image(systemName: annotationIcon(for: vehicle.status))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(annotationColor(for: vehicle.status), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

            Text(vehicle.licensePlate)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial, in: Capsule())
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
        case .active, .busy: return SierraTheme.Colors.info
        case .idle: return .gray
        case .inMaintenance: return .orange
        case .outOfService, .decommissioned: return SierraTheme.Colors.danger
        }
    }

    // MARK: - Geofence Colors

    private func geofenceColor(_ type: GeofenceType) -> Color {
        switch type {
        case .warehouse: return .blue
        case .deliveryPoint: return .green
        case .restrictedZone: return .red
        case .custom: return .gray
        }
    }

    // MARK: - Floating Button

    private func floatingButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(SierraTheme.Colors.summitNavy.opacity(0.9), in: Circle())
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
                            Text(filter.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if filter == viewModel.selectedFilter {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SierraTheme.Colors.ember)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { viewModel.showFilterPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Vehicle Search Sheet

    private var vehicleSearchSheet: some View {
        NavigationStack {
            let matches = store.vehicles.filter { v in
                guard !vehicleSearchText.isEmpty else { return true }
                let q = vehicleSearchText.lowercased()
                return v.name.localizedCaseInsensitiveContains(q)
                    || v.licensePlate.localizedCaseInsensitiveContains(q)
            }

            List {
                if matches.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "car.fill")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No vehicles matched")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(matches) { vehicle in
                        Button {
                            viewModel.selectedVehicleId = vehicle.id
                            showVehicleSearch = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(annotationColor(for: vehicle.status))
                                    .frame(width: 36, height: 36)
                                    .background(annotationColor(for: vehicle.status).opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(vehicle.licensePlate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                SierraBadge(vehicle.status, size: .compact)

                                if store.trips.contains(where: {
                                    $0.vehicleId == vehicle.id.uuidString && $0.status == .active
                                }) {
                                    Text("On Trip")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.green.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Find Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vehicleSearchText, prompt: "Search by name or plate…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showVehicleSearch = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
