# Phase: Fleet Manager TabView Wiring

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main

## Problem
ContentView currently routes `.fleetManagerDashboard` to `AdminDashboardView()`, which
has only 5 tabs (Dashboard, Vehicles, Staff, Trips+Map, Search/Add).

`FleetManagerTabView.swift` already exists and is fully built with 9 tabs:
Dashboard, Live Map, Alerts, Vehicles, Drivers, Maintenance, Reports, Geofences, Settings.
It is never called from ContentView — it is dead.

Missing from the currently shown admin UI:
- Standalone Live Map tab (FleetLiveMapView)
- Alerts Inbox tab (AlertsInboxView)
- Maintenance Requests tab (MaintenanceRequestsView)
- Reports tab (ReportsView)
- Geofences tab (GeofenceListView)
- Settings/Sign-Out tab

## Scope
Change ONLY ContentView.swift.

```swift
// ContentView.swift — destinationView(for:)
case .fleetManagerDashboard: FleetManagerTabView()
```

That single line replaces `AdminDashboardView()`. No other file should be touched.

## Constraints
- Do NOT modify FleetManagerTabView.swift — it is already complete.
- Do NOT modify AdminDashboardView.swift — it remains in the project but just won't be the root.
- Do NOT add environment objects or inject AppDataStore; FleetManagerTabView already has `@Environment(AppDataStore.self)`.
- Do NOT change any appearance, colours, or layouts.

## Verification
- Build compiles without warnings.
- Logging in as a fleet manager shows 9 tabs not 5.
- All 9 tabs navigate to their respective views without crashes.
- Signing out from the Settings tab works.
