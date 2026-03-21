# Phase 01 — Critical Bug Fixes (Must Ship Before Any UI Work)

## Context & Architecture
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable` (no `@Published` anywhere), Swift Concurrency
- **Backend:** Supabase (PostgreSQL). No RLS enforced. All business logic in Swift layer.
- **Repo:** `Kanishk101/Sierra` · Branch: `main`
- **Pattern:** `AppDataStore` is the single source of truth. Every service call that mutates state must also update the in-memory array in `AppDataStore`.

---

## ABSOLUTE ARCHITECTURAL RULE — READ BEFORE TOUCHING ANYTHING

`AdminDashboardView` is the fleet manager root. Full stop.

The current `AdminDashboardView` has exactly 5 tabs in this exact order:
1. **Dashboard** — `DashboardHomeView()`
2. **Vehicles** — `VehicleListView()`
3. **Staff** — `StaffTabView()` + pending badge
4. **Trips** — `TripsAndMapContainerView(mapViewModel:)`
5. **Search/Add** — contextual search + `QuickActionsSheet`

This structure is **correct, final, and must not be changed**. Do not:
- Add tabs
- Remove tabs
- Reorder tabs
- Change tab icons or labels
- Add a "More" tab or any overflow mechanism
- Route the fleet manager to `FleetManagerTabView` instead

`FleetManagerTabView.swift` exists in `Sierra/FleetManager/FleetManagerTabView.swift` and contains a 9-tab version of the fleet manager dashboard. This file is **entirely dead code**. It must be **deleted** as part of this phase. The features it contained (Maintenance, Reports, Geofences, Alerts, Live Map, Settings) are already implemented as standalone views — they just need to be wired into `AdminDashboardView`'s existing structure, which is handled in Phase 05 and Phase 06.

**DO NOT** change `ContentView.swift`. The routing line:
```swift
case .fleetManagerDashboard: AdminDashboardView()
```
is already correct. Leave it alone.

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

The service layer call already uses `workOrderId?.uuidString` so it is already correct. The model fix is the only change needed.

---

## Bug 2 — Delete `FleetManagerTabView.swift`

`Sierra/FleetManager/FleetManagerTabView.swift` is dead code. It is never referenced by `ContentView`, never presented, and never navigated to. Its entire 9-tab implementation is superseded by `AdminDashboardView` plus the individual feature views (`MaintenanceRequestsView`, `ReportsView`, etc.) that already exist and are wired in Phase 05/06.

**Action:** Delete `Sierra/FleetManager/FleetManagerTabView.swift` from the repository entirely.

Do NOT leave it as dead code. Dead code creates confusion for collaborators and for Claude when it reads the project.

After deletion, verify that no other file imports or references `FleetManagerTabView`. Run:
```
grep -r "FleetManagerTabView" Sierra/
```
The result should be empty. If any reference still exists, remove it.

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
Replace the notification block:

```swift
// 3. Notify ALL fleet managers (non-fatal)
do {
    struct FMIdRow: Decodable { let id: UUID }
    let fmRows: [FMIdRow] = try await supabase
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

---

## Verification Checklist

- [ ] `FleetManagerTabView.swift` deleted; `grep -r "FleetManagerTabView" Sierra/` returns empty
- [ ] A spare parts request with `work_order_id = NULL` in DB decodes correctly; `store.sparePartsRequests` is non-empty
- [ ] Fleet Manager login lands on `AdminDashboardView` — still 5 tabs, no structural change
- [ ] Driver logs fuel → `store.fuelLogs` array updated immediately without session reload
- [ ] Route deviation → fleet manager receives notification; driver does NOT receive their own deviation alert
- [ ] Build compiles with zero warnings and zero errors
- [ ] No `@Published` added anywhere
