import SwiftUI
import CoreLocation
import MapKit
import Supabase

/// FM's live alert centre — emergency alerts, route deviations, overdue maintenance.
/// Safeguard 3: NO polling timers. Realtime only + pull to refresh.
/// Safeguard 4: Reverse geocoding cached.
struct AlertsInboxView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var vm = AlertsViewModel()
    @State private var reversedAddresses: [UUID: String] = [:]  // Safeguard 4: cache

    var overdueMaintenanceTasks: [MaintenanceTask] {
        guard vm.selectedFilter == .all || vm.selectedFilter == .maintenance else { return [] }
        return store.maintenanceTasks.filter { $0.status == .pending && $0.dueDate < Date() }
    }

    var body: some View {
        List {
            // Header controls: status segment + filter menu
            Section {
                HStack {
                    Picker("Status", selection: $vm.selectedStatus) {
                        ForEach(AlertsViewModel.AlertStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    Menu {
                        ForEach(AlertsViewModel.AlertFilter.allCases, id: \.self) { filter in
                            Button {
                                vm.selectedFilter = filter
                            } label: {
                                Label(filter.rawValue, systemImage: vm.selectedFilter == filter ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3.weight(.semibold))
                            .padding(8)
                    }
                }
            }

            if vm.isLoading && vm.activeAlerts.isEmpty && vm.deviations(for: .active).isEmpty && overdueMaintenanceTasks.isEmpty {
                Section {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SierraSkeletonView(width: 120, height: 12)
                                Spacer()
                                SierraSkeletonView(width: 60, height: 10)
                            }
                            SierraSkeletonView(width: 180, height: 12)
                            SierraSkeletonView(width: 140, height: 10)
                        }
                        .padding(12)
                        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
                        )
                    }
                }
            } else {
                let alerts = vm.selectedStatus == .active ? vm.activeAlerts : vm.acknowledgedAlerts
                let activeSosAlerts = alerts.filter { !isPreTripReassignmentAlert($0) }
                let reassignmentAlerts = alerts.filter(isPreTripReassignmentAlert)

                // Priority / SOS alerts
                if !activeSosAlerts.isEmpty {
                    Section {
                        ForEach(activeSosAlerts) { alert in
                            NavigationLink(value: alert.id) {
                                emergencyRow(alert)
                            }
                        }
                    } header: {
                        sectionHeader("Emergency Alerts", count: activeSosAlerts.count, color: .red)
                    }
                }

                // Pre-trip reassignment requests
                if !reassignmentAlerts.isEmpty {
                    Section {
                        ForEach(reassignmentAlerts) { alert in
                            NavigationLink(value: alert.id) {
                                emergencyRow(alert)
                            }
                        }
                    } header: {
                        sectionHeader("Vehicle Reassignment", count: reassignmentAlerts.count, color: .orange)
                    }
                }

                let deviations = vm.deviations(for: vm.selectedStatus)
                if !deviations.isEmpty {
                    Section {
                        ForEach(deviations) { dev in
                            deviationRow(dev)
                        }
                    } header: {
                        sectionHeader("Route Deviations", count: deviations.count, color: .yellow)
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

                if activeSosAlerts.isEmpty && reassignmentAlerts.isEmpty && deviations.isEmpty && overdueMaintenanceTasks.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(SierraFont.scaled(40, weight: .light))
                                .foregroundStyle(.green.opacity(0.5))
                            Text("All clear — no active alerts")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                } onOpenMaintenanceTask: { taskId in
                    NotificationCenter.default.post(
                        name: .sierraOpenVehicleMaintenance,
                        object: nil,
                        userInfo: ["taskId": taskId.uuidString]
                    )
                    dismiss()
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
        .padding(12)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
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
        .padding(12)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
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
        .padding(12)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption.weight(.bold))
            Text("\(count)")
                .font(SierraFont.scaled(10, weight: .bold))
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
        case .defect: return "wrench.and.screwdriver.fill"
        }
    }

    private func isPreTripReassignmentAlert(_ alert: EmergencyAlert) -> Bool {
        guard alert.alertType == .defect, let tripId = alert.tripId else { return false }
        guard let preInspection = store.preInspection(forTrip: tripId) else { return false }
        return preInspection.overallResult == .failed
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    // MARK: - Reverse Geocode (Safeguard 4: cached, iOS 26 MapKit API)

    private func reverseGeocode(_ alert: EmergencyAlert) async {
        guard reversedAddresses[alert.id] == nil else { return }  // already cached
        do {
            let location = CLLocation(latitude: alert.latitude, longitude: alert.longitude)
            guard let request = MKReverseGeocodingRequest(location: location) else { return }
            let mapItems = try await request.mapItems
            if let item = mapItems.first {
                if let short = item.address?.shortAddress, !short.isEmpty {
                    reversedAddresses[alert.id] = short
                } else if let full = item.address?.fullAddress, !full.isEmpty {
                    reversedAddresses[alert.id] = full
                } else if let name = item.name, !name.isEmpty {
                    reversedAddresses[alert.id] = name
                }
            }
        } catch {
            // Non-fatal
        }
    }
}
