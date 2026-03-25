import SwiftUI
import MapKit

/// Admin fleet live map: vehicle annotations + geofence circle overlays.
struct FleetLiveMapView: View {

    @Environment(AppDataStore.self) private var store
    @Bindable var viewModel: FleetLiveMapViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasSetInitialRegion = false
    @State private var breadcrumbPollTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapContent

            VStack(spacing: 10) {
                mapToolButton(icon: "plus") { zoom(by: 0.6) }
                mapToolButton(icon: "minus") { zoom(by: 1.7) }
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 30, height: 1)
                mapToolButton(icon: "arrow.up.left.and.arrow.down.right") { fitAllVehicles() }
                mapToolButton(icon: "line.3.horizontal.decrease") { viewModel.showFilterPicker = true }
            }
            .frame(width: 60)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        .onAppear {
            if !hasSetInitialRegion {
                hasSetInitialRegion = true
                fitAllVehicles()
            }
            Task { await viewModel.refreshFallbackCoordinates(for: store.vehicles) }
            startBreadcrumbPollingIfNeeded()
        }
        .onDisappear {
            breadcrumbPollTask?.cancel()
            breadcrumbPollTask = nil
        }
        .sheet(isPresented: $viewModel.showVehicleDetail) {
            if let vehicleId = viewModel.selectedVehicleId,
               let vehicle = store.vehicles.first(where: { $0.id == vehicleId }) {
                VehicleMapDetailSheet(vehicle: vehicle, viewModel: viewModel) { viewModel.showVehicleDetail = false }
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
                // No GPS — show vehicle detail sheet even without map movement
                viewModel.showVehicleDetail = true
            }
            startBreadcrumbPollingIfNeeded()
        }
        .onChange(of: store.vehicles.count) { _, _ in
            Task { await viewModel.refreshFallbackCoordinates(for: store.vehicles) }
            startBreadcrumbPollingIfNeeded()
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
                if let coordinate = viewModel.coordinate(for: vehicle) {
                    Annotation(vehicle.licensePlate, coordinate: coordinate) {
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

            let breadcrumb = viewModel.sanitizedBreadcrumbCoordinates()
            if breadcrumb.count >= 2 {
                MapPolyline(coordinates: breadcrumb)
                    .stroke(.orange, lineWidth: 3)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            visibleRegion = context.region
        }
        .mapStyle(.standard)
        .mapControls { MapCompass() }
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

    private func mapToolButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.22), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
    }

    private func zoom(by factor: Double) {
        guard var region = visibleRegion else {
            fitAllVehicles()
            return
        }
        let minDelta = 0.002
        let maxDelta = 90.0
        region.span.latitudeDelta = min(max(region.span.latitudeDelta * factor, minDelta), maxDelta)
        region.span.longitudeDelta = min(max(region.span.longitudeDelta * factor, minDelta), maxDelta)
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
        }
        .presentationDetents([.medium])
    }

    private func startBreadcrumbPollingIfNeeded() {
        breadcrumbPollTask?.cancel()
        breadcrumbPollTask = nil

        if viewModel.selectedVehicleId == nil {
            if let firstLiveVehicle = viewModel
                .filteredVehicles(from: store.vehicles)
                .first(where: { viewModel.coordinate(for: $0) != nil }) {
                viewModel.selectedVehicleId = firstLiveVehicle.id
            }
        }

        guard viewModel.selectedVehicleId != nil else {
            viewModel.clearBreadcrumb()
            return
        }

        breadcrumbPollTask = Task {
            while !Task.isCancelled {
                await refreshSelectedVehicleBreadcrumb()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func refreshSelectedVehicleBreadcrumb() async {
        guard let selectedVehicleId = viewModel.selectedVehicleId else { return }
        let selectedVehicleIdText = selectedVehicleId.uuidString.lowercased()
        let activeTrip = store.trips
            .filter {
                $0.vehicleId?.lowercased() == selectedVehicleIdText &&
                $0.status.normalized == .active
            }
            .sorted { ($0.actualStartDate ?? $0.scheduledDate) > ($1.actualStartDate ?? $1.scheduledDate) }
            .first

        guard let trip = activeTrip else {
            await viewModel.fetchRecentBreadcrumb(vehicleId: selectedVehicleId)
            return
        }
        await viewModel.fetchBreadcrumb(vehicleId: selectedVehicleId, tripId: trip.id)
    }
}
