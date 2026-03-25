import SwiftUI

/// Trips tab container: Live Map (segment 0) | Trips (segment 1)
/// Exposes `mapSegment` via a binding so AdminDashboardView can wire
/// the search tab to vehicle search or trip search based on which
/// segment is currently active.
struct TripsAndMapContainerView: View {
    let mapViewModel: FleetLiveMapViewModel
    /// Bound to AdminDashboardView so the search tab knows the active mode.
    @Binding var mapSegment: Int
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mapSegment == 0 {
                    headerRowForMap
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

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
        }
        .animation(.none, value: mapSegment)
        .refreshable {
            await AppDataStore.shared.loadAll()
            if mapSegment == 0 {
                await mapViewModel.refreshFallbackCoordinates(for: AppDataStore.shared.vehicles)
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
        }
    }

    private var headerRowForMap: some View {
        HStack(spacing: 10) {
            Text("Fleet Map")
                .font(.largeTitle.bold())

            Spacer()

            Button {
                showCreateTrip = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button {
                mapViewModel.showFilterPicker = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }
}

#Preview {
    TripsAndMapContainerView(mapViewModel: FleetLiveMapViewModel(), mapSegment: .constant(0))
        .environment(AppDataStore.shared)
}
