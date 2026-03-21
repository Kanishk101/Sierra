# Phase 01 — Critical Bug Fixes (Must Ship Before Any UI Work)

## Context & Architecture
- **Project:** Sierra FMS — iOS 17+ SwiftUI, MVVM, `@Observable` (no `@Published` anywhere), Swift Concurrency
- **Backend:** Supabase (PostgreSQL). No RLS enforced. All business logic in Swift layer.
- **Repo:** `Kanishk101/Sierra` · Branch: `main`
- **Pattern:** `AppDataStore` is the single source of truth. Every service call that mutates state must also update the in-memory array in `AppDataStore`.

---

## Bug 1 — `SparePartsRequest.workOrderId` is non-optional → crashes the entire `sparePartsRequests` array decode

### Root Cause
In `Sierra/Shared/Models/SparePartsRequest.swift`, the field `workOrderId` is declared as `UUID` (non-optional). In the Supabase schema, `work_order_id` is `uuid NULLABLE`. When Supabase returns any row that has `work_order_id = NULL` (which happens whenever a spare parts request is filed before a work order exists for the task), the Codable decoder throws `keyNotFound` and the entire `[SparePartsRequest]` array fails to decode — returning empty for the whole session.

This means:
- `loadMaintenanceData` silently returns `sparePartsRequests = []` every time a NULL `work_order_id` row exists
- `loadAll` for the fleet manager also returns empty
- `AppDataStore.addSparePartsRequest()` cannot construct the model with `workOrderId: UUID` when the caller doesn't yet have a work order

### Fix in `Sierra/Shared/Models/SparePartsRequest.swift`
Change line:
```swift
var workOrderId: UUID
```
To:
```swift
var workOrderId: UUID?          // work_order_id (nullable — may not exist until work order is created)
```

Also update `AppDataStore.addSparePartsRequest()` — the service layer call already uses `workOrderId?.uuidString` so the service is already correct. The model fix is the only change needed.

---

## Bug 2 — `ContentView.swift` still routes Fleet Manager to `AdminDashboardView()` — 4 implemented features completely unreachable

### Root Cause
`ContentView.destinationView(for:)` has:
```swift
case .fleetManagerDashboard: AdminDashboardView()
```

`AdminDashboardView` is a 5-tab view (Dashboard, Vehicles, Staff, Trips, Search/Add). It has NO Maintenance tab and NO Reports tab. `FleetManagerTabView.swift` (9-tab) is fully implemented and was never wired.

This means the following fully-implemented views are **completely unreachable** from the Fleet Manager login:
- `MaintenanceRequestsView` (Spare Parts approval, maintenance task approval, history)
- `ReportsView` (CSV export, analytics)
- `GeofenceListView`
- `AlertsInboxView`

### CRITICAL CONSTRAINT — DO NOT CHANGE THE TAB BAR STRUCTURE
Kanishk explicitly wants **`AdminDashboardView`** to remain as the root — NOT `FleetManagerTabView`. The `AdminDashboardView` 5-tab structure (Dashboard, Vehicles, Staff, Trips, Search/Add) must stay **exactly as-is**. The missing features (Maintenance, Reports, Geofences, Alerts) must be surfaced **inside the existing 5 tabs** via the `QuickActionsSheet` and `DashboardHomeView`, not by adding new tabs.

Specifically:
- **DO NOT** change `ContentView.swift` to use `FleetManagerTabView()`
- **DO NOT** add more tabs to `AdminDashboardView`
- The `FleetManagerTabView.swift` file can remain in the project but is dead code

The correct fix is to wire `MaintenanceRequestsView`, `ReportsView`, `GeofenceListView`, and `AlertsInboxView` into the existing `AdminDashboardView` through the Dashboard tab's `DashboardHomeView` and the `QuickActionsSheet`. This is covered in Phase 05 and Phase 06.

---

## Bug 3 — `FuelLogViewModel.submit()` bypasses `AppDataStore` → in-memory `store.fuelLogs` never updated

### Root Cause
In `Sierra/Driver/ViewModels/FuelLogViewModel.swift`, the `submit()` method calls:
```swift
try await FuelLogService.addFuelLog(log)   // direct service call
```

This writes to Supabase but never appends to `AppDataStore.shared.fuelLogs`. So immediately after a driver logs fuel:
- The fuel log count on the home screen stays stale
- Any view that reads `store.fuelLogs` shows outdated data until next session reload
- The trip detail view shows 0 fuel logs even after logging

### Fix in `Sierra/Driver/ViewModels/FuelLogViewModel.swift`
In the `submit()` method, replace:
```swift
try await FuelLogService.addFuelLog(log)
submitSuccess = true
```
With:
```swift
try await AppDataStore.shared.addFuelLog(log)
submitSuccess = true
```

`AppDataStore.addFuelLog()` already calls `FuelLogService.addFuelLog()` AND appends to the in-memory array. No duplication.

---

## Bug 4 — `RouteDeviationService.recordDeviation` notifies the DRIVER about their own deviation, not the fleet manager

### Root Cause
In `Sierra/Shared/Services/RouteDeviationService.swift`, the notification step is:
```swift
try await NotificationService.insertNotification(
    recipientId: driverId,   // ← driver receives their own deviation alert
    type: .routeDeviation,
    ...
)
```

The comment even says `"placeholder — caller can replace with admin IDs"` but it was never replaced. Fleet managers never receive route deviation notifications in real-time. The deviation events ARE recorded correctly in `route_deviation_events` and shown in `AnalyticsDashboardView`, but there is no push to the fleet manager.

### Fix in `Sierra/Shared/Services/RouteDeviationService.swift`
Replace the notification block with a version that fetches all fleet manager IDs and inserts a notification for each. Since we have no RLS and Supabase is a pure data store:

```swift
// 3. Notify ALL fleet managers (non-fatal)
do {
    let fmRows: [StaffMemberDB] = try await supabase
        .from("staff_members")
        .select("id")
        .eq("role", value: "fleetManager")
        .eq("status", value: "Active")
        .execute()
        .value
    for fm in fmRows {
        try await NotificationService.insertNotification(
            recipientId: fm.id,
            type: .routeDeviation,
            title: "Route Deviation Detected",
            body: "A driver deviated \(Int(deviationMetres))m from the planned route on trip \(tripId.uuidString.prefix(8)).",
            entityType: "trip",
            entityId: tripId
        )
    }
} catch {
    print("[RouteDeviationService] Non-fatal: failed to notify fleet managers: \(error)")
}
```

Note: `StaffMemberDB` is the existing decodable struct in `StaffMemberService.swift`. Use it or define a minimal local struct:
```swift
struct FMIdRow: Decodable { let id: UUID }
```

---

## Verification Checklist

After applying all four fixes, verify:
- [ ] A spare parts request with `work_order_id = NULL` in DB decodes correctly; `store.sparePartsRequests` is non-empty
- [ ] Fleet Manager login still lands on `AdminDashboardView` with 5 tabs — no structure change
- [ ] Driver logs fuel → `store.fuelLogs` array updated immediately without session reload
- [ ] Route deviation recorded → fleet manager receives notification, driver does NOT receive their own deviation alert
- [ ] Build compiles with zero warnings and zero errors
- [ ] No `@Published` added anywhere
