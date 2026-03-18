# PhaseMap3 - Admin Dashboard + Drivers Tab + Fleet Map Breadcrumb

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
AppDataStore is @MainActor @Observable. Staff array is named "staff". No @Published wrappers.

## Read these files first — mandatory
- Sierra/FleetManager/FleetManagerTabView.swift
- Sierra/FleetManager/Views/DashboardHomeView.swift
- Sierra/FleetManager/Views/FleetLiveMapView.swift
- Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift
- Sierra/FleetManager/Views/VehicleMapDetailSheet.swift
- Sierra/FleetManager/Views/StaffTabView.swift (if it exists)
- Sierra/FleetManager/Views/StaffListView.swift

## Task 1 — Wire DashboardHomeView into FleetManagerTabView

Read FleetManagerTabView.swift. The Dashboard tab currently shows a placeholder.
Read DashboardHomeView.swift — it has real implementation and should be used instead.

In FleetManagerTabView, replace the Dashboard tab content:
  Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
    NavigationStack {
      DashboardHomeView()
    }
  }

Remove the placeholderTab call for Dashboard entirely.

## Task 2 — Wire Live Data into DashboardHomeView

Read DashboardHomeView.swift. Check which stats are hardcoded or use mock data.
For each stat, replace with computed values from AppDataStore (via @Environment(AppDataStore.self)):

  Active Vehicles:
    store.vehicles.filter { $0.status == .busy || $0.status == .active }.count

  Active Trips:
    store.trips.filter { $0.status == .active }.count

  Pending Approvals (combined):
    store.staffApplications.filter { $0.status == .pending }.count
    + store.maintenanceTasks.filter { $0.status == .pending }.count

  Available Drivers:
    store.staff.filter { $0.role == .driver && $0.status == .active && $0.availability == .available }.count

  Overdue Maintenance:
    store.maintenanceTasks.filter { $0.status == .pending && $0.dueDate < Date() }.count

  Unread Alerts: store.emergencyAlerts.filter { $0.status == .active }.count

  Recent Activity: use store.activityLogs.prefix(10), already sorted by timestamp

All computed from AppDataStore in-memory arrays. ZERO new Supabase queries.

Also add a notification bell toolbar button to DashboardHomeView:
  .toolbar {
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        showNotifications = true
      } label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "bell.fill")
          if store.unreadNotificationCount > 0 {
            Text("\(min(store.unreadNotificationCount, 9))")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 16, height: 16)
              .background(.red, in: Circle())
              .offset(x: 8, y: -8)
          }
        }
      }
    }
  }
  @State private var showNotifications = false
  .sheet(isPresented: $showNotifications) { NotificationCentreView() }

## Task 3 — Wire Drivers Tab into FleetManagerTabView

Read FleetManagerTabView.swift. The Drivers tab shows a placeholder.
Read Sierra/FleetManager/Views/StaffListView.swift or StaffTabView.swift — check which exists
and has the driver management UI.

Replace the Drivers placeholder with whichever staff management view exists:
  Tab("Drivers", systemImage: "person.2.fill") {
    NavigationStack {
      StaffTabView()  // or StaffListView() — use whichever has the real implementation
    }
  }

If StaffTabView wraps StaffListView, use StaffTabView. Read both files to determine the right one.

## Task 4 — Admin Fleet Map: Breadcrumb on Vehicle Tap

Read VehicleMapDetailSheet.swift and FleetLiveMapViewModel.swift.

VehicleMapDetailSheet is presented when an admin taps a vehicle annotation.
It should trigger the breadcrumb fetch for that vehicle's active trip.

In VehicleMapDetailSheet, find the place where the sheet appears (onAppear or init).
Call the viewModel.fetchBreadcrumb if the vehicle has an active trip:

The sheet needs access to FleetLiveMapViewModel. It currently has a dismiss callback.
Add a parameter: viewModel: FleetLiveMapViewModel

Then add in VehicleMapDetailSheet.onAppear:
  .onAppear {
    // Find active trip for this vehicle
    if let tripIdStr = AppDataStore.shared.trips.first(where: {
      $0.vehicleId == vehicle.id.uuidString && $0.status == .active
    })?.id {
      Task { await viewModel.fetchBreadcrumb(vehicleId: vehicle.id, tripId: tripIdStr) }
    }
  }

In FleetLiveMapView.swift where VehicleMapDetailSheet is presented, pass the viewModel:
  VehicleMapDetailSheet(vehicle: vehicle, viewModel: viewModel) {
    viewModel.showVehicleDetail = false
  }

Check VehicleMapDetailSheet.swift for its exact current init signature before modifying.
If it already accepts a viewModel parameter, verify the breadcrumb call is there.
If not, add the parameter and the onAppear call.

Also in VehicleMapDetailSheet, show the trip info for active trips:
- If vehicle has an active trip (status .active or .busy), show:
  - Trip task ID
  - Origin and destination
  - Driver name (lookup from AppDataStore.staff)
  - Speed (coordinator.currentSpeedKmh — but this is on driver side, not available here)
  - A "View Full Trip" NavigationLink to TripDetailView

## Task 5 — FleetManagerTabView: Notification Bell in Toolbar

Read FleetManagerTabView.swift. The showNotifications state variable exists but the bell icon
may not be surfaced in a tab bar context (tab bars don't have toolbars).

Add the notification bell to the Dashboard tab's NavigationStack toolbar (done in Task 2 above).
Also add to the Live Map tab:
  Tab("Live Map", systemImage: "map.fill") {
    NavigationStack {
      FleetLiveMapView(viewModel: mapViewModel)
        .toolbar {
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

The showNotifications sheet is already in FleetManagerTabView. It can be triggered from any tab.

## Rules
- Read every file before modifying — do not assume structure
- All stats computed from AppDataStore in-memory, zero new Supabase queries
- VehicleMapDetailSheet init signature must be read before adding viewModel parameter
- StaffTabView or StaffListView — read both to determine which is the correct entry point
- Nothing existing is removed or changed, only additions and replacements of placeholder code

## Output
Update FleetManagerTabView.swift, DashboardHomeView.swift, VehicleMapDetailSheet.swift,
FleetLiveMapView.swift. Commit all to main branch.
