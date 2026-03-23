import SwiftUI
import Charts

// MARK: - AnimatedCounterView
// Smoothly counts from 0 to target value on first appear.
struct AnimatedCounterView: View {
    let target: Int
    let color: Color
    let font: Font

    @State private var displayedValue: Int = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text("\(displayedValue)")
            .font(font)
            .foregroundStyle(color)
            .onAppear { animateTo(target) }
            .onChange(of: target) { _, newValue in animateTo(newValue) }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private func animateTo(_ value: Int) {
        guard value != displayedValue else { return }
        animationTask?.cancel()
        let startValue = displayedValue
        let delta = abs(value - startValue)

        // Fast count-up/down that settles within ~0.45s...1.8s based on distance.
        let duration = min(1.8, max(0.45, Double(delta) * 0.012))
        let frames = max(12, Int(duration * 60))

        animationTask = Task { @MainActor in
            for frame in 1...frames {
                if Task.isCancelled { return }
                let progress = Double(frame) / Double(frames)
                displayedValue = startValue + Int((Double(value - startValue) * progress).rounded())
                try? await Task.sleep(for: .milliseconds(16))
            }
            displayedValue = value
        }
    }
}

// MARK: - DashboardHomeView
struct DashboardHomeView: View {

    @Environment(AppDataStore.self) private var store
    @State private var viewModel: DashboardViewModel?
    @State private var showProfile       = false
    @State private var showAnalytics     = false
    @State private var showNotifications = false
    @State private var showReportsSheet   = false
    @State private var showAlertsSheet    = false
    @State private var showStaffTab          = false
    @State private var showAlertsFromKPI     = false
    @State private var showMaintenanceFromKPI = false
    @State private var showDriversFromKPI    = false

