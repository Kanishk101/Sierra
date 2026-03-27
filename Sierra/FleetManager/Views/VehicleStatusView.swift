import SwiftUI

/// FM vehicle status management view.
/// Safeguard 1: all data from AppDataStore, no extra Supabase queries.
struct VehicleStatusView: View {

    @Environment(AppDataStore.self) private var store

    private var groupedVehicles: [(VehicleStatus, [Vehicle])] {
        let order: [VehicleStatus] = [.active, .idle, .busy, .inMaintenance, .outOfService, .decommissioned]
        return order.compactMap { status in
            let vehicles = store.vehicles.filter { $0.status == status }
            guard !vehicles.isEmpty else { return nil }
            return (status, vehicles)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status bar chart (Safeguard 5: pure SwiftUI)
                statusBarChart
                    .padding(.horizontal, 16)

                // Grouped lists
                ForEach(groupedVehicles, id: \.0) { status, vehicles in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                            Text(status.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text("(\(vehicles.count))")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)

                        ForEach(vehicles) { vehicle in
                            vehicleCard(vehicle)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vehicle Status")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Status Bar Chart (Safeguard 5: SwiftUI only)

    private var statusBarChart: some View {
        let counts: [(VehicleStatus, Int)] = [
            (.active, store.vehicles.filter { $0.status == .active }.count),
            (.idle, store.vehicles.filter { $0.status == .idle }.count),
            (.inMaintenance, store.vehicles.filter { $0.status == .inMaintenance }.count),
            (.outOfService, store.vehicles.filter { $0.status == .outOfService }.count),
        ].filter { $0.1 > 0 }
        let maxCount = max(counts.map(\.1).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("FLEET BREAKDOWN").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)

            ForEach(counts, id: \.0) { status, count in
                HStack(spacing: 10) {
                    Text(status.rawValue)
                        .font(.caption.weight(.medium))
                        .frame(width: 100, alignment: .trailing)
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        let barWidth = max(geo.size.width * CGFloat(count) / CGFloat(maxCount), 4)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor(status).gradient)
                            .frame(width: barWidth, height: 24)
                    }
                    .frame(height: 24)

                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.name).font(.subheadline.weight(.semibold))
                    Text("\(vehicle.licensePlate) • \(vehicle.manufacturer) \(vehicle.model)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(vehicle.status.rawValue)
                    .font(SierraFont.scaled(10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor(vehicle.status), in: Capsule())
            }

            HStack(spacing: 16) {
                Label("\(Int(vehicle.odometer)) km", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.caption2).foregroundStyle(.secondary)
                Label("\(vehicle.totalTrips) trips", systemImage: "arrow.triangle.swap")
                    .font(.caption2).foregroundStyle(.secondary)
                if vehicle.totalDistanceKm > 0 {
                    Label("\(Int(vehicle.totalDistanceKm)) km total", systemImage: "road.lanes")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Doc expiry warnings
            let docs = store.vehicleDocuments.filter { $0.vehicleId == vehicle.id }
            let expiring = docs.filter { $0.isExpiringSoon && !$0.isExpired }
            let expired = docs.filter { $0.isExpired }
            if !expired.isEmpty {
                Label("\(expired.count) expired doc(s)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.red)
            }
            if !expiring.isEmpty {
                Label("\(expiring.count) expiring soon", systemImage: "clock.badge.exclamationmark")
                    .font(.caption2.weight(.medium)).foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func statusColor(_ s: VehicleStatus) -> Color {
        switch s {
        case .active: return .green
        case .idle: return .blue
        case .busy: return .purple
        case .inMaintenance: return .orange
        case .outOfService: return .red
        case .decommissioned: return .gray
        }
    }
}
