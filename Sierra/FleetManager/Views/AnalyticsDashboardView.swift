import SwiftUI
import Charts

// MARK: - AnalyticsDashboardViewModel

enum DriverSortField: String, CaseIterable {
    case name       = "Name"
    case trips      = "Trips"
    case distance   = "Distance"
    case deviations = "Deviations"
}

@Observable
final class AnalyticsDashboardViewModel {
    var selectedFleetStatus: VehicleStatus? = nil
    var selectedTripStatus: TripStatus?     = nil
    var selectedStaffLabel: String?         = nil

    // Raw angle bindings for SectorMark chartAngleSelection
    var rawFleetAngle:  Double? = nil
    var rawTripAngle:   Double? = nil
    var rawStaffAngle:  Double? = nil

    // Driver Activity Reports — sort & filter
    var driverSortField: DriverSortField = .name
    var driverSortAscending: Bool = true
    var driverNameFilter: String = ""
}

// MARK: - Slice Models

struct FleetStatusSlice: Identifiable {
    let id    = UUID()
    let status: VehicleStatus
    let count:  Int
    let color:  Color
}

struct TripStatusSlice: Identifiable {
    let id     = UUID()
    let status: TripStatus
    let count:  Int
    let color:  Color
}

struct StaffSlice: Identifiable {
    let id    = UUID()
    let label: String
    let count: Int
    let color: Color
}

struct MonthlyTripData: Identifiable {
    let id    = UUID()
    let month: String
    let year:  Int
    let count: Int
    let date:  Date
}

struct DriverActivityRow: Identifiable {
    let id: UUID
    let name: String
    let tripsCompleted: Int
    let totalDistanceKm: Double
    let avgDurationMinutes: Double?
    let onTimeRate: Double?
    let deviationCount: Int
    let totalLitres: Double
    let totalFuelKm: Double
    let kmPerLitre: Double?
}

// MARK: - AnalyticsDashboardView

