import SwiftUI

struct VehicleListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedFilter: VehicleStatus? = nil
    @State private var showAddSheet = false
    @State private var editingVehicle: Vehicle?
    @State private var deleteTarget: Vehicle?
    @State private var showFilterSheet = false
    @State private var navigationTarget: UUID?
    @State private var segmentMode = 0  // 0 = My Vehicles, 1 = Maintenance

    private var filterBinding: Binding<String?> {
        Binding(get: { selectedFilter?.rawValue }, set: { newVal in selectedFilter = newVal.flatMap { VehicleStatus(rawValue: $0) } })
    }

    private var vehicleFilterOptions: [FilterOption] {
        VehicleStatus.allCases.map { FilterOption(id: $0.rawValue, label: $0.rawValue, icon: vehicleStatusIcon($0), color: vehicleStatusColor($0)) }
    }

    private var filteredVehicles: [Vehicle] {
        store.vehicles.filter { v in
            if let filter = selectedFilter, v.status != filter { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker("Mode", selection: $segmentMode) {
                    Text("My Vehicles").tag(0)
                    Text("Maintenance").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if segmentMode == 0 {
                    // ── My Vehicles ──
                    headerRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    Group {
                        if filteredVehicles.isEmpty {
                            SierraEmptyState(icon: "car.fill", title: "No vehicles found", message: selectedFilter == nil ? "Add your first vehicle to get started." : "No vehicles match this filter.")
                        } else {
                            vehicleList
                        }
                    }
                } else {
                    // ── Maintenance Hub ──
                    MaintenanceHubView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { VehicleDetailView(vehicleId: $0) }
            .navigationDestination(item: $navigationTarget) { VehicleDetailView(vehicleId: $0) }
            .task { if store.vehicles.isEmpty { await store.loadAll() } }
            .refreshable { await store.loadAll() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(title: "Filter Vehicles", options: vehicleFilterOptions, selectedId: filterBinding)
            }
            .sheet(isPresented: $showAddSheet) { AddVehicleView() }
            .sheet(item: $editingVehicle) { AddVehicleView(editingVehicle: $0) }
            .confirmationDialog("Delete Vehicle?", isPresented: .init(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let v = deleteTarget { Task { try? await store.deleteVehicle(id: v.id) }; deleteTarget = nil }
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: { Text("This vehicle will be permanently removed.") }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text("Vehicles")
                .font(.largeTitle.bold())

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(selectedFilter == nil ? .secondary : .orange)
        }
    }

    private var vehicleList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredVehicles) { vehicle in
                    vehicleCard(vehicle)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { navigationTarget = vehicle.id }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteTarget = vehicle } label: { Label("Delete", systemImage: "trash.fill") }
                            Button { editingVehicle = vehicle } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        let driver: StaffMember? = vehicle.assignedDriverId.flatMap { UUID(uuidString: $0) }.flatMap { store.staffMember(for: $0) }
        return HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 20)).foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Text("\(vehicle.model) \u{00B7} \(vehicle.licensePlate)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                if let d = driver {
                    HStack(spacing: 4) {
                        Circle().fill(availabilityColor(d.availability)).frame(width: 6, height: 6)
                        Text(d.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No driver assigned").font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            SierraBadge(vehicle.status, size: .compact)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func vehicleStatusIcon(_ status: VehicleStatus) -> String {
        switch status {
        case .active: return "checkmark.circle.fill"
        case .idle: return "moon.zzz.fill"
        case .busy: return "arrow.right.circle.fill"
        case .inMaintenance: return "wrench.fill"
        case .outOfService: return "xmark.circle.fill"
        case .decommissioned: return "archivebox.fill"
        }
    }
    private func vehicleStatusColor(_ status: VehicleStatus) -> Color {
        switch status {
        case .active: return .green
        case .idle: return .blue
        case .busy: return .orange
        case .inMaintenance: return .purple
        case .outOfService: return .red
        case .decommissioned: return .gray
        }
    }
    private func availabilityColor(_ a: StaffAvailability) -> Color {
        switch a { case .available: return .green; case .busy: return .orange; case .unavailable: return .red }
    }
}

extension Vehicle: Hashable {
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview { VehicleListView().environment(AppDataStore.shared) }
