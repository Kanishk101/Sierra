# Sprint 2 Reality Check (Repo-Verified)

Generated: 2026-03-18 17:36:25 IST  
Repository: `/Users/kan/Documents/Sierra`  
Branch: `main`  
Commit snapshot: `5a3bb9b`

## Scope

This document validates two files against the current repository contents:

1. `Docs/SPRINT2_AUDIT.md`
2. `Docs/Sierra Execution Roadmap.md`

This is a codebase reality check only. It does not include live Supabase project introspection or runtime iOS testing.

Verdict legend:
- `Correct`: claim matches current repo state.
- `Partial`: claim is directionally right but incomplete or contains inaccuracies.
- `Incorrect`: claim is stale or contradicted by current code.
- `Not Verifiable`: cannot be proven from static repo alone.

---

## Repo Snapshot (Current State)

- Migrations present in repo: 2 files only:
  - `supabase/migrations/20260315000001_add_busy_status.sql`
  - `supabase/migrations/20260315000002_add_overlap_check_fn.sql`
- Missing roadmap migration files (`...00003` to `...00007`) in repo.
- `check_resource_overlap` migration grants execute to both `authenticated` and `anon`.
- SwiftUI realtime wiring exists in code:
  - `AppDataStore` channels for `emergency_alerts`, `staff_members`, `vehicles`, `trips`
  - `NotificationService` channel for `notifications`
- No centralized `RealtimeSubscriptionManager.swift` file.
- `VehicleLocationService` has 5-second throttle gate.
- `TripNavigationCoordinator` implements:
  - one-time route build guard,
  - location publishing timer (5s),
  - local route deviation math + `RouteDeviationService.recordDeviation`,
  - geofence region monitoring and `geofence_events` insert.
- Important wiring gap:
  - `startLocationTracking()` exists but is not called from `TripNavigationContainerView`, so geofence region callbacks and `currentLocation` updates may not run.
- `DriverTripHistoryView.swift` is small (~2.9 KB) but functional (not an empty stub).
- `MaintenanceApprovalDetailView` and `MaintenanceTaskDetailView` contain real DB update logic.
- `sendEmail.swift` still exists (duplicate concern with `EmailService` remains).
- `.DS_Store` files exist in repo root and `Sierra/`.
- `StaffApplicationStore.swift` exists only as deprecated empty stub; no active usage.

---

## Part A: Validation of `SPRINT2_AUDIT.md`

## A1) Domain Status Table Validation

| Audit Claim | Verdict | Reality |
|---|---|---|
| FM Live Map realtime not wired | Partial | Realtime channels exist, including `vehicles` updates; not a dedicated `vehicle_location_history` FM channel. |
| FM Geofence create/manage: create only, no list/edit/event listener | Partial | Create flow exists with radius/circle support. Dedicated list/edit screens missing; FM realtime geofence listener missing. |
| FM Route definition unverified | Correct | Trip stores origin/destination coordinates, but no FM waypoint authoring flow; `routePolyline` is initially nil in trip creation. |
| FM Alerts inbox: no realtime subscription | Partial | App has emergency realtime channel, but `AlertsInboxView` does direct fetch and not a unified realtime stream VM. |
| FM Maintenance approval DB call unverified | Incorrect | Approve/reject paths call `MaintenanceTaskService` with DB updates in view code. |
| FM Vehicle reassignment missing | Correct | No reassignment flow or `VehicleReassignmentSheet`. |
| Driver Pre-trip sequential upload unverified | Incorrect | Sequential for-loop upload exists in `PreTripInspectionViewModel.uploadPhotos()`. |
| Driver navigation throttle unverified | Incorrect | 5-second throttle exists in `VehicleLocationService`. |
| Driver POD OTP hash unverified | Partial | UI hashes OTP, but `ProofOfDeliveryService` payload omits OTP hash fields. |
| Driver SOS/Defect no realtime push to FM | Partial | SOS inserts alerts + notifications; emergency alerts realtime channel exists, but FM alert UI is not fully channel-driven. |
| Driver maintenance request missing | Correct | Missing `DriverMaintenanceRequestView` and dedicated create-request flow. |
| Driver fuel logging view missing | Correct | `FuelLogService` exists; `FuelLogView` missing. |
| Driver geofence notifications missing | Partial | Geofence event logic exists in coordinator, but location-tracking wiring gap and no dedicated driver geofence notification surface. |
| Maintenance dashboard VM is stub | Partial | VM is small but functional (fetch + filters + freshness guard). |
| Maintenance task DB save not wired | Incorrect | `MaintenanceTaskDetailView` performs status/work-order writes and image upload updates. |
| Supabase realtime zero infrastructure | Incorrect | Multiple realtime channels are implemented (`AppDataStore`, `NotificationService`). |
| DB triggers partial; trip/maintenance trigger migrations absent | Correct | Repo has only the first two migrations; trigger migrations not checked in. |