    private var vm: DashboardViewModel {
        viewModel ?? DashboardViewModel(store: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerRow
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    kpiGrid
                        .padding(.horizontal, 20)

                    if vm.isLoading {
                        loadingSkeleton.padding(.horizontal, 20)
                    } else {
                        analyticsSnapshotCard.padding(.horizontal, 20)
                    }

                    recentTripsSection
                    expiringDocsSection
                    fleetManagementSection.padding(.horizontal, 20)
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                AdminProfileView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsDashboardView().environment(AppDataStore.shared)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCentreView()
            }
            .sheet(isPresented: $showStaffTab) {
                NavigationStack { StaffTabView().environment(AppDataStore.shared) }
            }
            .sheet(isPresented: $showAlertsFromKPI) {
                NavigationStack { AlertsInboxView().environment(AppDataStore.shared) }
            }
            .sheet(isPresented: $showMaintenanceFromKPI) {
                NavigationStack { MaintenanceRequestsView().environment(AppDataStore.shared) }
            }
            .onAppear {
                if viewModel == nil { viewModel = DashboardViewModel(store: store) }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Dashboard")
                .font(.largeTitle.bold())

            Spacer()

            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.body.weight(.semibold))
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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button { showProfile = true } label: {
                Text(adminInitials)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private var adminInitials: String {
        let name = AuthManager.shared.currentUser?.name ?? "FM"
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Loading Skeleton
    private var loadingSkeleton: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill)).frame(height: 72)
                }
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill)).frame(height: 64)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(ProgressView("Loading fleet data...").tint(.orange).font(.caption))
        .frame(minHeight: 200)
    }

    // MARK: - KPI Grid
    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            kpiCard(icon: "car.fill", color: .blue, label: "Vehicles", value: vm.vehicleCount) { showStaffTab = false }
            kpiCard(icon: "arrow.triangle.swap", color: .green, label: "Active Trips", value: vm.activeTripsCount) {}
            kpiCard(icon: "person.2.fill", color: .orange, label: "Pending Staff", value: vm.pendingApplicationsCount, badge: vm.pendingApplicationsCount) { showStaffTab = true }
            kpiCard(icon: "exclamationmark.triangle.fill", color: .red, label: "Active Alerts", value: vm.activeAlertsCount, badge: vm.activeAlertsCount) { showAlertsFromKPI = true }
            kpiCard(icon: "wrench.fill", color: .purple, label: "In Maintenance", value: vm.inMaintenanceCount) { showMaintenanceFromKPI = true }
            kpiCard(icon: "person.fill.checkmark", color: .teal, label: "Available Drivers", value: vm.availableDriversCount) {}
        }
    }

    private func kpiCard(icon: String, color: Color, label: String, value: Int, badge: Int = 0, onTap: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    if badge > 0 {
                        Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    AnimatedCounterView(
                        target: value,
                        color: .primary,
                        font: .system(size: 24, weight: .bold, design: .rounded)
                    )
                    Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Analytics Snapshot Card
    private var analyticsSnapshotCard: some View {
        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showAnalytics = true } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.pie.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.orange)
                        Text("Fleet Analytics").font(.headline).foregroundStyle(.primary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View Report").font(.subheadline).foregroundStyle(.orange)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 12) {
                    miniDonut(title: "Fleet", total: vm.vehicleCount, slices: vm.fleetSlices)
                    miniDonut(title: "Trips", total: store.trips.count, slices: vm.tripSlices)
                    miniDonut(title: "Staff", total: vm.activeStaffCount, slices: vm.staffSlices)
                }
                if !vm.monthlyData.allSatisfy({ $0.count == 0 }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trip volume - last 6 months").font(.system(size: 12)).foregroundStyle(.secondary)
                        Chart(vm.monthlyData) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Trips", item.count))
                                .foregroundStyle(.tint).cornerRadius(4)
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis { AxisMarks { AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary) } }
                        .frame(height: 64)
                    }
                }
                HStack(spacing: 8) {
                    docPill(icon: "checkmark.shield.fill", count: vm.validDocCount, label: "Valid", color: .green)
                    docPill(icon: "clock.badge.exclamationmark", count: vm.expiringDocCount, label: "Expiring", color: .orange)
                    docPill(icon: "xmark.shield.fill", count: vm.expiredDocCount, label: "Expired", color: .red)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.05)))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func miniDonut(title: String, total: Int, slices: [(Double, Color)]) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if slices.isEmpty || !slices.allSatisfy({ $0.0.isFinite && $0.0 > 0 }) {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8).frame(width: 72, height: 72)
                } else {
                    Chart {
                        ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                            SectorMark(angle: .value("v", max(slice.0, 0.0001)), innerRadius: .ratio(0.65), angularInset: 2)
                                .foregroundStyle(LinearGradient(colors: [slice.1.opacity(0.9), slice.1], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(width: 72, height: 72)
                    .allowsHitTesting(false)
                    .rotationEffect(.degrees(-90))
                }
                AnimatedCounterView(target: total, color: .primary, font: .headline)
            }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func docPill(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text("\(count) \(label)").font(.system(size: 12, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Trips
    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recent Trips", icon: "clock").padding(.horizontal, 20).padding(.bottom, 8)
            let trips = vm.recentTrips
            if trips.isEmpty {
                emptyPlaceholder("No trips yet", icon: "arrow.triangle.swap").padding(.horizontal, 20)
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
                Image(systemName: tripStatusIcon(trip.status)).font(.system(size: 14, weight: .medium)).foregroundStyle(tripStatusColor(trip.status))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin) \u{2192} \(trip.destination)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(trip.taskId).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(trip.status.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium)).foregroundStyle(tripStatusColor(trip.status))
                .padding(.horizontal, 8).padding(.vertical, 4).background(tripStatusColor(trip.status).opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func tripStatusIcon(_ status: TripStatus) -> String {
        switch status {
        case .active: return "arrow.triangle.swap"
        case .scheduled: return "clock"
        case .pendingAcceptance: return "hourglass"
        case .accepted: return "checkmark.circle"
        case .completed: return "checkmark"
        case .rejected: return "xmark.circle"
        case .cancelled: return "xmark"
        }
    }
    private func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active: return .green
        case .scheduled: return .blue
        case .pendingAcceptance: return .orange
        case .accepted: return .teal
        case .completed: return Color.secondary
        case .rejected, .cancelled: return .red
        }
    }

    // MARK: - Expiring Documents
    private var expiringDocsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Expiring Documents", icon: "doc.badge.clock").padding(.horizontal, 20).padding(.bottom, 8)
            let docs = vm.expiringDocs
            if docs.isEmpty {
                emptyPlaceholder("All documents are up to date", icon: "checkmark.shield.fill").padding(.horizontal, 20)
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
                Text(doc.documentType.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Text("Expires \(doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.system(size: 13)).foregroundStyle(doc.isExpired ? .red : .orange)
            }
            Spacer()
            Text(doc.isExpired ? "Expired" : "Soon")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(doc.isExpired ? .red : .orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((doc.isExpired ? Color.red : Color.orange).opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Fleet Management (no geofence create — view-only via list)
    private var fleetManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FLEET MANAGEMENT").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1).padding(.horizontal, 2)

            NavigationLink {
                MaintenanceRequestsView().environment(AppDataStore.shared)
            } label: {
                managementCard(icon: "wrench.and.screwdriver.fill", title: "Maintenance", subtitle: "\(vm.pendingMaintenanceCount) pending tasks", color: .orange)
            }

            Button { showReportsSheet = true } label: {
                managementCard(icon: "chart.bar.fill", title: "Reports & Analytics", subtitle: "Fleet performance and exports", color: .blue)
            }

            Button { showAlertsSheet = true } label: {
                managementCard(icon: "bell.badge.fill", title: "Alerts Inbox", subtitle: "\(vm.activeAlertsCount) active alerts", color: .red)
            }
        }
        .sheet(isPresented: $showReportsSheet) {
            NavigationStack { ReportsView().environment(AppDataStore.shared) }.presentationDetents([.large])
        }
        .sheet(isPresented: $showAlertsSheet) {
            NavigationStack { AlertsInboxView().environment(AppDataStore.shared) }.presentationDetents([.large])
        }
    }

    private func managementCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
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

#Preview { DashboardHomeView().environment(AppDataStore.shared) }
