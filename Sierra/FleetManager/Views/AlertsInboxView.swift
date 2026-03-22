import SwiftUI
import CoreLocation
import MapKit
import Supabase

/// FM's live alert centre — emergency alerts, route deviations, overdue maintenance.
/// Safeguard 3: NO polling timers. Realtime only + pull to refresh.
/// Safeguard 4: Reverse geocoding cached, uses CLGeocoder (free).
struct AlertsInboxView: View {

    @Environment(AppDataStore.self) private var store
    @State var vm = AlertsViewModel()
    @State private var reversedAddresses: [UUID: String] = [:]  // Safeguard 4: cache

    var overdueMaintenanceTasks: [MaintenanceTask] {
        guard vm.selectedFilter == .all || vm.selectedFilter == .maintenance else { return [] }
        return store.maintenanceTasks.filter { $0.status == .pending && $0.dueDate < Date() }
    }

    var body: some View {
        List {
            // Filter picker
            Section {
                Picker("Filter", selection: $vm.selectedFilter) {
                    ForEach(AlertsViewModel.AlertFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, -4)
            }

            // Emergency alerts
            if !vm.activeAlerts.isEmpty {
                Section {
                    ForEach(vm.activeAlerts) { alert in
                        NavigationLink(value: alert.id) {
                            emergencyRow(alert)
                        }
                    }
                } header: {
                    sectionHeader("Emergency Alerts", count: vm.activeAlerts.count, color: .red)
                }
            }

            // Route deviations
            if !vm.unacknowledgedDeviations.isEmpty {
                Section {
                    ForEach(vm.unacknowledgedDeviations) { dev in
                        deviationRow(dev)
                    }
                } header: {
                    sectionHeader("Route Deviations", count: vm.unacknowledgedDeviations.count, color: .yellow)
                }
            }

            // Overdue maintenance
            if !overdueMaintenanceTasks.isEmpty {
                Section {
                    ForEach(overdueMaintenanceTasks) { task in
                        overdueRow(task)
                    }
                } header: {
                    sectionHeader("Overdue Maintenance", count: overdueMaintenanceTasks.count, color: .orange)
                }
            }

            if vm.activeAlerts.isEmpty && vm.unacknowledgedDeviations.isEmpty && overdueMaintenanceTasks.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.green.opacity(0.5))
                        Text("All clear — no active alerts")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
        }
        .navigationDestination(for: UUID.self) { alertId in
            if let alert = vm.emergencyAlerts.first(where: { $0.id == alertId }) {
                AlertDetailView(alert: alert) {
                    Task { await vm.load() }
                }
            }
        }
    }

    // MARK: - Emergency Row

    private func emergencyRow(_ alert: EmergencyAlert) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Image(systemName: alertIcon(alert.alertType))
                    .foregroundStyle(.red)
                Text(alert.alertType.rawValue)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                Spacer()
                Text(timeAgo(alert.triggeredAt))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                let driver = store.staff.first(where: { $0.id == alert.driverId })
                Text(driver?.name ?? "Unknown Driver").font(.caption).foregroundStyle(.secondary)
                if let vId = alert.vehicleId, let v = store.vehicles.first(where: { $0.id == vId }) {
                    Text(v.licensePlate).font(.caption).foregroundStyle(.tertiary)
                }
            }
            // Reverse geocoded address (Safeguard 4: cached)
            if let address = reversedAddresses[alert.id] {
                Text("near \(address)").font(.caption2).foregroundStyle(.secondary).italic()
            }
        }
        .padding(.vertical, 4)
        .task {
            await reverseGeocode(alert)
        }
    }

    // MARK: - Deviation Row

    private func deviationRow(_ dev: RouteDeviationEvent) -> some View {
        HStack(spacing: 8) {
            Circle().fill(.yellow).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(dev.deviationDistanceM))m off route")
                    .font(.subheadline.weight(.medium))
                let driver = store.staff.first(where: { $0.id == dev.driverId })
                Text(driver?.name ?? "Unknown").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeAgo(dev.detectedAt)).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Overdue Row

    private func overdueRow(_ task: MaintenanceTask) -> some View {
        HStack(spacing: 8) {
            Circle().fill(.orange).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
                Text(vehicle?.name ?? "Vehicle").font(.subheadline.weight(.medium))
                Text(task.title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let days = max(1, Int(Date().timeIntervalSince(task.dueDate) / 86400))
            Text("\(days)d overdue").font(.caption.weight(.bold)).foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption.weight(.bold))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color, in: Capsule())
        }
    }

    private func alertIcon(_ type: EmergencyAlertType) -> String {
        switch type {
        case .sos: return "sos.circle.fill"
        case .accident: return "car.side.front.open"
        case .breakdown: return "exclamationmark.triangle.fill"
        case .medical: return "cross.case.fill"
        case .defect: return "wrench.trianglebadge.exclamationmark"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    // MARK: - Reverse Geocode (Safeguard 4: cached, uses CLGeocoder)

    private func reverseGeocode(_ alert: EmergencyAlert) async {
        guard reversedAddresses[alert.id] == nil else { return }  // already cached
        do {
            let location = CLLocation(latitude: alert.latitude, longitude: alert.longitude)
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let pm = placemarks.first {
                let parts = [pm.name, pm.locality, pm.administrativeArea].compactMap { $0 }
                reversedAddresses[alert.id] = parts.joined(separator: ", ")
            }
        } catch {
            // Non-fatal
        }
    }
}