## A2) Jira Matrix Reality Check (Sprint 2-focused rows)

| Story | Audit Status | Verdict | Reality |
|---|---|---|---|
| FMS1-9 Geofences | Partial | Partial | Radius/circle support exists; list/edit flow still missing. |
| FMS1-10 Driver history | Partial | Incorrect | `DriverHistoryView` includes scoped query and rendering. |
| FMS1-11 Live tracking | Partial | Partial | Realtime exists via `vehicles` updates; not via dedicated location-history channel. |
| FMS1-12 Route deviation alerts | Partial | Partial | Deviation generation exists; FM realtime alert consumption not fully wired. |
| FMS1-13 Approve maintenance | Partial | Incorrect | Approve path is implemented and calls service methods. |
| FMS1-14 Geofence monitoring | Not implemented | Partial | Driver-side geofence monitoring/inserts exist; FM listener/UI flow incomplete. |
| FMS1-15 SOS/defect alerts | Partial | Partial | Creation + some realtime plumbing exist; alerts UI flow not fully realtime-unified. |
| FMS1-16 Reject maintenance | Partial | Incorrect | Reject path implemented and wired. |
| FMS1-19 Vehicle status view | Partial | Not Verifiable | Exists; freshness depends on runtime realtime permissions/config. |
| FMS1-24 Dashboard stats | Partial | Partial | Stats are computed from `AppDataStore` and can update with store changes. |
| FMS1-36 Pre-trip inspection | Partial | Partial | Core flow implemented; some architecture expectations differ. |
| FMS1-37 Start trip | Partial | Partial | Starts via service; trigger dependency remains unresolved in migrations. |
| FMS1-38 End trip | Partial | Partial | Completion flow exists via post-trip path and `store.endTrip`. |
| FMS1-39 Assigned route | Partial | Partial | Mapbox route exists; FM-authored waypoint flow absent. |
| FMS1-40 Delivery complete | Partial | Partial | POD capture exists; trip completion separated into post-trip flow. |
| FMS1-42 Trip history | Stub | Incorrect | `DriverTripHistoryView` is functional despite small file size. |
| FMS1-44 POD | Partial | Partial | OTP hash UI exists; service payload mismatch remains. |
| FMS1-45 SOS alert | Partial | Partial | Trigger path exists; end-to-end realtime UX still fragmented. |
| FMS1-47 Driver maintenance request | Missing | Correct | Missing flow/view. |
| FMS1-50 Deviation notification | Partial | Partial | Deviation detection/recording exists; dedicated banner file absent (equivalent HUD banner exists). |
| FMS1-77/FMS1-78 Geofence entry/exit notification | Missing | Partial | Event insertion exists; dedicated driver notification UX not clearly completed. |
| FMS1-79 Previous trips | Stub | Incorrect | Driver trip history view is implemented. |
| FMS1-53 Maintenance dashboard | Stub | Partial | VM is lightweight but functional; not empty. |
| FMS1-55/FMS1-56 Task update/complete | Partial | Partial | Write paths exist in view; architecture differs from VM-centric plan. |
| FMS1-57 Repair notes | Partial | Partial | Work-order notes exist; direct `MaintenanceRecordService` usage is limited. |

## A3) Security / Performance / Architecture Findings in Audit

| Audit Finding | Verdict | Reality |
|---|---|---|
| No RLS migration files in repo | Correct | True in repository. |
| OTP storage rule unverified | Correct | Still partially unresolved due mixed OTP implementations and payload mismatch. |
| `anon` execute on overlap function | Correct | Present in migration SQL. |
| `.DS_Store` committed | Correct | Present at repo root and `Sierra/`. |
| DB triggers not managed in migrations | Correct | Trigger migration files are absent in repo. |
| Location throttle unverified | Incorrect | Explicit 5-second throttle exists. |
| Missing indexes migration | Correct | Index migration file not present in repo. |
| Mapbox reactive call risk unverified | Partial | Current route build is explicit async (good), but runtime wiring still needs end-to-end validation. |
| `StaffApplicationStore` as active second store | Incorrect | File is deprecated stub only; no callsites found. |
| No realtime subscription infrastructure | Incorrect | Realtime channels exist, but are fragmented. |

