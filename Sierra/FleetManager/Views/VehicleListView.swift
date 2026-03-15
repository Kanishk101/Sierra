import SwiftUI

struct VehicleListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatus? = nil
    @State private var showAddSheet = false
    @State private var editingVehicle: Vehicle?
    @State private var deleteTarget: Vehicle?

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
                    .padding(.vertical, Spacing.sm)
                    .background(SierraTheme.Colors.appBackground)

                if filteredVehicles.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredVehicles) { vehicle in
                            NavigationLink(value: vehicle.id) {
                                vehicleRow(vehicle)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.md))
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
                                .tint(SierraTheme.Colors.ember)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search vehicles\u{2026}")
            .navigationDestination(for: UUID.self) { id in
                VehicleDetailView(vehicleId: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(SierraFont.body(17, weight: .semibold))
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
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterChip("All", isSelected: selectedFilter == nil) { selectedFilter = nil }
                ForEach(VehicleStatus.allCases, id: \.self) { status in
                    filterChip(status.rawValue, isSelected: selectedFilter == status) {
                        selectedFilter = status
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(SierraFont.caption1)
                .foregroundStyle(isSelected ? .white : SierraTheme.Colors.primaryText)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 7)
                .background(isSelected ? SierraTheme.Colors.ember : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .clear : SierraTheme.Colors.mist, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle Row

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        // Look up assigned driver from store
        let driver: StaffMember? = vehicle.assignedDriverId
            .flatMap { UUID(uuidString: $0) }
            .flatMap { store.staffMember(for: $0) }

        return HStack(spacing: Spacing.md) {
            // Vehicle icon
            Image(systemName: "car.fill")
                .font(.system(size: 20))
                .foregroundStyle(SierraTheme.Colors.sierraBlue.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(SierraTheme.Colors.sierraBlue.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: Radius.avatar, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.name)
                    .sierraStyle(.cardTitle)
                Text("\(vehicle.model) \u{00B7} \(vehicle.licensePlate)")
                    .sierraStyle(.caption)

                // Assigned driver + their availability
                if let driver {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(SierraTheme.Colors.granite)
                        Text(driver.displayName)
                            .font(SierraFont.body(11, weight: .medium))
                            .foregroundStyle(SierraTheme.Colors.granite)
                        availabilityDot(driver.availability)
                        Text(driver.availability.rawValue)
                            .font(SierraFont.body(11, weight: .medium))
                            .foregroundStyle(availabilityColor(driver.availability))
                    }
                } else if vehicle.assignedDriverId != nil {
                    // Driver ID exists but not in store
                    Text("Driver loading\u{2026}")
                        .font(SierraFont.body(11, weight: .medium))
                        .foregroundStyle(SierraTheme.Colors.granite)
                } else {
                    Text("No driver assigned")
                        .font(SierraFont.body(11, weight: .medium))
                        .foregroundStyle(SierraTheme.Colors.granite.opacity(0.6))
                }
            }

            Spacer()

            SierraBadge(vehicle.status, size: .compact)
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // MARK: - Availability helpers

    private func availabilityDot(_ availability: StaffAvailability) -> some View {
        Circle()
            .fill(availabilityColor(availability))
            .frame(width: 6, height: 6)
    }

    private func availabilityColor(_ availability: StaffAvailability) -> Color {
        switch availability {
        case .available:   return SierraTheme.Colors.alpineMint
        case .onTrip:      return SierraTheme.Colors.sierraBlue
        case .onTask:      return SierraTheme.Colors.warning
        case .unavailable: return SierraTheme.Colors.danger
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
        case .inMaintenance:  return "No vehicles currently in maintenance."
        case .idle:           return "No idle vehicles available."
        case .outOfService:   return "No out-of-service vehicles."
        case .decommissioned: return "No decommissioned vehicles."
        case .none:           return "Add your first vehicle to get started."
        }
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
