import SwiftUI

struct AdminDashboardView: View {
    @Environment(AppDataStore.self) private var store
    @State private var searchText       = ""
    @State private var selectedTab      = 0
    @State private var lastContentTab   = 0
    @State private var isSearchPresented = false
    @State private var showQuickActions = false
    @State private var mapViewModel     = FleetLiveMapViewModel()
    /// Tracks which segment is active inside the Trips tab (0 = Live Map, 1 = Trips)
    @State private var tripsMapSegment: Int = 0

    @State private var showAlerts        = false
    @State private var showReports       = false
    @State private var showGeofences     = false
    @State private var showNotifications = false

    @State private var showCreateTrip        = false
    @State private var showAddVehicle        = false
    @State private var showCreateStaff       = false
    @State private var showCreateMaintenance = false
    @State private var vehiclesInitialSegmentMode: Int = 0
    @State private var vehiclesOpenMaintenanceTaskId: UUID?

    private var mapSearchMatches: [Vehicle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let indiaScoped = store.vehicles.filter { mapViewModel.coordinate(for: $0) != nil }
        guard !query.isEmpty else { return indiaScoped }
        return indiaScoped.filter { vehicle in
            vehicle.name.localizedCaseInsensitiveContains(query)
            || vehicle.licensePlate.localizedCaseInsensitiveContains(query)
            || vehicle.model.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 0) {
                DashboardHomeView()
            }

            Tab("Vehicles", systemImage: "car.fill", value: 1) {
                NavigationStack {
                    VehicleListView(
                        initialSegmentMode: vehiclesInitialSegmentMode,
                        initialMaintenanceTaskId: vehiclesOpenMaintenanceTaskId
                    )
                }
            }

            Tab("Staff", systemImage: "person.2.fill", value: 2) {
                StaffTabView()
            }
            .badge(store.pendingCount)

            Tab("Trips", systemImage: "arrow.triangle.swap", value: 3) {
                TripsAndMapContainerView(mapViewModel: mapViewModel,
                                         mapSegment: $tripsMapSegment)
            }

            // Search / Add tab
            Tab(value: 4, role: .search) {
                searchTabContent
            } label: {
                if lastContentTab == 0 {
                    Label("Add", systemImage: "plus")
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
        }
        .tint(SierraTheme.Colors.ember)
        .task {
            if store.vehicles.isEmpty || store.staff.isEmpty { await store.loadAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await store.loadAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sierraOpenVehicleMaintenance)) { note in
            let taskId: UUID? = {
                if let raw = note.userInfo?["taskId"] as? UUID { return raw }
                if let raw = note.userInfo?["taskId"] as? String { return UUID(uuidString: raw) }
                return nil
            }()
            vehiclesOpenMaintenanceTaskId = taskId
            vehiclesInitialSegmentMode = 1
            selectedTab = 1
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 4 && lastContentTab == 0 {
                showQuickActions = true
                selectedTab = 0
                isSearchPresented = false
            } else if newValue == 4 {
                // Trigger native search expansion when the Search tab is selected.
                isSearchPresented = true
            } else if newValue != 4 {
                lastContentTab = newValue
                searchText = ""
                isSearchPresented = false
            }
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet {
                destination in switch destination {
                case .alerts:        showAlerts        = true
                case .reports:       showReports       = true
                case .geofences:     showGeofences     = true
                case .notifications: showNotifications = true
                }
            } onCreation: { tag in
                switch tag {
                case "trip":        showCreateTrip        = true
                case "vehicle":     showAddVehicle        = true
                case "staff":       showCreateStaff       = true
                case "maintenance": showCreateMaintenance = true
                default: break
                }
            }
            .presentationDetents([.height(340)])
            .presentationBackground(Color(.systemBackground))
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAlerts) { NavigationStack { AlertsInboxView().environment(AppDataStore.shared) } }
        .sheet(isPresented: $showReports) { NavigationStack { ReportsView().environment(AppDataStore.shared) } }
        .sheet(isPresented: $showGeofences) { NavigationStack { GeofenceListView().environment(AppDataStore.shared) } }
        .sheet(isPresented: $showNotifications) { NotificationCentreView() }
        .sheet(isPresented: $showCreateTrip)        { CreateTripView().presentationDetents([.large]) }
        .sheet(isPresented: $showAddVehicle)        { AddVehicleView().presentationDetents([.large]) }
        .sheet(isPresented: $showCreateStaff)       { CreateStaffView().presentationDetents([.large]) }
        .sheet(isPresented: $showCreateMaintenance) { NavigationStack { MaintenanceRequestsView() }.presentationDetents([.large]) }
    }

    // MARK: - Search Tab Content
    //
    // Context-aware search:
    //   Tab 1 (Vehicles)  → vehicle search + list
    //   Tab 2 (Staff)     → staff search + list
    //   Tab 3, segment 0  → vehicle search (Live Map mode: search zooms map to vehicle)
    //   Tab 3, segment 1  → trip search + list
    @ViewBuilder
    private var searchTabContent: some View {
        switch lastContentTab {
        case 1:
            NavigationStack {
                VehicleListView(
                    initialSegmentMode: vehiclesInitialSegmentMode,
                    initialMaintenanceTaskId: vehiclesOpenMaintenanceTaskId
                )
            }
                .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search vehicles\u{2026}")

        case 2:
            NavigationStack {
                StaffTabView(
                    embedInParentNavigation: true,
                    externalSearchText: $searchText
                )
            }
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search staff\u{2026}")

        case 3:
            if tripsMapSegment == 0 {
                // Live Map segment — search and jump to selected vehicle on the map.
                NavigationStack {
                    List {
                        if mapSearchMatches.isEmpty {
                            ContentUnavailableView(
                                "No matching vehicles",
                                systemImage: "car.fill",
                                description: Text("Try a different name, plate, or model.")
                            )
                        } else {
                            ForEach(mapSearchMatches) { vehicle in
                                Button {
                                    mapViewModel.selectedVehicleId = vehicle.id
                                    selectedTab = 3
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "car.fill")
                                            .font(SierraFont.scaled(16, weight: .semibold))
                                            .frame(width: 32, height: 32)
                                            .background(Color.blue.opacity(0.12), in: Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(vehicle.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text("\(vehicle.licensePlate) · \(vehicle.model)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Find on Live Map")
                    .navigationBarTitleDisplayMode(.large)
                }
                .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Find vehicle on map…")
            } else {
                // Trips segment — trip list search
                NavigationStack {
                    TripsListView(
                        externalSearchText: $searchText,
                        usesInlineNavigationTitle: false
                    )
                }
                    .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search trips\u{2026}")
            }

        default:
            NavigationStack {
                VehicleListView(
                    initialSegmentMode: vehiclesInitialSegmentMode,
                    initialMaintenanceTaskId: vehiclesOpenMaintenanceTaskId
                )
            }
                .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search\u{2026}")
        }
    }
}

#Preview {
    AdminDashboardView()
        .environment(AppDataStore.shared)
}
