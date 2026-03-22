import SwiftUI
import Charts

// MARK: - DashboardHomeView
// Fleet manager overview: KPI cards + analytics snapshot + recent trips + expiring docs.

struct DashboardHomeView: View {

    @Environment(AppDataStore.self) private var store
    @State private var showProfile   = false
    @State private var showAnalytics = false
    @State private var showNotifications = false

    // Sheets for fleet management (replaces NavigationLink push to avoid nested nav conflicts)
    @State private var showReportsSheet   = false
    @State private var showAlertsSheet    = false
    @State private var showGeofencesSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    kpiGrid
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    analyticsSnapshotCard
                        .padding(.horizontal, 20)

                    recentTripsSection

                    expiringDocsSection

                    fleetManagementSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Dashboard")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.body)
                            if store.unreadNotificationCount > 0 {
                                Text("\(min(store.unreadNotificationCount, 9))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(.red, in: Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showProfile) {
                AdminProfileView().presentationDetents([.medium])
            }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsDashboardView().environment(AppDataStore.shared)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCentreView()
            }
        }
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 14
        ) {
            kpiCard(icon: "car.fill",                  color: .blue,   label: "Vehicles",      value: "\(store.vehicles.count)")
            kpiCard(icon: "arrow.triangle.swap",       color: .green,  label: "Active Trips",  value: "\(store.activeTripsCount)")
            kpiCard(icon: "person.2.fill",             color: .orange, label: "Pending Staff", value: "\(store.pendingApplicationsCount)", badge: store.pendingApplicationsCount)
            kpiCard(icon: "exclamationmark.triangle.fill", color: .red, label: "Active Alerts", value: "\(store.activeEmergencyAlerts().count)", badge: store.activeEmergencyAlerts().count)
        }
    }

    private func kpiCard(icon: String, color: Color, label: String, value: String, badge: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                if badge > 0 {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Analytics Snapshot Card

    private var analyticsSnapshotCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAnalytics = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Fleet Analytics")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View Report")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                // Mini donuts
                HStack(spacing: 12) {
                    miniDonut(title: "Fleet",  total: store.vehicles.count,    slices: fleetSlices)
                    miniDonut(title: "Trips",  total: store.trips.count,       slices: tripSlices)
                    miniDonut(title: "Staff",  total: activeStaffCount,        slices: staffSlices)
                }

                // Sparkline - only show when there is data
                if !monthlyData.allSatisfy({ $0.count == 0 }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trip volume - last 6 months")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Chart(monthlyData) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Trips", item.count))
                                .foregroundStyle(.tint)
                                .cornerRadius(4)
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) }
                        }
                        .frame(height: 64)
                    }
                }

                // Doc health pills
                HStack(spacing: 8) {
                    docPill(icon: "checkmark.shield.fill",          count: validDocCount,    label: "Valid",    color: .green)
                    docPill(icon: "clock.badge.exclamationmark",    count: expiringDocCount, label: "Expiring", color: .orange)
                    docPill(icon: "xmark.shield.fill",              count: expiredDocCount,  label: "Expired",  color: .red)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.05)))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini Donut

    private func miniDonut(title: String, total: Int, slices: [(Double, Color)]) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if slices.isEmpty || !slices.allSatisfy({ $0.0.isFinite && $0.0 > 0 }) {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8).frame(width: 72, height: 72)
                } else {
                    Chart {
                        ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                            SectorMark(
                                angle: .value("v", max(slice.0, 0.0001)),
                                innerRadius: .ratio(0.65),
                                angularInset: 2
                            )
                            .foregroundStyle(LinearGradient(colors: [slice.1.opacity(0.9), slice.1], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(width: 72, height: 72)
                    .allowsHitTesting(false)
                    .rotationEffect(.degrees(-90))
                }
                Text("\(total)").font(.headline).foregroundStyle(.primary)
            }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Doc Pill

    private func docPill(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text("\(count) \(label)").font(.system(size: 12, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Data

    private var validDocCount:    Int { store.vehicleDocuments.filter { !$0.isExpiringSoon && !$0.isExpired }.count }
    private var expiringDocCount: Int { store.vehicleDocuments.filter { $0.isExpiringSoon && !$0.isExpired }.count }
    private var expiredDocCount:  Int { store.vehicleDocuments.filter { $0.isExpired }.count }
    private var activeStaffCount: Int { store.staff.filter { $0.status == .active }.count }

    private var fleetSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.vehicles.filter { $0.status == .active }.count),         .green),
            (Double(store.vehicles.filter { $0.status == .idle }.count),           .blue),
            (Double(store.vehicles.filter { $0.status == .inMaintenance }.count),  .orange),
            (Double(store.vehicles.filter { $0.status == .outOfService }.count),   .red)
        ]
        return s.filter { $0.0 > 0 }
    }

    private var tripSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.trips.filter { $0.status == .active }.count),    .green),
            (Double(store.trips.filter { $0.status == .scheduled }.count), .blue),
            (Double(store.trips.filter { $0.status == .completed }.count), Color.secondary),
            (Double(store.trips.filter { $0.status == .cancelled }.count), .red)
        ]
        return s.filter { $0.0 > 0 }
    }

    private var staffSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.staff.filter { $0.role == .driver && $0.status == .active }.count),              .blue),
            (Double(store.staff.filter { $0.role == .maintenancePersonnel && $0.status == .active }.count),.orange),
            (Double(store.staff.filter { $0.status == .pendingApproval }.count),                           .orange)
        ]
        return s.filter { $0.0 > 0 }
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
            return MonthlyTripData(month: formatter.string(from: monthStart),
                                   year:  calendar.component(.year, from: monthStart),
                                   count: count,
                                   date:  range.start)
        }
    }

    // MARK: - Recent Trips

    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recent Trips", icon: "clock")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            let trips = Array(store.trips.sorted { $0.createdAt > $1.createdAt }.prefix(5))

            if trips.isEmpty {
                emptyPlaceholder("No trips yet", icon: "arrow.triangle.swap")
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                        tripRow(trip)
                        if index < trips.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tripStatusColor(trip.status).opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: tripStatusIcon(trip.status))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tripStatusColor(trip.status))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(trip.taskId)
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(trip.status.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tripStatusColor(trip.status))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(tripStatusColor(trip.status).opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func tripStatusIcon(_ status: TripStatus) -> String {
        switch status {
        case .active:    return "arrow.triangle.swap"
        case .scheduled: return "clock"
        case .completed: return "checkmark"
        case .cancelled: return "xmark"
        }
    }

    private func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:    return .green
        case .scheduled: return .blue
        case .completed: return Color.secondary
        case .cancelled: return .red
        }
    }

    // MARK: - Expiring Documents

    private var expiringDocsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Expiring Documents", icon: "doc.badge.clock")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            let docs = store.documentsExpiringSoon()

            if docs.isEmpty {
                emptyPlaceholder("All documents are up to date", icon: "checkmark.shield.fill")
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                        docRow(doc)
                        if index < docs.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }

    private func docRow(_ doc: VehicleDocument) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((doc.isExpired ? Color.red : Color.orange).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: doc.isExpired ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(doc.isExpired ? .red : .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.documentType.rawValue)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Text("Expires \(doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.system(size: 13))
                    .foregroundStyle(doc.isExpired ? .red : .orange)
            }
            Spacer()
            Text(doc.isExpired ? "Expired" : "Soon")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(doc.isExpired ? .red : .orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((doc.isExpired ? Color.red : Color.orange).opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Fleet Management Section

    private var fleetManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FLEET MANAGEMENT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .kerning(1)
                .padding(.horizontal, 2)

            NavigationLink {
                MaintenanceRequestsView()
                    .environment(AppDataStore.shared)
            } label: {
                managementCard(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Maintenance",
                    subtitle: "\(store.maintenanceTasks.filter { $0.status == .pending }.count) pending tasks",
                    color: .orange
                )
            }

            Button { showReportsSheet = true } label: {
                managementCard(
                    icon: "chart.bar.fill",
                    title: "Reports & Analytics",
                    subtitle: "Fleet performance and exports",
                    color: .blue
                )
            }

            Button { showAlertsSheet = true } label: {
                managementCard(
                    icon: "bell.badge.fill",
                    title: "Alerts Inbox",
                    subtitle: "\(store.activeEmergencyAlerts().count) active alerts",
                    color: .red
                )
            }

            Button { showGeofencesSheet = true } label: {
                managementCard(
                    icon: "mappin.and.ellipse",
                    title: "Geofences",
                    subtitle: "\(store.geofences.filter { $0.isActive }.count) active zones",
                    color: .teal
                )
            }
        }
        .sheet(isPresented: $showReportsSheet) {
            NavigationStack {
                ReportsView()
                    .environment(AppDataStore.shared)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAlertsSheet) {
            NavigationStack {
                AlertsInboxView()
                    .environment(AppDataStore.shared)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showGeofencesSheet) {
            NavigationStack {
                GeofenceListView()
                    .environment(AppDataStore.shared)
            }
            .presentationDetents([.large])
        }
    }

    private func managementCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
        }
    }

    private func emptyPlaceholder(_ message: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.quaternary)
            Text(message).font(.system(size: 15)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    DashboardHomeView()
        .environment(AppDataStore.shared)
}
