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
    @State private var showCreateTrip = false
    @State private var tripsCreateTick = 0
    @State private var tripsSelectedStatus: TripStatus? = nil
    @State private var liveRefreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
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
            .safeAreaInset(edge: .top, spacing: 0) {
                topHeader
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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

    private var topHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Trip")
                    .font(.largeTitle.bold())

                Spacer()

                if mapSegment == 0 {
                    toolbarControlGroup(
                        leading: {
                            Button {
                                showCreateTrip = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(SierraFont.scaled(16, weight: .semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                        },
                        trailing: {
                            Menu {
                                ForEach(FleetLiveMapViewModel.VehicleFilter.allCases, id: \.self) { filter in
                                    Button {
                                        mapViewModel.selectedFilter = filter
                                    } label: {
                                        HStack {
                                            Text(filter.rawValue)
                                            if mapViewModel.selectedFilter == filter {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: mapViewModel.selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                    .font(SierraFont.scaled(16, weight: .semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    )
                } else {
                    toolbarControlGroup(
                        leading: {
                            Button {
                                tripsCreateTick += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(SierraFont.scaled(16, weight: .semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                        },
                        trailing: {
                            Menu {
                                Button {
                                    tripsSelectedStatus = nil
                                } label: {
                                    Label("All", systemImage: tripsSelectedStatus == nil ? "checkmark" : "")
                                }
                                Divider()
                                ForEach([TripStatus.pendingAcceptance, .scheduled, .active, .completed, .cancelled], id: \.self) { status in
                                    Button {
                                        tripsSelectedStatus = status
                                    } label: {
                                        Label(
                                            menuTripStatusLabel(status),
                                            systemImage: tripsSelectedStatus == status ? "checkmark" : ""
                                        )
                                    }
                                }
                            } label: {
                                Image(systemName: tripsSelectedStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                    .font(SierraFont.scaled(16, weight: .semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Picker("Trips Mode", selection: $mapSegment) {
                Text("Live Map").tag(0)
                Text("Trips").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
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

    private func toolbarControlGroup<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 0) {
            leading()
            Divider()
                .frame(height: 22)
                .overlay(Color.secondary.opacity(0.18))
                .padding(.vertical, 6)
            trailing()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private func menuTripStatusLabel(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "PendingAcceptance"
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
