# Sierra — Sprint 2 Implementation Plan

> Deadline: March 22, 2026  
> Each step is a discrete coding session. Complete steps in order — later steps depend on earlier ones.

---

## ✅ STEP 1 — Supabase Fixes
**Status: DONE**

- Added RLS policies to 5 blocked tables (`vehicle_location_history`, `route_deviation_events`, `notifications`, `spare_parts_requests`, `trip_expenses`)
- Fixed broken `staff_members` DELETE policy (was using `auth.role() = 'authenticated'` which never matched — silently blocked all fleet manager staff deletions)
- Fixed mutable `search_path` on 4 trigger functions (`handle_trip_started`, `handle_trip_completed`, `handle_trip_cancelled`, `check_resource_overlap`)
- Added 38 FK indexes on high-traffic Sprint 2 tables

---

## STEP 2 — Auth Bug Fixes
**Files to touch:** `ForcePasswordChangeView.swift`, `AuthManager.swift`

- [ ] **Bug 1:** Remove `generateOTP()` call from `ForcePasswordChangeView` — 2FA incorrectly appears during forced password change for new staff
- [ ] **Bug 2:** Fix Face ID not appearing after sign-out — `signOut()` clears the session token but `hasSessionToken()` check fails on re-launch; restore biometric prompt independently of session token

---

## STEP 3 — `TripViewModel.swift` (Core — everything gates on this)
**New file:** `Sierra/Driver/ViewModels/TripViewModel.swift`

