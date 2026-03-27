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

        // Keep KPI counters responsive on first load.
        let duration = min(0.55, max(0.14, Double(delta) * 0.0035))
        let frames = max(12, Int(duration * 60))

        animationTask = Task { @MainActor in
            for frame in 1...frames {
                if Task.isCancelled { return }
                let progress = Double(frame) / Double(frames)
                displayedValue = startValue + Int((Double(value - startValue) * progress).rounded())
                try? await Task.sleep(for: .milliseconds(12))
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
    @State private var showReports = false
    @State private var showAskAI          = false
    @State private var quickModal: DashboardQuickModal?
    @State private var selectedTripId: UUID?
    @State private var selectedVehicleId: UUID?

    private enum DashboardQuickModal: String, Identifiable {
        case staff
        case trips
        case vehicles
        case alerts
        var id: String { rawValue }
    }

    private var vm: DashboardViewModel {
        viewModel ?? DashboardViewModel(store: store)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                        Spacer(minLength: 90)
                    }
                }
                .refreshable { await store.loadAll(force: true) }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .toolbarBackground(.hidden, for: .navigationBar)
                .sheet(isPresented: $showProfile) {
                    AdminProfileView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showAnalytics) {
                    AnalyticsDashboardView().environment(AppDataStore.shared)
                }
                .sheet(isPresented: $showNotifications) {
                    NotificationCentreView()
                }
                .sheet(isPresented: $showReports) {
                    NavigationStack {
                        ReportsView(initialPage: 0)
                            .environment(AppDataStore.shared)
                    }
                }
                .sheet(item: $quickModal) { modal in
                    switch modal {
                    case .staff:
                        NavigationStack { StaffTabView().environment(AppDataStore.shared) }
                    case .trips:
                        NavigationStack { TripsListView().environment(AppDataStore.shared) }
                    case .vehicles:
                        NavigationStack { VehicleListView().environment(AppDataStore.shared) }
                    case .alerts:
                        NavigationStack { AlertsInboxView().environment(AppDataStore.shared) }
                    }
                }
                .navigationDestination(item: $selectedTripId) { TripDetailView(tripId: $0) }
                .navigationDestination(item: $selectedVehicleId) { VehicleDetailView(vehicleId: $0) }
                .onAppear {
                    if viewModel == nil { viewModel = DashboardViewModel(store: store) }
                }

                AskAIFAB(isPresented: $showAskAI)
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                    .sheet(isPresented: $showAskAI) {
                        AskAIChatView()
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                    }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Dashboard")
                .font(.largeTitle.bold())

            Spacer()

            HStack(spacing: 0) {
                Button {
                    showNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(SierraFont.scaled(15, weight: .semibold))
                            .frame(width: 36, height: 32)
                        if store.unreadNotificationCount > 0 {
                            Text("\(min(store.unreadNotificationCount, 9))")
                                .font(SierraFont.scaled(9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .accessibilityLabel("Notifications")

                Divider()
                    .frame(height: 20)
                    .padding(.vertical, 6)

                Button {
                    showReports = true
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(SierraFont.scaled(15, weight: .semibold))
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("Reports")

                Divider()
                    .frame(height: 20)
                    .padding(.vertical, 6)

                Button {
                    showProfile = true
                } label: {
                    Text(adminInitials)
                        .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("Profile")
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
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
            kpiCard(
                icon: "person.2.fill",
                color: .orange,
                label: "Staff",
                value: store.staff.count,
                badge: vm.pendingApplicationsCount
            ) { quickModal = .staff }
            kpiCard(
                icon: "arrow.triangle.swap",
                color: .green,
                label: "Trips",
                value: store.trips.count
            ) { quickModal = .trips }
            kpiCard(
                icon: "car.fill",
                color: .blue,
                label: "Vehicles",
                value: vm.vehicleCount
            ) { quickModal = .vehicles }
            kpiCard(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                label: "Alerts",
                value: vm.activeAlertsCount,
                badge: vm.activeAlertsCount
            ) { quickModal = .alerts }
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
                        .font(SierraFont.scaled(15, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    if badge > 0 {
                        Image(systemName: "circle.fill").font(SierraFont.scaled(10)).foregroundStyle(.orange)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    AnimatedCounterView(
                        target: value,
                        color: .primary,
                        font: .system(size: 24, weight: .bold, design: .rounded)
                    )
                    Text(label).font(SierraFont.scaled(13)).foregroundStyle(.secondary)
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
                    Text("Fleet Analytics")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View Report").font(.subheadline).foregroundStyle(.orange)
                        Image(systemName: "chevron.right").font(SierraFont.scaled(11, weight: .semibold)).foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 12) {
                    miniDonut(title: "Fleet", total: vm.vehicleCount, slices: vm.fleetSlices)
                    miniDonut(title: "Trips", total: store.trips.count, slices: vm.tripSlices)
                    miniDonut(title: "Staff", total: vm.activeStaffCount, slices: vm.staffSlices)
                }
                if !vm.monthlyData.allSatisfy({ $0.count == 0 }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trip volume - last 6 months").font(SierraFont.scaled(12)).foregroundStyle(.secondary)
                        Chart(vm.monthlyData) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Trips", item.count))
                                .foregroundStyle(.tint).cornerRadius(4)
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis { AxisMarks { AxisValueLabel().font(SierraFont.scaled(10)).foregroundStyle(Color.secondary) } }
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
            Image(systemName: icon).font(SierraFont.scaled(11, weight: .medium)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text("\(count) \(label)").font(SierraFont.scaled(12, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Trips
    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recent Trips").padding(.horizontal, 20).padding(.bottom, 8)
            let trips = vm.recentTrips
            if trips.isEmpty {
                emptyPlaceholder("No trips yet", icon: "arrow.triangle.swap").padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                        tripRow(trip)
                        if index < trips.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        let status = trip.status.normalized
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(SierraFont.scaled(16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(trip.taskId)
                    .font(SierraFont.scaled(13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(tripStatusLabel(status))
                .font(SierraFont.scaled(12, weight: .semibold))
                .foregroundStyle(tripStatusColor(status))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(tripStatusColor(status).opacity(0.12), in: Capsule())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { selectedTripId = trip.id }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(trip.origin) to \(trip.destination)")
        .accessibilityValue(tripStatusLabel(status))
        .accessibilityHint("Opens trip details")
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

    private func tripStatusLabel(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "Pending Acceptance"
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        case .accepted: return "Accepted"
        case .rejected, .cancelled: return "Cancelled"
        }
    }

    // MARK: - Expiring Documents
    private var expiringDocsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Expiring Documents").padding(.horizontal, 20).padding(.bottom, 8)
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
                    .font(SierraFont.scaled(14, weight: .medium))
                    .foregroundStyle(doc.isExpired ? .red : .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.documentType.rawValue).font(SierraFont.scaled(15, weight: .semibold)).foregroundStyle(.primary)
                Text("Expires \(doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(SierraFont.scaled(13)).foregroundStyle(doc.isExpired ? .red : .orange)
            }
            Spacer()
            Text(doc.isExpired ? "Expired" : "Soon")
                .font(SierraFont.scaled(12, weight: .semibold)).foregroundStyle(doc.isExpired ? .red : .orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((doc.isExpired ? Color.red : Color.orange).opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { selectedVehicleId = doc.vehicleId }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(doc.documentType.rawValue) document")
        .accessibilityValue(doc.isExpired ? "Expired" : "Expiring soon")
        .accessibilityHint("Opens vehicle details")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SierraFont.scaled(20, weight: .bold))
            .foregroundStyle(.primary)
    }

    private func emptyPlaceholder(_ message: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(SierraFont.scaled(20)).foregroundStyle(.quaternary)
            Text(message).font(SierraFont.scaled(15)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview { DashboardHomeView().environment(AppDataStore.shared) }
