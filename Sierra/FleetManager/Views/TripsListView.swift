import SwiftUI

// MARK: - TripsListView
// Fleet manager view: full trip list with filter sheet + search.
// Phase 9: filter chips replaced with FilterSheetView.

struct TripsListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedStatus: TripStatus? = nil
    @State private var showCreateSheet = false
    @State private var showFilterSheet = false

    // Bridge selectedStatus ↔ FilterSheetView's String? binding
    private var filterBinding: Binding<String?> {
        Binding(
            get: { selectedStatus?.rawValue },
            set: { newVal in
                selectedStatus = newVal.flatMap { TripStatus(rawValue: $0) }
            }
        )
    }

    private var tripFilterOptions: [FilterOption] {
        TripStatus.allCases.map { status in
            FilterOption(
                id: status.rawValue,
                label: status.rawValue,
                icon: tripStatusIcon(status),
                color: statusColor(status)
            )
        }
    }

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
        mainContent
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Trips")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search trips…")
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripId: id)
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(
                    title: "Filter Trips",
                    options: tripFilterOptions,
                    selectedId: filterBinding
                )
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

    // MARK: - Extracted subviews (break up complex body)

    @ViewBuilder
    private var mainContent: some View {
        if let error = store.loadError {
            SierraErrorView(message: error) {
                await store.loadAll()
            }
        } else if filtered.isEmpty {
            emptyState
        } else {
            tripList
        }
    }

    private var tripList: some View {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showFilterSheet = true
            } label: {
                filterButtonLabel
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showCreateSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var filterButtonLabel: some View {
        Label(
            selectedStatus == nil ? "Filter" : selectedStatus!.rawValue,
            systemImage: selectedStatus == nil
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill"
        )
        .foregroundStyle(selectedStatus == nil ? Color.secondary : Color.orange)
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
                Text("\(trip.origin) → \(trip.destination)")
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

            tripStatusBadge(trip)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func tripStatusBadge(_ trip: Trip) -> some View {
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

    // MARK: - Helpers

    private func tripStatusIcon(_ status: TripStatus) -> String {
        switch status {
        case .active:             return "arrow.triangle.swap"
        case .scheduled:          return "clock"
        case .pendingAcceptance:  return "hourglass"
        case .accepted:           return "checkmark.circle"
        case .completed:          return "checkmark"
        case .rejected:           return "xmark.circle"
        case .cancelled:          return "xmark"
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
