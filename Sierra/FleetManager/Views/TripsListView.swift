import SwiftUI

struct TripsListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedStatus: TripStatus? = nil
    @State private var showCreateSheet = false
    @State private var showFilterSheet = false
    @State private var navigationTarget: UUID?

    private var filterBinding: Binding<String?> {
        Binding(get: { selectedStatus?.rawValue }, set: { newVal in selectedStatus = newVal.flatMap { TripStatus(rawValue: $0) } })
    }
    private var tripFilterOptions: [FilterOption] {
        let statuses: [TripStatus] = [.pendingAcceptance, .scheduled, .active, .completed, .cancelled]
        return statuses.map { FilterOption(id: $0.rawValue, label: $0.rawValue, icon: tripStatusIcon($0), color: statusColor($0)) }
    }
    private var filtered: [Trip] {
        store.trips
            .filter { selectedStatus == nil || $0.status.normalized == selectedStatus }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Group {
                if filtered.isEmpty {
                    SierraEmptyState(icon: "arrow.triangle.swap", title: "No trips found", message: selectedStatus == nil ? "Create a trip to get started." : "No trips match this filter.")
                } else {
                    tripList
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(.orange)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { TripDetailView(tripId: $0) }
        .navigationDestination(item: $navigationTarget) { TripDetailView(tripId: $0) }
        .sheet(isPresented: $showFilterSheet) { FilterSheetView(title: "Filter Trips", options: tripFilterOptions, selectedId: filterBinding) }
        .sheet(isPresented: $showCreateSheet) {
            CreateTripView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGroupedBackground))
        }
        .task { if store.trips.isEmpty { await store.loadAll() } }
        .refreshable { await store.loadAll() }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text("Trips")
                .font(.largeTitle.bold())

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: selectedStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(selectedStatus == nil ? .secondary : .orange)
        }
    }

    private var tripList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { trip in
                    tripCard(trip)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { navigationTarget = trip.id }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 32)
        }
    }

    private func tripCard(_ trip: Trip) -> some View {
        let status = trip.status.normalized
        return HStack(spacing: 14) {
            Circle()
                .fill(statusColor(status)).frame(width: 10, height: 10)
                .padding(13)
                .background(statusColor(status).opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(trip.taskId).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())).font(.caption2).foregroundStyle(.secondary)
                }
                driverVehicleLine(trip)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(status.rawValue)
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(statusColor(status))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor(status).opacity(0.1), in: Capsule())
                Text(trip.priority.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private func driverVehicleLine(_ trip: Trip) -> some View {
        let driverName: String? = { guard let s = trip.driverId, let u = UUID(uuidString: s) else { return nil }; return store.staffMember(for: u)?.displayName }()
        let plate: String? = { guard let s = trip.vehicleId, let u = UUID(uuidString: s) else { return nil }; return store.vehicle(for: u)?.licensePlate }()
        if driverName != nil || plate != nil {
            HStack(spacing: 4) {
                Image(systemName: "person.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                if let n = driverName { Text(n).font(.caption2).foregroundStyle(.secondary) }
                if let p = plate { Text("\u{00B7} \(p)").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }

    private func tripStatusIcon(_ s: TripStatus) -> String {
        switch s { case .active: return "arrow.triangle.swap"; case .scheduled: return "clock"; case .pendingAcceptance: return "hourglass"; case .accepted: return "checkmark.circle"; case .completed: return "checkmark"; case .rejected: return "xmark.circle"; case .cancelled: return "xmark" }
    }
    private func statusColor(_ s: TripStatus) -> Color {
        switch s { case .active: return .green; case .scheduled: return .orange; case .pendingAcceptance: return .orange; case .accepted: return .teal; case .completed: return Color.secondary; case .rejected, .cancelled: return .red }
    }
}

#Preview { NavigationStack { TripsListView().environment(AppDataStore.shared) } }
