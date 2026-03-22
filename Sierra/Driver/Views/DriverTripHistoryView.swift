import SwiftUI

/// Driver-side trip history — completed + cancelled trips.
/// Phase 12: Shows real history with distance, duration, and status badge.
/// NOTE: .navigationDestination intentionally omitted here — it lives in
///   DriverTabView so there is exactly one declaration per NavigationStack.
struct DriverTripHistoryView: View {

    @Environment(AppDataStore.self) private var store

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var myHistoryTrips: [Trip] {
        let userId = currentUserId.uuidString
        return store.trips
            .filter { $0.driverId == userId && ($0.status == .completed || $0.status == .cancelled) }
            .sorted { ($0.actualEndDate ?? $0.scheduledDate) > ($1.actualEndDate ?? $1.scheduledDate) }
    }

    var body: some View {
        Group {
            if let error = store.loadError {
                SierraErrorView(message: error) {
                    await store.loadAll()
                }
            } else if myHistoryTrips.isEmpty {
                SierraEmptyState(
                    icon: "road.lanes",
                    title: "No Trip History",
                    message: "Your completed and cancelled trips will appear here."
                )
            } else {
                List {
                    ForEach(myHistoryTrips) { trip in
                        NavigationLink(value: trip.id) {
                            tripRow(trip)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Trip History")
        .navigationBarTitleDisplayMode(.large)
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                statusBadge(trip)
            }
            HStack(spacing: 12) {
                if let end = trip.actualEndDate {
                    Text(end.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let s = trip.startMileage, let e = trip.endMileage {
                    Text("\(Int(e - s)) km").font(.caption).foregroundStyle(.secondary)
                }
                if let start = trip.actualStartDate, let end = trip.actualEndDate {
                    let hrs = end.timeIntervalSince(start) / 3600
                    Text(String(format: "%.1fh", hrs)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ trip: Trip) -> some View {
        let isCompleted = trip.status == .completed
        return HStack(spacing: 4) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : "xmark.circle.fill")
                .font(.caption2)
            Text(isCompleted ? "Completed" : "Cancelled")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(isCompleted ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.danger)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isCompleted ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.danger).opacity(0.12),
            in: Capsule()
        )
    }
}
