import SwiftUI

// MARK: - DashboardHomeView
// Fleet manager overview: KPI cards + recent trips + expiring docs.

struct DashboardHomeView: View {

    @Environment(AppDataStore.self) private var store
    @State private var showProfile   = false
    @State private var showAnalytics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting hero card
                    greetingCard
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)

                    // KPI Grid
                    kpiGrid
                        .padding(.horizontal, Spacing.lg)

                    // Recent Trips
                    recentTripsSection
                        .padding(.horizontal, Spacing.lg)

                    // Expiring Documents
                    expiringDocsSection
                        .padding(.horizontal, Spacing.lg)

                    Spacer(minLength: 32)
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAnalytics = true
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(SierraFont.body(17, weight: .semibold))
                            .foregroundStyle(SierraTheme.Colors.ember)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        SierraAvatarView(initials: "FA", size: 34, gradient: SierraAvatarView.admin())
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                AdminProfileView()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsDashboardView()
                    .environment(AppDataStore.shared)
            }
            .onAppear {
                print("[DashboardHomeView] Appeared — vehicles: \(store.vehicles.count), trips: \(store.trips.count), staff: \(store.staff.count)")
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Greeting
    // ─────────────────────────────────────────────────────────────

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("\(greeting), Admin")
                .font(SierraFont.title1)
                .foregroundStyle(.white)
            Text(dateString)
                .font(SierraFont.bodyText)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - KPI Grid
    // ─────────────────────────────────────────────────────────────

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
            kpiCard(
                icon: "car.fill",
                color: SierraTheme.Colors.sierraBlue,
                label: "Total Vehicles",
                value: "\(store.vehicles.count)"
            )
            kpiCard(
                icon: "arrow.triangle.swap",
                color: SierraTheme.Colors.alpineMint,
                label: "Active Trips",
                value: "\(store.activeTripsCount)"
            )
            kpiCard(
                icon: "person.2.fill",
                color: SierraTheme.Colors.ember,
                label: "Pending Staff",
                value: "\(store.pendingApplicationsCount)",
                badgeCount: store.pendingApplicationsCount
            )
            kpiCard(
                icon: "exclamationmark.triangle.fill",
                color: SierraTheme.Colors.danger,
                label: "Active Alerts",
                value: "\(store.activeEmergencyAlerts().count)",
                badgeCount: store.activeEmergencyAlerts().count
            )
        }
    }

    private func kpiCard(
        icon: String,
        color: Color,
        label: String,
        value: String,
        badgeCount: Int = 0
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer()

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(SierraFont.body(10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(SierraTheme.Colors.danger, in: Capsule())
                }
            }

            Text(value)
                .font(SierraFont.body(28, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(SierraFont.caption2)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Recent Trips
    // ─────────────────────────────────────────────────────────────

    private var recentTrips: [Trip] {
        Array(store.trips.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Recent Trips", icon: "clock")

            if recentTrips.isEmpty {
                emptyPlaceholder("No trips yet", icon: "arrow.triangle.swap")
            } else {
                ForEach(recentTrips) { trip in
                    tripRow(trip)
                }
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(statusColor(trip.status).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.triangle.swap")
                        .font(SierraFont.caption2)
                        .foregroundStyle(statusColor(trip.status))
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(SierraFont.body(14, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(trip.taskId)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(SierraTheme.Colors.granite)
            }

            Spacer()

            Text(trip.status.rawValue)
                .font(SierraFont.body(11, weight: .bold))
                .foregroundStyle(statusColor(trip.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(trip.status).opacity(0.1), in: Capsule())
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:    return .green
        case .scheduled: return SierraTheme.Colors.sierraBlue
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Expiring Documents
    // ─────────────────────────────────────────────────────────────

    private var expiringDocsSection: some View {
        let docs = store.documentsExpiringSoon()
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Expiring Documents", icon: "doc.badge.clock")

            if docs.isEmpty {
                emptyPlaceholder("All documents are up to date", icon: "checkmark.shield")
            } else {
                ForEach(docs) { doc in
                    docRow(doc)
                }
            }
        }
    }

    private func docRow(_ doc: VehicleDocument) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: doc.isExpired ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundStyle(doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.warning)
                .frame(width: 36, height: 36)
                .background(
                    (doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.warning).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(doc.documentType.rawValue)
                    .font(SierraFont.body(14, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                Text("Expires \(doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(SierraFont.caption2)
                    .foregroundStyle(doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.warning)
            }

            Spacer()

            Text(doc.isExpired ? "Expired" : "Expiring")
                .font(SierraFont.body(11, weight: .bold))
                .foregroundStyle(doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.warning).opacity(0.1),
                    in: Capsule()
                )
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.ember)
            Text(title)
                .font(SierraFont.headline)
                .foregroundStyle(SierraTheme.Colors.primaryText)
        }
    }

    private func emptyPlaceholder(_ message: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(SierraTheme.Colors.granite)
            Text(message)
                .font(SierraFont.body(14, weight: .medium))
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    DashboardHomeView()
        .environment(AppDataStore.shared)
}
