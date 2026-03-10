import SwiftUI

struct FleetManagerTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
                placeholderTab(title: "Fleet Dashboard", icon: "chart.bar.fill", color: .blue)
            }
            Tab("Vehicles", systemImage: "car.fill") {
                placeholderTab(title: "Vehicles", icon: "car.2.fill", color: .green)
            }
            Tab("Drivers", systemImage: "person.2.fill") {
                placeholderTab(title: "Drivers", icon: "person.2.fill", color: .orange)
            }
            Tab("Reports", systemImage: "doc.text.fill") {
                placeholderTab(title: "Reports", icon: "chart.pie.fill", color: .purple)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                settingsTab()
            }
        }
        .tint(.white)
    }

    private func placeholderTab(title: String, icon: String, color: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(color.opacity(0.8))

                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("Coming soon")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func settingsTab() -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
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
                    .font(.system(size: 24, weight: .bold))
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
