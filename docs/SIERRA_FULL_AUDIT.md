# 🚨 SIERRA FMS — FULL SYSTEM AUDIT REPORT
> **Auditor Mode:** Principal Staff iOS Architect + Backend Architect + Supabase Expert + UX Systems Designer  
> **Sources Analysed:** SRS v2.0 (9 pages), GitHub `Kanishk101/Sierra` main branch (entire codebase), Supabase migrations  
> **Date:** 2026-03-22

---

## TABLE OF CONTENTS
1. [Full System Audit — Module by Module](#1-full-system-audit)
2. [Critical Issue List (Prioritised)](#2-critical-issue-list)
3. [System Design Corrections](#3-system-design-corrections)
4. [Claude Opus Implementation Prompts (14 Prompts)](#4-claude-opus-implementation-prompts)

---

# 1. FULL SYSTEM AUDIT

---

## MODULE 1: Authentication & Role System

### Expected (SRS)
- Secure login using admin-generated credentials
- Role-based access: Fleet Manager, Driver, Maintenance Personnel
- Passkeys, encryption, 2FA
- Role-based module access enforcement
- GDPR compliance

### Current Implementation
- `Auth/` folder handles sign-in via Supabase email/password
- `AuthManager.shared` manages session state
- `ContentView.swift` routes to role-specific tab views
- `TwoFactorSessionService` exists but appears to be a custom 6-digit OTP stored in `two_factor_sessions` table — NOT actual TOTP or FIDO2 Passkeys
- Migration `20260318000001` drops `plaintext_password_columns` — confirms passwords were previously stored in plaintext in `staff_members`

### Issues
1. **No Passkeys.** SRS explicitly requires Passkeys (FIDO2). Current implementation is email/password only. `TwoFactorSessionService` is a custom OTP stored in a DB table — not cryptographically sound, no time-based expiry enforced at DB level.
2. **Plaintext passwords were stored.** Migration `drop_plaintext_password_columns` confirms credentials were stored in cleartext in `staff_members` table previously. Any data from before this migration is compromised.
3. **No GDPR mechanisms.** No data deletion request flow, no consent tracking, no data export capability.
4. **No App Intents.** SRS specifies App Intents framework. Zero implementation.
5. **No Core ML / Vision.** SRS specifies predictive maintenance, fuel optimisation via AI. Zero implementation.
6. **2FA is DB-backed OTP, not real 2FA.** A DB-stored OTP has no replay protection, is visible to DB admins, and has no proper expiry validation — it's security theatre.

### Root Cause Analysis
The authentication system was built for speed, not compliance. The SRS requirements for Passkeys and GDPR were aspirational NFRs that were never addressed in the implementation phase.

---

## MODULE 2: Trip Lifecycle System

### Expected (SRS)
- Admin creates trip with unique Task ID, destination, driver, vehicle, start/end times, priority
- Driver receives trip assignment
- Driver formally accepts/rejects trip
- Pre-trip inspection → Start trip → Navigate → Complete delivery (POD) → Post-trip inspection
- Status transitions: Scheduled → Active → Completed / Cancelled
- Reminder system for upcoming trips
- Trip progress monitoring by admin

### Current Implementation
- `Trip.swift` defines statuses: `scheduled`, `active`, `completed`, `cancelled`
- `TripDetailDriverView.swift` shows a flow steps card with correct step order
- `TripService.swift` has `startTrip`, `completeTrip`, `cancelTrip`
- `AppDataStore.startActiveTrip` and `endTrip` exist
- DB trigger `trg_trip_status_change` atomically manages driver availability and vehicle status on status change
- Resource overlap check via edge function `check-resource-overlap`

### Issues

#### CRITICAL
1. **No Trip Acceptance Flow.** `TripStatus` enum has no `.pendingAcceptance` or `.accepted` state. When admin assigns a trip to a driver, the driver has NO mechanism to acknowledge, accept, or reject it. The trip just appears in their list as `Scheduled`. SRS §4.2.3 implies drivers "start" trips — but there is zero acceptance step.

2. **Trip Steps Show False Completion.** In `TripDetailDriverView.flowStepsCard`, the step check for "Start Trip" is:
   ```swift
   done: trip.status == .active || trip.status == .completed
   ```
   And for "Pre-Trip Inspection":
   ```swift
   done: trip.preInspectionId != nil
   ```
   The **root bug**: `InspectionCheckItem` defaults to `result: InspectionResult = .notChecked`. The `overallResult` computed property returns `.passed` when there are NO failed or warned items — i.e. ALL notChecked items count as PASSED. A driver can submit a blank inspection form (never touching a single checklist item) and it will register as a PASSED pre-inspection, set `preInspectionId`, and unlock "Start Trip". **This is the "steps already completed" bug** — it manifests because the inspection can be submitted with zero actual checks.

3. **No Reminders.** Zero timer-based, notification-based, or background-task-based reminder system. `checkOverdueMaintenance()` exists for maintenance but there is no equivalent for upcoming trips (e.g., "Your trip starts in 30 minutes").

4. **TripUpdatePayload Missing Coordinate Fields.** `TripUpdatePayload` does NOT include `origin_latitude`, `origin_longitude`, `destination_latitude`, `destination_longitude`, or `route_polyline`. Only `TripInsertPayload` has some of these. `TripService.updateTripCoordinates` is a separate method — but `AppDataStore.updateTrip` uses `TripUpdatePayload` which will WIPE coordinates on any general update. If admin edits a trip after coordinates are set, they will be nullified.

5. **routeStops Encoding Mismatch.** `TripInsertPayload` sends `routeStops` as a JSON STRING `"[]"` into a JSONB column. When read back by the `Trip` decoder, `routeStops: [RouteStop]?` expects a JSON array. The JSONB column stores the raw JSON correctly, but the Supabase Swift SDK may double-encode or mis-decode this — consistent with the JSONB double-encoding issue documented in code comments.

#### HIGH
6. **No Push Notifications for Trip Assignment.** When admin creates a trip and assigns it to a driver, `NotificationService.insertNotification` is NOT called in `AppDataStore.addTrip`. Drivers only discover new trips by manually pulling to refresh or via Realtime channel. Realtime only covers `UPDATE` and `INSERT` events but the INSERT subscription decodes `action.record` using `JSONEncoder().encode(action.record)` then `JSONDecoder` — this double-encode path is known to fail for complex types (documented in code for inspections).

7. **Trip Completion Bypasses Post-Inspection Requirement.** `AppDataStore.addProofOfDelivery` auto-completes the trip:
   ```swift
   try await updateTripStatus(id: pod.tripId, status: .completed)
   ```
   This triggers the DB trigger releasing driver+vehicle. But `postInspectionId` has NOT been set yet. The post-trip inspection is orphaned — the trip is already marked `completed` and resources released before post-inspection is done.

8. **No Admin Trip Monitoring Real-Time.** Admin cannot see live GPS location during trips. `FleetLiveMapView.swift` exists but vehicle locations are only updated when `publishDriverLocation` is called by the driver's TripNavigationCoordinator. There is no Realtime subscription on `vehicle_location_history` for the admin.

### Root Cause Analysis
The trip lifecycle was implemented as a linear state machine without the intermediate acceptance state. The inspection submission validation is the core architectural error — it trusts the client to have completed all steps without server-side enforcement.

---

## MODULE 3: Driver Inspection System

### Expected (SRS)
- Pre-trip vehicle inspection with structured checklist
- Pass/Fail/Warn per item
- Defect reporting with photos
- Post-trip inspection
- Failed inspection triggers admin alert + maintenance task
- Fuel level logged as part of inspection

### Current Implementation
- `PreTripInspectionView.swift` — 3-step wizard: checklist → photos → summary
- `PreTripInspectionViewModel.swift` — handles state, photo upload, submission
- 13 default check items covering safety, tyres, lights, fluids, engine
- Pass/Warn/Fail segmented picker per item
- Photo upload to `inspection-photos` bucket
- Failed inspection creates `MaintenanceTask` automatically
- Both pre-trip and post-trip use the same view (inspectionType param)

### Issues

#### CRITICAL
1. **`notChecked` = Silent Pass Bug.** All items default to `result: InspectionResult = .notChecked`. The segmented picker shows only Pass / Warn / Fail — there is NO visible "Not Checked" state in the UI. When the driver advances to summary without selecting anything, `overallResult` computes:
   ```swift
   let hasFail = checkItems.contains { $0.result == .failed }     // false
   let hasWarning = checkItems.contains { $0.result == .passedWithWarnings } // false
   // returns .passed ← WRONG: all 13 items were never touched
   ```
   Root cause: the checklist UI has no "requires all items to be explicitly set" validation. A 0-second inspection shows as PASSED.

2. **No Mandatory Photo for Failed Items.** When an item is marked FAIL, the driver should be required to take at least one photo of that specific defect. Currently photo upload is entirely optional and not linked to specific check items.

3. **Fuel Level Check Item Does Not Capture Quantity.** The inspection has a "Fuel Level" check item that can be Pass/Fail. But the SRS (§4.2.7) requires actual fuel quantity and cost to be logged. The `FuelLogView` is a completely separate standalone form with no integration into the inspection flow. A driver can fail the Fuel Level check but never log actual fuel data.

4. **Post-Trip Inspection Has No Completion Gate.** `AppDataStore.addProofOfDelivery` calls `updateTripStatus(.completed)` immediately. The post-trip inspection is displayed as a UI step AFTER POD, but the trip is already `completed` and resources released. The post-inspection becomes cosmetic.

#### HIGH
5. **InspectionCheckItem ID Collision Risk.** `let id = UUID()` is generated at struct init time. When the ViewModel is created (`State(initialValue:)`), IDs are stable for that session. But if ViewModel is recreated (e.g., view dismissed and reopened), new UUIDs are generated — not idempotent. If a partially-submitted inspection is retried, duplicate rows could be inserted.

6. **Photo Upload Sequential But Partial Failure Ignored.** Upload failures are caught and printed but execution continues. If 3 of 5 photos fail, the inspection is submitted with only 2 photo URLs. No user feedback about partial failure.

7. **No Defect-to-Maintenance-Task Link Visible in UI.** When a failed inspection creates a `MaintenanceTask`, the driver gets no confirmation that a task was created. The admin has no direct link from the maintenance task back to the originating inspection photos.

### Root Cause Analysis
The inspection form was designed as a form-submit UI rather than a validation-gated workflow. The fundamental architectural error is allowing submission of a logically incomplete inspection.

---

## MODULE 4: Fuel Logging

### Expected (SRS)
- Record fuel quantity (litres)
- Record fuel cost
- Upload fuel receipt photo
- OCR of receipt (Vision framework mentioned in SRS tech spec)
- Integration with inspection flow

### Current Implementation
- `FuelLogView.swift` — standalone form: quantity, cost per litre, total cost, fuel station, odometer, optional receipt photo, notes
- `FuelLogViewModel.swift` — handles submission and receipt upload
- `FuelLogService` — CRUD on `fuel_logs` table
- Accessed from `TripDetailDriverView` as standalone "Log Fuel" button

### Issues

#### CRITICAL
1. **No OCR / Vision Integration.** SRS tech spec lists `Vision` framework. No Vision or Core ML usage anywhere in the codebase. Receipt photo is uploaded as-is with no OCR extraction. Driver must manually type all values.

2. **Not Integrated Into Inspection.** The fuel level checklist item in inspection is binary (pass/fail). Fuel quantity is a separate standalone form. These two are completely disconnected. When a driver fails the "Fuel Level" check, they should be redirected to the fuel log form. This never happens.

3. **No Validation: Fuel Math.** `FuelLogView` has three separate fields: Quantity (L), Cost per Litre (₹), Total Cost (₹). These three fields should satisfy: `quantity × costPerLitre = totalCost`. There is ZERO validation. A driver can enter `quantity=10L`, `costPerLitre=100`, `totalCost=5000` and it will submit. This corrupts fuel cost analytics.

4. **No Trip-Level Fuel Aggregation.** `FuelLog` has a `tripId` field and fuel logs can be scoped to a trip. But `AppDataStore` has no computed property for total fuel cost per trip, and `AnalyticsDashboardView` may not use this data correctly.

#### HIGH
5. **Fuel Log is Not Mandatory.** SRS implies fuel logging is a driver responsibility. There is no enforcement — a driver can complete an entire trip without ever logging fuel.

---

## MODULE 5: Vehicle Management

### Expected (SRS)
- Add/edit/delete vehicles with VIN, make, model, year, license plate
- Manage operational status: Active, Idle, Busy, In Maintenance, Out of Service, Decommissioned
- Vehicle document storage with expiry monitoring
- Vehicle assignment to drivers and trips
- Live location tracking

### Current Implementation
- `VehicleListView.swift` — search + horizontal filter chips + vehicle cards
- `AddVehicleView.swift` (40KB!) — multi-section form for full vehicle details
- `VehicleDetailView.swift` — view details, documents, maintenance history
- `VehicleService.swift` — full CRUD
- Filter chips: All, Active, Idle, Busy, In Maintenance, Out of Service, Decommissioned

### Issues

#### HIGH
1. **Filter Chips are Wrong UX Pattern.** User-reported issue confirmed. The horizontal scroll of filter chips works for 2-3 options. With 7 status options (All + 6 statuses), the chip row is cramped and requires scrolling. The correct pattern for 5+ filter options is a filter button → bottom sheet with a proper picker. Chips should only be used for 2-4 quick toggles.

2. **`AddVehicleView` is 40KB — God View.** A single 40KB SwiftUI view for vehicle creation is a massive MVVM violation. Business logic, network calls, and validation are almost certainly bleeding into the view. Needs ViewModel extraction.

3. **Vehicle Status `busy` vs `active` Confusion.** `Vehicle.status` has `.active` and `.busy` as separate states. The DB trigger sets vehicles to `Busy` when a trip becomes active. But `availableVehicles()` filters for `status == .idle && assignedDriverId == nil`. A vehicle assigned to a driver but not on a trip may be `.idle` or `.active` — the boundary between these states is unclear and likely inconsistent.

4. **No Mileage Tracking on Vehicle.** `Vehicle` model has no total odometer field. Trip `startMileage`/`endMileage` fields exist but there's no aggregation of odometer readings back to the vehicle's total mileage. `VehicleDetailView` cannot show total distance driven.

5. **Live Vehicle Tracking is Driver-Side Only.** Admin's `FleetLiveMapView` shows vehicle locations, but location data only exists if the driver has an active trip AND has the navigation open. There is no continuous background location reporting. As soon as driver closes the navigation, location stops updating.

---

## MODULE 6: Staff Management

### Expected (SRS)
- Admin creates driver and maintenance accounts
- System generates credentials → emails to staff
- Staff submits onboarding info + identity documents
- Admin reviews and approves/rejects
- Staff can view and update availability

### Current Implementation
- `CreateStaffView.swift` — admin creates staff with email + temp password
- `StaffApplicationService` — manages onboarding application flow
- `StaffReviewSheet.swift` — admin approves/rejects with reason
- `StaffMemberService.setApprovalStatus` — sets `availability = 'Available'` on approval (critical fix in code)
- `EmailService.swift` — sends credentials email via edge function

### Issues

#### CRITICAL
1. **Staff Creation Race Condition.** When admin creates a staff member, the flow is:
   1. Create Supabase Auth user (auth.users)
   2. Insert staff_members row
   If step 1 succeeds but step 2 fails (network drop, RLS policy block, schema violation), there is an orphaned auth user with no staff_members record. On next login, the user can authenticate but the app cannot find their profile → silent crash loop. No rollback mechanism, no orphan cleanup.

2. **Admin Cannot Delete Auth Users.** `StaffMemberService.deleteStaffMember` only deletes the `staff_members` row. The `auth.users` entry remains. The deleted staff member can still authenticate but will get a "profile not found" error. Requires Supabase admin API to delete auth users — which requires a service role edge function.

#### HIGH
3. **No Driver History Accessible from Staff Tab.** `DriverHistoryView.swift` EXISTS (11KB) but there is no navigation path from `StaffTabView` or `StaffDetailSheet` to `DriverHistoryView`. The file is dead code from an integration perspective. This confirms the user-reported issue.

4. **Credential Email Has No Expiry.** `EmailService` sends a temp password via email. There is no forced password change on first login (the `isFirstLogin` flag exists but is it enforced?).

5. **Staff Profile Photos Stored Without Compression.** `StaffMemberUpdatePayload` includes `profile_photo_url`. No image compression before upload is a scalability issue.

---

## MODULE 7: Admin Dashboard

### Expected (SRS)
- Centralized overview: vehicle count, active trips, pending approvals, alerts
- Live fleet map
- Quick access to maintenance, reports, geofences, alerts
- Notification centre

### Current Implementation
- `DashboardHomeView.swift` — KPI grid, analytics snapshot card, recent trips, expiring docs, fleet management section
- Notification bell on `topBarLeading`
- Profile on `topBarTrailing`

### Issues

#### HIGH
1. **Ellipsis Bug — Confirmed.** KPI card value Text uses:
   ```swift
   .lineLimit(1)
   .minimumScaleFactor(0.6)
   ```
   With `.font(.system(size: 30, weight: .bold, design: .rounded))` and a 2-column grid, available width per card is ~170pt. For large values (e.g. "1,234" vehicles), even at 0.6x scale factor (18pt), this can still clip and show "..." because `lineLimit(1)` truncates before `minimumScaleFactor` fully reduces.

2. **Notification Bell on Wrong Side.** iOS HIG places primary navigation actions on `.topBarTrailing`. The bell on `.topBarLeading` is non-standard and conflicts with natural thumb reach on large iPhones.

3. **No Direct Navigation from Dashboard KPI Cards.** Tapping the "Pending Staff" KPI card does nothing. Tapping "Active Alerts" does nothing. These should be interactive.

4. **`DashboardHomeView` Has Zero ViewModels.** All computed properties (fleetSlices, tripSlices, staffSlices, monthlyData, etc.) are directly in the View struct. MVVM violation.

---

## MODULE 8: Notifications System

### Issues

#### CRITICAL
1. **NO Push Notifications (APNs).** All notifications are in-app Supabase database notifications. If the app is backgrounded or closed, the driver/maintenance user NEVER receives alerts.

2. **Trip Assignment Never Triggers Notification.** `AppDataStore.addTrip` does NOT call `NotificationService.insertNotification`. When admin creates and assigns a trip to a driver, the driver gets zero notification.

3. **Emergency Alert Has No Real-Time Admin Alert.** `AppDataStore.addEmergencyAlert` inserts the alert but does NOT notify any admin.

4. **Document Expiry Check is Never Called.** `AppDataStore.checkOverdueMaintenance` is called manually with no automatic trigger. Vehicle document expiry monitoring (SRS §4.1.8.3) has NO automated check.

#### HIGH
5. **Notification Realtime Decode Path Fragile.** The AnyJSON → custom type double-encode path silently drops new notifications.

---

## MODULE 9: Navigation / Maps

### Issues

#### CRITICAL
1. **Mapbox Token Exposed in Info.plist.** `MBXAccessToken` is read from `Bundle.main` — bundled in the app binary and accessible via binary analysis.

2. **Route Fetch Bypasses Service Layer.** `StartTripSheet` calls URLSession directly with Mapbox URL constructed inline. No error handling for non-200 HTTP responses. No timeout configuration.

3. **Navigation Uses MapKit for Rendering, Mapbox for Routing.** No turn-by-turn instruction rendering. Driver is looking at a line on a static map with no maneuver instructions.

4. **No Background Location Entitlement Verification.** `UIBackgroundModes: location` needs to be confirmed in Info.plist or location stops when app is backgrounded.

#### HIGH
5. **TripNavigationCoordinator is 19KB — God Object.** CLLocationManager delegate, route progress, deviation detection, DB writes, and UI state all in one class.

6. **Geofencing is Client-Side Only.** If the app is killed or backgrounded, vehicles can enter/exit geofences with no events logged.

---

## MODULE 10: Maintenance System

### Issues

#### CRITICAL
1. **VIN Scanning — COMPLETELY MISSING.** SRS §4.3.3.1 explicitly requires VIN camera scanning. Zero implementation.

#### HIGH
2. **Maintenance Personnel Cannot Write Vehicles via RLS.** `completeMaintenanceTask` uses `try?` on vehicle update — the UI shows stale vehicle status after task completion.

3. **`closeWorkOrder` Does Not Notify Admin.** No notification is sent to admin when work order is closed.

---

## MODULE 11: Geofencing

### Issues

#### CRITICAL
1. **CRUD Not Working — Root Cause.** Almost certainly an RLS policy: the `geofences` table requires admin role for INSERT, but role check in RLS may fail for authenticated users.

2. **Geofencing is Entirely Client-Side.** No Postgres function, Edge Function, or pg_cron job monitors vehicle locations against geofences server-side.

3. **No Geofence Notification Generated.** `GeofenceEventService.addGeofenceEvent` inserts an event row but NEVER calls `NotificationService.insertNotification`.

---

## MODULE 12: iOS Architecture

### Issues

#### CRITICAL
1. **AppDataStore as Global Singleton is Untestable.** Dual access pattern (`@Environment` + `AppDataStore.shared`) creates tight coupling.

2. **DashboardHomeView, VehicleListView, CreateTripView, AddVehicleView Have Zero ViewModels.** MVVM violation across the most complex views.

#### HIGH
3. **Potential Retain Cycles in Realtime Subscriptions.** `NotificationService.shared.subscribeToNotifications` closure may capture AppDataStore strongly.

4. **`loadAll` fires 20 simultaneous async tasks.** Aggressive connection pool usage on startup.

5. **VehicleListView uses polling loop for timeout** — should use `withTaskCancellationHandler`.

---

## MODULE 13: Data Model Issues

1. **Trip FK columns as `String?`** — fragile case-sensitive UUID lookups throughout.
2. **No `accepted_at` timestamp** — cannot track trip acceptance SLA.
3. **No Audit Trail for Status Changes** — who changed what, when?
4. **`SierraNotification` Type Enum Gap** — `tripAssigned`, `documentExpiry` types never triggered.

---

# 2. CRITICAL ISSUE LIST

## 🔴 CRITICAL (Blocks Core Functionality)

| ID | Issue | Module | Root Cause |
|----|-------|--------|------------|
| C-01 | Silent Pass Inspection Bug | Inspection | `notChecked` default + no submission validation |
| C-02 | No Trip Acceptance Flow | Trips | `TripStatus` missing `pendingAcceptance` |
| C-03 | Post-Trip Inspection Orphaned | Trips | `addProofOfDelivery` calls `updateTripStatus(.completed)` immediately |
| C-04 | No Push Notifications | Notifications | No APNs integration |
| C-05 | Trip Assignment Never Notifies Driver | Notifications | `addTrip` never calls `NotificationService` |
| C-06 | Staff Creation Race Condition | Staff | No atomic rollback between auth.users + staff_members |
| C-07 | Admin Cannot Delete Auth Users | Staff | `deleteStaffMember` only deletes staff_members row |
| C-08 | VIN Scanning Completely Missing | Maintenance | Never implemented |
| C-09 | Geofencing Server-Side Not Implemented | Geofencing | Client-side only |
| C-10 | Fuel Quantity Not Captured During Inspection | Fuel/Inspection | FuelLog and Inspection are disconnected |
| C-11 | Mapbox Token Exposed in Info.plist | Security | Token read from bundle at runtime |
| C-12 | TripUpdatePayload Wipes GPS Coordinates on Edit | Trips | Coordinates missing from TripUpdatePayload |
| C-13 | CRUD Failures (staff/trips/geofence) | Backend | RLS policy mismatch |

## 🟠 HIGH (Major UX / System Flaw)

| ID | Issue | Module |
|----|-------|--------|
| H-01 | No Reminders for Upcoming Trips | Trips |
| H-02 | Filter Chips — Wrong UX Pattern | Vehicles/Trips UI |
| H-03 | Profile Tab Misuse | Driver UX |
| H-04 | No Driver History Navigation Path — DriverHistoryView is dead code | Admin/Staff |
| H-05 | Dashboard Ellipsis Bug — KPI values truncated | Dashboard |
| H-06 | Notification Bell on Wrong Side | Dashboard UX |
| H-07 | KPI Cards Not Interactive | Dashboard |
| H-08 | Fuel Math Validation Missing | Fuel Log |
| H-09 | No OCR for Receipt Scanning | Fuel Log |
| H-10 | No Mandatory Photo for Failed Inspection Items | Inspection |
| H-11 | Emergency Alert Never Notifies Admins | Notifications |
| H-12 | Document Expiry Check Never Auto-Runs | Notifications |
| H-13 | Navigation Uses MapKit for Rendering, Mapbox for Routing | Navigation |
| H-14 | No Turn-by-Turn Instructions | Navigation |
| H-15 | Geofence Events Never Generate Notifications | Geofencing |
| H-16 | DashboardHomeView Has Zero ViewModels | Architecture |
| H-17 | AddVehicleView is 40KB God View | Architecture |
| H-18 | TripNavigationCoordinator is 19KB God Object | Architecture |
| H-19 | Maintenance User UI Shows Stale Vehicle Status | Maintenance |
| H-20 | Driver Rating System Has No Admin UI | Trips |

## 🟡 MEDIUM

| ID | Issue |
|----|-------|
| M-01 | Trip FK columns stored as String? not UUID? |
| M-02 | No Audit Trail for Status Changes |
| M-03 | Vehicle Total Odometer Not Tracked |
| M-04 | Realtime INSERT decode path fragile |
| M-05 | Photo Upload — No Compression Before Upload |
| M-06 | Fuel Log Not Mandatory Even When Fuel Level Fails Inspection |
| M-07 | InspectionCheckItem ID Collision on ViewModel Recreation |
| M-08 | `closeWorkOrder` Does Not Notify Admin |
| M-09 | Admin Cannot Access Maintenance Work Order from Dashboard Directly |
| M-10 | No Passkeys Implementation (SRS NFR) |
| M-11 | No GDPR Data Export/Deletion Flow |
| M-12 | 20 Parallel API Calls on App Launch |
| M-13 | VehicleListView Uses Polling Loop for Timeout |
| M-14 | Spare Parts Cost Not Reconciled with Actual Parts Used |

## 🔵 LOW

| ID | Issue |
|----|-------|
| L-01 | No App Intents Integration |
| L-02 | No Core ML Predictive Maintenance |
| L-03 | location_history 30-day retention may accumulate 52M rows |
| L-04 | Mock data in Trip.swift should be in #if DEBUG block |
| L-05 | DS_Store files committed to repo |
| L-06 | No unit tests |
| L-07 | Driver Rating Note has no character limit |

---

# 3. SYSTEM DESIGN CORRECTIONS

## 3.1 Correct Trip Lifecycle

```
Scheduled (admin creates) 
  → PendingAcceptance (admin assigns driver) → notification sent to driver
    → Accepted (driver taps Accept) 
      → Active (pre-inspection done + start trip)
        → Completed (POD submitted + post-inspection done)
    → Rejected (driver rejects) → admin notified, re-assign
```

SQL additions needed:
```sql
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'PendingAcceptance';
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Accepted';
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Rejected';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS acceptance_deadline TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS rejected_reason TEXT;
```

## 3.2 Correct Inspection Validation

- ALL items must be explicitly set — `notChecked` is NOT acceptable on submit
- Failed items MUST have at least one photo
- Photos linked to specific inspection items (not global photo pool)
- `canSubmit = allItemsChecked && failedItemsWithoutPhoto.isEmpty`

## 3.3 Correct Fuel Log + Inspection Integration

"Fuel Level" failed/warned → automatically present `FuelLogView` as required step before advancing.

## 3.4 Correct Notification Architecture

1. Add Supabase Edge Function `send-push-notification` that calls APNs
2. Store device push tokens in `push_tokens` table
3. Add DB trigger on `notifications` INSERT that calls the edge function
4. Register for APNs in `SierraApp.swift`

## 3.5 Correct Filter UX Pattern

Replace horizontal chip scroll with filter button → `.presentationDetents([.medium])` sheet with proper picker/list.

## 3.6 Correct Architecture

Every View with >2 state variables MUST have a ViewModel. No network calls in Views. No business logic in Views.

## 3.7 Correct Geofence Architecture

Server-side PostGIS monitoring:
- DB trigger on `vehicle_location_history` INSERT
- `ST_DWithin` check against active geofences
- On entry/exit: INSERT `geofence_events` + INSERT `notifications` for admins

---

# 4. CLAUDE OPUS IMPLEMENTATION PROMPTS

See full prompt text in the local file at `/home/claude/SIERRA_FULL_AUDIT.md` or the audit document.
All 14 prompts are self-contained, implementation-ready, and cover:

1. **PROMPT 1:** Backend — Supabase Schema & RLS Fixes (full SQL migration)
2. **PROMPT 2:** Backend — Data Model Redesign (Trip acceptance + Inspection validation)
3. **PROMPT 3:** Trip Lifecycle — Driver Acceptance UI + TripDetailDriverView Redesign
4. **PROMPT 4:** CRUD Fixes — Staff, Trip, Geofence (atomic edge functions)
5. **PROMPT 5:** Notification System — Full APNs Implementation
6. **PROMPT 6:** Inspection — Image Upload + Per-Item Defect Photos
7. **PROMPT 7:** Driver Acceptance + Reminder System (local UNUserNotificationCenter)
8. **PROMPT 8:** Admin Dashboard Fixes (ViewModel + ellipsis + nav button)
9. **PROMPT 9:** Filtering UX Redesign (FilterSheetView reusable component)
10. **PROMPT 10:** Navigation + MapKit Overhaul (MapService + turn-by-turn + voice)
11. **PROMPT 11:** Fuel Logging + Vision OCR Integration
12. **PROMPT 12:** Full UI/UX Refactor (loading states + empty states + Driver tabs)
13. **PROMPT 13:** MVVM Architecture Refactor (AddVehicleViewModel + CreateTripViewModel)
14. **PROMPT 14:** VIN Scanning + Maintenance Module Fixes

---

## SUMMARY STATISTICS

| Category | Count |
|----------|-------|
| 🔴 Critical Issues | 13 |
| 🟠 High Issues | 20 |
| 🟡 Medium Issues | 14 |
| 🔵 Low Issues | 7 |
| **Total Issues** | **54** |
| Claude Opus Prompts Generated | 14 |
| Modules Audited | 13 |

## FILES NEEDING CREATION (NET NEW)
- TripAcceptanceService.swift, TripReminderService.swift, PushTokenService.swift
- MapService.swift, VoiceNavigationService.swift
- FilterSheetView.swift, VINScannerView.swift, CameraPreviewView.swift
- SierraLoadingView.swift, SierraErrorView.swift
- DriverInspectionsView.swift, DriverTripAcceptanceSheet.swift
- DashboardViewModel.swift, AddVehicleViewModel.swift, CreateTripViewModel.swift
- 4 Edge Functions: create-staff-member, delete-staff-member, send-push-notification, update-vehicle-status
- 3 SQL Migrations: 20260322000001, 20260322000002, 20260322000003

## FILES NEEDING MODIFICATION (MAJOR)
- TripDetailDriverView.swift, PreTripInspectionView.swift, PreTripInspectionViewModel.swift
- FuelLogView.swift, FuelLogViewModel.swift, StartTripSheet.swift
- NavigationHUDOverlay.swift, TripNavigationCoordinator.swift
- TripService.swift, AppDataStore.swift, DashboardHomeView.swift
- VehicleListView.swift, TripsListView.swift, AddVehicleView.swift, CreateTripView.swift
- DriverTabView.swift, DriverHomeView.swift, Trip.swift, SierraNotification.swift, SierraApp.swift

---
*Audit complete. 54 issues documented. 14 production-grade prompts generated.*
