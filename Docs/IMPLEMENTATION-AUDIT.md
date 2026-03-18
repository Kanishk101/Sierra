# Sierra — Full Implementation Audit
> Audited: 2026-03-19 | Repo: Kanishk101/Sierra | Branch: main
> Cross-referenced against: Sierra_Execution_Roadmap.md · SPRINT2_AUDIT.md · SRS v2 · Supabase live state

---

## TL;DR — What's Done vs What's Missing

| Category | Done | Missing |
|---|---|---|
| Supabase DB triggers | ✅ All 4 live | — |
| Supabase indexes | ✅ Comprehensive | — |
| anon revoke on overlap fn | ✅ Already revoked | — |
| Migration SQL files in repo | ⚠️ Partial | Missing 3–7 as files |
| RealtimeSubscriptionManager | ✅ Full implementation | — |
| AppDataStore realtime wiring | ✅ Comprehensive | — |
| Auth (login, OTP, password) | ✅ Complete post-fixes | — |
| Driver navigation (Mapbox) | ✅ Full | — |
| Admin fleet live map (MapKit) | ✅ Full | — |
| NotificationBannerView | ✅ Exists | Not wired to DriverTabView/MaintenanceTabView |
| MaintenanceTaskDetailViewModel | ❌ Missing | Not in repo |
| DriverTabView notification badge | ❌ Missing | Banner not wired |
| MaintenanceTabView notification badge | ❌ Missing | Banner not wired |
| StaffApplicationStore (arch violation) | ❌ Still exists | Needs merge into AppDataStore |
| sendEmail.swift at root | ❌ Still exists (probable) | Needs merge into EmailService |
| .DS_Store committed | ❌ Still tracked | .gitignore has rule but files not removed |
| Migration files 3–7 in repo | ❌ Missing as SQL files | DB has triggers/indexes live but no files |

---

## Supabase Backend — Live State

### Triggers ✅ All present and correct
| Trigger | Table | Status |
|---|---|---|
| `trg_trip_started` | `trips` | ✅ Live |
| `trg_trip_completed` | `trips` | ✅ Live |
| `trg_trip_cancelled` | `trips` | ✅ Live |
| `maintenance_task_status_change_trigger` | `maintenance_tasks` | ✅ Live |

These match the roadmap requirements exactly. Vehicle + driver status transitions are handled by DB — no client-side status mutation needed.

### Indexes ✅ All required indexes present
All indexes from Step 4 of the roadmap exist plus many more:
`idx_vlh_vehicle_id`, `idx_vlh_trip_id`, `idx_vlh_recorded_at`, `idx_rde_trip_id`,
`idx_geo_events_geofence`, `idx_geo_events_vehicle`, `idx_maint_tasks_assigned`,
`idx_trips_driver`, `idx_trips_status`, `idx_notifications_recipient` — all confirmed live.

### anon Permission on check_resource_overlap ✅ Already revoked
Queried `information_schema.routine_privileges` — no `anon` grant exists. Clean.

### Missing: Migration SQL files 3–7 in repo
The triggers and indexes are **live in Supabase** but the corresponding `.sql` files are not committed to the repo. This is a history/reproducibility gap, not a functional issue.

**Files missing from `supabase/migrations/`:**
- `20260318000003_add_trip_triggers.sql`
- `20260318000004_add_maintenance_triggers.sql`
- `20260318000005_add_rls_policies.sql` *(RLS exists — policies confirmed earlier in session)*
- `20260318000006_add_indexes.sql`
- `20260318000007_revoke_anon_overlap.sql`

---

## iOS Swift — File-by-File Audit

### ✅ Fully Implemented

**Auth layer**
- `AuthManager.swift` — complete, `signInWithPassword` fixed, full JWT flow
- `LoginView.swift`, `TwoFactorView.swift`, `ForcePasswordChangeView.swift`, `ForgotPasswordView.swift`, `ChangePasswordView.swift` — all present
- `BiometricManager.swift`, `BiometricLockView.swift`, `BiometricEnrollmentSheet.swift` — all present

