import SwiftUI

struct TripsListView: View {
    var embeddedInContainer: Bool = false
    var externalCreateTick: Int = 0
    var externalSelectedStatus: Binding<TripStatus?>? = nil
    var externalSearchText: Binding<String>? = nil
    var usesInlineNavigationTitle: Bool = true
    @Environment(AppDataStore.self) private var store
    @State private var selectedStatus: TripStatus? = nil
    @State private var showCreateSheet = false
    @State private var navigationTarget: UUID?

    private var activeSelectedStatus: TripStatus? {
        externalSelectedStatus?.wrappedValue ?? selectedStatus
    }

    private func setSelectedStatus(_ value: TripStatus?) {
        if let externalSelectedStatus {
            externalSelectedStatus.wrappedValue = value
        } else {
            selectedStatus = value
        }
    }

    private var activeSearchText: String {
        externalSearchText?.wrappedValue ?? ""
    }

    private var filtered: [Trip] {
        let query = activeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return store.trips
            .filter { activeSelectedStatus == nil || $0.status.normalized == activeSelectedStatus }
            .filter { trip in
                guard !query.isEmpty else { return true }
                let driver = driverName(for: trip)?.lowercased() ?? ""
                let plate = vehiclePlate(for: trip)?.lowercased() ?? ""
                return trip.taskId.lowercased().contains(query)
                    || trip.origin.lowercased().contains(query)
                    || trip.destination.lowercased().contains(query)
                    || driver.contains(query)
                    || plate.contains(query)
            }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private let accentOrange = Color(red: 0.96, green: 0.54, blue: 0.13)
    private let accentCream = Color(red: 0.95, green: 0.91, blue: 0.86)

    var body: some View {
        let content = Group {
            if filtered.isEmpty {
                SierraEmptyState(icon: "arrow.triangle.swap", title: "No trips found", message: activeSelectedStatus == nil ? "Create a trip to get started." : "No trips match this filter.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                tripList
            }
        }
        .navigationDestination(for: UUID.self) { TripDetailView(tripId: $0) }
        .navigationDestination(item: $navigationTarget) { TripDetailView(tripId: $0) }
        .sheet(isPresented: $showCreateSheet) { CreateTripView() }
        .task { if store.trips.isEmpty { await store.loadAll() } }
        .refreshable { await store.loadAll() }
        .onChange(of: externalCreateTick) { _, _ in
            guard embeddedInContainer else { return }
            showCreateSheet = true
        }

        if embeddedInContainer {
            content
        } else {
            content
                .navigationTitle("Trip")
                .navigationBarTitleDisplayMode(usesInlineNavigationTitle ? .inline : .large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }

                        Menu {
                            Button {
                                setSelectedStatus(nil)
                            } label: {
                                HStack {
                                    Text("All")
                                    if activeSelectedStatus == nil {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Divider()
                            ForEach([TripStatus.pendingAcceptance, .scheduled, .active, .completed, .cancelled], id: \.self) { status in
                                Button {
                                    setSelectedStatus(status)
                                } label: {
                                    HStack {
                                        Text(status.rawValue)
                                        if activeSelectedStatus == status {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: activeSelectedStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                        .tint(activeSelectedStatus == nil ? .primary : .orange)
                    }
                }
        }
    }

    private var tripList: some View {
        List {
            ForEach(filtered) { trip in
                tripCard(trip)
                    .contentShape(Rectangle())
                    .onTapGesture { navigationTarget = trip.id }
                    .accessibilityAddTraits(.isButton)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private func tripCard(_ trip: Trip) -> some View {
        let driverName = driverName(for: trip)
        let plate = vehiclePlate(for: trip)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bus")
                    .font(SierraFont.scaled(18, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(trip.taskId)
                    .font(SierraFont.scaled(13, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentOrange)
                Spacer()
            }

            HStack(spacing: 10) {
                Text(trip.origin.uppercased())
                    .font(SierraFont.scaled(18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "arrow.right")
                    .font(SierraFont.scaled(17, weight: .bold))
                    .foregroundStyle(accentOrange)
                Text(trip.destination.uppercased())
                    .font(SierraFont.scaled(18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(SierraFont.scaled(18, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(SierraFont.scaled(14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "person")
                    .font(SierraFont.scaled(16, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(driverName ?? "Unassigned driver")
                    .font(SierraFont.scaled(14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let plate {
                HStack(spacing: 8) {
                    Text(plate)
                        .font(SierraFont.scaled(13, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentOrange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accentCream))

                    Spacer(minLength: 8)

                    Text(trip.priority.rawValue)
                        .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentOrange)

                    statusPill(trip.status)
                }
            } else {
                HStack(spacing: 8) {
                    Spacer(minLength: 8)

                    Text(trip.priority.rawValue)
                        .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentOrange)
                    statusPill(trip.status)
                }
            }

            Button {
                navigationTarget = trip.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(SierraFont.scaled(15, weight: .semibold))
                    Text("View Details")
                        .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(accentOrange))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.origin) to \(trip.destination)")
        .accessibilityValue("\(trip.status.rawValue), priority \(trip.priority.rawValue)")
        .accessibilityHint("Opens trip details")
    }

    private func driverName(for trip: Trip) -> String? {
        guard let raw = trip.driverId, let id = UUID(uuidString: raw) else { return nil }
        return store.staffMember(for: id)?.displayName
    }

    private func vehiclePlate(for trip: Trip) -> String? {
        guard let raw = trip.vehicleId, let id = UUID(uuidString: raw) else { return nil }
        return store.vehicle(for: id)?.licensePlate
    }

    private func statusColor(_ s: TripStatus) -> Color {
        switch s {
        case .active: return .green
        case .scheduled: return .blue
        case .pendingAcceptance: return .orange
        case .accepted: return .teal
        case .completed: return Color.secondary
        case .rejected, .cancelled: return .red
        }
    }

    private func statusLabel(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "Pending Acceptance"
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }

    private func statusPill(_ status: TripStatus) -> some View {
        let color = statusColor(status)
        return Text(statusLabel(status))
            .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview { NavigationStack { TripsListView().environment(AppDataStore.shared) } }
