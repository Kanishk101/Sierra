import SwiftUI

/// Trips tab container: Live Map (segment 0) | Trips (segment 1)
/// Exposes `mapSegment` via a binding so AdminDashboardView can wire
/// the search tab to vehicle search or trip search based on which
/// segment is currently active.
struct TripsAndMapContainerView: View {
    @Environment(AppDataStore.self) private var store
    let mapViewModel: FleetLiveMapViewModel
    let embedInParentNavigation: Bool
    /// Bound to AdminDashboardView so the search tab knows the active mode.
    @Binding var mapSegment: Int
    @State private var showCreateTrip = false
    @State private var tripsCreateTick = 0
    @State private var tripsSelectedStatus: TripStatus? = nil
    @State private var liveRefreshTask: Task<Void, Never>?

    init(
        mapViewModel: FleetLiveMapViewModel,
        mapSegment: Binding<Int>,
        embedInParentNavigation: Bool = false
    ) {
        self.mapViewModel = mapViewModel
        self._mapSegment = mapSegment
        self.embedInParentNavigation = embedInParentNavigation
    }

    var body: some View {
        Group {
            if embedInParentNavigation {
                content
            } else {
                NavigationStack { content }
            }
        }
        .animation(.none, value: mapSegment)
        .task {
            await refreshAdminTripSurface()
            startLiveRefreshLoop()
        }
        .onDisappear {
            liveRefreshTask?.cancel()
            liveRefreshTask = nil
        }
        .onChange(of: mapSegment) { _, _ in
            Task { await refreshAdminTripSurface() }
        }
        .refreshable {
            await refreshAdminTripSurface()
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
        }
    }

    private var content: some View {
        Group {
            if mapSegment == 0 {
                FleetLiveMapView(viewModel: mapViewModel)
            } else {
                TripsListView(
                    embeddedInContainer: true,
                    externalCreateTick: tripsCreateTick,
                    externalSelectedStatus: $tripsSelectedStatus
                )
            }
        }
        .navigationTitle(mapSegment == 0 ? "Fleet Map" : "Trips")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top, spacing: 0) {
            topHeader
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if mapSegment == 0 {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Menu {
                        ForEach(FleetLiveMapViewModel.VehicleFilter.allCases, id: \.self) { filter in
                            Button {
                                mapViewModel.selectedFilter = filter
                            } label: {
                                SierraSelectionMenuRow(
                                    title: filter.rawValue,
                                    isSelected: mapViewModel.selectedFilter == filter
                                )
                            }
                        }
                    } label: {
                        Image(systemName: mapViewModel.selectedFilter == .all
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                    .tint(mapViewModel.selectedFilter == .all ? .primary : .orange)
                } else {
                    Button {
                        tripsCreateTick += 1
                    } label: {
                        Image(systemName: "plus")
                    }

                    Menu {
                        Button {
                            tripsSelectedStatus = nil
                        } label: {
                            SierraSelectionMenuRow(title: "All", isSelected: tripsSelectedStatus == nil)
                        }
                        Divider()
                        ForEach([TripStatus.pendingAcceptance, .scheduled, .active, .completed, .cancelled], id: \.self) { status in
                            Button {
                                tripsSelectedStatus = status
                            } label: {
                                SierraSelectionMenuRow(
                                    title: menuTripStatusLabel(status),
                                    isSelected: tripsSelectedStatus == status
                                )
                            }
                        }
                    } label: {
                        Image(systemName: tripsSelectedStatus == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                    .tint(tripsSelectedStatus == nil ? .primary : .orange)
                }
            }
        }
    }

    private var topHeader: some View {
        VStack(spacing: 0) {
            Picker("Trips Mode", selection: $mapSegment) {
                Text("Live Map").tag(0)
                Text("Trips").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func startLiveRefreshLoop() {
        liveRefreshTask?.cancel()
        liveRefreshTask = Task {
            while !Task.isCancelled {
                await refreshAdminTripSurface()
                try? await Task.sleep(nanoseconds: 7_000_000_000)
            }
        }
    }

    @MainActor
    private func refreshAdminTripSurface() async {
        await store.refreshAdminTripsLiveData()
        if mapSegment == 0 {
            await mapViewModel.refreshFallbackCoordinates(for: store.vehicles)
        }
    }

    private func menuTripStatusLabel(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "Pending Acceptance"
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }
}

#Preview {
    TripsAndMapContainerView(mapViewModel: FleetLiveMapViewModel(), mapSegment: .constant(0))
        .environment(AppDataStore.shared)
}
