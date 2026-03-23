import SwiftUI

/// Trips tab container: Live Map (segment 0) | Trips (segment 1)
/// Exposes `mapSegment` via a binding so AdminDashboardView can wire
/// the search tab to vehicle search or trip search based on which
/// segment is currently active.
struct TripsAndMapContainerView: View {
    let mapViewModel: FleetLiveMapViewModel
    /// Bound to AdminDashboardView so the search tab knows the active mode.
    @Binding var mapSegment: Int

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
        }
        .animation(.none, value: mapSegment)
    }
}

#Preview {
    TripsAndMapContainerView(mapViewModel: FleetLiveMapViewModel(), mapSegment: .constant(0))
        .environment(AppDataStore.shared)
}
