import SwiftUI

/// Driver-side trip list. Shows only trips assigned to the authenticated driver.
/// navigationDestination for UUID is declared by the parent NavigationStack in
/// DriverTabView, NOT here, to avoid the duplicate-destination warning.
struct DriverTripsListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedStatus: TripStatus? = nil

    private var driverId: UUID? { AuthManager.shared.currentUser?.id }

    private var driverTrips: [Trip] {
        guard let id = driverId else { return [] }
        return store.trips(forDriver: id)
    }

    private var filtered: [Trip] {
        driverTrips
            .filter { trip in
                if let s = selectedStatus, trip.status != s { return false }
                if !searchText.isEmpty {
                    let q = searchText.lowercased()
                    return trip.taskId.lowercased().contains(q)
                        || trip.origin.lowercased().contains(q)
                        || trip.destination.lowercased().contains(q)
                }
                return true
            }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private var isFilterActive: Bool { selectedStatus != nil }

    var body: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { trip in
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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Trips")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search task ID, origin…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Status") {
                        Button {
                            selectedStatus = nil
                        } label: {
                            Label("All Statuses", systemImage: selectedStatus == nil ? "checkmark" : "")
                        }
                        ForEach(TripStatus.allCases, id: \.self) { status in
                            Button {
                                selectedStatus = status
                            } label: {
                                Label(status.rawValue, systemImage: selectedStatus == status ? "checkmark" : "")
                            }
                        }
                    }
                    if isFilterActive {
                        Divider()
                        Button(role: .destructive) {
                            selectedStatus = nil
                        } label: {
                            Label("Clear Filters", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isFilterActive ? .orange : .primary)
                }
            }
        }
        // navigationDestination is declared by the parent NavigationStack in DriverTabView.
        // Declaring it here too causes the "declared earlier on the stack" SwiftUI warning.
        .task {
            if store.trips.isEmpty, let id = driverId {
                await store.loadDriverData(driverId: id)
            }
        }
        .refreshable {
            if let id = driverId { await store.loadDriverData(driverId: id) }
        }
    }



    // MARK: - Trip Row

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor(trip.status))
                .frame(width: 10, height: 10)
                .padding(13)
                .background(statusColor(trip.status).opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(trip.taskId)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.caption2).foregroundStyle(.secondary)
                }

                vehicleLine(trip)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor(trip.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(trip.status).opacity(0.1), in: Capsule())
                Text(trip.priority.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    @ViewBuilder
    private func vehicleLine(_ trip: Trip) -> some View {
        if let idStr = trip.vehicleId, let uuid = UUID(uuidString: idStr),
           let v = store.vehicle(for: uuid) {
            HStack(spacing: 4) {
                Image(systemName: "car.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                Text(v.licensePlate).font(.caption2).foregroundStyle(.secondary)
                Text("· \(v.name) \(v.model)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "map").font(.system(size: 44)).foregroundStyle(.gray.opacity(0.4))
            Text("No trips found").font(.headline).foregroundStyle(.secondary)
            Text(searchText.isEmpty
                 ? "You haven't been assigned any trips yet."
                 : "Try a different search term.")
                .font(.subheadline).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:    return .green
        case .scheduled: return .blue
        case .completed: return Color.secondary
        case .cancelled: return .red
        }
    }
}

#Preview {
    NavigationStack {
        DriverTripsListView()
            .environment(AppDataStore.shared)
    }
}
