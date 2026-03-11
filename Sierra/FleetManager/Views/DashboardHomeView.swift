import SwiftUI

private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
private let navyDark = Color(hex: "0D1B2A")
private let navyMid = Color(hex: "1B3A6B")

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
                VStack(spacing: 20) {
                    greetingCard
                    statsGrid
                    alertsSection
                    recentActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "F2F3F7").ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        initialsCircle("FA", size: 34, bg: accentOrange)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("\(greeting), Admin")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Text(dateString)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(colors: [navyDark, navyMid], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let vehicles = store.vehicles
        let staff = store.staff
        let activeCount = vehicles.filter { $0.status == .active }.count
        let pending = vehicles.filter { $0.status == .inMaintenance }.count
        let staffCount = staff.count

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            statCard(value: "\(vehicles.count)", label: "Total Vehicles", icon: "car.fill", tint: .blue)
            statCard(value: "\(activeCount)", label: "Active Trips", icon: "location.fill", tint: .green)
            statCard(value: "\(pending)", label: "Pending Maint.", icon: "wrench.fill", tint: accentOrange)
            statCard(value: "\(staffCount)", label: "Staff Count", icon: "person.2.fill", tint: .purple)
        }
    }

    private func statCard(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
                Spacer()
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(navyDark)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        let expiring = store.vehicles.filter { $0.documentsExpiringSoon }
        return Group {
            if !expiring.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Document Alerts", icon: "exclamationmark.triangle.fill", tint: .orange)
                    ForEach(expiring) { v in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.clock.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(navyDark)
                                Text("\(v.licensePlate) · Documents expiring soon")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Activity", icon: "clock.fill", tint: navyMid)
            ForEach(activity) { log in
                HStack(spacing: 12) {
                    typeBadge(log.type)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(navyDark)
                            .lineLimit(2)
                        Text(log.timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(navyDark)
        }
        .padding(.top, 4)
    }

    private func typeBadge(_ type: ActivityType) -> some View {
        let (icon, color): (String, Color) = switch type {
        case .trip:        ("location.fill", .blue)
        case .maintenance: ("wrench.fill", .orange)
        case .fuel:        ("fuelpump.fill", .green)
        case .staff:       ("person.fill", .purple)
        case .alert:       ("exclamationmark.triangle.fill", .red)
        }
        return Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
