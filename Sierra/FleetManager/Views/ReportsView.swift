import SwiftUI
import UIKit

/// Full reports view with CSV export via UIActivityViewController.
/// Safeguard 1: stats computed from AppDataStore in-memory.
/// Safeguard 2: date range filter in Swift, not via Supabase query.
/// Safeguard 3: CSV export via UIActivityViewController, no file writes.
struct ReportsView: View {

    @Environment(AppDataStore.self) private var store

    enum ReportTab: String, CaseIterable {
        case fleet = "Fleet Usage"
        case driver = "Driver Activity"
        case maintenance = "Maintenance"
    }

    enum DateRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
    }

    @State private var selectedTab: ReportTab = .fleet
    @State private var selectedRange: DateRange = .month
    @State private var selectedDriverId: UUID?

    private var cutoffDate: Date {
        let days: Int
        switch selectedRange {
        case .week: days = -7
        case .month: days = -30
        case .quarter: days = -90
        }
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    // Safeguard 2: filtered in Swift from cached data
    private var tripsInRange: [Trip] {
        store.trips.filter { $0.createdAt >= cutoffDate }
    }

    private var completedTripsInRange: [Trip] {
        tripsInRange.filter { $0.status == .completed }
    }

    private var maintenanceTasksInRange: [MaintenanceTask] {
        store.maintenanceTasks.filter { $0.createdAt >= cutoffDate }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Report", selection: $selectedTab) {
                    ForEach(ReportTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)

                // Date range
                Picker("Range", selection: $selectedRange) {
                    ForEach(DateRange.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .fleet: fleetUsageReport
                        case .driver: driverActivityReport
                        case .maintenance: maintenanceReport
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Fleet Usage Report

    private var fleetUsageReport: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportHeader("Fleet Usage Report", subtitle: "Last \(selectedRange.rawValue)")

            HStack(spacing: 12) {
                reportStat("Trips", value: "\(completedTripsInRange.count)")
                reportStat("Total Dist", value: "\(Int(totalDistanceInRange)) km")
                reportStat("Avg Duration", value: avgTripDuration)
            }

            // Top 3 vehicles
            VStack(alignment: .leading, spacing: 8) {
                Text("TOP VEHICLES").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                let sorted = store.vehicles.sorted { $0.totalTrips > $1.totalTrips }.prefix(3)
                ForEach(Array(sorted), id: \.id) { v in
                    HStack {
                        Text(v.name).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(v.totalTrips) trips").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            exportButton { generateFleetCSV() }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var totalDistanceInRange: Double {
        completedTripsInRange.compactMap { t -> Double? in
            guard let s = t.startMileage, let e = t.endMileage else { return nil }
            return e - s
        }.reduce(0, +)
    }

    private var avgTripDuration: String {
        let durations = completedTripsInRange.compactMap { t -> TimeInterval? in
            guard let s = t.actualStartDate, let e = t.actualEndDate else { return nil }
            return e.timeIntervalSince(s)
        }
        guard !durations.isEmpty else { return "N/A" }
        let avg = durations.reduce(0, +) / Double(durations.count)
        let hrs = Int(avg / 3600)
        let mins = Int((avg.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hrs)h \(mins)m"
    }

    // MARK: - Driver Activity Report

    private var driverActivityReport: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportHeader("Driver Activity", subtitle: "Last \(selectedRange.rawValue)")

            // Driver picker
            Picker("Driver", selection: $selectedDriverId) {
                Text("All Drivers").tag(UUID?.none)
                ForEach(store.staff.filter({ $0.role == .driver })) { d in
                    Text(d.name ?? d.email).tag(Optional(d.id))
                }
            }
            .pickerStyle(.menu)

            let driverTrips = selectedDriverId == nil
                ? completedTripsInRange
                : completedTripsInRange.filter { $0.driverId == selectedDriverId?.uuidString }

            HStack(spacing: 12) {
                reportStat("Trips", value: "\(driverTrips.count)")
                let dist = driverTrips.compactMap { t -> Double? in
                    guard let s = t.startMileage, let e = t.endMileage else { return nil }
                    return e - s
                }.reduce(0, +)
                reportStat("Distance", value: "\(Int(dist)) km")

                // Safeguard 7: non-nil ratings
                let rated = driverTrips.compactMap(\.driverRating)
                let avg = rated.isEmpty ? "N/A" : String(format: "%.1f★", Double(rated.reduce(0, +)) / Double(rated.count))
                reportStat("Rating", value: avg)
            }

            // Driver list
            if selectedDriverId == nil {
                ForEach(store.staff.filter({ $0.role == .driver && $0.status == .active })) { d in
                    let trips = completedTripsInRange.filter { $0.driverId == d.id.uuidString }
                    HStack {
                        Text(d.name ?? "Unknown").font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(trips.count) trips").font(.caption).foregroundStyle(.secondary)
                        let rated = trips.compactMap(\.driverRating)
                        if !rated.isEmpty {
                            Text(String(format: "%.1f★", Double(rated.reduce(0, +)) / Double(rated.count)))
                                .font(.caption.weight(.bold)).foregroundStyle(.orange)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            exportButton { generateDriverCSV(driverTrips) }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Maintenance Report

    private var maintenanceReport: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportHeader("Maintenance", subtitle: "Last \(selectedRange.rawValue)")

            let completed = maintenanceTasksInRange.filter { $0.status == .completed }
            let inProgress = maintenanceTasksInRange.filter { $0.status == .inProgress }
            let pending = maintenanceTasksInRange.filter { $0.status == .pending || $0.status == .assigned }

            HStack(spacing: 12) {
                reportStat("Completed", value: "\(completed.count)")
                reportStat("In Progress", value: "\(inProgress.count)")
                reportStat("Pending", value: "\(pending.count)")
            }

            // Average resolution time
            let resTimes = completed.compactMap { t -> TimeInterval? in
                guard let c = t.completedAt else { return nil }
                return c.timeIntervalSince(t.createdAt)
            }
            if !resTimes.isEmpty {
                let avgRes = resTimes.reduce(0, +) / Double(resTimes.count)
                let days = Int(avgRes / 86400)
                let hrs = Int((avgRes.truncatingRemainder(dividingBy: 86400)) / 3600)
                HStack {
                    Text("Avg Resolution").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(days)d \(hrs)h").font(.subheadline.weight(.bold))
                }
                .padding(10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            exportButton { generateMaintenanceCSV() }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func reportHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func reportStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func exportButton(csvGenerator: @escaping () -> String) -> some View {
        Button {
            let csv = csvGenerator()
            shareCSV(csv)
        } label: {
            Label("Export CSV", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SierraTheme.Colors.info)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(SierraTheme.Colors.info.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - CSV Generators (Safeguard 3: in-memory string, shared via UIActivityViewController)

    private func generateFleetCSV() -> String {
        var csv = "Trip ID,Origin,Destination,Status,Driver,Distance (km),Start Date,End Date\n"
        for trip in completedTripsInRange {
            let driver = store.staff.first(where: { $0.id.uuidString == trip.driverId })?.name ?? ""
            let dist = (trip.endMileage ?? 0) - (trip.startMileage ?? 0)
            csv += "\(trip.taskId),\(trip.origin),\(trip.destination),\(trip.status.rawValue),\(driver),\(Int(dist)),\(trip.actualStartDate?.ISO8601Format() ?? ""),\(trip.actualEndDate?.ISO8601Format() ?? "")\n"
        }
        return csv
    }

    private func generateDriverCSV(_ trips: [Trip]) -> String {
        var csv = "Trip ID,Origin,Destination,Distance (km),Duration (h),Rating\n"
        for trip in trips {
            let dist = (trip.endMileage ?? 0) - (trip.startMileage ?? 0)
            let dur = (trip.actualEndDate?.timeIntervalSince(trip.actualStartDate ?? Date()) ?? 0) / 3600
            csv += "\(trip.taskId),\(trip.origin),\(trip.destination),\(Int(dist)),\(String(format: "%.1f", dur)),\(trip.driverRating.map(String.init) ?? "N/A")\n"
        }
        return csv
    }

    private func generateMaintenanceCSV() -> String {
        var csv = "Title,Type,Priority,Status,Created,Completed,Due Date\n"
        for task in maintenanceTasksInRange {
            csv += "\(task.title),\(task.taskType.rawValue),\(task.priority.rawValue),\(task.status.rawValue),\(task.createdAt.ISO8601Format()),\(task.completedAt?.ISO8601Format() ?? ""),\(task.dueDate.ISO8601Format())\n"
        }
        return csv
    }

    // Safeguard 3: UIActivityViewController, no file writes
    private func shareCSV(_ csv: String) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [csv], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = root.view
        root.present(activityVC, animated: true)
    }
}

#Preview {
    ReportsView()
        .environment(AppDataStore.shared)
}
