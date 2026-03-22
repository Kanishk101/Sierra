import SwiftUI

// MARK: - TripsListView
// Fleet manager view: full trip list with filter chips + search.

struct TripsListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedStatus: TripStatus? = nil
    @State private var showCreateSheet = false

    private var filtered: [Trip] {
        store.trips
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

    var body: some View {
        VStack(spacing: 0) {
            filterChips
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

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
        .navigationTitle("Trips")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { id in
            TripDetailView(tripId: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTripView()
        }
        .onAppear {
            print("[TripsListView] Appeared — \(store.trips.count) trips loaded")
        }
        .task {
            if store.trips.isEmpty { await store.loadAll() }
        }
        .refreshable {
            await store.loadAll()
        }
    }

    // MARK: - Filter Chips
    // FIX: unselected chips had Color.clear background — invisible against
    // systemGroupedBackground. Changed to secondarySystemGroupedBackground
    // so unselected chips are visible as pill cards.

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isSelected: selectedStatus == nil) { selectedStatus = nil }
                ForEach(TripStatus.allCases, id: \.self) { status in
                    chip(status.rawValue, isSelected: selectedStatus == status) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedStatus = status
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? Color.orange
                        : Color(.secondarySystemGroupedBackground),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color(.separator),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    // MARK: - Trip Row

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 14) {
            // Status dot
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

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                driverVehicleLine(trip)
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

    // MARK: - Driver / Vehicle inline line

    @ViewBuilder
    private func driverVehicleLine(_ trip: Trip) -> some View {
        let driverName: String? = {
            guard let idStr = trip.driverId,
                  let uuid  = UUID(uuidString: idStr),
                  let m     = store.staffMember(for: uuid) else { return nil }
            return m.displayName
        }()
        let plate: String? = {
            guard let idStr = trip.vehicleId,
                  let uuid  = UUID(uuidString: idStr),
                  let v     = store.vehicle(for: uuid) else { return nil }
            return v.licensePlate
        }()

        if driverName != nil || plate != nil {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if let name = driverName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let p = plate {
                    Text("· \(p)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SierraEmptyState(
            icon: "arrow.triangle.swap",
            title: "No trips found",
            message: searchText.isEmpty ? "Create a trip to get started." : "Try a different search term."
        )
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:             return .green
        case .scheduled:          return .blue
        case .pendingAcceptance:  return .orange
        case .accepted:           return .teal
        case .completed:          return Color.secondary
        case .rejected:           return .red
        case .cancelled:          return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TripsListView()
            .environment(AppDataStore.shared)
    }
}
