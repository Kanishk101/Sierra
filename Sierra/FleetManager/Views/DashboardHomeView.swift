import SwiftUI

struct DashboardHomeView: View {
    @Environment(AppDataStore.self) private var store
    @State private var showProfile = false

    private let activity = ActivityLog.samples

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    greetingCard
                    statsGrid
                    alertsSection
                    recentActivitySection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxl)
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        }
    }

    // MARK: - Greeting Card

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

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let vehicles = store.vehicles
        let staff = store.staff
        let activeCount = vehicles.filter { $0.status == .active }.count
        let pending = vehicles.filter { $0.status == .inMaintenance }.count

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)], spacing: Spacing.md) {
            StatCardView.vehicles(count: vehicles.count)
            StatCardView.active(count: activeCount)
            StatCardView(
                label: "Maintenance",
                value: "\(pending)",
                accentColor: SierraTheme.Colors.warning,
                icon: "wrench.fill"
            )
            StatCardView.pending(count: staff.count)
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        let expiring = store.documentsExpiringSoon(withinDays: 30)
        // Group by vehicle for display
        let vehicleIds = Set(expiring.compactMap { $0.vehicleId })
        let expiringVehicles = vehicleIds.compactMap { store.vehicle(for: $0) }
        return Group {
            if !expiringVehicles.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    sectionHeader("Document Alerts", icon: "exclamationmark.triangle.fill", tint: SierraTheme.Colors.warning)
                    ForEach(expiringVehicles) { v in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "doc.badge.clock.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(SierraTheme.Colors.warning)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name)
                                    .sierraStyle(.cardTitle)
                                Text("\(v.licensePlate) · Documents expiring soon")
                                    .sierraStyle(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(SierraFont.caption2)
                                .foregroundStyle(SierraTheme.Colors.granite)
                        }
                        .padding(Spacing.md)
                        .background(
                            SierraTheme.Colors.warning.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .strokeBorder(SierraTheme.Colors.warning.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Recent Activity", icon: "clock.fill", tint: SierraTheme.Colors.sierraBlue)
            ForEach(activity) { log in
                HStack(spacing: Spacing.sm) {
                    typeBadge(log.type)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.description)
                            .font(SierraFont.subheadline)
                            .foregroundStyle(SierraTheme.Colors.primaryText)
                            .lineLimit(2)
                        Text(log.timeAgo)
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.granite)
                    }
                    Spacer()
                }
                .padding(Spacing.md)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .sierraShadow(SierraTheme.Shadow.card)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(tint)
            Text(title)
                .font(SierraFont.headline)
                .foregroundStyle(SierraTheme.Colors.primaryText)
        }
        .padding(.top, Spacing.xxs)
    }

    private func typeBadge(_ type: ActivityType) -> some View {
        let (icon, color): (String, Color) = switch type {
        case .tripStarted, .tripCompleted, .tripCancelled, .vehicleAssigned, .inspectionFailed:
            ("location.fill", SierraTheme.Colors.info)
        case .maintenanceRequested, .maintenanceCompleted:
            ("wrench.fill", SierraTheme.Colors.warning)
        case .fuelLogged:
            ("fuelpump.fill", SierraTheme.Colors.alpineMint)
        case .staffApproved, .staffRejected:
            ("person.fill", SierraTheme.Colors.sierraBlue)
        case .emergencyAlert, .geofenceViolation:
            ("exclamationmark.triangle.fill", SierraTheme.Colors.danger)
        case .documentExpiringSoon, .documentExpired:
            ("doc.badge.clock.fill", SierraTheme.Colors.warning)
        }
        return Image(systemName: icon)
            .font(SierraFont.caption1)
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

func initialsCircle(_ text: String, size: CGFloat, bg: Color) -> some View {
    Text(text)
        .font(.system(size: size * 0.38, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(bg, in: Circle())
}

#Preview {
    DashboardHomeView()
}
