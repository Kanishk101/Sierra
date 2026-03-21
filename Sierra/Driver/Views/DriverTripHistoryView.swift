import SwiftUI

/// Driver-side completed trip history.
/// Safeguard 1: data from AppDataStore, no extra queries.
/// Safeguard 2: NO .navigationDestination declared here — it lives in
///   DriverTabView so there is exactly one declaration per NavigationStack.
struct DriverTripHistoryView: View {

    @Environment(AppDataStore.self) private var store

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var myCompletedTrips: [Trip] {
        let userId = currentUserId.uuidString
        return store.trips
            .filter { $0.driverId == userId && $0.status == .completed }
            .sorted { ($0.actualEndDate ?? .distantPast) > ($1.actualEndDate ?? .distantPast) }
    }

    var body: some View {
        Group {
            if myCompletedTrips.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "road.lanes")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No completed trips yet")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(myCompletedTrips) { trip in
                        // Uses parent NavigationStack's destination declaration
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
        // NOTE: .navigationDestination intentionally omitted here.
        // DriverTabView declares it once on each NavigationStack to avoid
        // the SwiftUI "declared earlier on the stack" warning and recursive push.
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                if trip.proofOfDeliveryId != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.green)
                }
            }
            HStack(spacing: 12) {
                if let end = trip.actualEndDate {
                    Text(end.formatted(.dateTime.month(.abbreviated).day()))
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
}