- [ ] `@Observable final class TripViewModel`
- [ ] `var activeTrip: Trip?` — single source of truth for active trip state
- [ ] `var isNavigating: Bool`
- [ ] `startTrip(_ trip: Trip) async throws` — calls `TripService.startTrip()`, does NOT touch vehicle status (DB trigger handles it)
- [ ] `endTrip(tripId:, endMileage:) async throws` — calls `TripService.endTrip()`, does NOT touch vehicle status
- [ ] `publishLocation(lat:, lng:, tripId:, driverId:, vehicleId:) async` — inserts to `vehicle_location_history` with **5-second throttle** enforced internally
- [ ] `private var lastPublishTime: Date?` + `shouldPublish() -> Bool` throttle guard
- [ ] Verify `VehicleLocationService.swift` also throttles correctly (it's only 2.85 KB — likely missing the guard)

---

## STEP 4 — Wire `StartTripSheet` → `TripViewModel`
**Files to touch:** `StartTripSheet.swift`, `DriverHomeView.swift`

- [ ] Inject `TripViewModel` into `StartTripSheet`
- [ ] Add odometer entry field (`OdometerEntryView` inline or as a separate sheet) — populates `trip.start_mileage`
- [ ] On confirm: call `TripViewModel.startTrip(trip)` → navigate to `TripNavigationContainerView`
- [ ] Gate: pre-trip inspection must be completed before `startTrip()` is callable

---

## STEP 5 — Pre-Trip Inspection Alert Wiring
**Files to touch:** `PreTripInspectionViewModel.swift`

- [ ] After `submitInspection()`, check result
- [ ] If `result == .failed` or `result == .passedWithWarnings` → call `EmergencyAlertService.createAlert(type: .defect, ...)` to notify Fleet Manager
- [ ] Alert must include `tripId`, `vehicleId`, `driverId`, description of failed items
- [ ] Figma explicitly shows: Pre-Trip Inspection → Issue Found? → YES → Send alert to Fleet Manager

---

## STEP 6 — `PostTripInspectionViewModel.swift`
**New file:** `Sierra/Driver/ViewModels/PostTripInspectionViewModel.swift`

- [ ] Submit post-trip inspection to `vehicle_inspections` table
- [ ] If `result == .failed` → create `MaintenanceTask` (raise maintenance request) + call `TripViewModel.endTrip()`
- [ ] If `result == .passed` → call `TripViewModel.endTrip()` only (DB trigger auto-sets vehicle to available)
- [ ] Do NOT manually update vehicle status — `handle_trip_completed` trigger handles it
- [ ] Wire to `PostTripInspectionView`

---

## STEP 7 — `EndTripView.swift`
**New file:** `Sierra/Driver/Views/EndTripView.swift`

- [ ] End mileage input field
- [ ] Summary of trip (distance, duration, origin → destination)
- [ ] Calls `TripViewModel.endTrip(tripId:, endMileage:)`
- [ ] On success → navigate to `DriverTripHistoryView` (Figma: End the trip → View Previous Trips)

---

## STEP 8 — `ProofOfDeliveryViewModel.swift`
**New file:** `Sierra/Driver/ViewModels/ProofOfDeliveryViewModel.swift`

- [ ] `submitDelivery() async throws`
- [ ] Photo uploads must be **sequential** (not concurrent — not `async let`, not `TaskGroup`)
- [ ] OTP stored as **hash only** — `CryptoService.hash(otp)` — never plaintext
- [ ] Signature upload
- [ ] Insert to `proof_of_deliveries` table, then update `trips.proof_of_delivery_id`
- [ ] Wire to `ProofOfDeliveryView.swift`

---

## STEP 9 — `SOSAlertViewModel.swift`
**New file:** `Sierra/Driver/ViewModels/SOSAlertViewModel.swift`

- [ ] Capture current GPS coordinates via `CoreLocation`
- [ ] `submitSOS(type: EmergencyAlertType, description: String) async throws`
- [ ] Insert to `emergency_alerts` table with `driver_id`, `trip_id`, `vehicle_id`, lat/lng
- [ ] Insert to `notifications` table for Fleet Manager recipient
- [ ] Wire to `SOSAlertSheet.swift`
- [ ] SOS and Defect buttons must be accessible mid-navigation from `NavigationHUDOverlay`

---

## STEP 10 — Fuel Log UI
**New files:** `Sierra/Driver/Views/FuelLogEntryView.swift`, `Sierra/Driver/ViewModels/FuelLogViewModel.swift`

- [ ] Fields: fuel type, quantity (litres), cost, receipt photo upload, odometer at fill
- [ ] `FuelLogViewModel.submitLog() async throws` → insert to `fuel_logs` table
- [ ] Also handle toll receipts (`trip_expenses` table, `expense_type = .toll`)
- [ ] Accessible from `NavigationHUDOverlay` or `TripDetailDriverView` during active trip

---

## STEP 11 — Driver Trip History (un-stub)
**Files to touch:** `DriverTripHistoryView.swift`  
**New file:** `Sierra/Driver/ViewModels/DriverTripHistoryViewModel.swift`

- [ ] Load trips where `driver_id = currentUser.id` ordered by `scheduled_date DESC`
- [ ] Show status badge (Completed, Cancelled, Active)
- [ ] Tap → `TripDetailDriverView`
- [ ] Empty state when no trips
- [ ] Wire post-trip navigation here from `EndTripView`

---

## STEP 12 — Route Deviation — Driver Side
**Files to touch:** `TripNavigationCoordinator.swift`, `RouteDeviationService.swift`  
**New file:** `Sierra/Driver/Views/RouteDeviationAlertView.swift`

- [ ] During active navigation, compare current GPS position against `trips.route_polyline`
- [ ] If deviation > threshold → insert to `route_deviation_events` + show in-app alert to driver
- [ ] `RouteDeviationAlertView` — non-blocking banner overlay in `NavigationHUDOverlay`

---

## STEP 13 — Fleet Manager: `FleetLiveMapViewModel` — Realtime
**Files to touch:** `FleetLiveMapViewModel.swift`, `FleetLiveMapView.swift`

- [ ] Supabase realtime subscription on `vehicle_location_history` filtered by active trips
- [ ] Update map annotations as new location rows arrive
- [ ] Show vehicle marker with driver name, vehicle plate, speed
- [ ] Tap marker → `VehicleMapDetailSheet`
- [ ] Subscription must be cancelled in `deinit` / on view disappear

---

## STEP 14 — `AlertsViewModel.swift` + Wire `AlertsInboxView`
**New file:** `Sierra/FleetManager/ViewModels/AlertsViewModel.swift`

- [ ] Realtime subscription on `emergency_alerts` (SOS, Defect, Accident, Breakdown, Medical)
- [ ] Realtime subscription on `route_deviation_events`
- [ ] Realtime subscription on `geofence_events`
- [ ] Badge count on alerts tab from unacknowledged items
- [ ] `acknowledgeAlert(id:) async` → updates `acknowledged_by`, `acknowledged_at`
- [ ] Wire to `AlertsInboxView.swift` and `AlertDetailView.swift`
- [ ] All three subscriptions cancelled in `deinit`

---

## STEP 15 — `GeofenceViewModel.swift` + Wire `CreateGeofenceSheet`
**New file:** `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift`

- [ ] `createGeofence(name:, type:, centerLat:, centerLng:, radiusMetres:) async throws`
- [ ] `deleteGeofence(id:) async throws`
- [ ] `loadGeofences() async` — fetch all active geofences for map overlay
- [ ] Wire to `CreateGeofenceSheet.swift` — implement the full 4-step flow from Figma:
  1. Name + type (Warehouse / Delivery Point / Restricted Zone / Custom)
  2. Map picker for centre coordinate
  3. Radius slider/input in metres
  4. Confirm → create
- [ ] Geofence polygons/circles displayed on `FleetLiveMapView`

---

## STEP 16 — Geofence Breach Detection
**Files to touch:** `GeofenceEventService.swift`, `TripNavigationCoordinator.swift`

- [ ] During active trip, on each location publish, check if vehicle is inside/outside any active geofence
- [ ] On state change (entry or exit) → insert to `geofence_events` table
- [ ] Insert to `notifications` table for Fleet Manager
- [ ] `AlertsViewModel` realtime subscription picks this up automatically (from Step 14)

---

## STEP 17 — Maintenance Approval: Add Technician Assignment
**Files to touch:** `MaintenanceApprovalDetailView.swift`  
**New file or update:** `MaintenanceRequestViewModel.swift`

- [ ] Fetch all `staff_members` with `role = 'maintenance'` and `status = 'Active'`
- [ ] Add `Picker("Assign Technician")` to the approval detail view
- [ ] On approve: set `maintenance_tasks.assigned_to_id = selectedTechnician.id` + `status = 'Assigned'` + `approved_by_id = currentUser.id` + `approved_at = now()`
- [ ] On reject: set `status = 'Cancelled'` + `rejection_reason`
- [ ] Figma: Approve → Assign maintenance personnel → (Monitor maintenance process)

---

## STEP 18 — `MaintenanceTaskViewModel.swift` (Maintenance Staff Side)
**New file:** `Sierra/Maintenance/ViewModels/MaintenanceTaskViewModel.swift`

- [ ] Load tasks assigned to `currentUser.id` (`assigned_to_id = staffMemberId`)
- [ ] `startTask(id:) async` → `status = 'In Progress'`
- [ ] `updateStatus(id:, status:, notes:) async`
- [ ] `completeTask(id:, recordDetails:) async throws`:
  - Set `status = 'Completed'`, `completed_at = now()`
  - Insert `maintenance_records` row with repair details, parts, labour cost
  - Insert `notifications` row for Fleet Manager: "Maintenance completed for [vehicle]"
  - Do NOT manually update vehicle status — the Fleet Manager controls that
- [ ] Wire to `MaintenanceDashboardView` and `MaintenanceTaskDetailView`
- [ ] Add realtime subscription on `maintenance_tasks` where `assigned_to_id = currentUser.id`

---

## STEP 19 — `TaskStatusUpdateSheet.swift`
**New file:** `Sierra/Maintenance/Views/TaskStatusUpdateSheet.swift`

- [ ] Quick bottom sheet for maintenance staff to update status inline from dashboard
- [ ] Fields: status picker, notes text field, parts used (optional quick add)
- [ ] Calls `MaintenanceTaskViewModel.updateStatus()`

---

## STEP 20 — Driver Maintenance Request Creation
**New file:** `Sierra/Driver/Views/MaintenanceRequestCreationView.swift`

- [ ] Title, description, priority picker, photo attach (optional)
- [ ] Submits to `maintenance_tasks` with `task_type = 'Breakdown'` or `'Inspection Defect'`
- [ ] Sets `source_alert_id` or `source_inspection_id` if raised from inspection or SOS
- [ ] Accessible from `PostTripInspectionView` (on failure) and `NavigationHUDOverlay` (mid-trip)

---

## STEP 21 — `DashboardHomeViewModel.swift`
**New file:** `Sierra/FleetManager/ViewModels/DashboardHomeViewModel.swift`

- [ ] Extract all data loading currently embedded in `DashboardHomeView` (19 KB)
- [ ] Stats: active trips count, available vehicles count, pending maintenance count, unacknowledged alerts count
- [ ] Recent activity feed from `activity_logs`
- [ ] Refresh on pull-to-refresh

---

## STEP 22 — `VehicleStatusViewModel.swift`
**New file:** `Sierra/FleetManager/ViewModels/VehicleStatusViewModel.swift`

- [ ] Load all vehicles with their current `status` enum
- [ ] Group by status: Active / Idle / In Maintenance / Out of Service
- [ ] Wire to `VehicleStatusView.swift`

---

## STEP 23 — `CreateTripView` → `CreateTripViewModel` + Route Waypoints
**New file:** `Sierra/FleetManager/ViewModels/CreateTripViewModel.swift`  
**Files to touch:** `CreateTripView.swift`

- [ ] Extract all business logic from `CreateTripView` (27 KB) into `CreateTripViewModel`
- [ ] Add origin + destination coordinate picker (map tap or search)
- [ ] Populate `trips.origin_latitude`, `trips.origin_longitude`, `trips.destination_latitude`, `trips.destination_longitude`
- [ ] Optionally compute and store `trips.route_polyline` via Mapbox Directions at creation time (NOT reactive — one-shot on form submit)
- [ ] Handle `check_resource_overlap` DB constraint violation with a user-readable error: "This vehicle or driver is already assigned to another trip at this time"

---

## STEP 24 — Driver Deactivation (FMS1-8)
**Files to touch:** `StaffMemberService.swift`, `StaffListView.swift`

- [ ] `StaffMemberService.deactivateStaff(id:) async throws` → set `status = 'Suspended'`
- [ ] Deactivated staff cannot log in (check `status != 'Suspended'` in `AuthManager.signIn()`)
- [ ] Add deactivate/reactivate button to staff detail in `StaffListView`

---

## STEP 25 — Analytics & Reports (lower priority — do if time permits)
**New file:** `Sierra/FleetManager/ViewModels/AnalyticsDashboardViewModel.swift`

- [ ] Extract all data loading from `AnalyticsDashboardView` (32 KB)
- [ ] Fleet usage stats: total trips, total km, average trip duration
- [ ] Per-driver stats for `DriverHistoryView`
- [ ] Fuel cost aggregation from `fuel_logs` + `trip_expenses`

---

## STEP 26 — Driver Availability Notification Wiring (FMS1-46)
**Files to touch:** `NotificationService.swift`

- [ ] When Fleet Manager creates a trip and assigns a driver → insert to `notifications` with `recipient_id = driver.id`, `type = 'Trip Assigned'`
- [ ] Driver's `DriverHomeView` polls or subscribes to `notifications` and shows badge / alert

---

## STEP 27 — WorkOrder UI (if time permits)
**New files:** `Sierra/Maintenance/Views/WorkOrderListView.swift`, `Sierra/Maintenance/ViewModels/WorkOrderViewModel.swift`

- [ ] List work orders assigned to current maintenance staff member
- [ ] Status: Open / In Progress / On Hold / Completed / Closed
- [ ] Link to associated `maintenance_task`

---

## Dependency Map

```
Step 1 (Supabase)  ──────────────────────────────────────────── unblocks all
Step 2 (Auth bugs) ──────────────────────────────────────────── standalone
Step 3 (TripViewModel) ──┬──────────────────────────────────── core
                         ├── Step 4 (StartTripSheet)
                         ├── Step 5 (PreTrip alert)
                         ├── Step 6 (PostTripVM)
                         ├── Step 7 (EndTripView)
                         ├── Step 9 (SOS)
                         └── Step 12 (Route deviation)
Step 8 (ProofOfDelivery) ── independent but needs active trip
Step 10 (FuelLog) ───────── independent but needs active trip
Step 11 (TripHistory) ───── needs Step 7 (EndTrip nav)
Step 13 (LiveMap) ───────── needs Step 3 GPS publishing
Step 14 (AlertsVM) ──────── needs Step 9 (SOS inserts)
Step 15 (Geofence) ──────── needs Step 13 (map)
Step 16 (Breach detect) ─── needs Step 15
Step 17 (Maint approval) ── independent of driver flow
Step 18 (MaintTaskVM) ───── needs Step 17
Step 19 (StatusSheet) ───── needs Step 18
Step 20 (Driver maint req) ─ needs Step 6 (PostTrip) or Step 9 (SOS)
Step 21 (Dashboard VM) ──── needs Steps 3, 14, 17
Step 22–27 ─────────────── polish, lower priority
```

---

## Files Being Created (New)

| # | Path |
|---|------|
| 3 | `Sierra/Driver/ViewModels/TripViewModel.swift` |
| 6 | `Sierra/Driver/ViewModels/PostTripInspectionViewModel.swift` |
| 7 | `Sierra/Driver/Views/EndTripView.swift` |
| 8 | `Sierra/Driver/ViewModels/ProofOfDeliveryViewModel.swift` |
| 9 | `Sierra/Driver/ViewModels/SOSAlertViewModel.swift` |
| 10 | `Sierra/Driver/Views/FuelLogEntryView.swift` |
| 10 | `Sierra/Driver/ViewModels/FuelLogViewModel.swift` |
| 11 | `Sierra/Driver/ViewModels/DriverTripHistoryViewModel.swift` |
| 12 | `Sierra/Driver/Views/RouteDeviationAlertView.swift` |
| 14 | `Sierra/FleetManager/ViewModels/AlertsViewModel.swift` |
| 15 | `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift` |
| 17 | `Sierra/FleetManager/ViewModels/MaintenanceRequestViewModel.swift` |
| 18 | `Sierra/Maintenance/ViewModels/MaintenanceTaskViewModel.swift` |
| 19 | `Sierra/Maintenance/Views/TaskStatusUpdateSheet.swift` |
| 20 | `Sierra/Driver/Views/MaintenanceRequestCreationView.swift` |
| 21 | `Sierra/FleetManager/ViewModels/DashboardHomeViewModel.swift` |
| 22 | `Sierra/FleetManager/ViewModels/VehicleStatusViewModel.swift` |
| 23 | `Sierra/FleetManager/ViewModels/CreateTripViewModel.swift` |
| 25 | `Sierra/FleetManager/ViewModels/AnalyticsDashboardViewModel.swift` |
| 27 | `Sierra/Maintenance/Views/WorkOrderListView.swift` |
| 27 | `Sierra/Maintenance/ViewModels/WorkOrderViewModel.swift` |

## Files Being Modified (Existing)

| # | Path | Change |
|---|------|--------|
| 2 | `Sierra/Auth/ForcePasswordChangeView.swift` | Remove `generateOTP()` call |
| 2 | `Sierra/Auth/AuthManager.swift` | Fix Face ID post-signout |
| 4 | `Sierra/Driver/Views/StartTripSheet.swift` | Wire TripViewModel, add odometer |
| 4 | `Sierra/Driver/Views/DriverHomeView.swift` | Navigation to TripNavigationContainerView |
| 5 | `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift` | Add failure alert insert |
| 9 | `Sierra/Driver/Views/NavigationHUDOverlay.swift` | Add SOS + Defect buttons |
| 13 | `Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift` | Add realtime subscription |
| 15 | `Sierra/FleetManager/Views/CreateGeofenceSheet.swift` | Wire GeofenceViewModel, 4-step flow |
| 16 | `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` | Add geofence breach detection |
| 17 | `Sierra/FleetManager/Views/MaintenanceApprovalDetailView.swift` | Add technician picker |
| 23 | `Sierra/FleetManager/Views/CreateTripView.swift` | Extract to VM, add coordinate picker |
| 24 | `Sierra/Shared/Services/StaffMemberService.swift` | Add `deactivateStaff()` |
| 24 | `Sierra/FleetManager/Views/StaffListView.swift` | Add deactivate button |