---

## Part B: Validation of `Sierra Execution Roadmap.md`

## B1) Step-by-Step Verdict (All 32 Steps)

| Step | Verdict | Notes |
|---|---|---|
| 1 Trip trigger migration | Correct (missing) | Not present in repo. |
| 2 Maintenance trigger migration | Correct (missing) | Not present in repo. |
| 3 RLS migration | Correct (missing) | Not present in repo. |
| 4 Index migration | Correct (missing) | Not present in repo. |
| 5 Revoke anon overlap | Correct (missing) | Not present in repo. |
| 6 RealtimeSubscriptionManager | Partial | File missing, but realtime exists in `AppDataStore` and `NotificationService`. |
| 7 LocationPublishingService | Partial | File missing, but effective 5s publish behavior exists in `VehicleLocationService` + coordinator timer. |
| 8 TripNavigationCoordinator rules | Partial | Non-reactive route build exists; roadmap assumes `NavigationViewController`, current code uses `MapView`. |
| 9 DriverHomeViewModel | Partial | File missing, but behavior is implemented directly in view. |
| 10 PreTrip sequential + defect alert | Partial | Sequential upload confirmed; failed inspection currently creates maintenance task, not emergency alert row. |
| 11 StartTrip uses TripService only | Partial | Start trip path uses service; broader repo still has manual status/resource updates in other flows. |
| 12 RouteDeviationBannerView | Partial | Separate file missing; equivalent off-route banner exists in `NavigationHUDOverlay`. |
| 13 GeofenceMonitorService | Partial | File missing; similar monitor logic exists in coordinator. |
| 14 ProofOfDeliveryViewModel | Partial | VM missing; view handles logic. OTP hash persistence mismatch remains in service payload. |
| 15 PostTripInspectionViewModel | Partial | VM missing; post-trip view exists and reuses pre-trip VM flow. |
| 16 FuelLogViewModel + FuelLogView | Correct (missing) | Not present. |
| 17 DriverMaintenanceRequestView | Correct (missing) | Not present. |
| 18 Complete DriverTripHistoryView stub | Incorrect | It is already functional in current repo. |
| 19 FleetLiveMapViewModel realtime stream | Partial | VM exists and works, but not via proposed `vehicleLocations` stream shape. |
| 20 AlertsViewModel | Correct (missing) | Not present; alerts view uses direct fetch/state. |
| 21 GeofenceViewModel + GeofenceListView | Correct (missing) | Missing. |
| 22 MaintenanceApprovalViewModel | Partial | VM missing, but approval/reject flow already implemented in view layer. |
| 23 MaintenanceTaskDetailViewModel | Partial | VM missing, but most detail actions already implemented in view layer. |
| 24 MaintenanceDashboardViewModel realtime wiring | Partial | VM exists with fetch/filter; not fully wired as proposed realtime-stream reader. |
| 25 RepairImageUploadView | Partial | Separate view missing; upload exists inside `MaintenanceTaskDetailView`. |
| 26 SparePartsViewModel | Correct (missing) | Missing. |
| 27 SOSAlertViewModel | Partial | VM missing; SOS behavior implemented directly in view. |
| 28 Notification banner overlay | Partial | Dedicated shared banner file missing; notification center/badges are partial. |
| 29 Merge StaffApplicationStore into AppDataStore | Partial | Already effectively merged; leftover deprecated stub still present. |
| 30 DashboardHome live stats wiring | Partial | Dashboard already computes from `AppDataStore`; not fully dependent on proposed manager model. |
| 31 Analytics/Reports real data wiring | Partial | Large parts already implemented using store-backed data and charts. |
| 32 Git/cleanup | Partial | `sendEmail.swift` and `.DS_Store` cleanup still pending; OTP compliance still mixed. |

## B2) Roadmap Assumptions That Are Now Stale

- "Nothing can function before any Swift changes" is too strict for current repo; substantial Swift features already exist.
- Multiple steps marked "create from scratch" are actually "refactor existing view-layer logic into VMs/services."
- Roadmap assumes `NavigationViewController` architecture; current map stack uses `MapView` via `UIViewRepresentable`.
- Roadmap assumes realtime is absent; actual issue is fragmentation and inconsistent consumption, not total absence.

