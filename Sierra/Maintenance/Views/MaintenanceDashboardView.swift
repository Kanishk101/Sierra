import SwiftUI


struct MaintenanceDashboardView: View {
    @State private var selectedTab: MaintenanceTab = .tasks

    enum MaintenanceTab: Int, CaseIterable {
        case tasks, workOrders, vinScanner, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            comingSoonTab(icon: "wrench.and.screwdriver.fill", title: "Tasks", subtitle: "Assigned maintenance tasks will appear here.")
                .tag(MaintenanceTab.tasks)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Tasks")
                }

            comingSoonTab(icon: "doc.text.fill", title: "Work Orders", subtitle: "Your work orders and repair logs will be managed here.")
                .tag(MaintenanceTab.workOrders)
                .tabItem {
                    Image(systemName: "doc.plaintext.fill")
                    Text("Work Orders")
                }

            comingSoonTab(icon: "barcode.viewfinder", title: "VIN Scanner", subtitle: "Scan vehicle VIN barcodes for quick lookup.")
                .tag(MaintenanceTab.vinScanner)
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("VIN Scanner")
                }

            profileTab
                .tag(MaintenanceTab.profile)
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
        }
        .tint(SierraTheme.Colors.ember)
    }

    // MARK: - Coming Soon

    private func comingSoonTab(icon: String, title: String, subtitle: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(SierraTheme.Colors.ember.opacity(0.5))

                Text(title)
                    .font(SierraFont.title3)
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                Text(subtitle)
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)

                Text("Coming Soon")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(SierraTheme.Colors.ember.opacity(0.1), in: Capsule())

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Profile Tab

    private var profileTab: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Avatar
                let user = AuthManager.shared.currentUser
                let initials = (user?.name ?? "M").prefix(2).uppercased()

                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.summitNavy)
                        .frame(width: 80, height: 80)
                    Text(initials)
                        .font(SierraFont.title1)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text(user?.name ?? "Maintenance Staff")
                        .font(SierraFont.title3)
                        .foregroundStyle(SierraTheme.Colors.primaryText)

                    Text(user?.email ?? "")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.secondary)
                }

                // Role badge
                HStack(spacing: 6) {
                    Image(systemName: "wrench.fill")
                        .font(SierraFont.caption2)
                    Text("Maintenance Personnel")
                        .font(SierraFont.caption1)
                }
                .foregroundStyle(SierraTheme.Colors.granite)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(SierraTheme.Colors.sierraBlue.opacity(0.06), in: Capsule())

                // Approval status
                HStack(spacing: 8) {
                    Image(systemName: user?.isApproved == true ? "checkmark.seal.fill" : "clock.fill")
                        .font(SierraFont.bodyText)
                        .foregroundStyle(user?.isApproved == true ? .green : SierraTheme.Colors.warning)
                    Text(user?.isApproved == true ? "Approved" : "Pending Approval")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                .padding(.horizontal, 24)

                Spacer()

                // Sign out
                Button {
                    AuthManager.shared.signOut()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(SierraFont.caption1)
                        Text("Sign Out")
                            .font(SierraFont.subheadline)
                    }
                    .foregroundStyle(SierraTheme.Colors.danger.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MaintenanceDashboardView()
}
