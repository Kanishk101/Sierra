import SwiftUI

struct DriverTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var showNotifications = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    DriverHomeView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                notificationBell
                            }
                        }
                }
            }
            Tab("Trips", systemImage: "map.fill") {
                NavigationStack {
                    DriverTripHistoryView()
                }
            }
            Tab("Vehicle", systemImage: "car.fill") {
                placeholderTab(title: "Inspection", icon: "checklist", color: .orange)
            }
            Tab("Profile", systemImage: "person.fill") {
                settingsTab()
            }
        }
        .tint(.white)
        .sheet(isPresented: $showNotifications) {
            NotificationCentreView()
        }
    }

    private var notificationBell: some View {
        Button { showNotifications = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                if store.unreadNotificationCount > 0 {
                    Text("\(store.unreadNotificationCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.red, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
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

                Text("Coming Soon")
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
                Image(systemName: "person.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Profile")
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
    DriverTabView()
        .environment(AppDataStore.shared)
}
