import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab: Int = 0
    @State private var showQuickActions = false
    private var store = StaffApplicationStore.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // Tab 1: Dashboard
                DashboardHomeView()
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(0)

                // Tab 2: Vehicles
                NavigationStack {
                    VehicleListView()
                }
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
                .tag(1)

                // Tab 3: Staff
                StaffTabView()
                    .tabItem {
                        Label("Staff", systemImage: "person.2.fill")
                    }
                    .tag(2)
                    .badge(store.pendingCount)

                // Tab 4: Trips
                NavigationStack {
                    TripsListView()
                }
                .tabItem {
                    Label("Trips", systemImage: "arrow.triangle.swap")
                }
                .tag(3)
            }
            .tint(SierraTheme.Colors.ember)

            // Floating Action Button — bottom right, above tab bar
            Button {
                showQuickActions = true
            } label: {
                Image(systemName: "plus")
                    .font(SierraFont.title3)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        SierraTheme.Colors.ember,
                        in: Circle()
                    )
                    .shadow(color: SierraTheme.Colors.ember.opacity(0.35), radius: 10, y: 5)
            }
            .padding(.trailing, Spacing.lg)
            .padding(.bottom, 72) // above the tab bar
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet()
                .presentationDetents([.fraction(0.45)])
        }
    }
}

#Preview {
    AdminDashboardView()
}
