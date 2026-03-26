import SwiftUI
import Charts
import UIKit
import UniformTypeIdentifiers

/// Full reports view with 5 paginated pages and CSV export.
/// Safeguard 1: stats computed from AppDataStore in-memory.
/// Safeguard 2: date range filter in Swift, not via Supabase query.
/// Safeguard 3: CSV export via UIActivityViewController, no file writes.
struct ReportsView: View {

    @Environment(AppDataStore.self) private var store

    enum DateRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
    }

    @State private var currentPage = 0
    @State private var selectedRange: DateRange = .month
    @State private var selectedDriverId: UUID?

    // MARK: - Date Helpers

    private var csvDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }

    private func csvDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        return csvDateFormatter.string(from: d)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private var cutoffDate: Date {
        let days: Int
        switch selectedRange {
        case .week: days = -7
        case .month: days = -30
        case .quarter: days = -90
        }
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    // MARK: - Filtered Data

    private var tripsInRange: [Trip] {
        store.trips.filter { $0.createdAt >= cutoffDate }
    }

    private var completedTripsInRange: [Trip] {
        tripsInRange.filter { $0.status == .completed }
    }

    private var maintenanceTasksInRange: [MaintenanceTask] {
        store.maintenanceTasks.filter { $0.createdAt >= cutoffDate }
    }

    private var fuelLogsInRange: [FuelLog] {
        store.fuelLogs.filter { $0.loggedAt >= cutoffDate }
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

    private var drivers: [StaffMember] {
        store.staff.filter { $0.role == .driver && $0.status == .active }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $currentPage) {
            overviewPage.tag(0)
            fleetUsagePage.tag(1)
            driverActivityPage.tag(2)
            maintenancePage.tag(3)
            exportPage.tag(4)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { currentPage = 4 } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Page 0: Overview / KPI Summary

    private var overviewPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date Range Picker
                Picker("Range", selection: $selectedRange) {
                    ForEach(DateRange.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)

                // KPI Row 1
                HStack(spacing: 12) {
                    kpiCard(icon: "arrow.triangle.swap", label: "Active Trips", value: "\(tripsInRange.filter { $0.status == .active }.count)", color: .green)
                    kpiCard(icon: "car.2.fill", label: "Vehicles Online", value: "\(store.vehicles.filter { $0.status == .active }.count)", color: .blue)
                    kpiCard(icon: "wrench.and.screwdriver", label: "Pending Tasks", value: "\(maintenanceTasksInRange.filter { $0.status == .pending || $0.status == .assigned }.count)", color: .orange)
                }

                // KPI Row 2
                HStack(spacing: 12) {
                    kpiCard(icon: "checkmark.circle.fill", label: "Completed Trips", value: "\(completedTripsInRange.count)", color: .green)
                    kpiCard(icon: "road.lanes", label: "Total Distance", value: "\(Int(totalDistanceInRange)) km", color: .blue)
                    kpiCard(icon: "clock.fill", label: "Avg Duration", value: avgTripDuration, color: .purple)
                }

                // Quick Health Indicators
                VStack(spacing: 8) {
                    let inactiveVehicles = store.vehicles.filter { $0.status != .active }.count
                    healthRow(icon: "car.fill", label: "Inactive Vehicles", count: inactiveVehicles, color: .orange)

                    let overdueCount = maintenanceTasksInRange.filter { t in
                        t.dueDate < Date() && t.status != .completed && t.status != .cancelled
                    }.count
                    healthRow(icon: "exclamationmark.triangle.fill", label: "Overdue Maintenance", count: overdueCount, color: .red)
                }
            }
            .padding(16)
            .padding(.bottom, 32)  // room for dot indicators
        }
    }

    // MARK: - Page 1: Fleet Usage

    private var fleetUsagePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Fleet Usage", subtitle: "Last \(selectedRange.rawValue)")

                // Vehicle utilisation chart
                if !store.vehicles.isEmpty {
                    Chart {
                        ForEach(store.vehicles.sorted { $0.totalTrips > $1.totalTrips }.prefix(8), id: \.id) { v in
                            BarMark(
                                x: .value("Vehicle", v.licensePlate),
                                y: .value("Trips", v.totalTrips)
                            )
                            .foregroundStyle(.orange.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis { AxisMarks(values: .automatic) { _ in AxisValueLabel().font(.system(size: 8)) } }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Top 5 vehicles by distance
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOP VEHICLES BY DISTANCE").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                    let vehicleDistances = Dictionary(grouping: completedTripsInRange, by: { $0.vehicleId ?? "" })
                        .map { (key: $0.key, dist: $0.value.compactMap { t -> Double? in
                            guard let s = t.startMileage, let e = t.endMileage else { return nil }
                            return e - s
                        }.reduce(0, +), trips: $0.value.count) }
                        .sorted { $0.dist > $1.dist }
                        .prefix(5)

                    ForEach(Array(vehicleDistances), id: \.key) { item in
                        let vehicle = store.vehicles.first(where: { $0.id.uuidString == item.key })
                        HStack {
                            Text(vehicle?.name ?? "Unknown").font(.subheadline.weight(.medium))
                            Text(vehicle?.licensePlate ?? "").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(item.dist)) km").font(.caption.weight(.bold)).foregroundStyle(.orange)
                            Text("· \(item.trips) trips").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Fuel summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("FUEL CONSUMPTION").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                    let totalLitres = fuelLogsInRange.map(\.fuelQuantityLitres).reduce(0, +)
                    let totalSpend = fuelLogsInRange.map(\.fuelCost).reduce(0, +)
                    let avgPrice = fuelLogsInRange.isEmpty ? 0 : totalSpend / totalLitres
                    HStack(spacing: 12) {
                        miniStat("Total Litres", "\(String(format: "%.0f", totalLitres)) L")
                        miniStat("Avg Price/L", "₹\(String(format: "%.1f", avgPrice))")
                        miniStat("Total Spend", "₹\(String(format: "%.0f", totalSpend))")
                    }
                }

                exportInlineButton("Export Fleet CSV") { shareCSV(generateFleetCSV(), filename: "fleet_report.csv") }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Page 2: Driver Activity

    private var driverActivityPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Driver Activity", subtitle: "Last \(selectedRange.rawValue)")

                // Driver picker
                Picker("Driver", selection: $selectedDriverId) {
                    Text("All Drivers").tag(UUID?.none)
                    ForEach(drivers) { d in
                        Text(d.name ?? d.email).tag(Optional(d.id))
                    }
                }
                .pickerStyle(.menu)

                let driverTrips = selectedDriverId == nil
                    ? completedTripsInRange
                    : completedTripsInRange.filter { $0.driverId == selectedDriverId?.uuidString }

                // Stats row
                HStack(spacing: 12) {
                    miniStat("Trips", "\(driverTrips.count)")
                    let dist = driverTrips.compactMap { t -> Double? in
                        guard let s = t.startMileage, let e = t.endMileage else { return nil }
                        return e - s
                    }.reduce(0, +)
                    miniStat("Distance", "\(Int(dist)) km")
                    let rated = driverTrips.compactMap(\.driverRating)
                    let avg = rated.isEmpty ? "N/A" : String(format: "%.1f★", Double(rated.reduce(0, +)) / Double(rated.count))
                    miniStat("Rating", avg)
                }

                // Driver table or individual detail
                if selectedDriverId == nil {
                    // All drivers table
                    ForEach(drivers) { d in
                        let trips = completedTripsInRange.filter { $0.driverId == d.id.uuidString }
                        HStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 32, height: 32)
                                .overlay(Text(d.initials).font(.system(size: 11, weight: .bold, design: .rounded)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(d.name ?? "Unknown").font(.subheadline.weight(.medium))
                                Text("\(trips.count) trips").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            let rated = trips.compactMap(\.driverRating)
                            if !rated.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.orange)
                                    Text(String(format: "%.1f", Double(rated.reduce(0, +)) / Double(rated.count)))
                                        .font(.caption.weight(.bold)).foregroundStyle(.orange)
                                }
                            } else {
                                Text("Not rated").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    // Recent trips for selected driver
                    Text("RECENT TRIPS").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                    let recent = driverTrips.sorted { $0.scheduledDate > $1.scheduledDate }.prefix(5)
                    ForEach(Array(recent)) { trip in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(trip.origin) \u{2192} \(trip.destination)")
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(trip.status.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(trip.status == .completed ? .green : .orange)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background((trip.status == .completed ? Color.green : .orange).opacity(0.1), in: Capsule())
                            if let rating = trip.driverRating {
                                HStack(spacing: 1) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < rating ? "star.fill" : "star")
                                            .font(.system(size: 8))
                                            .foregroundStyle(i < rating ? .orange : Color(.systemGray4))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                exportInlineButton("Export Driver CSV") { shareCSV(generateDriverCSV(driverTrips), filename: "driver_report.csv") }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Page 3: Maintenance

    private var maintenancePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Maintenance", subtitle: "Last \(selectedRange.rawValue)")

                let completed = maintenanceTasksInRange.filter { $0.status == .completed }
                let inProgress = maintenanceTasksInRange.filter { $0.status == .inProgress }
                let overdue = maintenanceTasksInRange.filter { t in
                    t.dueDate < Date() && t.status != .completed && t.status != .cancelled
                }

                // Summary row
                HStack(spacing: 12) {
                    miniStat("Created", "\(maintenanceTasksInRange.count)")
                    miniStat("Completed", "\(completed.count)")
                    miniStat("In Progress", "\(inProgress.count)")
                    miniStat("Overdue", "\(overdue.count)")
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
                        Image(systemName: "clock.arrow.circlepath").font(.caption).foregroundStyle(.orange)
                        Text("Avg Resolution Time").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(days)d \(hrs)h").font(.subheadline.weight(.bold))
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                // Cost breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("COST BREAKDOWN").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                    let records = store.maintenanceRecords.filter { rec in
                        maintenanceTasksInRange.contains(where: { $0.id == rec.maintenanceTaskId })
                    }
                    let totalLabour = records.map(\.labourCost).reduce(0, +)
                    let totalParts = records.map(\.partsCost).reduce(0, +)
                    let totalCost = records.map(\.totalCost).reduce(0, +)
                    HStack(spacing: 12) {
                        miniStat("Labour", "₹\(String(format: "%.0f", totalLabour))")
                        miniStat("Parts", "₹\(String(format: "%.0f", totalParts))")
                        miniStat("Total", "₹\(String(format: "%.0f", totalCost))")
                    }
                }

                // Urgency breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("BY PRIORITY").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                    let priorities = Dictionary(grouping: maintenanceTasksInRange, by: \.priority)
                    let total = max(maintenanceTasksInRange.count, 1)
                    ForEach(["Low", "Medium", "High", "Urgent"], id: \.self) { label in
                        let priority = TaskPriority(rawValue: label) ?? .low
                        let count = priorities[priority]?.count ?? 0
                        HStack(spacing: 8) {
                            Text(label).font(.caption).frame(width: 60, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(priorityColor(label))
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                            }
                            .frame(height: 14)
                            Text("\(count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

                exportInlineButton("Export Maintenance CSV") { shareCSV(generateMaintenanceCSV(), filename: "maintenance_report.csv") }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Page 4: Export

    private var exportPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Export Reports", subtitle: "Generate CSV files")

                // Date range
                Picker("Range", selection: $selectedRange) {
                    ForEach(DateRange.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                exportRow(
                    icon: "chart.bar.fill",
                    title: "Trip Report",
                    subtitle: "\(tripsInRange.count) trips · \(Int(totalDistanceInRange)) km · \(selectedRange.rawValue) range",
                    color: .blue
                ) { shareCSV(generateFleetCSV(), filename: "trips_report.csv") }

                exportRow(
                    icon: "fuelpump.fill",
                    title: "Fuel Log Report",
                    subtitle: "\(fuelLogsInRange.count) logs · ₹\(String(format: "%.0f", fuelLogsInRange.map(\.fuelCost).reduce(0, +))) total spend",
                    color: .green
                ) { shareCSV(generateFuelCSV(), filename: "fuel_report.csv") }

                exportRow(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Maintenance Report",
                    subtitle: "\(maintenanceTasksInRange.count) tasks · ₹\(String(format: "%.0f", store.maintenanceRecords.filter { rec in maintenanceTasksInRange.contains(where: { $0.id == rec.maintenanceTaskId }) }.map(\.totalCost).reduce(0, +))) total cost",
                    color: .orange
                ) { shareCSV(generateMaintenanceCSV(), filename: "maintenance_report.csv") }

                exportRow(
                    icon: "person.2.fill",
                    title: "Driver Activity",
                    subtitle: "\(drivers.count) drivers · \(completedTripsInRange.count) completed trips",
                    color: .purple
                ) { shareCSV(generateDriverCSV(completedTripsInRange), filename: "driver_report.csv") }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Shared UI Components

    private func kpiCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func healthRow(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(count > 0 ? color : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(count > 0 ? color.opacity(0.1) : Color(.systemGray5), in: Capsule())
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func exportInlineButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func exportRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }

                Spacer()

                Text("Export CSV")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func priorityColor(_ label: String) -> Color {
        switch label {
        case "Low":    return .green
        case "Medium": return .blue
        case "High":   return .orange
        case "Urgent": return .red
        default:       return .gray
        }
    }

    // MARK: - CSV Generators (Safeguard 3: in-memory string, shared via UIActivityViewController)

    private func generateFleetCSV() -> String {
        var csv = "Task ID,Driver,Vehicle Plate,Origin,Destination,Scheduled Date,Actual Start,Actual End,Distance (km),Status,Priority\n"
        for trip in tripsInRange {
            let driver = store.staff.first(where: { $0.id.uuidString == trip.driverId })?.name ?? ""
            let vehicle = store.vehicles.first(where: { $0.id.uuidString == (trip.vehicleId ?? "") })
            let plate = vehicle?.licensePlate ?? ""
            let dist = (trip.endMileage ?? 0) - (trip.startMileage ?? 0)
            csv += "\(csvEscape(trip.taskId)),\(csvEscape(driver)),\(csvEscape(plate)),\(csvEscape(trip.origin)),\(csvEscape(trip.destination)),\(csvDate(trip.scheduledDate)),\(csvDate(trip.actualStartDate)),\(csvDate(trip.actualEndDate)),\(Int(dist)),\(trip.status.rawValue),\(trip.priority.rawValue)\n"
        }
        return csv
    }

    private func generateDriverCSV(_ trips: [Trip]) -> String {
        var csv = "Task ID,Origin,Destination,Distance (km),Duration (h),Rating\n"
        for trip in trips {
            let dist = (trip.endMileage ?? 0) - (trip.startMileage ?? 0)
            let dur = (trip.actualEndDate?.timeIntervalSince(trip.actualStartDate ?? Date()) ?? 0) / 3600
            csv += "\(csvEscape(trip.taskId)),\(csvEscape(trip.origin)),\(csvEscape(trip.destination)),\(Int(dist)),\(String(format: "%.1f", dur)),\(trip.driverRating.map(String.init) ?? "N/A")\n"
        }
        return csv
    }

    private func generateFuelCSV() -> String {
        var csv = "Date,Driver,Vehicle Plate,Litres,Cost,Price/Litre,Odometer,Fuel Station\n"
        for log in fuelLogsInRange {
            let driver = store.staffMember(for: log.driverId)?.name ?? ""
            let vehicle = store.vehicle(for: log.vehicleId)
            let plate = vehicle?.licensePlate ?? ""
            csv += "\(csvDate(log.loggedAt)),\(csvEscape(driver)),\(csvEscape(plate)),\(String(format: "%.1f", log.fuelQuantityLitres)),\(String(format: "%.0f", log.fuelCost)),\(String(format: "%.2f", log.pricePerLitre)),\(String(format: "%.0f", log.odometerAtFill)),\(csvEscape(log.fuelStation ?? ""))\n"
        }
        return csv
    }

    private func generateMaintenanceCSV() -> String {
        var csv = "Title,Vehicle,Vehicle Plate,Assigned To,Priority,Status,Due Date,Completed,Labour Cost,Parts Cost,Total Cost\n"
        for task in maintenanceTasksInRange {
            let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
            let assignee = task.assignedToId.flatMap { store.staffMember(for: $0) }
            let record = store.maintenanceRecords.first(where: { $0.maintenanceTaskId == task.id })
            let labourCost = record.map { String(format: "%.0f", $0.labourCost) } ?? ""
            let partsCost  = record.map { String(format: "%.0f", $0.partsCost) } ?? ""
            let totalCost  = record.map { String(format: "%.0f", $0.totalCost) } ?? ""
            csv += "\(csvEscape(task.title)),\(csvEscape(vehicle?.name ?? "")),\(csvEscape(vehicle?.licensePlate ?? "")),\(csvEscape(assignee?.name ?? "")),\(task.priority.rawValue),\(task.status.rawValue),\(csvDate(task.dueDate)),\(csvDate(task.completedAt)),\(labourCost),\(partsCost),\(totalCost)\n"
        }
        return csv
    }

    // Safeguard 3: temp file shared via UIActivityViewController
    private func shareCSV(_ csv: String, filename: String = "report.csv") {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("[ReportsView] CSV write error: \(error)")
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = root.view
        root.present(activityVC, animated: true)
    }
}

#Preview {
    ReportsView()
        .environment(AppDataStore.shared)
}
