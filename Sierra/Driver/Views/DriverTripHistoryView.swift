import SwiftUI

/// Driver-side trip history — completed + cancelled trips.
struct DriverTripHistoryView: View {

    @Environment(AppDataStore.self) private var store

    // C-04 FIX: guard instead of UUID() fallback
    private var currentUserId: UUID? { AuthManager.shared.currentUser?.id }

    private var myHistoryTrips: [Trip] {
        // FIX: compare lowercased on both sides — driver_id TEXT column is stored
        // lowercase (after migration 20260323000001) and auth.uid()::text is lowercase,
        // but legacy rows may still be uppercase; LOWER() on both sides is safe either way.
        guard let userId = currentUserId?.uuidString.lowercased() else { return [] }
        return store.trips
            .filter {
                ($0.driverId?.lowercased() ?? "") == userId
                    && ($0.status == .completed || $0.status == .cancelled)
            }
            .sorted {
                ($0.actualEndDate ?? $0.scheduledDate) > ($1.actualEndDate ?? $1.scheduledDate)
            }
    }

    var body: some View {
        Group {
            if let error = store.loadError {
                // H-02 FIX: Use loadDriverData (driver-scoped) not loadAll (admin-scoped)
                SierraErrorView(message: error) {
                    if let uid = currentUserId {
                        await store.refreshDriverData(driverId: uid, force: true)
                    }
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
                Text("\(trip.origin) → \(trip.destination)")
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
