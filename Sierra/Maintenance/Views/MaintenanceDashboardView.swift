import SwiftUI

/// Legacy compatibility screen.
///
/// This view used to host a dense nested-tab dashboard that no longer matches
/// Sierra's design language. It now forwards to the modern maintenance home
/// flow so any stale route still lands on the redesigned experience.
struct MaintenanceDashboardView: View {
    @Environment(AppDataStore.self) private var store

    var body: some View {
        NavigationStack {
            MaintenanceHomeView()
                .environment(store)
        }
    }
}

#Preview {
    MaintenanceDashboardView()
        .environment(AppDataStore.shared)
}