---

## Part C: Current Missing Items (Confirmed)

Missing/mapped as not present by filename:
- `Sierra/Shared/Services/RealtimeSubscriptionManager.swift`
- `Sierra/Shared/Services/LocationPublishingService.swift`
- `Sierra/Shared/Services/GeofenceMonitorService.swift`
- `Sierra/Driver/ViewModels/DriverHomeViewModel.swift`
- `Sierra/Driver/ViewModels/ProofOfDeliveryViewModel.swift`
- `Sierra/Driver/ViewModels/PostTripInspectionViewModel.swift`
- `Sierra/Driver/ViewModels/FuelLogViewModel.swift`
- `Sierra/Driver/ViewModels/SOSAlertViewModel.swift`
- `Sierra/Driver/Views/DriverMaintenanceRequestView.swift`
- `Sierra/Driver/Views/FuelLogView.swift`
- `Sierra/Driver/Views/RouteDeviationBannerView.swift` (equivalent UI exists elsewhere)
- `Sierra/FleetManager/ViewModels/AlertsViewModel.swift`
- `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift`
- `Sierra/FleetManager/ViewModels/MaintenanceApprovalViewModel.swift`
- `Sierra/FleetManager/Views/GeofenceListView.swift`
- `Sierra/Maintenance/ViewModels/MaintenanceTaskDetailViewModel.swift`
- `Sierra/Maintenance/ViewModels/SparePartsViewModel.swift`
- `Sierra/Maintenance/Views/RepairImageUploadView.swift`
- `Sierra/Shared/Views/NotificationBannerView.swift`
- Trigger/RLS/index/revoke migrations (`20260318000003`..`20260318000007`)

---

## Part D: Key Corrections Required in Docs

For `SPRINT2_AUDIT.md`:
- Replace all "zero realtime infrastructure" claims with "realtime exists but is fragmented and incomplete for several Sprint 2 surfaces."
- Mark location throttle as verified in code.
- Mark maintenance approval/reject and maintenance task update flows as implemented (view-layer).
- Update trip history status from "stub" to "implemented lightweight view."
- Keep missing migration and security findings (RLS/trigger/index/anon grant), as they remain valid for repo state.

For `Sierra Execution Roadmap.md`:
- Reframe many steps as refactor/integration tasks, not greenfield creation.
- Keep migration steps 1-5 as top repo gaps.
- Align navigation step with current `MapView` architecture.
- Add explicit fix for `ProofOfDeliveryService` payload to include OTP hash fields.
- Add explicit fix for location tracking wiring (`startLocationTracking()` invocation).

---

## Evidence Index (Primary Files Used)

- `Docs/SPRINT2_AUDIT.md`
- `Docs/Sierra Execution Roadmap.md`
- `supabase/migrations/20260315000001_add_busy_status.sql`
- `supabase/migrations/20260315000002_add_overlap_check_fn.sql`
- `Sierra/Shared/Services/AppDataStore.swift`
- `Sierra/Shared/Services/NotificationService.swift`
- `Sierra/Shared/Services/VehicleLocationService.swift`
- `Sierra/Shared/Services/TripService.swift`
- `Sierra/Shared/Services/ProofOfDeliveryService.swift`
- `Sierra/Shared/Services/SupabaseManager.swift`
- `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift`
- `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift`
- `Sierra/Driver/Views/StartTripSheet.swift`
- `Sierra/Driver/Views/ProofOfDeliveryView.swift`
- `Sierra/Driver/Views/NavigationHUDOverlay.swift`
- `Sierra/Driver/Views/DriverTripHistoryView.swift`
- `Sierra/Driver/Views/TripNavigationContainerView.swift`
- `Sierra/FleetManager/Views/AlertsInboxView.swift`
- `Sierra/FleetManager/Views/MaintenanceApprovalDetailView.swift`
- `Sierra/FleetManager/Views/CreateGeofenceSheet.swift`
- `Sierra/FleetManager/Views/CreateTripView.swift`
- `Sierra/FleetManager/Views/FleetManagerTabView.swift`
- `Sierra/Maintenance/ViewModels/MaintenanceDashboardViewModel.swift`
- `Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift`
- `Sierra/Shared/Services/StaffApplicationStore.swift`
- `Sierra/sendEmail.swift`
- `.gitignore`

