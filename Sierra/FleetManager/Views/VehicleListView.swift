import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

struct VehicleListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatus? = nil
    @State private var showAddSheet = false
    @State private var editingVehicle: Vehicle?
    @State private var deleteTarget: Vehicle?

    private var filteredVehicles: [Vehicle] {
        store.vehicles.filter { v in
            // Status filter
            if let filter = selectedFilter, v.status != filter { return false }
            // Search filter
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
                // Filter chips
                filterChips
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F3F7"))

                // Vehicle list
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
            .background(Color(hex: "F2F3F7").ignoresSafeArea())
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search vehicles…")
            .navigationDestination(for: UUID.self) { id in
                VehicleDetailView(vehicleId: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(navyDark)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddVehicleView()
            }
            .sheet(item: $editingVehicle) { vehicle in
                AddVehicleView(editingVehicle: vehicle)
            }
            .confirmationDialog("Delete Vehicle?", isPresented: .init(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let v = deleteTarget {
                        store.deleteVehicle(id: v.id)
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
            HStack(spacing: 10) {
                filterChip("All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : navyDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected ? accentOrange : .clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? .clear : navyDark.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle Row

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 20))
                .foregroundStyle(navyDark.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(navyDark.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(navyDark)
                Text("\(vehicle.model) · \(vehicle.licensePlate)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge(vehicle.status)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    private func statusBadge(_ status: VehicleStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .active:        ("Active", .green)
        case .inMaintenance: ("Maint.", .orange)
        case .idle:          ("Idle", Color(hex: "8E8E93"))
        }
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "car.fill")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.4))
            Text("No vehicles found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(emptySubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptySubtitle: String {
        if !searchText.isEmpty { return "Try a different search term." }
        switch selectedFilter {
        case .active:        return "No active vehicles at the moment."
        case .inMaintenance: return "No vehicles currently in maintenance."
        case .idle:          return "No idle vehicles available."
        case .none:          return "Add your first vehicle to get started."
        }
    }
}

// Make Vehicle conform to Identifiable for .sheet(item:)
extension Vehicle: Hashable {
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    VehicleListView()
        .environment(AppDataStore.shared)
}
