import SwiftUI


struct TripsListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var selectedFilter: TripStatus? = nil
    @State private var showCreateTrip = false

    private var filteredTrips: [Trip] {
        store.trips.filter { trip in
            if let filter = selectedFilter { return trip.status == filter }
            return true
        }
        .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            filterTabs
                .padding(.vertical, 10)
                .background(SierraTheme.Colors.appBackground)

            if filteredTrips.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredTrips) { trip in
                        NavigationLink(value: trip.id) {
                            tripRow(trip)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            TripDetailView(tripId: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateTrip = true } label: {
                    Image(systemName: "plus")
                        .font(SierraFont.body(17, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                }
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip("All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(TripStatus.allCases, id: \.self) { status in
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
                .font(SierraFont.caption1)
                .foregroundStyle(isSelected ? .white : SierraTheme.Colors.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? SierraTheme.Colors.ember : .clear, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? .clear : SierraTheme.Colors.cloud, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trip Row

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 0) {
            // Status color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor(trip.status))
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                // Task ID badge
                HStack(spacing: 8) {
                    Text(trip.taskId)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.12), in: Capsule())

                    if trip.priority == .high || trip.priority == .urgent {
                        priorityBadge(trip.priority)
                    }
                }

                // Route
                Text("\(trip.origin) → \(trip.destination)")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                // Driver + Vehicle
                HStack(spacing: 6) {
                    if let dId = trip.driverId,
                       let driver = store.staffMember(forId: dId) {
                        Text(driver.name)
                            .font(SierraFont.caption1)
                            .foregroundStyle(.secondary)
                    }
                    if let vId = trip.vehicleId,
                       let vehicle = store.vehicle(forId: vId) {
                        Text("· \(vehicle.licensePlate)")
                            .font(SierraFont.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                // Date
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(SierraFont.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled: SierraTheme.Colors.info
        case .active:    SierraTheme.Colors.alpineMint
        case .completed: SierraTheme.Colors.granite
        case .cancelled: SierraTheme.Colors.danger
        }
    }

    private func priorityBadge(_ priority: TripPriority) -> some View {
        let color: Color = priority == .urgent ? .red : SierraTheme.Colors.warning
        return Text(priority.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.4))
            Text("No trips found")
                .font(SierraFont.body(18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(emptySubtitle)
                .font(SierraFont.caption1)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptySubtitle: String {
        switch selectedFilter {
        case .scheduled: "No scheduled trips."
        case .active:    "No active trips right now."
        case .completed: "No completed trips yet."
        case .cancelled: "No cancelled trips."
        case .none:      "Create your first trip to get started."
        }
    }
}

#Preview {
    NavigationStack {
        TripsListView()
            .environment(AppDataStore.shared)
    }
}
