import SwiftUI
import Charts

// MARK: - AnalyticsDashboardViewModel

@Observable
final class AnalyticsDashboardViewModel {
    var selectedFleetStatus: VehicleStatus? = nil
    var selectedTripStatus: TripStatus?     = nil
    var selectedStaffLabel: String?         = nil

    // Raw angle bindings for SectorMark chartAngleSelection
    var rawFleetAngle:  Double? = nil
    var rawTripAngle:   Double? = nil
    var rawStaffAngle:  Double? = nil
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

// MARK: - AnalyticsDashboardView

struct AnalyticsDashboardView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss)        private var dismiss

    @State private var viewModel = AnalyticsDashboardViewModel()
    @State private var appeared  = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Fleet Status Donut
                    sectionCard(title: "Fleet Status",
                                subtitle: "Vehicle distribution by operational state") {
                        fleetStatusChart
                    }

                    // 2. Trip Status Donut
                    sectionCard(title: "Trip Overview",
                                subtitle: "All trips by current status") {
                        tripStatusChart
                    }

                    // 3. Staff Distribution Donut
                    sectionCard(title: "Staff Distribution",
                                subtitle: "Team breakdown by role and status") {
                        staffDistributionChart
                    }

                    // 4. Monthly Trip Volume Bar Chart
                    sectionCard(title: "Monthly Trip Volume",
                                subtitle: "Trips scheduled over the past 6 months") {
                        monthlyTripBarChart
                    }

                    // 5. Document Health
                    sectionCard(title: "Document Health",
                                subtitle: "Vehicle documents by validity status") {
                        documentHealthSection
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Fleet Analytics")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                    appeared = true
                }
            }
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
            (.active,    .green),
            (.scheduled, .blue),
            (.completed, .gray),
            (.cancelled, .red),
        ]
        return statuses.compactMap { (status, color) in
            let count = store.trips.filter { $0.status == status }.count
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
                                    .font(.system(size: 13, weight: .bold))
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
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.vehicles.count)")
                                .font(.system(size: 28, weight: .bold))
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
                            legendChip(color: slice.color,
                                       label: slice.status.rawValue,
                                       count: slice.count,
                                       isSelected: viewModel.selectedFleetStatus == slice.status)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedFleetStatus = viewModel.selectedFleetStatus == slice.status ? nil : slice.status
                                }
                            }
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
                                    .font(.system(size: 13, weight: .bold))
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
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.trips.count)")
                                .font(.system(size: 28, weight: .bold))
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
                            legendChip(color: slice.color,
                                       label: slice.status.rawValue,
                                       count: slice.count,
                                       isSelected: viewModel.selectedTripStatus == slice.status)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedTripStatus = viewModel.selectedTripStatus == slice.status ? nil : slice.status
                                }
                            }
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
                                    .font(.system(size: 13, weight: .bold))
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
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(selected)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        } else {
                            Text("\(store.staff.count)")
                                .font(.system(size: 28, weight: .bold))
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
                            legendChip(color: slice.color,
                                       label: slice.label,
                                       count: slice.count,
                                       isSelected: viewModel.selectedStaffLabel == slice.label)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    viewModel.selectedStaffLabel = viewModel.selectedStaffLabel == slice.label ? nil : slice.label
                                }
                            }
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

    private func docHealthCell(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
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