struct AnalyticsDashboardView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss)        private var dismiss

    @State private var viewModel = AnalyticsDashboardViewModel()
    @State private var appeared  = false
    @State private var selectedDays: Int = 30   // date range filter: 7, 30, 90
    @State private var selectedPage = 0

    // MARK: - AI Summary State
    @State private var fleetStatusSummaryState: AISummaryCard.SummaryState = .idle
    @State private var staffSummaryState:       AISummaryCard.SummaryState = .idle
    @State private var tripOverviewSummaryState: AISummaryCard.SummaryState = .idle
    @State private var tripVolumeSummaryState:   AISummaryCard.SummaryState = .idle
    @State private var completedTripsSummaryState: AISummaryCard.SummaryState = .idle

    private let pages = ["Fleet", "Trips", "Maintenance", "Drivers", "Fuel & Cost"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page indicator pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, label in
                            Button { withAnimation(.easeInOut(duration: 0.25)) { selectedPage = i } } label: {
                                Text(label)
                                    .font(SierraFont.scaled(13, weight: .semibold))
                                    .foregroundStyle(selectedPage == i ? .white : .primary)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(
                                        selectedPage == i ? Color.orange : Color.primary.opacity(0.08),
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                }

                Divider()

                TabView(selection: $selectedPage) {
                    fleetPage.tag(0)
                    tripsPage.tag(1)
                    maintenancePage.tag(2)
                    driverActivityPage.tag(3)
                    fuelCostPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedPage)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Fleet Analytics")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(SierraFont.scaled(22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                    appeared = true
                }
                // Initial fetch
                if case .idle = fleetStatusSummaryState { Task { await fetchFleetStatusSummary() } }
                if case .idle = staffSummaryState       { Task { await fetchStaffSummary() } }
                if case .idle = tripOverviewSummaryState { Task { await fetchTripOverviewSummary() } }
                if case .idle = tripVolumeSummaryState   { Task { await fetchTripVolumeSummary() } }
                if case .idle = completedTripsSummaryState { Task { await fetchCompletedTripsSummary() } }
            }
            .onChange(of: selectedPage) { old, new in
                if new == 0 {
                    if case .idle = fleetStatusSummaryState { Task { await fetchFleetStatusSummary() } }
                    if case .idle = staffSummaryState       { Task { await fetchStaffSummary() } }
                }
                if new == 1 {
                    if case .idle = tripOverviewSummaryState { Task { await fetchTripOverviewSummary() } }
                    if case .idle = tripVolumeSummaryState   { Task { await fetchTripVolumeSummary() } }
                    if case .idle = completedTripsSummaryState { Task { await fetchCompletedTripsSummary() } }
                }
            }
        }
    }

    // MARK: - AI Summary Fetchers

    @MainActor
    private func fetchFleetStatusSummary() async {
        fleetStatusSummaryState = .loading
        let fleetCounts = Dictionary(grouping: store.vehicles, by: \.status).mapValues { $0.count }
        let snapshot: [String: Any] = [
            "total_vehicles": store.vehicles.count,
            "status_breakdown": Dictionary(uniqueKeysWithValues: fleetCounts.map { ($0.key.rawValue, $0.value) })
        ]
        do {
            let text = try await GroqSummaryService.summarise(topic: "Fleet Status", data: snapshot)
            withAnimation { fleetStatusSummaryState = .loaded(text) }
        } catch {
            fleetStatusSummaryState = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func fetchStaffSummary() async {
        staffSummaryState = .loading
        let staffCounts = Dictionary(grouping: store.staff, by: \.role).mapValues { $0.count }
        let snapshot: [String: Any] = [
            "total_staff": store.staff.count,
            "role_breakdown": Dictionary(uniqueKeysWithValues: staffCounts.map { ($0.key.rawValue, $0.value) })
        ]
        do {
            let text = try await GroqSummaryService.summarise(topic: "Staff Distribution", data: snapshot)
            withAnimation { staffSummaryState = .loaded(text) }
        } catch {
            staffSummaryState = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func fetchTripOverviewSummary() async {
        tripOverviewSummaryState = .loading
        let statusCounts = store.trips.reduce(into: [TripStatus: Int]()) { result, trip in
            result[trip.status.normalized, default: 0] += 1
        }
        let snapshot: [String: Any] = [
            "total_trips": store.trips.count,
            "status_breakdown": Dictionary(uniqueKeysWithValues: statusCounts.map { ($0.key.rawValue, $0.value) })
        ]
        do {
            let text = try await GroqSummaryService.summarise(topic: "Trip Overview", data: snapshot)
            withAnimation { tripOverviewSummaryState = .loaded(text) }
        } catch {
            tripOverviewSummaryState = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func fetchTripVolumeSummary() async {
        tripVolumeSummaryState = .loading
        let snapshot: [String: Any] = [
            "monthly_volume_last_6_months": monthlyData.map { ["month": $0.month, "count": $0.count] }
        ]
        do {
            let text = try await GroqSummaryService.summarise(topic: "Monthly Trip Volume", data: snapshot)
            withAnimation { tripVolumeSummaryState = .loaded(text) }
        } catch {
            tripVolumeSummaryState = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func fetchCompletedTripsSummary() async {
        completedTripsSummaryState = .loading
        let snapshot: [String: Any] = [
            "trips_in_range_count": tripsInRange.count,
            "total_distance_km": totalDistanceKm,
            "avg_duration_min": averageDurationMinutes ?? 0
        ]
        do {
            let text = try await GroqSummaryService.summarise(topic: "Completed Trips Performance", data: snapshot)
            withAnimation { completedTripsSummaryState = .loaded(text) }
        } catch {
            completedTripsSummaryState = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Pages

    private var fleetPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionCard(title: "Fleet Status",
                            subtitle: "Vehicle distribution by operational state") {
                    VStack(spacing: 16) {
                        fleetStatusChart
                        AISummaryCard(state: fleetStatusSummaryState, isFlat: true) {
                            Task { await fetchFleetStatusSummary() }
                        }
                    }
                }
                sectionCard(title: "Staff Distribution",
                            subtitle: "Team breakdown by role and status") {
                    VStack(spacing: 16) {
                        staffDistributionChart
                        AISummaryCard(state: staffSummaryState, isFlat: true) {
                            Task { await fetchStaffSummary() }
                        }
                    }
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
    }

    private var tripsPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionCard(title: "Trip Overview",
                            subtitle: "All trips by current status") {
                    VStack(spacing: 16) {
                        tripStatusChart
                        AISummaryCard(state: tripOverviewSummaryState, isFlat: true) {
                            Task { await fetchTripOverviewSummary() }
                        }
                    }
                }
                sectionCard(title: "Monthly Trip Volume",
                            subtitle: "Trips scheduled over the past 6 months") {
                    VStack(spacing: 16) {
                        monthlyTripBarChart
                        AISummaryCard(state: tripVolumeSummaryState, isFlat: true) {
                            Task { await fetchTripVolumeSummary() }
                        }
                    }
                }
                sectionCard(title: "Completed Trips Summary",
                            subtitle: "Aggregated stats for completed trips — filtered client-side") {
                    VStack(spacing: 16) {
                        completedTripsSummarySection
                        AISummaryCard(state: completedTripsSummaryState, isFlat: true) {
                            Task { await fetchCompletedTripsSummary() }
                        }
                    }
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
    }

    private var maintenancePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionCard(title: "Document Health",
                            subtitle: "Vehicle documents by validity status") {
                    documentHealthSection
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
    }

    private var driverActivityPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                sectionCard(title: "Driver Activity Reports",
                            subtitle: "Per-driver performance breakdown") {
                    driverActivitySection
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
    }

    private var fuelCostPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Placeholder — extend with fuel/cost analytics as data becomes available
                VStack(spacing: 12) {
                    Image(systemName: "fuelpump.fill")
                        .font(SierraFont.scaled(40))
                        .foregroundStyle(.orange.opacity(0.4))
                    Text("Fuel & Cost Analytics")
                        .font(.headline)
                    Text("Detailed fuel consumption and cost breakdowns will appear here once trip fuel data is recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
    }

    // MARK: - Computed Data

    private var fleetSlices: [FleetStatusSlice] {
        let statuses: [(VehicleStatus, Color)] = [
            (.active,          .green),
            (.idle,            .blue),
            (.inMaintenance,   .orange),
            (.outOfService,    .red),
            (.decommissioned,  .gray),
        ]
        return statuses.compactMap { (status, color) in
            let count = store.vehicles.filter { $0.status == status }.count
            guard count > 0 else { return nil }
            return FleetStatusSlice(status: status, count: count, color: color)
        }
    }

    private var tripSlices: [TripStatusSlice] {
        let statuses: [(TripStatus, Color)] = [
            (.pendingAcceptance, .orange),
            (.active,    .green),
            (.scheduled, .blue),
            (.completed, .gray),
            (.cancelled, .red),
        ]
        let normalizedCounts = store.trips.reduce(into: [TripStatus: Int]()) { result, trip in
            result[trip.status.normalized, default: 0] += 1
        }
        return statuses.compactMap { (status, color) in
            let count = normalizedCounts[status, default: 0]
            guard count > 0 else { return nil }
            return TripStatusSlice(status: status, count: count, color: color)
        }
    }

    private var staffSlices: [StaffSlice] {
        [
            StaffSlice(label: "Drivers",     count: store.staff.filter { $0.role == .driver && $0.status == .active }.count,              color: .blue),
            StaffSlice(label: "Maintenance", count: store.staff.filter { $0.role == .maintenancePersonnel && $0.status == .active }.count, color: .orange),
            StaffSlice(label: "Pending",     count: store.staff.filter { $0.status == .pendingApproval }.count,                           color: Color(.systemOrange)),
            StaffSlice(label: "Suspended",   count: store.staff.filter { $0.status == .suspended }.count,                                 color: .red),
        ].filter { $0.count > 0 }
    }

    private var monthlyData: [MonthlyTripData] {
        let calendar  = Calendar.current
        let now       = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().compactMap { offset -> MonthlyTripData? in
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: now),
                  let range      = calendar.dateInterval(of: .month, for: monthStart) else { return nil }
            let count = store.trips.filter { range.contains($0.scheduledDate) }.count
            return MonthlyTripData(
                month: formatter.string(from: monthStart),
                year:  calendar.component(.year, from: monthStart),
                count: count,
                date:  range.start
            )
        }
    }

    // MARK: - Date Range Computed Props (Safeguard: all client-side, no new Supabase calls)

    private var tripsInRange: [Trip] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedDays, to: Date()) ?? Date()
        return store.trips.filter { $0.createdAt >= cutoff && $0.status == .completed }
    }

    private var totalDistanceKm: Double {
        tripsInRange.compactMap { trip -> Double? in
            guard let end = trip.endMileage, let start = trip.startMileage else { return nil }
            return max(0, end - start)
        }.reduce(0, +)
    }

    private var averageDurationMinutes: Double? {
        let durations = tripsInRange.compactMap { trip -> Double? in
            guard let start = trip.actualStartDate, let end = trip.actualEndDate else { return nil }
            return end.timeIntervalSince(start) / 60
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    // MARK: - Driver Activity Rows (FMS1-21)

    private var driverActivityRows: [DriverActivityRow] {
        let drivers = store.staff.filter { $0.role == .driver && $0.status == .active }
        let allCompleted = store.trips.filter { $0.status == .completed }

        var rows = drivers.compactMap { driver -> DriverActivityRow? in
            let dTrips = allCompleted.filter { $0.driverUUID == driver.id }

            // Distance
            let totalDist = dTrips.compactMap { trip -> Double? in
                guard let e = trip.endMileage, let s = trip.startMileage else { return nil }
                return max(0, e - s)
            }.reduce(0, +)

            // Avg duration
            let durations = dTrips.compactMap { trip -> Double? in
                guard let s = trip.actualStartDate, let e = trip.actualEndDate else { return nil }
                return e.timeIntervalSince(s) / 60
            }
            let avgDur: Double? = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)

            // On-time rate
            let tripsWithScheduledEnd = dTrips.filter { $0.scheduledEndDate != nil }
            let onTime: Double? = tripsWithScheduledEnd.isEmpty ? nil : {
                let onTimeCount = tripsWithScheduledEnd.filter { trip in
                    guard let actual = trip.actualEndDate, let scheduled = trip.scheduledEndDate else { return false }
                    return actual <= scheduled
                }.count
                return Double(onTimeCount) / Double(tripsWithScheduledEnd.count)
            }()

            // Deviations
            let devCount = store.routeDeviationEvents.filter { $0.driverId == driver.id }.count

            // Fuel
            let driverFuelLogs = store.fuelLogs.filter { $0.driverId == driver.id }
            let totalLitres = driverFuelLogs.reduce(0) { $0 + $1.fuelQuantityLitres }
            let kmpl: Double? = totalLitres > 0 ? totalDist / totalLitres : nil

            return DriverActivityRow(
                id: driver.id,
                name: driver.name ?? "Unknown",
                tripsCompleted: dTrips.count,
                totalDistanceKm: totalDist,
                avgDurationMinutes: avgDur,
                onTimeRate: onTime,
                deviationCount: devCount,
                totalLitres: totalLitres,
                totalFuelKm: totalDist,
                kmPerLitre: kmpl
            )
        }

        // Filter
        if !viewModel.driverNameFilter.isEmpty {
            rows = rows.filter { $0.name.localizedCaseInsensitiveContains(viewModel.driverNameFilter) }
        }

        // Sort
        rows.sort { a, b in
            let result: Bool
            switch viewModel.driverSortField {
            case .name:       result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .trips:      result = a.tripsCompleted < b.tripsCompleted
            case .distance:   result = a.totalDistanceKm < b.totalDistanceKm
            case .deviations: result = a.deviationCount < b.deviationCount
            }
            return viewModel.driverSortAscending ? result : !result
        }

        return rows
    }

    // MARK: - Chart 1: Fleet Status

    private var fleetStatusChart: some View {
        VStack(spacing: 16) {
            if fleetSlices.isEmpty {
                ContentUnavailableView("No Vehicle Data", systemImage: "car.fill",
                                       description: Text("Add vehicles to see fleet status."))
                    .frame(height: 200)
            } else {
                ZStack {
                    Chart(fleetSlices) { slice in
                        SectorMark(
                            angle: .value("Count", slice.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .opacity(viewModel.selectedFleetStatus == nil || viewModel.selectedFleetStatus == slice.status ? 1.0 : 0.35)
                        .annotation(position: .overlay) {
                            let isSelected = viewModel.selectedFleetStatus == slice.status
                            let isLargest  = viewModel.selectedFleetStatus == nil && slice.count == fleetSlices.max(by: { $0.count < $1.count })?.count
                            if isSelected || isLargest {
                                Text("\(slice.count)")
                                    .font(SierraFont.scaled(13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .chartAngleSelection(value: $viewModel.rawFleetAngle)
                    .onChange(of: viewModel.rawFleetAngle) { _, newAngle in
                        updateFleetSelection(from: newAngle)
                    }
                    .frame(height: 200)

                    // Center overlay
                    VStack(spacing: 2) {
                        if let selected = viewModel.selectedFleetStatus {
                            Text("\(fleetSlices.first(where: { $0.status == selected })?.count ?? 0)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.vehicles.count)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Vehicles")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                }

                // Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(fleetSlices) { slice in
                            Button {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedFleetStatus = viewModel.selectedFleetStatus == slice.status ? nil : slice.status
                                }
                            } label: {
                                legendChip(color: slice.color,
                                           label: slice.status.rawValue,
                                           count: slice.count,
                                           isSelected: viewModel.selectedFleetStatus == slice.status)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(slice.status.rawValue), \(slice.count)")
                            .accessibilityHint("Filters the fleet chart")
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func updateFleetSelection(from angle: Double?) {
        guard let angle, !fleetSlices.isEmpty, angle.isFinite else {
            withAnimation(.spring(duration: 0.25)) { viewModel.selectedFleetStatus = nil }
            return
        }
        let total  = Double(fleetSlices.reduce(0) { $0 + $1.count })
        guard total > 0 else { return }
        var cumulative = 0.0
        let normalised = angle.truncatingRemainder(dividingBy: 360)
        let target     = normalised < 0 ? normalised + 360 : normalised
        for slice in fleetSlices {
            let share = Double(slice.count) / total * 360
            cumulative += share
            if target <= cumulative {
                withAnimation(.spring(duration: 0.25)) {
                    viewModel.selectedFleetStatus = slice.status
                }
                return
            }
        }
    }

    // MARK: - Chart 2: Trip Status

    private var tripStatusChart: some View {
        VStack(spacing: 16) {
            if tripSlices.isEmpty {
                ContentUnavailableView("No Trip Data", systemImage: "arrow.triangle.swap",
                                       description: Text("Create trips to see the distribution."))
                    .frame(height: 200)
            } else {
                ZStack {
                    Chart(tripSlices) { slice in
                        SectorMark(
                            angle: .value("Count", slice.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .opacity(viewModel.selectedTripStatus == nil || viewModel.selectedTripStatus == slice.status ? 1.0 : 0.35)
                        .annotation(position: .overlay) {
                            let isSelected = viewModel.selectedTripStatus == slice.status
                            let isLargest  = viewModel.selectedTripStatus == nil && slice.count == tripSlices.max(by: { $0.count < $1.count })?.count
                            if isSelected || isLargest {
                                Text("\(slice.count)")
                                    .font(SierraFont.scaled(13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .chartAngleSelection(value: $viewModel.rawTripAngle)
                    .onChange(of: viewModel.rawTripAngle) { _, newAngle in
                        updateTripSelection(from: newAngle)
                    }
                    .frame(height: 200)

                    // Center overlay
                    VStack(spacing: 2) {
                        if let selected = viewModel.selectedTripStatus {
                            Text("\(tripSlices.first(where: { $0.status == selected })?.count ?? 0)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.trips.count)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Trips")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tripSlices) { slice in
                            Button {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedTripStatus = viewModel.selectedTripStatus == slice.status ? nil : slice.status
                                }
                            } label: {
                                legendChip(color: slice.color,
                                           label: slice.status.rawValue,
                                           count: slice.count,
                                           isSelected: viewModel.selectedTripStatus == slice.status)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(slice.status.rawValue), \(slice.count)")
                            .accessibilityHint("Filters the trip chart")
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func updateTripSelection(from angle: Double?) {
        guard let angle, !tripSlices.isEmpty, angle.isFinite else {
            withAnimation(.spring(duration: 0.25)) { viewModel.selectedTripStatus = nil }
            return
        }
        let total  = Double(tripSlices.reduce(0) { $0 + $1.count })
        guard total > 0 else { return }
        var cumulative = 0.0
        let normalised = angle.truncatingRemainder(dividingBy: 360)
        let target     = normalised < 0 ? normalised + 360 : normalised
        for slice in tripSlices {
            let share = Double(slice.count) / total * 360
            cumulative += share
            if target <= cumulative {
                withAnimation(.spring(duration: 0.25)) {
                    viewModel.selectedTripStatus = slice.status
                }
                return
            }
        }
    }

    // MARK: - Chart 3: Staff Distribution

    private var staffDistributionChart: some View {
        VStack(spacing: 16) {
            if staffSlices.isEmpty {
                ContentUnavailableView("No Staff Data", systemImage: "person.2.fill",
                                       description: Text("No active staff members yet."))
                    .frame(height: 200)
            } else {
                ZStack {
                    Chart(staffSlices) { slice in
                        SectorMark(
                            angle: .value("Count", slice.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .opacity(viewModel.selectedStaffLabel == nil || viewModel.selectedStaffLabel == slice.label ? 1.0 : 0.35)
                        .annotation(position: .overlay) {
                            let isSelected = viewModel.selectedStaffLabel == slice.label
                            let isLargest  = viewModel.selectedStaffLabel == nil && slice.count == staffSlices.max(by: { $0.count < $1.count })?.count
                            if isSelected || isLargest {
                                Text("\(slice.count)")
                                    .font(SierraFont.scaled(13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .chartAngleSelection(value: $viewModel.rawStaffAngle)
                    .onChange(of: viewModel.rawStaffAngle) { _, newAngle in
                        updateStaffSelection(from: newAngle)
                    }
                    .frame(height: 200)

                    // Center overlay
                    VStack(spacing: 2) {
                        if let selected = viewModel.selectedStaffLabel {
                            Text("\(staffSlices.first(where: { $0.label == selected })?.count ?? 0)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.staff.count)")
                                .font(SierraFont.scaled(28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Staff")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(staffSlices) { slice in
                            Button {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedStaffLabel = viewModel.selectedStaffLabel == slice.label ? nil : slice.label
                                }
                            } label: {
                                legendChip(color: slice.color,
                                           label: slice.label,
                                           count: slice.count,
                                           isSelected: viewModel.selectedStaffLabel == slice.label)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(slice.label), \(slice.count)")
                            .accessibilityHint("Filters the staff chart")
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func updateStaffSelection(from angle: Double?) {
        guard let angle, !staffSlices.isEmpty, angle.isFinite else {
            withAnimation(.spring(duration: 0.25)) { viewModel.selectedStaffLabel = nil }
            return
        }
        let total  = Double(staffSlices.reduce(0) { $0 + $1.count })
        guard total > 0 else { return }
        var cumulative = 0.0
        let normalised = angle.truncatingRemainder(dividingBy: 360)
        let target     = normalised < 0 ? normalised + 360 : normalised
        for slice in staffSlices {
            let share = Double(slice.count) / total * 360
            cumulative += share
            if target <= cumulative {
                withAnimation(.spring(duration: 0.25)) {
                    viewModel.selectedStaffLabel = slice.label
                }
                return
            }
        }
    }

    // MARK: - Chart 4: Monthly Trip Volume Bar Chart

    private var monthlyTripBarChart: some View {
        Group {
            if monthlyData.allSatisfy({ $0.count == 0 }) {
                ContentUnavailableView("No Trip History", systemImage: "chart.bar",
                                       description: Text("Trip data will appear here once trips are created."))
                    .frame(height: 180)
            } else {
                Chart(monthlyData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Trips", item.count)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.separator))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Section 7: Driver Activity Reports (FMS1-21)

    private var driverActivitySection: some View {
        VStack(spacing: 14) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by driver name", text: $viewModel.driverNameFilter)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !viewModel.driverNameFilter.isEmpty {
                    Button {
                        viewModel.driverNameFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Sort controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DriverSortField.allCases, id: \.self) { field in
                        let isActive = viewModel.driverSortField == field
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                if viewModel.driverSortField == field {
                                    viewModel.driverSortAscending.toggle()
                                } else {
                                    viewModel.driverSortField = field
                                    viewModel.driverSortAscending = true
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(field.rawValue)
                                    .font(.caption.weight(isActive ? .bold : .medium))
                                if isActive {
                                    Image(systemName: viewModel.driverSortAscending ? "chevron.up" : "chevron.down")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(isActive ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isActive ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Table
            let rows = driverActivityRows
            if rows.isEmpty {
                ContentUnavailableView("No Matching Drivers",
                                       systemImage: "person.slash",
                                       description: Text(viewModel.driverNameFilter.isEmpty
                                                         ? "No active drivers found."
                                                         : "No drivers match \"\(viewModel.driverNameFilter)\"."))
                    .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        driverTableHeader

                        ForEach(rows) { row in
                            driverTableRow(row)
                            if row.id != rows.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var driverTableHeader: some View {
        HStack(spacing: 0) {
            Text("Driver").frame(width: 110, alignment: .leading)
            Text("Trips").frame(width: 50, alignment: .trailing)
            Text("Distance").frame(width: 72, alignment: .trailing)
            Text("Avg Dur.").frame(width: 66, alignment: .trailing)
            Text("On-time").frame(width: 62, alignment: .trailing)
            Text("Devs").frame(width: 48, alignment: .trailing)
            Text("km/L").frame(width: 52, alignment: .trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func driverTableRow(_ row: DriverActivityRow) -> some View {
        HStack(spacing: 0) {
            Text(row.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            Text("\(row.tripsCompleted)")
                .font(.caption.monospacedDigit())
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.0f km", row.totalDistanceKm))
                .font(.caption.monospacedDigit())
                .frame(width: 72, alignment: .trailing)

            Text(row.avgDurationMinutes.map { String(format: "%.0f min", $0) } ?? "—")
                .font(.caption.monospacedDigit())
                .frame(width: 66, alignment: .trailing)

            Text(row.onTimeRate.map { String(format: "%.0f%%", $0 * 100) } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(row.onTimeRate.map { $0 >= 0.8 ? Color.green : ($0 >= 0.5 ? Color.orange : Color.red) } ?? Color.secondary)
                .frame(width: 62, alignment: .trailing)

            Text("\(row.deviationCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(row.deviationCount == 0 ? Color.secondary : Color.orange)
                .frame(width: 48, alignment: .trailing)

            Text(row.kmPerLitre.map { String(format: "%.1f", $0) } ?? "—")
                .font(.caption.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Chart 5: Document Health

    private var documentHealthSection: some View {
        let allDocs  = store.vehicleDocuments
        let valid    = allDocs.filter { !$0.isExpiringSoon && !$0.isExpired }.count
        let expiring = allDocs.filter { $0.isExpiringSoon && !$0.isExpired }.count
        let expired  = allDocs.filter { $0.isExpired }.count

        return Group {
            if allDocs.isEmpty {
                ContentUnavailableView("No Documents", systemImage: "doc.fill",
                                       description: Text("Upload vehicle documents to track their health."))
                    .frame(height: 100)
            } else {
                HStack(spacing: 8) {
                    docHealthCell(icon: "checkmark.shield.fill", count: valid,    label: "Valid",    color: .green)
                    docHealthCell(icon: "clock.badge.exclamationmark", count: expiring, label: "Expiring", color: .orange)
                    docHealthCell(icon: "xmark.shield.fill", count: expired,  label: "Expired",  color: .red)
                }
            }
        }
    }

    // MARK: - Completed Trips Summary Section

    private var completedTripsSummarySection: some View {
        VStack(spacing: 16) {
            // Date range picker
            Picker("Range", selection: $selectedDays) {
                Text("7 Days").tag(7)
                Text("30 Days").tag(30)
                Text("90 Days").tag(90)
            }
            .pickerStyle(.segmented)

            // Summary stats row
            HStack(spacing: 0) {
                summaryStatCell(value: "\(tripsInRange.count)",
                                label: "Completed")
                Divider().frame(height: 40)
                summaryStatCell(value: String(format: "%.0f km", totalDistanceKm),
                                label: "Distance")
                Divider().frame(height: 40)
                if let avg = averageDurationMinutes {
                    summaryStatCell(value: String(format: "%.0f min", avg),
                                    label: "Avg Duration")
                } else {
                    summaryStatCell(value: "—", label: "Avg Duration")
                }
            }
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Driver performance table
            let drivers = store.staff.filter { $0.role == .driver && $0.status == .active }
            if !drivers.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Driver").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Trips").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                        Text("Rating").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 54, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground))

                    ForEach(drivers) { driver in
                        let dTrips = tripsInRange.filter { $0.driverUUID == driver.id }
                        let ratedTrips = dTrips.filter { $0.driverRating != nil }
                        let avgRating: String = {
                            guard !ratedTrips.isEmpty else { return "—" }
                            let sum = ratedTrips.compactMap { $0.driverRating }.reduce(0, +)
                            let avg = Double(sum) / Double(ratedTrips.count)
                            return String(format: "%.1f ★", avg)
                        }()
                        HStack {
                            Text(driver.name ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            Text("\(dTrips.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(width: 44, alignment: .trailing)
                            Text(avgRating)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 54, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 12)
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func summaryStatCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func docHealthCell(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(SierraFont.scaled(26, weight: .light))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text("\(count)")
                .font(SierraFont.scaled(28, weight: .bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Shared Helpers

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func legendChip(color: Color, label: String, count: Int, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(isSelected ? color : Color(.tertiaryLabel))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? color.opacity(0.12) : Color(.secondarySystemGroupedBackground),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(duration: 0.25, bounce: 0.15), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    AnalyticsDashboardView()
        .environment(AppDataStore.shared)
}
