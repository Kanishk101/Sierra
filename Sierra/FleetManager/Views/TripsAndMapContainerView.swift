import SwiftUI

struct TripsAndMapContainerView: View {
    @Environment(AppDataStore.self) private var store

    let mapViewModel: FleetLiveMapViewModel
    @State private var segment: Int = 0
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Live Map").tag(0)
                    Text("Trips").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                if segment == 0 {
                    FleetLiveMapView(viewModel: mapViewModel)
                } else {
                    TripsListView()
                }
            }
            .navigationTitle(segment == 0 ? "Fleet Map" : "Trips")
            .toolbar {
                if segment == 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNotifications = true } label: {
                            Image(systemName: "bell.fill")
                                .overlay(alignment: .topTrailing) {
                                    if store.unreadNotificationCount > 0 {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .animation(.none, value: segment)
        .sheet(isPresented: $showNotifications) {
            NotificationCentreView()
        }
    }
}

#Preview {
    TripsAndMapContainerView(mapViewModel: FleetLiveMapViewModel())
        .environment(AppDataStore.shared)
}
