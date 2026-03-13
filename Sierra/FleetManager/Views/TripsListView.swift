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
                .padding(.vertical, Spacing.sm)
                .background(SierraTheme.Colors.appBackground)

            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { trip in
                        NavigationLink(value: trip.id) {
                            tripRow(trip)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.md))
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
        .searchable(text: $searchText, prompt: "Search task ID, origin…")
        .navigationDestination(for: UUID.self) { id in
            TripDetailView(tripId: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                        .font(SierraFont.body(17, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTripView()
        }
        .onAppear {
            print("[TripsListView] Appeared — \(store.trips.count) trips loaded")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Filter Chips
    // ─────────────────────────────────────────────────────────────

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                chip("All", isSelected: selectedStatus == nil) { selectedStatus = nil }
                ForEach(TripStatus.allCases, id: \.self) { status in
                    chip(status.rawValue, isSelected: selectedStatus == status) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func chip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    // ─────────────────────────────────────────────────────────────
    // MARK: - Trip Row
    // ─────────────────────────────────────────────────────────────

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: Spacing.md) {
            // Status dot
            Circle()
                .fill(statusColor(trip.status))
                .frame(width: 10, height: 10)
                .padding(13)
                .background(statusColor(trip.status).opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(SierraFont.body(15, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(trip.taskId)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(SierraTheme.Colors.granite)

                    Text("·")
                        .foregroundStyle(SierraTheme.Colors.granite)

                    Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(SierraFont.caption2)
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.status.rawValue)
                    .font(SierraFont.body(11, weight: .bold))
                    .foregroundStyle(statusColor(trip.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(trip.status).opacity(0.1), in: Capsule())

                Text(trip.priority.rawValue)
                    .font(SierraFont.body(10, weight: .medium))
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
            }
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Empty State
    // ─────────────────────────────────────────────────────────────

    private var emptyState: some View {
        SierraEmptyState(
            icon: "arrow.triangle.swap",
            title: "No trips found",
            message: searchText.isEmpty ? "Create a trip to get started." : "Try a different search term."
        )
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:    return .green
        case .scheduled: return SierraTheme.Colors.sierraBlue
        case .completed: return .gray
        case .cancelled: return .red
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
