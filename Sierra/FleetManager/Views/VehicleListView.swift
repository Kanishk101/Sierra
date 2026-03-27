import SwiftUI

struct VehicleListView: View {
    @Environment(AppDataStore.self) private var store
    private let initialMaintenanceTaskId: UUID?
    private let embedInParentNavigation: Bool
    @State private var selectedFilter: VehicleStatus? = nil
    @State private var showAddSheet = false
    @State private var editingVehicle: Vehicle?
    @State private var deleteTarget: Vehicle?
    @State private var navigationTarget: UUID?
    @State private var segmentMode = 0  // 0 = My Vehicles, 1 = Maintenance

    init(
        initialSegmentMode: Int = 0,
        initialMaintenanceTaskId: UUID? = nil,
        embedInParentNavigation: Bool = false
    ) {
        self.initialMaintenanceTaskId = initialMaintenanceTaskId
        self.embedInParentNavigation = embedInParentNavigation
        _segmentMode = State(initialValue: initialSegmentMode)
    }

    private var filteredVehicles: [Vehicle] {
        store.vehicles.filter { v in
            if let filter = selectedFilter, v.status != filter { return false }
            return true
        }
    }

    var body: some View {
        Group {
            if embedInParentNavigation {
                content
            } else {
                NavigationStack { content }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if segmentMode == 0 {
                modePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                Group {
                    if store.isLoading && store.vehicles.isEmpty {
                        vehiclesLoadingSkeleton
                    } else if filteredVehicles.isEmpty {
                        SierraEmptyState(icon: "car.fill", title: "No vehicles found", message: selectedFilter == nil ? "Add your first vehicle to get started." : "No vehicles match this filter.")
                    } else {
                        vehicleList
                    }
                }
            } else {
                MaintenanceHubView(
                    showInlineHeader: true,
                    topAccessory: AnyView(
                        modePicker
                            .padding(.horizontal, 16)
                    ),
                    openTaskId: initialMaintenanceTaskId
                )
            }
        }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { VehicleDetailView(vehicleId: $0) }
            .navigationDestination(item: $navigationTarget) { VehicleDetailView(vehicleId: $0) }
            .task { if store.vehicles.isEmpty { await store.loadAll() } }
            .sheet(isPresented: $showAddSheet) { AddVehicleView() }
            .sheet(item: $editingVehicle) { AddVehicleView(editingVehicle: $0) }
            .confirmationDialog("Delete Vehicle?", isPresented: .init(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let v = deleteTarget { Task { try? await store.deleteVehicle(id: v.id) }; deleteTarget = nil }
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: { Text("This vehicle will be permanently removed.") }
            .toolbar {
                if segmentMode == 0 {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }

                        Menu {
                            Button {
                                selectedFilter = nil
                            } label: {
                                SierraSelectionMenuRow(title: "All", isSelected: selectedFilter == nil)
                            }
                            Divider()
                            ForEach(VehicleStatus.allCases, id: \.self) { status in
                                Button {
                                    selectedFilter = status
                                } label: {
                                    SierraSelectionMenuRow(title: status.rawValue, isSelected: selectedFilter == status)
                                }
                            }
                        } label: {
                            Image(systemName: selectedFilter == nil
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill")
                        }
                        .tint(selectedFilter == nil ? .primary : .orange)
                    }
                }
            }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $segmentMode) {
            Text("My Vehicles").tag(0)
            Text("Maintenance").tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var vehicleList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredVehicles) { vehicle in
                    vehicleCard(vehicle)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { navigationTarget = vehicle.id }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(vehicle.name), \(vehicle.licensePlate)")
                        .accessibilityHint("Opens vehicle details")
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
        .refreshable { await store.loadAll(force: true) }
    }

    private var vehiclesLoadingSkeleton: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 14) {
                        SierraSkeletonView(width: 44, height: 44, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 8) {
                            SierraSkeletonView(width: 160, height: 14)
                            SierraSkeletonView(width: 170, height: 10)
                            SierraSkeletonView(width: 120, height: 10)
                        }
                        Spacer()
                        SierraSkeletonView(width: 74, height: 20, cornerRadius: 10)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(SierraFont.scaled(20)).foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.name).font(SierraFont.scaled(15, weight: .semibold)).foregroundStyle(.primary)
                Text("\(vehicle.model) \u{00B7} \(vehicle.licensePlate)")
                    .font(SierraFont.scaled(12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                if let d = driver {
                    HStack(spacing: 4) {
                        Circle().fill(availabilityColor(d.availability)).frame(width: 6, height: 6)
                        Text(d.displayName).font(SierraFont.scaled(11, weight: .medium)).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No driver assigned").font(SierraFont.scaled(11, weight: .medium)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            SierraBadge(vehicle.status, size: .compact)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
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