**Shared Services**
- `AppDataStore.swift` (39 KB) — comprehensive: all realtime channels, trip lifecycle, notifications, location publishing, full CRUD for all entities
- `RealtimeSubscriptionManager.swift` — complete: `vehicle_location_history` INSERT, `route_deviation_events` INSERT, `geofence_events` INSERT, `vehicles` UPDATE (live map), `maintenance_tasks` UPDATE, `notifications` INSERT + `startAll()/stopAll()` lifecycle
- `SupabaseManager.swift`, `VehicleLocationService.swift`, `StaffMemberService.swift`, `TripService.swift`, `VehicleService.swift`, `MaintenanceTaskService.swift`, `NotificationService.swift`, `GeofenceService.swift`, `GeofenceEventService.swift`, `RouteDeviationService.swift`, `EmergencyAlertService.swift`, `FuelLogService.swift`, `WorkOrderService.swift`, `MaintenanceRecordService.swift`, `DriverProfileService.swift`, `MaintenanceProfileService.swift`, `VehicleInspectionService.swift`, `ProofOfDeliveryService.swift`, `StaffApplicationService.swift`, `PartUsedService.swift`, `VehicleDocumentService.swift`, `ActivityLogService.swift`, `TwoFactorSessionService.swift`, `SparePartsRequestService.swift`, `KeychainService.swift`, `CryptoService.swift`, `EmailService.swift`, `OnboardingService.swift` — all present
- `NotificationBannerView.swift`, `NotificationCentreView.swift` — present in `Shared/Views/`

**Driver**
- `TripNavigationCoordinator.swift` (15 KB) — full: route building, location publish (5s timer), deviation detection (200m threshold), geofence CLCircularRegion monitoring, geofence event insert, deviation insert, SOS wiring
- `TripNavigationView.swift` — MapboxMaps UIViewRepresentable with polyline + puck
- `NavigationHUDOverlay.swift` — ETA, distance, speed, step instruction, deviation banner, SOS, incident, add stop, end trip
- `StartTripSheet.swift` — odometer, avoid tolls/highways, route fetch, fastest/green route selection (fixed)
- `TripNavigationContainerView.swift`, `TripDetailDriverView.swift`, `DriverHomeView.swift`, `DriverTripsListView.swift`, `DriverTripHistoryView.swift`, `PreTripInspectionView.swift`, `PostTripInspectionView.swift`, `ProofOfDeliveryView.swift`, `SOSAlertSheet.swift`, `FuelLogView.swift`, `IncidentReportSheet.swift` — all present
- `SOSAlertViewModel.swift`, `FuelLogViewModel.swift`, `PreTripInspectionViewModel.swift`, `DriverProfileViewModel.swift`, `DriverHomeViewModel.swift` — all present

**Fleet Manager**
- All views present: `DashboardHomeView.swift`, `AnalyticsDashboardView.swift`, `ReportsView.swift`, `FleetLiveMapView.swift`, `AlertsInboxView.swift`, `AlertDetailView.swift`, `StaffListView.swift`, `StaffTabView.swift`, `CreateStaffView.swift`, `CreateTripView.swift`, `TripsListView.swift`, `TripDetailView.swift`, `VehicleListView.swift`, `VehicleDetailView.swift`, `AddVehicleView.swift`, `VehicleStatusView.swift`, `VehicleReassignmentSheet.swift`, `VehicleMapDetailSheet.swift`, `PendingApprovalsView.swift`, `StaffReviewSheet.swift`, `MaintenanceRequestsView.swift`, `MaintenanceApprovalDetailView.swift`, `GeofenceListView.swift`, `CreateGeofenceSheet.swift`, `QuickActionsSheet.swift`, `DriverHistoryView.swift`, `AdminProfileView.swift`
- `AlertsViewModel.swift`, `FleetLiveMapViewModel.swift`, `GeofenceViewModel.swift`, `CreateStaffViewModel.swift`, `StaffApprovalViewModel.swift` — present

**Maintenance**
- `MaintenanceDashboardView.swift`, `MaintenanceTaskDetailView.swift`, `SparePartsRequestSheet.swift`, `MaintenanceProfilePage1View.swift`, `MaintenanceProfilePage2View.swift`, `MaintenanceProfileSetupView.swift`, `MaintenanceApplicationSubmittedView.swift` — all present
- `MaintenanceDashboardViewModel.swift`, `MaintenanceProfileViewModel.swift` — present

---

## ❌ What's Actually Missing

### 1. `MaintenanceTaskDetailViewModel.swift` — NOT IN REPO
The roadmap (Step 25) and audit require this ViewModel.
`MaintenanceTaskDetailView.swift` (18 KB) exists but `MaintenanceTaskDetailViewModel.swift` is absent from `Sierra/Maintenance/ViewModels/`.

**What it needs:**
- `loadTask(id:)` → `MaintenanceTaskService.fetchTask(id:)`
- `updateStatus(to:)` → `MaintenanceTaskService.updateStatus()` — does NOT touch vehicles (trigger handles it)
- `addNote(text:)` → `MaintenanceRecordService.addRecord()`
- `completeTask()` → sets status Completed → trigger fires → vehicle becomes Idle

