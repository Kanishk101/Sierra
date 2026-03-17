import SwiftUI

struct FleetManagerTabView: View {
    // Safeguard 1: ViewModel persisted at TabView level so map survives tab switches
    @State private var mapViewModel = FleetLiveMapViewModel()
    @State private var showNotifications = false
    @Environment(AppDataStore.self) private var store

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
                placeholderTab(title: "Fleet Dashboard", icon: "chart.bar.fill", color: .orange)
            }
            Tab("Live Map", systemImage: "map.fill") {
                NavigationStack {
                    FleetLiveMapView(viewModel: mapViewModel)
                }
            }
            Tab("Alerts", systemImage: "bell.badge.fill") {
                NavigationStack {
                    AlertsInboxView()
                }
            }
            Tab("Vehicles", systemImage: "car.fill") {
                NavigationStack {
                    VehicleStatusView()
                }
            }
            Tab("Drivers", systemImage: "person.2.fill") {
                placeholderTab(title: "Drivers", icon: "person.2.fill", color: .orange)
            }
            Tab("Maintenance", systemImage: "wrench.and.screwdriver.fill") {
                NavigationStack {
                    MaintenanceRequestsView()
                }
            }
            Tab("Reports", systemImage: "doc.text.fill") {
                ReportsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                settingsTab()
            }
        }
        .tint(.white)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await store.checkOverdueMaintenance() }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationCentreView()
        }
    }

    private func placeholderTab(title: String, icon: String, color: Color) -> some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(color)

                Text(title)
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsTab() -> some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Settings")
                    .font(.title2)
                    .foregroundStyle(.white)

                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

#Preview {
    FleetManagerTabView()
}
