import SwiftUI

struct AdminDashboardView: View {
    @Environment(AppDataStore.self) private var store
    @State private var searchText       = ""
    @State private var selectedTab      = 0
    @State private var lastContentTab   = 0
    @State private var showQuickActions = false
    @State private var mapViewModel     = FleetLiveMapViewModel()

    // Navigation destinations triggered from QuickActionsSheet
    @State private var showAlerts        = false
    @State private var showReports       = false
    @State private var showGeofences     = false
    @State private var showNotifications = false

    // Creation sheets — hoisted from QuickActionsSheet to avoid dismiss race condition
    @State private var showCreateTrip        = false
    @State private var showAddVehicle        = false
    @State private var showCreateStaff       = false
    @State private var showCreateMaintenance = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 0) {
                DashboardHomeView()
            }

            Tab("Vehicles", systemImage: "car.fill", value: 1) {
                NavigationStack {
                    VehicleListView()
                }
            }

            Tab("Staff", systemImage: "person.2.fill", value: 2) {
                StaffTabView()
            }
            .badge(store.pendingCount)

            Tab("Trips", systemImage: "arrow.triangle.swap", value: 3) {
                TripsAndMapContainerView(mapViewModel: mapViewModel)
            }

            Tab(value: 4, role: .search) {
                switch lastContentTab {
                case 1:
                    NavigationStack {
                        VehicleListView()
                    }
                    .searchable(text: $searchText, prompt: "Search vehicles\u{2026}")
                case 2:
                    StaffTabView()
                        .searchable(text: $searchText, prompt: "Search staff\u{2026}")
                case 3:
                    NavigationStack {
                        TripsListView()
                    }
                    .searchable(text: $searchText, prompt: "Search trips\u{2026}")
                default:
                    NavigationStack {
                        VehicleListView()
                    }
                    .searchable(text: $searchText, prompt: "Search\u{2026}")
                }
            } label: {
                if lastContentTab == 0 {
                    Label("Add", systemImage: "plus")
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
        }
        .tint(.orange)
        // ── Data load on first appear ─────────────────────────────────────────
        .task {
            if store.vehicles.isEmpty || store.staff.isEmpty {
                await store.loadAll()
            }
        }
        // Refresh data whenever the app returns from background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await store.loadAll() }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 4 && lastContentTab == 0 {
                showQuickActions = true
                selectedTab = 0
            } else if newValue != 4 {
                lastContentTab = newValue
                searchText = ""
            }
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet { destination in
                switch destination {
                case .alerts:
                    showAlerts = true
                case .reports:
                    showReports = true
                case .geofences:
                    showGeofences = true
                case .notifications:
                    showNotifications = true
                }
            } onCreation: { tag in
                switch tag {
                case "trip":        showCreateTrip = true
                case "vehicle":     showAddVehicle = true
                case "staff":       showCreateStaff = true
                case "maintenance": showCreateMaintenance = true
                default: break
                }
            }
            .presentationDetents([.fraction(0.65)])
            .presentationDragIndicator(.visible)
        }
        // Navigation destinations from QuickActionsSheet — presented at root level
        .sheet(isPresented: $showAlerts) {
            NavigationStack {
                AlertsInboxView()
                    .environment(AppDataStore.shared)
            }
        }
        .sheet(isPresented: $showReports) {
            NavigationStack {
                ReportsView()
                    .environment(AppDataStore.shared)
            }
        }
        .sheet(isPresented: $showGeofences) {
            NavigationStack {
                GeofenceListView()
                    .environment(AppDataStore.shared)
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationCentreView()
        }
        // Creation sheets — attached at root, opened via onCreation callback
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateStaff) {
            CreateStaffView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateMaintenance) {
            NavigationStack {
                MaintenanceRequestsView()
            }
            .presentationDetents([.large])
        }
    }
}

#Preview {
    AdminDashboardView()
        .environment(AppDataStore.shared)
}