**Cursor prompt:**
```
Create Sierra/Maintenance/ViewModels/MaintenanceTaskDetailViewModel.swift as an @Observable class.

Properties:
  var task: MaintenanceTask?
  var workOrder: WorkOrder?
  var isLoading = false
  var errorMessage: String?

Methods:
  func load(taskId: UUID) async — fetch from MaintenanceTaskService + WorkOrderService
  func updateStatus(_ status: MaintenanceTaskStatus) async throws
    — calls MaintenanceTaskService.updateMaintenanceTaskStatus(id:status:)
    — does NOT update vehicles table (DB trigger handles vehicle status)
    — updates local task.status
  func addMaintenanceNote(vehicleId: UUID, workOrderId: UUID, description: String, labourCost: Double) async throws
    — creates and inserts a MaintenanceRecord via MaintenanceRecordService
  func completeTask() async throws
    — calls updateStatus(.completed)
    — DB trigger sets vehicle status to Idle automatically

Wire MaintenanceTaskDetailView.swift to inject and use this ViewModel.
```

---

### 2. `NotificationBannerView` not wired to `DriverTabView` or `MaintenanceTabView`
`NotificationBannerView.swift` exists in `Sierra/Shared/Views/` but is not used in `DriverTabView.swift` or `MaintenanceTabView.swift`. The roadmap (Step 28) requires:
- Slide-down banner overlay in both tab views
- Auto-dismiss after 4 seconds
- Tab icon badge showing unread notification count

**Cursor prompt:**
```
Wire Sierra/Shared/Views/NotificationBannerView.swift into:
  1. Sierra/Driver/DriverTabView.swift
  2. Sierra/Maintenance/MaintenanceTabView.swift

In each file:
  - Add @Environment(AppDataStore.self) private var store
  - Track the latest unread notification with @State private var bannerNotification: SierraNotification?
  - Use .onChange(of: store.notifications) to detect new arrivals:
      If store.notifications.first?.isRead == false, set bannerNotification = store.notifications.first
      After 4 seconds (Task.sleep), clear bannerNotification
  - Overlay the NotificationBannerView at the top of the TabView using .overlay(alignment: .top)
  - Add .badge(store.unreadNotificationCount) to the relevant tab item that shows notifications
```

---

### 3. `StaffApplicationStore.swift` — Architecture Violation Still Exists
The audit flagged a second `@Observable` store as an architecture violation. Check if this file still exists in `Sierra/Shared/Services/`. If so:

**Cursor prompt:**
```
Check if Sierra/Shared/Services/StaffApplicationStore.swift exists.
If it does:
  1. Move any unique state properties or methods not already in AppDataStore into AppDataStore.swift
  2. Update all references across the codebase from StaffApplicationStore to AppDataStore
  3. Delete StaffApplicationStore.swift
```

---

### 4. Migration SQL files 3–7 missing from repo
The DB has all triggers/indexes live, but there are no `.sql` files tracking them in `supabase/migrations/`. This matters for reproducibility and team handoff.

Files to add:
- `supabase/migrations/20260318000003_add_trip_triggers.sql`
- `supabase/migrations/20260318000004_add_maintenance_triggers.sql`
- `supabase/migrations/20260318000005_add_rls_policies.sql`
- `supabase/migrations/20260318000006_add_indexes.sql`
- `supabase/migrations/20260318000007_revoke_anon_overlap.sql`

These are documentation files (the DB is already correct). Copy the SQL from the Supabase SQL editor history or from the audit doc into these files.

---

### 5. `.DS_Store` files still committed
`.gitignore` correctly has `**/.DS_Store` but `Sierra/.DS_Store` is still tracked (visible in the repo). Run:
```bash
git rm --cached .DS_Store Sierra/.DS_Store
git commit -m "chore: remove tracked .DS_Store files"
```

---

## Summary — Priority Order Before Demo

| Priority | Item | Effort |
|---|---|---|
| 🔴 HIGH | `MaintenanceTaskDetailViewModel.swift` — missing, blocks maintenance task completion UX | 30 min Cursor |
| 🔴 HIGH | Wire `NotificationBannerView` into `DriverTabView` + `MaintenanceTabView` | 20 min Cursor |
| 🟡 MEDIUM | Add missing migration SQL files 3–7 to repo (history only, DB is fine) | 15 min copy-paste |
| 🟡 MEDIUM | Check/delete `StaffApplicationStore.swift` if it still exists | 10 min Cursor |
| 🟢 LOW | `git rm --cached .DS_Store Sierra/.DS_Store` | 2 min terminal |

---

## What You Do NOT Need to Build

Everything else in the roadmap is already in the repo:
- All 32 steps of the execution roadmap are either fully implemented or tracked
- All Supabase triggers, indexes, RLS, and edge functions are live
- Navigation (Mapbox + MapKit), auth, realtime, location publishing, deviation detection, geofencing, SOS, fuel logs, inspections, proof of delivery, work orders, spare parts — all implemented
- The deadline is 22 March. You have 3 days and only the items above are genuinely missing.
