import SwiftUI

struct VehicleListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatus? = nil
    @State private var showAddSheet = false
    @State private var editingVehicle: Vehicle?
    @State private var deleteTarget: Vehicle?
    @State private var isVehicleRefreshRunning = false
    @State private var showRefreshTimeoutAlert = false

    private let refreshTimeoutSeconds = 10
    private let refreshPollIntervalNanoseconds: UInt64 = 200_000_000

    private var filteredVehicles: [Vehicle] {
        store.vehicles.filter { v in
            if let filter = selectedFilter, v.status != filter { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return v.name.lowercased().contains(q)
                    || v.model.lowercased().contains(q)
                    || v.licensePlate.lowercased().contains(q)
                    || v.vin.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))

                if filteredVehicles.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredVehicles) { vehicle in
                            NavigationLink(value: vehicle.id) {
                                vehicleRow(vehicle)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = vehicle
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                Button {
                                    editingVehicle = vehicle
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Vehicles")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                VehicleDetailView(vehicleId: id)
            }
            .task {
                if store.vehicles.isEmpty { await loadVehiclesWithTimeout() }
            }
            .refreshable {
                await loadVehiclesWithTimeout()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) { AddVehicleView() }
            .sheet(item: $editingVehicle) { vehicle in AddVehicleView(editingVehicle: vehicle) }
            .confirmationDialog("Delete Vehicle?", isPresented: .init(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let v = deleteTarget {
                        Task { try? await store.deleteVehicle(id: v.id) }
                        deleteTarget = nil
                    }
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("This vehicle will be permanently removed.")
            }
            .alert("Refresh Timed Out", isPresented: $showRefreshTimeoutAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Vehicle refresh exceeded 10 seconds. Please pull to refresh again.")
            }
        }
    }

    @MainActor
    private func loadVehiclesWithTimeout() async {
        guard !isVehicleRefreshRunning else { return }
        isVehicleRefreshRunning = true

        let tracker = RefreshTracker()
        let refreshTask = Task {
            await store.loadAll()
            await tracker.markFinished()
        }

        defer { isVehicleRefreshRunning = false }

        for _ in 0..<(refreshTimeoutSeconds * 5) {
            if await tracker.isFinished() { return }
            try? await Task.sleep(nanoseconds: refreshPollIntervalNanoseconds)
        }

        refreshTask.cancel()
        store.loadError = "Vehicle refresh timed out after 10 seconds."
        showRefreshTimeoutAlert = true
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", isSelected: selectedFilter == nil) { selectedFilter = nil }
                ForEach(VehicleStatus.allCases, id: \.self) { status in
                    filterChip(status.rawValue, isSelected: selectedFilter == status) {
                        selectedFilter = status
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .clear : Color(.separator), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle Row

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        // Look up assigned driver from store
        let driver: StaffMember? = vehicle.assignedDriverId
            .flatMap { UUID(uuidString: $0) }
            .flatMap { store.staffMember(for: $0) }

        return HStack(spacing: 14) {
            // Vehicle icon
            Image(systemName: "car.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(vehicle.model) \u{00B7} \(vehicle.licensePlate)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                // Assigned driver + their availability
                if let driver {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(driver.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        availabilityDot(driver.availability)
                        Text(driver.availability.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(availabilityColor(driver.availability))
                    }
                } else if vehicle.assignedDriverId != nil {
                    // Driver ID exists but not in store
                    Text("Driver loading\u{2026}")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No driver assigned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            SierraBadge(vehicle.status, size: .compact)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Availability helpers

    private func availabilityDot(_ availability: StaffAvailability) -> some View {
        Circle()
            .fill(availabilityColor(availability))
            .frame(width: 6, height: 6)
    }

    private func availabilityColor(_ availability: StaffAvailability) -> Color {
        switch availability {
        case .available:   return .green
        case .busy:        return .orange
        case .onTrip:      return .blue
        case .onTask:      return Color(.systemOrange)
        case .unavailable: return .red
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SierraEmptyState(
            icon: "car.fill",
            title: "No vehicles found",
            message: emptySubtitle
        )
    }

    private var emptySubtitle: String {
        if !searchText.isEmpty { return "Try a different search term." }
        switch selectedFilter {
        case .active:         return "No active vehicles at the moment."
        case .idle:           return "No idle vehicles available."
        case .busy:           return "No busy vehicles at the moment."
        case .inMaintenance:  return "No vehicles currently in maintenance."
        case .outOfService:   return "No out-of-service vehicles."
        case .decommissioned: return "No decommissioned vehicles."
        case .none:           return "Add your first vehicle to get started."
        }
    }
}

private actor RefreshTracker {
    private var finished = false

    func markFinished() {
        finished = true
    }

    func isFinished() -> Bool {
        finished
    }
}

extension Vehicle: Hashable {
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    VehicleListView()
        .environment(AppDataStore.shared)
}
