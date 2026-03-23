import SwiftUI

/// Trips tab container: Live Map (segment 0) | Trips (segment 1)
/// Exposes `mapSegment` via a binding so AdminDashboardView can wire
/// the search tab to vehicle search or trip search based on which
/// segment is currently active.
struct TripsAndMapContainerView: View {
    @Environment(AppDataStore.self) private var store

    let mapViewModel: FleetLiveMapViewModel
    /// Bound to AdminDashboardView so the search tab knows the active mode.
    @Binding var mapSegment: Int
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mapSegment) {
                    Text("Live Map").tag(0)
                    Text("Trips").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                if mapSegment == 0 {
                    FleetLiveMapView(viewModel: mapViewModel)
                } else {
                    TripsListView()
                }
            }
            .navigationTitle(mapSegment == 0 ? "Fleet Map" : "Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mapSegment == 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNotifications = true } label: {
                            Image(systemName: "bell.fill")
                                .overlay(alignment: .topTrailing) {
                                    if store.unreadNotificationCount > 0 {
                                        Circle().fill(.red).frame(width: 8, height: 8).offset(x: 4, y: -4)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .animation(.none, value: mapSegment)
        .sheet(isPresented: $showNotifications) { NotificationCentreView() }
    }
}

#Preview {
    TripsAndMapContainerView(mapViewModel: FleetLiveMapViewModel(), mapSegment: .constant(0))
        .environment(AppDataStore.shared)
}
