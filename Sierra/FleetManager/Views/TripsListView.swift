import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

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
                .background(Color(hex: "F2F3F7"))

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
        .background(Color(hex: "F2F3F7").ignoresSafeArea())
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            TripDetailView(tripId: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateTrip = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(navyDark)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : navyDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? accentOrange : .clear, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? .clear : navyDark.opacity(0.2), lineWidth: 1)
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(navyDark)

                // Driver + Vehicle
                HStack(spacing: 6) {
                    if let dId = trip.driverId,
                       let driver = store.staffMember(forId: dId) {
                        Text(driver.name)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    if let vId = trip.vehicleId,
                       let vehicle = store.vehicle(forId: vId) {
                        Text("· \(vehicle.licensePlate)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                // Date
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled: .blue
        case .active:    .green
        case .completed: .gray
        case .cancelled: .red
        }
    }

    private func priorityBadge(_ priority: TripPriority) -> some View {
        let color: Color = priority == .urgent ? .red : .orange
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
