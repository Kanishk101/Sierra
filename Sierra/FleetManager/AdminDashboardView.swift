import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

struct AdminDashboardView: View {
    @State private var selectedTab: AdminTab = .dashboard
    @State private var showQuickActions = false
    private var store = StaffApplicationStore.shared

    enum AdminTab: Int, CaseIterable {
        case dashboard, vehicles, quickAction, staff, trips
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            Group {
                switch selectedTab {
                case .dashboard:   DashboardHomeView()
                case .vehicles:    NavigationStack { VehicleListView() }
                case .staff:       PendingApprovalsView()
                case .trips:       NavigationStack { TripsListView() }
                case .quickAction: DashboardHomeView() // never shown, intercepted
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            customTabBar
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet()
                .presentationDetents([.fraction(0.45)])
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(.dashboard, icon: "square.grid.2x2.fill", label: "Dashboard")
            tabBarItem(.vehicles, icon: "car.fill", label: "Vehicles")
            centerPlusButton
            tabBarItem(.staff, icon: "person.2.fill", label: "Staff", badgeCount: store.pendingCount)
            tabBarItem(.trips, icon: "arrow.triangle.swap", label: "Trips")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarItem(_ tab: AdminTab, icon: String, label: String, badgeCount: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .symbolRenderingMode(.monochrome)

                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(.red, in: Circle())
                            .offset(x: 8, y: -6)
                    }
                }

                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? navyDark : Color(hex: "A0A0A8"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerPlusButton: some View {
        Button {
            showQuickActions = true
        } label: {
            ZStack {
                Circle()
                    .fill(accentOrange)
                    .frame(width: 48, height: 48)
                    .shadow(color: accentOrange.opacity(0.35), radius: 8, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: -12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AdminDashboardView()
}
