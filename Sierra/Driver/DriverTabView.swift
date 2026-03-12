import SwiftUI

struct DriverTabView: View {

    @Environment(AppDataStore.self) private var store

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    DriverHomeView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailView(tripId: id)
                        }
                }
            }
            Tab("Trips", systemImage: "map.fill") {
                placeholderTab(title: "My Trips", icon: "location.fill", color: .green)
            }
            Tab("Vehicle", systemImage: "car.fill") {
                placeholderTab(title: "Inspection", icon: "checklist", color: SierraTheme.Colors.warning)
            }
            Tab("Profile", systemImage: "person.fill") {
                settingsTab()
            }
        }
        .tint(.white)
    }

    private func placeholderTab(title: String, icon: String, color: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(color.opacity(0.8))

                Text(title)
                    .font(SierraFont.title2)
                    .foregroundStyle(.white)

                Text("Coming Soon")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
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
                    .font(SierraFont.title2)
                    .foregroundStyle(.white)

                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(SierraFont.body(17, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.danger)
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
