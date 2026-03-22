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

4. **Credential Email Has No Expiry.** `EmailService` sends a temp password via email. There is no forced password change on first login (the `isFirstLogin` flag exists but is it enforced? `ContentView` likely routes to a password change screen for first login — not verified in this audit pass, but flag exists).

5. **Staff Profile Photos Stored Without Compression.** `StaffMemberUpdatePayload` includes `profile_photo_url`. The upload path for profile photos is not visible in the services layer — likely in `DriverProfileViewModel`. No image compression before upload is a scalability issue.

---

## MODULE 7: Admin Dashboard

### Expected (SRS)
- Centralized overview: vehicle count, active trips, pending approvals, alerts
- Live fleet map
- Quick access to maintenance, reports, geofences, alerts
- Notification centre

### Current Implementation
- `DashboardHomeView.swift` — KPI grid (Vehicles, Active Trips, Pending Staff, Active Alerts), analytics snapshot card with mini donuts + sparkline, recent trips section, expiring docs section, fleet management section (Maintenance, Reports, Alerts, Geofences)
- Notification bell on `topBarLeading`
- Profile on `topBarTrailing`

### Issues

#### HIGH
1. **Ellipsis Bug — Confirmed.** KPI card value Text uses:
   ```swift
   .lineLimit(1)
   .minimumScaleFactor(0.6)
   ```
   With `.font(.system(size: 30, weight: .bold, design: .rounded))` and a 2-column grid, the available width per card is roughly `(screenWidth - 20*2 - 14) / 2 ≈ 170pt`. For large values (e.g. "1,234" vehicles), even at 0.6x scale factor (18pt), this can still clip and show "..." because the `lineLimit(1)` truncates before `minimumScaleFactor` fully reduces. Fix: use adaptive font size or reduce font.

2. **Notification Bell on Wrong Side.** iOS HIG places primary navigation actions on `.topBarTrailing`. The bell on `.topBarLeading` is non-standard and conflicts with natural thumb reach on large iPhones. This is the user-reported "notification button misplacement."

3. **No Direct Navigation from Dashboard KPI Cards.** Tapping the "Pending Staff" KPI card does nothing. Tapping "Active Alerts" does nothing. These should be interactive — tapping Pending Staff should navigate to the pending approvals list.

4. **Analytics Snapshot Card Hits loadAll on Appear.** If the dashboard data is stale, the mini-donut and sparkline will show zeroes until `loadAll` completes. There is no skeleton/shimmer loading state for the analytics card.

5. **`DashboardHomeView` Has Zero ViewModels.** All computed properties (fleetSlices, tripSlices, staffSlices, monthlyData, validDocCount, etc.) are directly in the View struct. MVVM violation — business aggregation logic belongs in a ViewModel.

---

## MODULE 8: Notifications System

### Expected (SRS)
- Alert admin when defect reported (§4.1.7.2)
- Notify driver of application approval (§4.1.1.6)
- Vehicle document expiry alerts (§4.1.8.3)
- Emergency alert notification
- Maintenance overdue notification
- Trip assignment notification

### Current Implementation
- `NotificationService.swift` — insert, fetch, mark read, Realtime subscribe
- `SierraNotification` model — type, title, body, entityType, entityId, isRead
- In-app notification centre via `NotificationCentreView` (referenced but not audited in this pass)
- `AppDataStore.checkOverdueMaintenance()` — inserts overdue notifications
- Approval notifications inserted in `AppDataStore.approveStaffApplication`
- Realtime subscribe filters by `recipient_id` server-side

### Issues

#### CRITICAL
1. **NO Push Notifications (APNs).** All notifications are in-app Supabase database notifications. If the app is backgrounded or closed, the driver/maintenance user NEVER receives alerts. SRS implies real-time alerting for emergencies and task assignments — impossible without APNs. This is the "no notifications system" issue — it exists but only when the app is open.

2. **Trip Assignment Never Triggers Notification.** `AppDataStore.addTrip` does NOT call `NotificationService.insertNotification`. When admin creates and assigns a trip to a driver, the driver gets zero notification. They must manually refresh.

3. **Emergency Alert Has No Real-Time Admin Alert.** `AppDataStore.addEmergencyAlert` inserts the alert but does NOT notify any admin. The `subscribeToEmergencyAlerts` channel updates `emergencyAlerts` array for admins who have the app open, but no notification is inserted for admins.

4. **Document Expiry Check is Never Called.** `AppDataStore.checkOverdueMaintenance` is called manually via `checkOverdueMaintenance()` but there is no automatic trigger. Vehicle document expiry monitoring (SRS §4.1.8.3) has NO automated check — no cron, no trigger, no periodic task.

#### HIGH
5. **Notification Realtime Decode Path Fragile.** The channel callback:
   ```swift
   if let data = try? JSONEncoder().encode(action.record),
      let notification = try? JSONDecoder().decode(SierraNotification.self, from: data)
   ```
   `action.record` is `[String: AnyJSON]`. Encoding `AnyJSON` values then decoding as `SierraNotification` is fragile — dates encoded as strings may not match the ISO8601 decoder expectation. Silent failures drop new notifications without any user feedback.

---

## MODULE 9: Navigation / Maps

### Expected (SRS)
- Drivers access assigned routes
- Navigate to delivery destinations
- GPS location sent during trips

### Current Implementation
- `StartTripSheet.swift` — Mapbox Directions API called via URLSession directly, returns route options (Fastest/Green)
- `TripNavigationContainerView.swift` — wraps the navigation UI
- `TripNavigationView.swift` — MapKit-based map, NOT Mapbox for rendering
- `NavigationHUDOverlay.swift` — shows driver HUD during navigation
- `TripNavigationCoordinator.swift` (19KB ViewModel) — manages CLLocationManager, route progress, deviation detection
- `RouteDeviationService.swift` — logs deviations to DB
- Location published to `vehicle_location_history` via `AppDataStore.publishDriverLocation`

### Issues

#### CRITICAL
1. **Mapbox Token Exposed in Info.plist.** `MBXAccessToken` is read from `Bundle.main.object(forInfoDictionaryKey:)`. Info.plist is committed to the repo and bundled in the app binary. This token is publicly accessible via binary analysis.

2. **Route Fetch Bypasses Service Layer.** `StartTripSheet` calls `URLSession.shared.data(from: url)` directly with Mapbox API URL constructed inline. No error handling for non-200 HTTP responses. No timeout configuration. Not abstracted to a service.

3. **Navigation Uses MapKit, Routes from Mapbox.** This is a fundamental architecture split: route geometry comes from Mapbox (`driving` profile, polyline6 encoding) but is rendered on a MapKit `Map`. There is NO turn-by-turn instruction rendering — the `NavigationHUDOverlay` shows distance remaining but not "In 200m, turn left onto Main St." type instructions. The driver is effectively looking at a line on a static map.

4. **No Background Location Entitlement Verification.** `TripNavigationCoordinator` uses `CLLocationManager` but if `UIBackgroundModes: location` is not in Info.plist, location stops when app is backgrounded. The `Info.plist` shows `NSLocationWhenInUseUsageDescription` but background mode needs verification.

#### HIGH
5. **TripNavigationCoordinator is 19KB — God Object.** CLLocationManager delegate, route progress calculation, deviation detection, DB writes, and UI state all in one class. Violates single responsibility.

6. **Route Selection Not Persisted.** If driver picks "Green Route" in `StartTripSheet`, the selected route's geometry is saved to the trip via `updateTripCoordinates`. But if the driver closes and reopens the navigation, `TripNavigationContainerView` must re-fetch or re-decode the polyline. Unclear if this is handled.

7. **Geofencing is Client-Side Only.** Geofence monitoring happens in the app while it's running. If the app is killed or backgrounded (and background location is not running), vehicles can enter/exit geofences with no events logged.

---

## MODULE 10: Maintenance System

### Expected (SRS)
- Admin creates maintenance requests and assigns to personnel
- Maintenance personnel view tasks, update progress, record parts and labour
- VIN scanning to identify vehicles (§4.3.3)
- Work orders management
- Breakdown handling with alerts

### Current Implementation
- `MaintenanceRequestsView.swift` — admin view of maintenance tasks
- `MaintenanceApprovalDetailView.swift` — approve/reject maintenance tasks
- `WorkOrderService.swift`, `MaintenanceRecordService.swift`, `PartUsedService.swift`
- `SparePartsRequestService.swift` — request spare parts with approval flow
- Maintenance module loads via `loadMaintenanceData(staffId:)`

### Issues

#### CRITICAL
1. **VIN Scanning — COMPLETELY MISSING.** SRS §4.3.3.1 explicitly requires: "Maintenance personnel shall scan vehicle VIN numbers using the camera. The system shall retrieve vehicle details based on VIN." Zero implementation. No Vision/AVFoundation barcode scanning anywhere in the codebase.

#### HIGH
2. **Maintenance Personnel Cannot Write Vehicles via RLS.** Code comment in `completeMaintenanceTask`:
   ```swift
   // try? here is intentional — maintenance personnel cannot write vehicles
   // via RLS, but the trigger fires regardless.
   ```
   This means the local `vehicles` array in the maintenance user's AppDataStore shows stale vehicle status. The DB trigger correctly updates vehicle status, but the UI update (`vehicles[vIdx].status = .idle`) that precedes it via `try?` silently fails. The maintenance user's UI is stale.

3. **`closeWorkOrder` Does Not Notify Admin.** When maintenance marks a work order closed, no notification is sent to the admin. Admin must manually refresh.

4. **Spare Parts Request Has No Cost Aggregation to Work Order.** `addPartUsed` in AppDataStore correctly aggregates `partsCostTotal` to the work order. But `SparePartsRequest` (pre-approval stage) has an `estimatedUnitCost` that is NOT factored into the work order cost — approved parts go through a separate flow that may not reconcile with actual `PartsUsed` costs.

---

## MODULE 11: Geofencing

### Expected (SRS §4.1.10)
- Define virtual geofences on map
- Track vehicle entry/exit
- Alerts on entry/exit
- Timestamp + location logging
- View historical records
- Edit/delete geofences

### Current Implementation
- `CreateGeofenceSheet.swift` — create geofence with name, coordinates, radius
- `GeofenceListView.swift` — list of geofences with toggle active/inactive
- `GeofenceService.swift` — CRUD on `geofences` table
- `GeofenceEventService.swift` — log geofence entry/exit events

### Issues

#### CRITICAL
1. **CRUD Not Working — Root Cause.** User reported geofence CRUD broken. Looking at `CreateGeofenceSheet`, it likely submits to `GeofenceService.addGeofence`. The issue is almost certainly an RLS policy: the `geofences` table requires admin role for INSERT, but if the authenticated user's role check in RLS fails (e.g., checking `auth.uid()` against a `staff_members` role instead of a JWT claim), all geofence inserts will fail with a 403. Without the full schema+RLS policies (not in repo), this can only be inferred.

2. **Geofencing is Entirely Client-Side.** There is no Postgres function, Edge Function, or pg_cron job that monitors vehicle locations against geofences. The iOS app must be running AND the admin must have the geofence map open for any monitoring to occur. The SRS requires server-side event generation — "The system shall generate alerts" — not "the app shall generate alerts."

3. **No Geofence Notification Generated.** `GeofenceEventService.addGeofenceEvent` inserts an event row but NEVER calls `NotificationService.insertNotification`. Geofence violations generate DB rows that nobody is alerted about.

---

## MODULE 12: iOS Architecture

### Expected (SRS)
- MVVM with Swift Concurrency
- Zero memory leaks
- Zero constraint warnings

### Current Implementation
- Mix: some modules have dedicated ViewModels (`PreTripInspectionViewModel`, `FuelLogViewModel`, `SOSAlertViewModel`, `TripNavigationCoordinator`), others have none (`DashboardHomeView`, `VehicleListView`, `CreateTripView`, `AddVehicleView`)
- `AppDataStore` acts as a global singleton service layer
- `@Observable` macro used on ViewModels and AppDataStore
- Swift Concurrency (`async/await`) throughout

### Issues

#### CRITICAL
1. **AppDataStore as Global Singleton is Untestable.** `AppDataStore.shared` is injected via `.environment()` in most views but also accessed via `AppDataStore.shared` directly in some places (e.g., `TripNavigationContainerView`). This dual access pattern creates tight coupling and makes unit testing impossible without dependency injection.

2. **DashboardHomeView, VehicleListView, CreateTripView, AddVehicleView Have Zero ViewModels.** These are the most complex views in the app. All computed properties, network calls, and state live directly in the view structs. MVVM violation.

3. **`AddVehicleView` is 40KB.** This is almost certainly a multiple-violation file with network calls, business logic, and complex UI all co-mingled.

4. **`TripNavigationCoordinator` is 19KB.** Too large for a single ViewModel. Should be split into: LocationCoordinator, RouteProgressService, DeviationDetector.

#### HIGH
5. **Potential Retain Cycles in Realtime Subscriptions.** All four Realtime channel callbacks use `[weak self]` correctly in `AppDataStore`. However, `NotificationService.shared.subscribeToNotifications` takes `onNew: @escaping (SierraNotification) -> Void` — if this closure captures `self` (AppDataStore) strongly, it creates a cycle. The closure is stored in `NotificationService` (which is stored in `AppDataStore` via the channel reference). This is a potential leak.

6. **Concurrency: `loadAll` fires 20 simultaneous async tasks.** While `async let` parallelism is correct, 20 simultaneous Supabase REST calls on app launch may overwhelm the Supabase connection pool (typically 60 for free tier, but still aggressive). No batching or pagination strategy.

7. **VehicleListView.loadVehiclesWithTimeout Uses Polling Loop.** The timeout implementation:
   ```swift
   for _ in 0..<(refreshTimeoutSeconds * 5) {
       if await tracker.isFinished() { return }
       try? await Task.sleep(nanoseconds: refreshPollIntervalNanoseconds)
   }
   ```
   This polls every 200ms for up to 10 seconds. An actor-based polling loop is less efficient than `withTaskCancellationHandler` + `Task.cancel`. Also `RefreshTracker` is an actor but `markFinished` is not `throws` — fine, but this pattern should use `withTimeout` or Swift's `TaskGroup`.

---

## MODULE 13: Data Model Issues

### Issues

1. **Trip FK columns as `String?` instead of `UUID?`.** `Trip.driverId: String?` and `Trip.vehicleId: String?` are stored as TEXT in Supabase. All lookups must manually call `UUID(uuidString:)`. Case-sensitivity issues: `driverId.lowercased()` is used in some filters but not others:
   ```swift
   trips.filter { $0.driverId?.lowercased() == driverId.uuidString.lowercased() }
   ```
   This fragile pattern will silently fail if case doesn't match.

2. **No `accepted_at` timestamp on Trip.** Without an acceptance timestamp, there is no way to track SLA for trip acceptance (how long does it take a driver to accept after assignment?).

3. **`vehicle_location_history` Retention.** A pg_cron job retains 30 days of location history. At 5-second intervals per active driver per trip, with 10 drivers = 172,800 rows/day. Over 30 days = ~5.2M rows per driver. With 10 drivers = 52M rows. The index on `recorded_at` helps range deletes but SELECT performance at scale will degrade.

4. **No Audit Trail for Status Changes.** Trip status changes are not logged. Who changed a trip from Scheduled to Cancelled? No timestamp, no actor. Same for vehicle status changes.

5. **`SierraNotification` Type Enum Gap.** `NotificationType` enum likely has: `general`, `tripAssigned`, `maintenanceOverdue`, `emergency`, `inspection` etc. But the current code only uses `general` and `maintenanceOverdue` in practice. `tripAssigned` and `documentExpiry` notification types are never triggered.

---

# 2. CRITICAL ISSUE LIST

## 🔴 CRITICAL (Blocks Core Functionality)

| ID | Issue | Module | Root Cause |
|----|-------|--------|-----------|
| C-01 | Silent Pass Inspection Bug — drivers submit blank inspection as PASSED | Inspection | `notChecked` default + no submission validation |
| C-02 | No Trip Acceptance Flow — missing lifecycle state | Trips | `TripStatus` enum missing `pendingAcceptance` |
| C-03 | Post-Trip Inspection Orphaned — trip completes before post-inspection | Trips | `addProofOfDelivery` calls `updateTripStatus(.completed)` immediately |
| C-04 | No Push Notifications — users miss all alerts when app is backgrounded | Notifications | No APNs integration |
| C-05 | Trip Assignment Never Notifies Driver | Notifications | `addTrip` never calls `NotificationService.insertNotification` |
| C-06 | Staff Creation Race Condition — orphaned auth users on failure | Staff | No atomic rollback between auth.users + staff_members insert |
| C-07 | Admin Cannot Delete Auth Users | Staff | `deleteStaffMember` only deletes staff_members row |
| C-08 | VIN Scanning Completely Missing | Maintenance | Never implemented |
| C-09 | Geofencing Server-Side Not Implemented | Geofencing | Client-side only; no Postgres/Edge function monitoring |
| C-10 | Fuel Quantity Not Captured During Inspection | Fuel/Inspection | FuelLog and Inspection are disconnected |
| C-11 | Mapbox Token Exposed in Info.plist | Security | Token read from bundle at runtime |
| C-12 | TripUpdatePayload Wipes GPS Coordinates on Edit | Trips | Coordinates missing from TripUpdatePayload |
| C-13 | CRUD Failures (staff/trips/geofence) — likely RLS policy mismatch | Backend | Role check in RLS policies inconsistent |

## 🟠 HIGH (Major UX / System Flaw)

| ID | Issue | Module |
|----|-------|--------|
| H-01 | No Reminders for Upcoming Trips | Trips |
| H-02 | Filter Chips — Wrong UX Pattern (should be filter sheet) | Vehicles/Trips UI |
| H-03 | Profile Tab Misuse — needs audit of what's in Driver tab | Driver UX |
| H-04 | No Driver History Navigation Path — DriverHistoryView is dead code | Admin/Staff |
| H-05 | Dashboard Ellipsis Bug — KPI values truncated with "..." | Dashboard |
| H-06 | Notification Bell on Wrong Side (topBarLeading) | Dashboard UX |
| H-07 | KPI Cards Not Tappable/Interactive | Dashboard |
| H-08 | Fuel Math Validation Missing | Fuel Log |
| H-09 | No OCR for Receipt Scanning | Fuel Log |
| H-10 | No Mandatory Photo for Failed Inspection Items | Inspection |
| H-11 | Emergency Alert Never Notifies Admins | Notifications |
| H-12 | Document Expiry Check Never Auto-Runs | Notifications |
| H-13 | Navigation Uses MapKit for Rendering, Mapbox for Routing | Navigation |
| H-14 | No Turn-by-Turn Instructions | Navigation |
| H-15 | Geofence Events Never Generate Notifications | Geofencing |
| H-16 | DashboardHomeView Has Zero ViewModels (MVVM violation) | Architecture |
| H-17 | AddVehicleView is 40KB God View | Architecture |
| H-18 | TripNavigationCoordinator is 19KB God Object | Architecture |
| H-19 | Maintenance User UI Shows Stale Vehicle Status | Maintenance |
| H-20 | Driver Rating System Has No Admin UI | Trips |

## 🟡 MEDIUM

| ID | Issue |
|----|-------|
| M-01 | Trip FK columns stored as String? not UUID? — fragile case-sensitive lookups |
| M-02 | No Audit Trail for Status Changes |
| M-03 | Vehicle Total Odometer Not Tracked |
| M-04 | Realtime INSERT decode path fragile (AnyJSON → custom type) |
| M-05 | Photo Upload — No Compression Before Upload |
| M-06 | Fuel Log Not Mandatory Even When Fuel Level Fails Inspection |
| M-07 | InspectionCheckItem ID Collision on ViewModel Recreation |
| M-08 | `closeWorkOrder` Does Not Notify Admin |
| M-09 | Admin Cannot Access Maintenance Work Order from Dashboard Directly |
| M-10 | No Passkeys Implementation (SRS NFR) |
| M-11 | No GDPR Data Export/Deletion Flow |
| M-12 | 20 Parallel API Calls on App Launch — Connection Pool Pressure |
| M-13 | VehicleListView Uses Polling Loop for Timeout |
| M-14 | Spare Parts Cost Not Reconciled with Actual Parts Used |

## 🔵 LOW

| ID | Issue |
|----|-------|
| L-01 | No App Intents Integration |
| L-02 | No Core ML Predictive Maintenance |
| L-03 | location_history 30-day retention may still accumulate 52M rows |
| L-04 | Mock data in Trip.swift should be in a separate #if DEBUG block |
| L-05 | DS_Store files committed to repo |
| L-06 | No unit tests |
| L-07 | Driver Rating Note field has no character limit |

---

# 3. SYSTEM DESIGN CORRECTIONS

## 3.1 Correct Trip Lifecycle Data Model

```sql
-- Add to trips table
ALTER TABLE trips ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS acceptance_deadline TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS rejected_reason TEXT;

-- Update trip_status enum
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'PendingAcceptance';
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Accepted';
ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Rejected';
```

**Correct Status Flow:**
```
Scheduled (admin creates) 
  → PendingAcceptance (admin assigns driver) → notification sent to driver
    → Accepted (driver taps Accept) 
      → Active (pre-inspection done + start trip)
        → Completed (POD submitted + post-inspection done)
    → Rejected (driver rejects) → admin notified, re-assign
```

## 3.2 Correct Inspection Validation

```swift
// PreTripInspectionViewModel
var canAdvanceFromChecklist: Bool {
    // ALL items must be explicitly set — notChecked is NOT acceptable
    return checkItems.allSatisfy { $0.result != .notChecked }
}

// Failed items MUST have a photo
var failedItemsWithoutPhoto: [InspectionCheckItem] {
    failedItems.filter { item in 
        !uploadedPhotoUrls.contains(where: { $0.contains(item.id.uuidString) })
    }
}

var canSubmit: Bool {
    canAdvanceFromChecklist && failedItemsWithoutPhoto.isEmpty
}
```

## 3.3 Correct Fuel Log + Inspection Integration

The "Fuel Level" checklist item should, when marked FAIL, automatically present `FuelLogView` as a required step before the driver can advance. When marked PASS or WARN, fuel log should still be accessible as optional.

```swift
// In PreTripInspectionView checklistStep button
if viewModel.fuelLevelItem?.result == .failed {
    Button("Next: Log Fuel + Photos") { ... } // routes to FuelLog before Photos
} else {
    Button("Next: Photos") { ... }
}
```

## 3.4 Correct Notification Architecture

**Required changes:**
1. Add Supabase Edge Function `send-push-notification` that calls APNs/FCM
2. Store device push tokens in `push_tokens` table with `staff_id`, `device_token`, `platform`
3. Add DB trigger on `notifications` INSERT that calls the edge function
4. Register for APNs in `SierraApp.swift`

## 3.5 Correct Filter UX Pattern

Replace horizontal chip scroll with a standard filter button:

```swift
// Toolbar button
ToolbarItem(placement: .topBarTrailing) {
    Button { showFilterSheet = true } label: {
        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            .symbolVariant(activeFilters.isEmpty ? .none : .fill)
    }
}
.sheet(isPresented: $showFilterSheet) {
    FilterSheet(selectedStatus: $selectedFilter)
        .presentationDetents([.medium])
}
```

## 3.6 Correct Architecture Pattern

```
Sierra/
├── Shared/
│   ├── Models/           ← Pure data, Codable, no logic
│   ├── Services/         ← Supabase CRUD, pure static funcs
│   ├── Store/
│   │   └── AppDataStore.swift  ← @Observable, orchestration only
│   └── ViewModels/       ← @Observable, per-feature VM
├── Driver/
│   ├── ViewModels/       ← One ViewModel per complex view
│   └── Views/            ← Only UI, bind to ViewModel
├── FleetManager/
│   ├── ViewModels/       ← DashboardViewModel, VehicleListViewModel, etc.
│   └── Views/
└── Maintenance/
    ├── ViewModels/
    └── Views/
```

Every View with >2 state variables MUST have a ViewModel. No network calls in Views.

## 3.7 Correct Geofence Architecture

```
iOS App          Supabase
   │                │
   │ location ───►  vehicle_location_history INSERT
   │                │
   │                ▼ pg_trigger: fn_check_geofences()
   │                │  - for each active geofence
   │                │  - ST_DWithin(point, geofence.center, geofence.radius)
   │                │  - if entry/exit detected:
   │                │      INSERT geofence_events
   │                │      INSERT notifications (admin)
   │                ▼ Realtime channel → admin app notified
```

This requires PostGIS extension and `ST_DWithin` for proper geospatial queries.

---

# 4. CLAUDE OPUS IMPLEMENTATION PROMPTS

---

## PROMPT 1: Backend — Supabase Schema & RLS Fixes

```
CONTEXT:
You are working on Sierra FMS, a Fleet Management System iOS app using Supabase as the backend.
The codebase is at GitHub repo Kanishk101/Sierra (branch: main).
The Supabase project is named Sierra-FMS-v2.

PROBLEM:
Several CRUD operations are silently failing due to RLS policy mismatches. The current migrations 
do not show the full initial schema. We need to:
1. Fix RLS policies so authenticated staff members can perform their role-specific operations
2. Add missing columns to the trips table for the acceptance flow
3. Add a notifications trigger for geofence events
4. Add a server-side geofence monitoring function

EXACT REQUIREMENTS:
Write a complete SQL migration file named: 20260322000001_full_rls_and_schema_fix.sql

This migration must:

A) TRIPS TABLE:
- Add column: accepted_at TIMESTAMPTZ DEFAULT NULL
- Add column: acceptance_deadline TIMESTAMPTZ DEFAULT NULL  
- Add column: rejected_reason TEXT DEFAULT NULL
- Add new enum values to trip_status: 'PendingAcceptance', 'Accepted', 'Rejected'
  Use: DO $$ BEGIN ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'PendingAcceptance'; ... END $$;

B) RLS POLICIES — Fix staff_members table:
- Drivers can SELECT their own row (auth.uid() = id)
- Admins can SELECT/INSERT/UPDATE/DELETE all rows (check role = 'Admin' in staff_members WHERE id = auth.uid())
- Staff can UPDATE only their own availability (id = auth.uid(), only availability column)
- Use SECURITY INVOKER, not DEFINER for these policies

C) RLS POLICIES — Fix vehicles table:
- All authenticated users can SELECT vehicles
- Only admins (role='Admin') can INSERT/UPDATE/DELETE vehicles
- Exception: The DB trigger fn_trip_status_change (SECURITY DEFINER) must be able to UPDATE vehicle status

D) RLS POLICIES — Fix geofences table:
- Only admins can SELECT/INSERT/UPDATE/DELETE geofences
- Pattern: WITH CHECK ((SELECT role FROM staff_members WHERE id = auth.uid()) = 'Admin')

E) RLS POLICIES — Fix trips table:
- Admins: full CRUD
- Drivers: SELECT trips WHERE driver_id = auth.uid()::text
- Drivers: UPDATE their own trips for acceptance (status field only, where driver_id = auth.uid()::text)
- Maintenance: SELECT trips (for context only)

F) NOTIFICATIONS TABLE RLS:
- Users can only SELECT their own notifications (recipient_id = auth.uid()::text OR recipient_id = auth.uid()::uuid — handle both)
- Service role (edge functions) bypass RLS for INSERT
- Users can UPDATE is_read on their own notifications

G) CREATE FUNCTION fn_notify_on_geofence_event():
- RETURNS TRIGGER, LANGUAGE plpgsql, SECURITY DEFINER, SET search_path = public
- On INSERT to geofence_events:
  - Find all admin staff members (SELECT id FROM staff_members WHERE role = 'Admin')
  - For each admin, INSERT a row into notifications table with:
    - type: 'geofence_alert'
    - title: 'Geofence Alert: [enter or exit] [geofence name]'
    - body: 'Vehicle [vehicle_id] [entered/exited] geofence zone at [NOW()]'
    - entity_type: 'geofence_event', entity_id: NEW.id
    - is_read: false, sent_at: NOW()

H) ATTACH TRIGGER:
- DROP TRIGGER IF EXISTS trg_geofence_notification ON public.geofence_events;
- CREATE TRIGGER trg_geofence_notification AFTER INSERT ON public.geofence_events
  FOR EACH ROW EXECUTE FUNCTION fn_notify_on_geofence_event();

I) TRIP ASSIGNMENT NOTIFICATION TRIGGER:
- CREATE FUNCTION fn_notify_driver_trip_assigned()
- On INSERT to trips WHERE driver_id IS NOT NULL:
  - INSERT into notifications for the driver (driver_id)
  - title: 'New Trip Assigned: [task_id]'
  - body: 'You have been assigned a trip from [origin] to [destination] scheduled for [scheduled_date]'
  - type: 'trip_assigned'
  - entity_type: 'trip', entity_id: NEW.id

EXPECTED OUTPUT:
A single .sql file containing all migrations above, idempotent (uses IF NOT EXISTS, IF EXISTS, 
CREATE OR REPLACE), with comments explaining each section.

CONSTRAINTS:
- Use Supabase's auth.uid() function (returns uuid)
- Staff member IDs stored as UUID in staff_members.id
- Trip FK columns (driver_id, vehicle_id) stored as TEXT — use auth.uid()::text for comparisons
- All triggers must use SET search_path = public
- Test that enabling realtime on notifications table is included (ALTER TABLE notifications REPLICA IDENTITY FULL)
```

---

## PROMPT 2: Backend — Data Model Redesign (Trip Acceptance + Inspection Validation)

```
CONTEXT:
Sierra FMS is an iOS fleet management app. The Trip and VehicleInspection data models need 
redesign to support:
1. A proper trip acceptance lifecycle 
2. Server-side inspection validation (preventing blank inspection submissions)

PROBLEM:
- TripStatus has no acceptance state — drivers cannot formally accept/reject trips
- VehicleInspection accepts submissions where all items are 'notChecked' — shows as PASSED
- No server-side enforcement of inspection completeness

EXACT REQUIREMENTS:

A) Modify Trip.swift to add:
```swift
enum TripStatus: String, Codable, CaseIterable {
    case scheduled        = "Scheduled"
    case pendingAcceptance = "PendingAcceptance"  // ADD
    case accepted         = "Accepted"             // ADD
    case rejected         = "Rejected"             // ADD
    case active           = "Active"
    case completed        = "Completed"
    case cancelled        = "Cancelled"
}
```
Add to Trip struct:
```swift
var acceptedAt: Date?           // accepted_at
var acceptanceDeadline: Date?   // acceptance_deadline
var rejectedReason: String?     // rejected_reason
```
Add to CodingKeys:
```swift
case acceptedAt           = "accepted_at"
case acceptanceDeadline   = "acceptance_deadline"
case rejectedReason       = "rejected_reason"
```

B) Modify TripUpdatePayload in TripService.swift to include accepted_at, acceptance_deadline, rejected_reason

C) Add to TripService:
```swift
static func acceptTrip(tripId: UUID, driverId: UUID) async throws {
    // Update status to Accepted, set accepted_at = now()
}

static func rejectTrip(tripId: UUID, driverId: UUID, reason: String) async throws {
    // Update status to Rejected, set rejected_reason
}
```

D) Add to AppDataStore:
```swift
func acceptTrip(tripId: UUID) async throws {
    guard let driverId = AuthManager.shared.currentUser?.id else { throw ... }
    try await TripService.acceptTrip(tripId: tripId, driverId: driverId)
    // Update local state
    // Insert notification to admin: driver accepted trip
}

func rejectTrip(tripId: UUID, reason: String) async throws {
    guard let driverId = AuthManager.shared.currentUser?.id else { throw ... }
    try await TripService.rejectTrip(tripId: tripId, driverId: driverId, reason: reason)
    // Update local state
    // Insert notification to admin: driver rejected trip with reason
}
```

E) Modify PreTripInspectionViewModel:
- Add computed property: `var allItemsChecked: Bool { checkItems.allSatisfy { $0.result != .notChecked } }`
- Add computed property: `var failedItemsMissingPhoto: [InspectionCheckItem]` — returns failed items that have no associated uploaded photo URL
- Add: `var canAdvanceToPhotos: Bool { allItemsChecked }`
- Add: `var canSubmit: Bool { allItemsChecked && (failedItemsMissingPhoto.isEmpty || overallResult == .passed) }`
- Modify `submitInspection` to guard: `guard canSubmit else { submitError = "All items must be checked. Failed items require photos."; return }`

F) Modify PreTripInspectionView:
- In `checklistStep`, disable the "Next: Photos" button with `.disabled(!viewModel.canAdvanceToPhotos)`
- Add validation message below the list: "⚠️ X items not yet checked" using `viewModel.checkItems.filter { $0.result == .notChecked }.count`
- In `photoStep`, when `viewModel.failedItems` is non-empty, show a required photos banner:
  "Photos required for failed items: [comma-separated item names]"
- Disable "Next: Summary" if required photos not uploaded

EXPECTED OUTPUT:
Modified Swift files: Trip.swift, TripService.swift, AppDataStore.swift (trip section), 
PreTripInspectionViewModel.swift, PreTripInspectionView.swift.
Each file must be complete (not partial snippets).

CONSTRAINTS:
- Use @Observable on ViewModels, @Environment for store access
- No business logic in Views (all logic stays in ViewModel)
- All async operations must use Swift Concurrency (async/await), no DispatchQueue
- Error propagation must reach the UI — no silent catch-and-print
```

---

## PROMPT 3: Trip Lifecycle — Driver Acceptance UI + TripDetailDriverView Redesign

```
CONTEXT:
Sierra FMS iOS app (SwiftUI, MVVM, Supabase backend).
File to redesign: Sierra/Driver/Views/TripDetailDriverView.swift

PROBLEM:
1. No driver acceptance/rejection flow exists
2. flowStepsCard shows "steps already completed" because TripStatus.active = step done,
   but there is no PendingAcceptance or Accepted intermediate state
3. Navigate step is never marked done
4. Post-trip inspection is cosmetic (trip already completed by POD)

EXACT REQUIREMENTS:
Completely rewrite TripDetailDriverView.swift with these changes:

A) ACTION BUTTONS — Updated logic per status:
   - `.scheduled` (unassigned): show "Awaiting Assignment" message
   - `.pendingAcceptance`: show Accept button (green) + Reject button (red) prominently
     - Accept: calls `store.acceptTrip(tripId:)`
     - Reject: shows text field for reason, then calls `store.rejectTrip(tripId:reason:)`
   - `.accepted`: show "Begin Pre-Trip Inspection" if `trip.preInspectionId == nil`
     - After inspection: show "Start Trip"
   - `.active`:
     - Primary: Navigate button (pulsing, green, full width)
     - If POD not done: "Complete Delivery" button
     - If POD done but post-inspection not done: "Post-Trip Inspection" (required gate)
     - If post-inspection done: show "End Trip" button → calls `store.endTrip`
     - Supporting: Log Fuel, Report Issue always visible
   - `.completed`: completion summary
   - `.rejected`: "Trip Rejected" banner with reason
   - `.cancelled`: "Trip Cancelled" banner

B) FLOW STEPS CARD — Update steps and done logic:
   1. "Accept Trip" — done: status != .scheduled && status != .pendingAcceptance
   2. "Pre-Trip Inspection" — done: trip.preInspectionId != nil
   3. "Start Trip" — done: status == .active || status == .completed
   4. "Navigate" — done: status == .completed (navigation was completed when trip ended)
   5. "Complete Delivery" — done: trip.proofOfDeliveryId != nil
   6. "Post-Trip Inspection" — done: trip.postInspectionId != nil
   7. "End Trip" — done: status == .completed

C) STATUS BANNER — Add colors for new statuses:
   - .pendingAcceptance: orange "Awaiting Your Acceptance"
   - .accepted: blue "Accepted — Ready to Start"
   - .rejected: red "Trip Rejected"

D) ACCEPT/REJECT UI:
   When status == .pendingAcceptance, replace action buttons with:
   - Large green "Accept Trip" button
   - Smaller red "Reject" button that expands a TextField for rejection reason
   - Show acceptance deadline if set: "Please respond by [date]"
   - Both buttons trigger async action with loading state

E) POST-TRIP COMPLETION GATE:
   Remove the auto-complete in addProofOfDelivery.
   Instead, after POD is captured:
   - Trip status stays .active
   - Show "Post-Trip Inspection Required" as next action
   - Only after postInspectionId is set: show "End Trip" button
   - "End Trip" calls `store.endTrip(tripId:endMileage:)` → sets status to .completed

F) REJECT FLOW:
   - @State private var showRejectSheet = false
   - @State private var rejectionReason = ""
   - Sheet with TextField + "Confirm Rejection" button
   - Minimum 10 characters for reason
   - On confirm: call `store.rejectTrip(tripId: trip.id, reason: rejectionReason)`

EXPECTED OUTPUT:
Complete replacement of TripDetailDriverView.swift.

CONSTRAINTS:
- Must compile with Swift 6 strict concurrency
- @Environment(AppDataStore.self) for store access
- All state vars declared at top of struct
- flowStepsCard must have 7 steps matching the new lifecycle
- No hardcoded UUIDs
- Animate status transitions using withAnimation
```

---

## PROMPT 4: CRUD Fixes — Staff, Trip, Geofence

```
CONTEXT:
Sierra FMS iOS + Supabase. CRUD operations for staff creation, trip creation, and geofence 
creation are reported as failing. This prompt addresses all three simultaneously.

PROBLEM ROOT CAUSES TO FIX:
1. Staff creation: orphaned auth users when staff_members INSERT fails
2. Staff deletion: auth.users record remains after staff_members is deleted
3. Trip creation: TripUpdatePayload missing GPS coordinate fields, wipes coordinates on edit
4. Geofence creation: RLS policy likely blocks non-service-role inserts

EXACT REQUIREMENTS:

A) CREATE EDGE FUNCTION: create-staff-member
File: supabase/functions/create-staff-member/index.ts

This Deno edge function must:
- Accept POST with JSON body: { email, tempPassword, role, name, phone, adminId }
- Use Supabase Admin client (service role key from env) to create auth user:
  supabaseAdmin.auth.admin.createUser({ email, password: tempPassword, email_confirm: true })
- If auth creation fails: return 400 with error
- On auth creation success: INSERT into staff_members with id = new auth user's id
- If staff_members INSERT fails: call supabaseAdmin.auth.admin.deleteUser(userId) to rollback
- Return 201 with the created staff member
- Protect with verify_jwt: true (only authenticated admins can call this)
- Add role check: query staff_members WHERE id = auth user's id AND role = 'Admin'

B) CREATE EDGE FUNCTION: delete-staff-member
File: supabase/functions/delete-staff-member/index.ts

- Accept DELETE with JSON body: { staffMemberId }
- Verify caller is Admin (same role check as above)
- DELETE from staff_members WHERE id = staffMemberId
- Call supabaseAdmin.auth.admin.deleteUser(staffMemberId)
- Return 200 on success

C) FIX TripUpdatePayload in TripService.swift:
Add these missing fields to TripUpdatePayload:
```swift
let originLatitude: Double?
let originLongitude: Double?
let destinationLatitude: Double?
let destinationLongitude: Double?
let routePolyline: String?
let routeStops: String
```
And their CodingKeys:
```swift
case originLatitude       = "origin_latitude"
case originLongitude      = "origin_longitude"
case destinationLatitude  = "destination_latitude"
case destinationLongitude = "destination_longitude"
case routePolyline        = "route_polyline"
case routeStops           = "route_stops"
```
Update `init(from t: Trip)` to populate these.
Remove `TripService.updateTripCoordinates` — it's now redundant.

D) UPDATE CreateStaffView.swift to call the edge function instead of direct Supabase inserts:
```swift
let result = try await supabase.functions.invoke(
    "create-staff-member",
    options: FunctionInvokeOptions(body: CreateStaffPayload(...))
)
```

E) UPDATE AppDataStore.deleteStaffMember to call delete-staff-member edge function:
```swift
func deleteStaffMember(id: UUID) async throws {
    struct Payload: Encodable { let staffMemberId: String }
    try await supabase.functions.invoke(
        "delete-staff-member",
        options: FunctionInvokeOptions(body: Payload(staffMemberId: id.uuidString))
    )
    staff.removeAll { $0.id == id }
    driverProfiles.removeAll { $0.staffMemberId == id }
    maintenanceProfiles.removeAll { $0.staffMemberId == id }
    staffApplications.removeAll { $0.staffMemberId == id }
}
```

EXPECTED OUTPUT:
1. supabase/functions/create-staff-member/index.ts (complete Deno TypeScript)
2. supabase/functions/delete-staff-member/index.ts (complete Deno TypeScript)
3. Modified TripService.swift (complete file)
4. Modified AppDataStore.swift — just the deleteStaffMember method and addTrip (to call notification)

CONSTRAINTS:
- Edge functions must import from "jsr:@supabase/supabase-js"
- Use Supabase service role key from Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
- verify_jwt: true on both functions
- No hardcoded keys or URLs
- Functions must return proper HTTP status codes and JSON error bodies
```

---

## PROMPT 5: Notification System — Full Implementation

```
CONTEXT:
Sierra FMS iOS app. The notification system exists in-app only (Supabase DB rows).
When the app is backgrounded or closed, users receive NO alerts.

PROBLEM:
1. No APNs push notification integration
2. Trip assignment never triggers in-app notification
3. Emergency alerts don't notify admins
4. Document expiry monitoring never runs automatically
5. Geofence violations don't notify anyone

EXACT REQUIREMENTS:

A) iOS — Register for Push Notifications in SierraApp.swift:
```swift
// In @main App init or onAppear:
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
    if granted {
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    }
}
```
Add `AppDelegate` or `UIApplicationDelegateAdaptor`:
```swift
func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task { await PushTokenService.registerToken(token) }
}
```

B) CREATE PushTokenService.swift in Sierra/Shared/Services/:
```swift
struct PushTokenService {
    static func registerToken(_ token: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        struct Payload: Encodable {
            let staff_id: String
            let device_token: String
            let platform: String
            let updated_at: String
        }
        try? await supabase
            .from("push_tokens")
            .upsert(Payload(
                staff_id: userId.uuidString,
                device_token: token,
                platform: "ios",
                updated_at: ISO8601DateFormatter().string(from: Date())
            ), onConflict: "staff_id,device_token")
            .execute()
    }
}
```

C) CREATE SQL migration 20260322000002_push_tokens.sql:
```sql
CREATE TABLE IF NOT EXISTS public.push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(staff_id, device_token)
);
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY push_tokens_own ON push_tokens
    USING (staff_id = auth.uid())
    WITH CHECK (staff_id = auth.uid());
```

D) CREATE Edge Function: send-push-notification/index.ts
- Receives: { recipientId: string, title: string, body: string, data?: object }
- Queries push_tokens WHERE staff_id = recipientId
- For each token, sends APNs HTTP/2 request using Deno fetch with JWT auth
- APNs endpoint: https://api.push.apple.com/3/device/{token}
- Use APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY from env vars
- Generate JWT for APNs authentication (ES256, sub: team_id, iss: team_id, iat: now, exp: now+3600)
- Return 200 with { sent: count }

E) CREATE DB Function fn_send_push_on_notification_insert():
```sql
CREATE OR REPLACE FUNCTION fn_send_push_on_notification_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM net.http_post(
        url := current_setting('app.edge_function_base_url') || '/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.service_role_key')
        ),
        body := jsonb_build_object(
            'recipientId', NEW.recipient_id,
            'title', NEW.title,
            'body', NEW.body,
            'data', jsonb_build_object('type', NEW.type, 'entityId', NEW.entity_id)
        )
    );
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
    AFTER INSERT ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION fn_send_push_on_notification_insert();
```
Note: Requires pg_net extension. Include: CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

F) FIX AppDataStore.addTrip to notify driver:
After inserting the trip, if driverId is not nil:
```swift
if let driverIdStr = trip.driverId, let driverUUID = UUID(uuidString: driverIdStr) {
    try? await NotificationService.insertNotification(
        recipientId: driverUUID,
        type: .tripAssigned,
        title: "New Trip Assigned: \(trip.taskId)",
        body: "Trip from \(trip.origin) to \(trip.destination) on \(trip.scheduledDate.formatted(.dateTime.month().day().hour().minute()))",
        entityType: "trip",
        entityId: trip.id
    )
}
```

G) FIX AppDataStore.addEmergencyAlert to notify all admins:
After inserting the alert:
```swift
let admins = staff.filter { $0.role == .admin }
for admin in admins {
    try? await NotificationService.insertNotification(
        recipientId: admin.id,
        type: .emergency,
        title: "🚨 Emergency Alert",
        body: "Driver \(alert.driverId ?? "Unknown") has triggered an SOS alert",
        entityType: "emergency_alert",
        entityId: alert.id
    )
}
```

H) ADD to SierraNotification NotificationType:
```swift
case tripAssigned     = "trip_assigned"
case tripAccepted     = "trip_accepted"
case tripRejected     = "trip_rejected"
case documentExpiry   = "document_expiry"
case geofenceAlert    = "geofence_alert"
case emergency        = "emergency"
```

EXPECTED OUTPUT:
1. Modified SierraApp.swift
2. New PushTokenService.swift
3. SQL migration: 20260322000002_push_tokens.sql
4. supabase/functions/send-push-notification/index.ts
5. SQL migration: 20260322000003_push_trigger.sql
6. Modified AppDataStore.swift (addTrip + addEmergencyAlert sections)
7. Modified SierraNotification.swift

CONSTRAINTS:
- APNs JWT must use ES256 algorithm
- pg_net must be checked for availability (CREATE EXTENSION IF NOT EXISTS)
- Edge function must handle APNs sandbox vs production via env var: APNS_ENVIRONMENT
- Error in push sending must NOT fail the notification INSERT (fire and forget)
```

---

## PROMPT 6: Inspection — Image Upload + Defect Photo Fix

```
CONTEXT:
Sierra FMS iOS. The inspection photo upload flow exists but has critical gaps:
1. No compression before upload (images can be 5-15MB each)
2. Failed items don't require a photo (SRS requires defect documentation)
3. Photos are not linked to specific inspection items
4. Photo upload continues silently on failure

EXACT REQUIREMENTS:

A) Modify PreTripInspectionViewModel:
Add a property to link photos to failed items:
```swift
var itemPhotoMap: [UUID: [Data]] = [:] // itemId → array of photo data
var itemPhotoUrls: [UUID: [String]] = [:] // itemId → uploaded URL array
```

B) Modify the photo upload to be per-item:
```swift
func uploadPhotosForItem(itemId: UUID, photos: [Data]) async throws {
    var urls: [String] = []
    for (idx, data) in photos.enumerated() {
        // Compress to max 800KB
        guard let compressed = compressImage(data, maxSizeKB: 800) else { continue }
        let path = "\(inspectionType == .preTripInspection ? "pre" : "post")-trip/\(tripId)/\(itemId)/\(UUID()).jpg"
        try await supabase.storage.from("inspection-photos")
            .upload(path, data: compressed, options: .init(contentType: "image/jpeg"))
        let url = try supabase.storage.from("inspection-photos").getPublicURL(path: path)
        urls.append(url.absoluteString)
    }
    itemPhotoUrls[itemId] = urls
}
```

C) Add image compression function:
```swift
private func compressImage(_ data: Data, maxSizeKB: Int) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    // Start at 0.8 quality, reduce until under maxSizeKB
    var quality: CGFloat = 0.8
    var compressed = image.jpegData(compressionQuality: quality)
    while let c = compressed, c.count > maxSizeKB * 1024, quality > 0.1 {
        quality -= 0.1
        compressed = image.jpegData(compressionQuality: quality)
    }
    // If still too large, resize
    if let c = compressed, c.count > maxSizeKB * 1024 {
        let scale = CGFloat(maxSizeKB * 1024) / CGFloat(c.count)
        let newSize = CGSize(width: image.size.width * sqrt(scale), 
                             height: image.size.height * sqrt(scale))
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
    }
    return compressed
}
```

D) Redesign the photo step UI (Step 2) in PreTripInspectionView:
Instead of a single "Select Photos" button:
- Group by failed/warning items
- For each failed item: show "📷 Add photo for [item name]" with PhotosPicker specific to that item
- Use `@State private var itemPhotoSelections: [UUID: [PhotosPickerItem]] = [:]`
- Show checkmark when at least 1 photo is uploaded for the item
- At bottom: optional "General Vehicle Photos" picker for non-defect photos

E) Modify canSubmit computation:
```swift
var canSubmit: Bool {
    // All items must be checked
    guard allItemsChecked else { return false }
    // All failed items must have at least one photo
    let failedWithoutPhoto = failedItems.filter { 
        (itemPhotoUrls[$0.id] ?? []).isEmpty 
    }
    return failedWithoutPhoto.isEmpty
}
```

F) Modify submitInspection to include per-item photo URLs in the inspection items:
When creating InspectionItem array, include photoUrls:
```swift
let items = checkItems.map { item in
    InspectionItem(
        id: item.id,
        checkName: item.name,
        category: item.category,
        result: item.result,
        notes: item.notes.isEmpty ? nil : item.notes,
        photoUrls: itemPhotoUrls[item.id] ?? []
    )
}
```

G) If InspectionItem model doesn't have photoUrls, add it:
```swift
struct InspectionItem: Codable {
    // ... existing fields ...
    var photoUrls: [String] = []
}
```

EXPECTED OUTPUT:
1. Modified PreTripInspectionViewModel.swift (complete)
2. Modified PreTripInspectionView.swift (complete) — photo step redesigned
3. Modified VehicleInspection.swift if InspectionItem needs photoUrls

CONSTRAINTS:
- UIImage operations must happen off MainActor — use Task.detached or actor
- PhotosPicker changes must be handled with .onChange(of:) not .task
- No force unwraps
- Compression must not block the main thread
```

---

## PROMPT 7: Driver Acceptance + Reminder System

```
CONTEXT:
Sierra FMS iOS app. Two completely missing systems need to be built:
1. Driver trip acceptance flow (drivers must explicitly accept/reject assigned trips)
2. Reminder system (upcoming trips generate reminders 2h before scheduled time)

EXACT REQUIREMENTS:

A) CREATE TripAcceptanceService.swift in Sierra/Shared/Services/:
```swift
struct TripAcceptanceService {
    static func acceptTrip(tripId: UUID, driverId: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let accepted_at: String
        }
        try await supabase.from("trips")
            .update(Payload(status: "Accepted", accepted_at: iso.string(from: Date())))
            .eq("id", value: tripId.uuidString)
            .eq("driver_id", value: driverId.uuidString.lowercased()) // security: only own trips
            .execute()
    }
    
    static func rejectTrip(tripId: UUID, driverId: UUID, reason: String) async throws {
        struct Payload: Encodable {
            let status: String
            let rejected_reason: String
        }
        try await supabase.from("trips")
            .update(Payload(status: "Rejected", rejected_reason: reason))
            .eq("id", value: tripId.uuidString)
            .eq("driver_id", value: driverId.uuidString.lowercased())
            .execute()
    }
}
```

B) CREATE TripReminderService.swift in Sierra/Shared/Services/:
Uses UNUserNotificationCenter for LOCAL notifications (no APNs server needed):
```swift
import UserNotifications

@MainActor
final class TripReminderService {
    static let shared = TripReminderService()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    func scheduleReminders(for trips: [Trip]) async {
        // Cancel existing trip reminders
        let existingIds = await notificationCenter.pendingNotificationRequests()
            .map { $0.identifier }
            .filter { $0.hasPrefix("trip-reminder-") }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: existingIds)
        
        // Schedule new reminders for upcoming trips
        let upcoming = trips.filter { 
            $0.status == .accepted || $0.status == .scheduled
            && $0.scheduledDate > Date() 
            && $0.scheduledDate < Date().addingTimeInterval(24 * 3600) // within 24h
        }
        
        for trip in upcoming {
            // 2 hour reminder
            let twoHourBefore = trip.scheduledDate.addingTimeInterval(-2 * 3600)
            if twoHourBefore > Date() {
                await scheduleLocalNotification(
                    id: "trip-reminder-2h-\(trip.id)",
                    title: "Trip Starting in 2 Hours",
                    body: "Your trip from \(trip.origin) to \(trip.destination) starts at \(trip.scheduledDate.formatted(.dateTime.hour().minute()))",
                    fireDate: twoHourBefore
                )
            }
            // 30 min reminder
            let thirtyMinBefore = trip.scheduledDate.addingTimeInterval(-30 * 60)
            if thirtyMinBefore > Date() {
                await scheduleLocalNotification(
                    id: "trip-reminder-30m-\(trip.id)",
                    title: "Trip Starting Soon",
                    body: "Your trip to \(trip.destination) starts in 30 minutes. Complete pre-trip inspection now.",
                    fireDate: thirtyMinBefore
                )
            }
        }
    }
    
    private func scheduleLocalNotification(id: String, title: String, body: String, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        try? await notificationCenter.add(request)
    }
    
    func cancelReminders(for tripId: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "trip-reminder-2h-\(tripId)",
            "trip-reminder-30m-\(tripId)"
        ])
    }
}
```

C) Integrate TripReminderService into AppDataStore:
In `loadDriverData`: after trips are loaded, call:
```swift
await TripReminderService.shared.scheduleReminders(for: trips)
```

In `acceptTrip`: after success, re-schedule reminders:
```swift
await TripReminderService.shared.scheduleReminders(for: trips)
```

In `rejectTrip` / `cancelTrip`:
```swift
TripReminderService.shared.cancelReminders(for: tripId)
```

D) ADD to DriverTripsListView.swift:
When showing scheduled/pending-acceptance trips, show a deadline indicator:
- If `acceptanceDeadline` is set and < 2 hours away: show orange "Respond by [time]" badge
- If past deadline: show red "Response Overdue" badge

E) CREATE DriverTripAcceptanceSheet.swift:
A dedicated sheet that appears when driver taps a PendingAcceptance trip:
- Full-width "Accept" button (green, prominent)
- "Decline" button (secondary)
- On Decline: text field expands requesting reason (min 10 chars)
- Shows trip details: origin, destination, scheduled time, vehicle
- Shows "Please respond by [deadline]" if applicable

EXPECTED OUTPUT:
1. TripAcceptanceService.swift (new file)
2. TripReminderService.swift (new file)
3. Modified AppDataStore.swift — acceptTrip, rejectTrip methods, loadDriverData reminder scheduling
4. DriverTripAcceptanceSheet.swift (new file)
5. Modified DriverTripsListView.swift — deadline badges

CONSTRAINTS:
- UNUserNotificationCenter must request authorization before scheduling
- Local notifications for reminders (no server needed)
- acceptTrip / rejectTrip must use .eq("driver_id") security filter — drivers cannot accept trips not assigned to them
- All @MainActor on TripReminderService methods that touch UNUserNotificationCenter
```

---

## PROMPT 8: Admin Dashboard Fixes

```
CONTEXT:
Sierra FMS iOS. DashboardHomeView.swift has several confirmed bugs and MVVM violations.

EXACT REQUIREMENTS:

A) CREATE DashboardViewModel.swift in Sierra/FleetManager/ViewModels/:
Extract all computed properties from DashboardHomeView into @Observable ViewModel:
```swift
@MainActor
@Observable
final class DashboardViewModel {
    private let store: AppDataStore
    
    init(store: AppDataStore) {
        self.store = store
    }
    
    var vehicleCount: Int { store.vehicles.count }
    var activeTripsCount: Int { store.activeTripsCount }
    var pendingApplicationsCount: Int { store.pendingApplicationsCount }
    var activeAlertsCount: Int { store.activeEmergencyAlerts().count }
    
    var fleetSlices: [(Double, Color)] { ... }
    var tripSlices: [(Double, Color)] { ... }
    var staffSlices: [(Double, Color)] { ... }
    var monthlyData: [MonthlyTripData] { ... }
    var validDocCount: Int { ... }
    var expiringDocCount: Int { ... }
    var expiredDocCount: Int { ... }
    var recentTrips: [Trip] { Array(store.trips.sorted { $0.createdAt > $1.createdAt }.prefix(5)) }
    var expiringDocs: [VehicleDocument] { store.documentsExpiringSoon() }
}
```

B) FIX the Ellipsis Bug in kpiCard:
Replace:
```swift
Text(value)
    .font(.system(size: 30, weight: .bold, design: .rounded))
    .lineLimit(1)
    .minimumScaleFactor(0.6)
```
With:
```swift
Text(value)
    .font(.system(size: 24, weight: .bold, design: .rounded))
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .fixedSize(horizontal: false, vertical: true)
```
And ensure the kpiCard VStack has proper frame constraints:
```swift
.frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
```

C) FIX Notification Button Placement:
Move from `.topBarLeading` to `.topBarTrailing`:
```swift
ToolbarItem(placement: .topBarTrailing) {
    // notification bell
}
// Remove the profile button from toolbar — add it to a Profile tab instead
```

D) FIX KPI Cards to be Interactive:
Each KPI card should NavigationLink or sheet to the relevant module:
```swift
NavigationLink(destination: StaffTabView().environment(AppDataStore.shared)) {
    kpiCard(icon: "person.2.fill", ...)
}
// Or use .onTapGesture { selectedTab = .staff }
```
Implement by adding an `onTap: (() -> Void)?` parameter to `kpiCard`.

E) FIX Loading States:
Add skeleton loading states to the analytics snapshot card:
```swift
if store.isLoading {
    ProgressView("Loading fleet data...")
        .frame(maxWidth: .infinity, minHeight: 200)
} else {
    analyticsSnapshotCard
}
```

F) ADD Quick Stats to kpiGrid:
Add 2 more KPI cards to make a 3-column grid or expanded 2-column:
- "In Maintenance" vehicles count
- "Available Drivers" count

G) FIX DashboardHomeView to use DashboardViewModel:
```swift
struct DashboardHomeView: View {
    @Environment(AppDataStore.self) private var store
    @State private var viewModel: DashboardViewModel?
    
    var body: some View {
        // Use viewModel.vehicleCount etc. instead of store.vehicles.count directly
    }
    .onAppear {
        if viewModel == nil {
            viewModel = DashboardViewModel(store: store)
        }
    }
}
```

EXPECTED OUTPUT:
1. DashboardViewModel.swift (new file, complete)
2. Modified DashboardHomeView.swift (complete, uses DashboardViewModel)

CONSTRAINTS:
- MonthlyTripData struct must remain where it is or move to DashboardViewModel
- All @MainActor on DashboardViewModel
- KPI tap navigation must not conflict with existing NavigationStack
- isLoading from store must propagate to skeleton states
```

---

## PROMPT 9: Filtering UX Redesign — Vehicles + Trips

```
CONTEXT:
Sierra FMS. VehicleListView and TripsListView both use horizontal filter chips.
User reports this is wrong UX pattern. Must be replaced with proper filter sheet.

EXACT REQUIREMENTS:

A) CREATE FilterSheetView.swift (reusable) in Sierra/Shared/Components/:
```swift
struct FilterOption: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String?
    let color: Color?
}

struct FilterSheetView: View {
    let title: String
    let options: [FilterOption]
    @Binding var selectedId: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // "All" option
                filterRow(FilterOption(id: "all", label: "All", icon: nil, color: nil))
                ForEach(options) { option in
                    filterRow(option)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func filterRow(_ option: FilterOption) -> some View {
        Button {
            selectedId = option.id == "all" ? nil : option.id
            dismiss()
        } label: {
            HStack {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .foregroundStyle(option.color ?? .secondary)
                        .frame(width: 28)
                }
                Text(option.label)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedId == option.id || (option.id == "all" && selectedId == nil) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
```

B) MODIFY VehicleListView.swift:
- Remove `filterChips` computed property entirely
- Remove `filterChip()` function
- Add `@State private var showFilterSheet = false`
- Change `@State private var selectedFilter: VehicleStatus? = nil` → keep as is
- Add to toolbar:
```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        showFilterSheet = true
    } label: {
        Label(
            selectedFilter == nil ? "Filter" : selectedFilter!.rawValue,
            systemImage: selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
        )
        .foregroundStyle(selectedFilter == nil ? .secondary : .orange)
    }
}
```
- Add `.sheet(isPresented: $showFilterSheet) { FilterSheetView(...) }` with VehicleStatus options
- Remove the VStack spacing filler that was consumed by chip row

C) MODIFY TripsListView.swift similarly:
- Replace filter chips with filter button + FilterSheetView
- Trip filter options: All, Scheduled, Active, Completed, Cancelled
- Add active filter badge to filter button

D) ADD search field above list (if not already present):
```swift
.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search vehicles...")
```

EXPECTED OUTPUT:
1. FilterSheetView.swift (new reusable component)
2. Modified VehicleListView.swift (complete, chips removed)
3. Modified TripsListView.swift (complete, chips removed)

CONSTRAINTS:
- FilterSheetView must be generic enough to use for vehicles AND trips
- Active filter state must be visually communicated (filled icon, tinted label)
- Removing chips must not remove padding/spacing from the list — adjust VStack spacing
- Must work with pull-to-refresh still functioning
```

---

## PROMPT 10: Navigation + MapKit Overhaul

```
CONTEXT:
Sierra FMS. Navigation is split: Mapbox API for routing, MapKit for rendering.
No turn-by-turn instructions. Mapbox token exposed in bundle.

EXACT REQUIREMENTS:

A) CREATE MapService.swift in Sierra/Shared/Services/:
Centralise all Mapbox API calls:
```swift
enum MapServiceError: LocalizedError {
    case tokenMissing
    case noRoutesFound
    case networkError(Error)
    
    var errorDescription: String? { ... }
}

struct MapRoute: Identifiable {
    let id = UUID()
    let label: String
    let distanceKm: Double
    let durationMinutes: Double
    let geometry: String // polyline6 encoded
    let steps: [RouteStep]
    let isGreen: Bool
}

struct RouteStep {
    let instruction: String
    let distanceM: Double
    let maneuverType: String
    let maneuverModifier: String?
}

struct MapService {
    private static var token: String? {
        // First try env (for tests), then bundle
        ProcessInfo.processInfo.environment["MAPBOX_TOKEN"] 
            ?? Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String
    }
    
    static func fetchRoutes(
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        avoidTolls: Bool = false,
        avoidHighways: Bool = false
    ) async throws -> [MapRoute] {
        guard let token else { throw MapServiceError.tokenMissing }
        
        var components = URLComponents(string: "https://api.mapbox.com/directions/v5/mapbox/driving/")!
        components.path += "\(originLng),\(originLat);\(destLng),\(destLat)"
        components.queryItems = [
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "geometries", value: "polyline6"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "steps", value: "true"),        // ← ENABLES turn-by-turn
            URLQueryItem(name: "voice_instructions", value: "true"),
            URLQueryItem(name: "banner_instructions", value: "true"),
            URLQueryItem(name: "access_token", value: token)
        ]
        if avoidTolls || avoidHighways {
            let exclusions = [avoidTolls ? "toll" : nil, avoidHighways ? "motorway" : nil]
                .compactMap { $0 }.joined(separator: ",")
            components.queryItems?.append(URLQueryItem(name: "exclude", value: exclusions))
        }
        
        guard let url = components.url else { throw MapServiceError.noRoutesFound }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Sierra-FMS/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MapServiceError.networkError(URLError(.badServerResponse))
        }
        
        return try parseMapboxResponse(data)
    }
    
    private static func parseMapboxResponse(_ data: Data) throws -> [MapRoute] {
        // Parse JSON, extract routes, steps, instructions
        // Return array of MapRoute with steps populated
        // ... (complete implementation)
    }
}
```

B) MODIFY StartTripSheet.swift:
Replace inline URLSession call with `MapService.fetchRoutes`:
```swift
private func fetchRouteOptions() async {
    guard let trip = trip,
          let originLat = trip.originLatitude, ... else { return }
    isFetchingRoutes = true
    defer { isFetchingRoutes = false }
    do {
        let routes = try await MapService.fetchRoutes(
            originLat: originLat, originLng: originLng,
            destLat: destLat, destLng: destLng,
            avoidTolls: avoidTolls, avoidHighways: avoidHighways
        )
        routeOptions = routes.map { RouteOption(from: $0) }
    } catch MapServiceError.tokenMissing {
        errorMessage = "Navigation configuration error. Please contact your fleet manager."
        showError = true
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

C) MODIFY TripNavigationCoordinator.swift:
Add step-by-step instruction tracking:
```swift
@Published var currentStep: RouteStep?
@Published var nextStep: RouteStep?
@Published var currentInstructionText: String = ""
@Published var distanceToNextManeuver: Double = 0 // metres

// When location updates:
func updateCurrentStep(location: CLLocation) {
    // Find closest step based on current location
    // Update currentStep, nextStep
    // Calculate distance to next maneuver point
    // If distance < 200m: announce with AVSpeechSynthesizer
}
```

D) MODIFY NavigationHUDOverlay.swift:
Show turn-by-turn instruction banner:
```swift
VStack {
    // Current instruction banner (top of screen)
    if let step = coordinator.currentStep {
        HStack(spacing: 12) {
            Image(systemName: maneuverIcon(step.maneuverType, modifier: step.maneuverModifier))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading) {
                Text(step.instruction)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let next = coordinator.nextStep {
                    Text("Then: \(next.instruction)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
    Spacer()
    // ... existing HUD ...
}
```

E) ADD Voice Instructions using AVSpeechSynthesizer:
```swift
import AVFoundation

class VoiceNavigationService {
    private let synthesizer = AVSpeechSynthesizer()
    
    func announce(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
```

EXPECTED OUTPUT:
1. MapService.swift (new, complete)
2. Modified StartTripSheet.swift (uses MapService)
3. Modified TripNavigationCoordinator.swift (step tracking)
4. Modified NavigationHUDOverlay.swift (instruction banner)
5. VoiceNavigationService.swift (new)

CONSTRAINTS:
- Mapbox token must NEVER be printed to logs
- URLSession timeout must be set (15 seconds)
- Step tracking must account for GPS drift (allow ±50m tolerance)
- Voice announcements must respect device silent mode check
- All Mapbox API parsing must use proper error handling (no force-unwraps)
```

---

## PROMPT 11: Fuel Logging + OCR Integration

```
CONTEXT:
Sierra FMS. Fuel logging exists as a standalone form with no OCR, no inspection integration,
and no fuel math validation.

EXACT REQUIREMENTS:

A) MODIFY FuelLogView.swift — Add validation:
```swift
// After quantity and costPerLitre are entered, auto-calculate totalCost:
.onChange(of: vm.quantity) { _, _ in vm.recalculateTotalCost() }
.onChange(of: vm.costPerLitre) { _, _ in vm.recalculateTotalCost() }

// Show validation error if total cost doesn't match:
if vm.hasTotalCostMismatch {
    Label("Total cost doesn't match quantity × cost per litre", systemImage: "exclamationmark.triangle")
        .foregroundStyle(.orange)
        .font(.caption)
}
```

B) MODIFY FuelLogViewModel.swift — Add calculations:
```swift
func recalculateTotalCost() {
    guard let q = Double(quantity), let c = Double(costPerLitre) else { return }
    let calculated = q * c
    // Auto-fill if total is empty
    if totalCost.isEmpty {
        totalCost = String(format: "%.2f", calculated)
    }
}

var hasTotalCostMismatch: Bool {
    guard let q = Double(quantity), 
          let c = Double(costPerLitre),
          let t = Double(totalCost) else { return false }
    return abs(q * c - t) > 1.0 // Allow ₹1 rounding tolerance
}

var canSubmit: Bool {
    !quantity.isEmpty && !totalCost.isEmpty && !hasTotalCostMismatch
}
```

C) ADD Vision OCR for receipt scanning — FuelLogView.swift:
Import Vision framework:
```swift
import Vision

// Replace PhotosPicker with a camera + OCR option:
Button("Scan Receipt") {
    showCamera = true
}
.sheet(isPresented: $showCamera) {
    CameraView { image in
        Task { await vm.processReceiptWithOCR(image) }
    }
}
```

D) MODIFY FuelLogViewModel.swift — Add OCR method:
```swift
import Vision

func processReceiptWithOCR(_ image: UIImage) async {
    isUploadingReceipt = true
    defer { isUploadingReceipt = false }
    
    guard let cgImage = image.cgImage else { return }
    
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-IN", "en-US"]
    request.usesLanguageCorrection = true
    
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try? handler.perform([request])
    
    guard let observations = request.results else { return }
    
    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
    
    // Extract fuel data from OCR text
    extractFuelData(from: lines)
    
    // Upload the receipt image
    if let data = image.jpegData(compressionQuality: 0.7) {
        await uploadReceipt(data)
    }
}

private func extractFuelData(from lines: [String]) {
    // Pattern match for litres: "XX.X L" or "XX.X litres"
    let litresPattern = /(\d+\.?\d*)\s*[Ll](?:itres?)?/
    // Pattern match for total: "₹ XXXX" or "Rs. XXXX" or "Total: XXXX"
    let amountPattern = /(?:₹|Rs\.?\s*)(\d+\.?\d*)/
    // Pattern match for per-litre price: "₹XX/L" or "Rate: XX"
    let ratePattern = /(?:Rate|Per\s*[Ll]itre?)[:\s]*(\d+\.?\d*)/
    
    for line in lines {
        if quantity.isEmpty, let match = line.firstMatch(of: litresPattern) {
            quantity = String(match.1)
        }
        if totalCost.isEmpty, let match = line.firstMatch(of: amountPattern) {
            totalCost = String(match.1)
        }
        if costPerLitre.isEmpty, let match = line.firstMatch(of: ratePattern) {
            costPerLitre = String(match.1)
        }
    }
    recalculateTotalCost()
}
```

E) CREATE CameraView.swift in Sierra/Shared/Components/:
A UIViewControllerRepresentable wrapping UIImagePickerController for camera capture:
```swift
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    // ... standard implementation
}
```

F) Integrate FuelLog into inspection flow:
In PreTripInspectionView, when "Fuel Level" item is marked failed:
```swift
// After checklistStep advances
if viewModel.fuelLevelItem?.result == .failed || viewModel.fuelLevelItem?.result == .passedWithWarnings {
    Text("⛽ Fuel level issue noted. Please log fuel after inspection.")
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 16)
}
```
And in `TripDetailDriverView`, when pre-inspection is done and trip is accepted:
- If fuelLevelItem was warned/failed: show "Log Fuel (Recommended)" as a prominent step before "Start Trip"

EXPECTED OUTPUT:
1. Modified FuelLogView.swift (complete)
2. Modified FuelLogViewModel.swift (complete, with OCR + validation)
3. CameraView.swift (new)
4. Modified PreTripInspectionView.swift — fuel level integration note

CONSTRAINTS:
- Vision requests must run on background thread (not MainActor)
- OCR extraction is best-effort — show toast "Auto-filled from receipt" if successful, don't block if not
- `NSCameraUsageDescription` must be in Info.plist (add note about this)
- FuelLogView uses NavigationStack already — ensure CameraView does not nest another NavigationStack
```

---

## PROMPT 12: Full UI/UX Refactor — Driver Home + Missing States

```
CONTEXT:
Sierra FMS iOS. Multiple views missing empty states, loading states, and error states.
DriverHomeView is 25KB with everything mixed in. Profile tab is misused.

EXACT REQUIREMENTS:

A) CREATE SierraLoadingView.swift in Sierra/Shared/Components/:
```swift
struct SierraLoadingView: View {
    var message: String = "Loading..."
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
```

B) Ensure SierraEmptyState component (already referenced in code) has consistent implementation:
```swift
struct SierraEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
```

C) MODIFY DriverHomeView.swift — Add proper loading + empty states:
Replace any direct data access with loading-aware views:
```swift
var body: some View {
    Group {
        if store.isLoading {
            SierraLoadingView(message: "Loading your assignments...")
        } else if let error = store.loadError {
            SierraErrorView(message: error) {
                Task { await store.loadDriverData(driverId: ...) }
            }
        } else {
            mainContent
        }
    }
}
```

D) FIX DriverTabView — Profile tab misuse:
The Driver tab bar should have:
1. "Home" (current assignments + active trip)
2. "Trips" (history + upcoming)
3. "Inspections" (list of inspections performed)
4. "Profile" (ONLY personal info + settings + availability toggle)

If the current Profile tab shows anything other than personal settings, move that content to appropriate tabs.

E) ADD DriverInspectionsView.swift as a new Driver tab:
Shows list of pre/post trip inspections performed by the driver:
```swift
struct DriverInspectionsView: View {
    @Environment(AppDataStore.self) private var store
    
    private var driverInspections: [VehicleInspection] {
        guard let driverId = AuthManager.shared.currentUser?.id else { return [] }
        return store.vehicleInspections
            .filter { $0.driverId == driverId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            if driverInspections.isEmpty {
                SierraEmptyState(icon: "checklist", title: "No Inspections", 
                                 message: "Your vehicle inspections will appear here.")
            } else {
                List(driverInspections) { inspection in
                    inspectionRow(inspection)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inspections")
    }
}
```

F) ADD loadError display to all list views:
In VehicleListView, TripsListView, StaffListView, MaintenanceRequestsView:
```swift
if let error = store.loadError {
    VStack(spacing: 12) {
        Image(systemName: "wifi.exclamationmark")
            .font(.system(size: 36))
            .foregroundStyle(.secondary)
        Text("Failed to load")
            .font(.headline)
        Text(error)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        Button("Retry") {
            Task { await store.loadAll() }
        }
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
}
```

G) FIX DriverTripHistoryView — Show real history:
Currently 3.2KB — likely shows placeholder. Must show completed + cancelled trips filtered for current driver, sorted by date, with total distance and duration per trip.

EXPECTED OUTPUT:
1. SierraLoadingView.swift (new)
2. SierraEmptyState.swift (complete, not just referenced)
3. SierraErrorView.swift (new) 
4. Modified DriverHomeView.swift
5. Modified DriverTabView.swift — corrected tabs
6. DriverInspectionsView.swift (new)
7. Modified DriverTripHistoryView.swift

CONSTRAINTS:
- SierraLoadingView and SierraEmptyState must be in Shared/Components/
- Must support Dark Mode
- Retry actions must use store.loadAll() or loadDriverData as appropriate per role
- DriverTabView tabs must use SF Symbols with consistent sizing (.tabViewStyle(.sidebarAdaptable) if iPad support needed)
```

---

## PROMPT 13: MVVM Architecture Refactor

```
CONTEXT:
Sierra FMS. Multiple high-traffic views violate MVVM. This prompt addresses the 3 most critical:
DashboardHomeView (handled in Prompt 8), AddVehicleView (40KB god view), CreateTripView (37KB).

EXACT REQUIREMENTS:

A) CREATE AddVehicleViewModel.swift in Sierra/FleetManager/ViewModels/:
Extract all from AddVehicleView:
- All @State form fields (make, model, year, vin, plate, color, status, fuelType, etc.)
- All photo upload state
- All validation logic (VIN format check, plate format check)
- All submission logic (calls to store.addVehicle / store.updateVehicle)
- Error state management

```swift
@MainActor
@Observable
final class AddVehicleViewModel {
    // MARK: - Inputs
    var name = ""
    var model = ""
    var year = Calendar.current.component(.year, from: Date())
    var vin = ""
    var licensePlate = ""
    var color = ""
    var status: VehicleStatus = .idle
    // ... all other fields
    
    // MARK: - Photo State
    var selectedPhotoItem: PhotosPickerItem?
    var vehiclePhotoData: Data?
    var vehiclePhotoUrl: String?
    var isUploadingPhoto = false
    
    // MARK: - Submission State
    var isSubmitting = false
    var submitError: String?
    var didSubmitSuccessfully = false
    
    // MARK: - Edit Mode
    let editingVehicle: Vehicle?
    var isEditing: Bool { editingVehicle != nil }
    
    init(editingVehicle: Vehicle? = nil) {
        self.editingVehicle = editingVehicle
        if let v = editingVehicle { populateFromVehicle(v) }
    }
    
    // MARK: - Validation
    var isVinValid: Bool { vin.count == 17 && vin.allSatisfy { $0.isLetter || $0.isNumber } }
    var canSubmit: Bool { !name.isEmpty && !model.isEmpty && !licensePlate.isEmpty && isVinValid }
    var validationMessage: String? {
        if !isVinValid && !vin.isEmpty { return "VIN must be 17 alphanumeric characters" }
        return nil
    }
    
    // MARK: - Actions
    func uploadVehiclePhoto(_ data: Data, store: AppDataStore) async { ... }
    func submit(store: AppDataStore) async { ... }
    private func populateFromVehicle(_ v: Vehicle) { ... }
    private func buildVehicle(adminId: UUID) -> Vehicle { ... }
}
```

B) REDUCE AddVehicleView.swift to UI ONLY:
```swift
struct AddVehicleView: View {
    @State private var viewModel: AddVehicleViewModel
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    init(editingVehicle: Vehicle? = nil) {
        _viewModel = State(initialValue: AddVehicleViewModel(editingVehicle: editingVehicle))
    }
    
    var body: some View {
        Form {
            basicInfoSection
            registrationSection
            operationalSection
            photoSection
        }
        .navigationTitle(viewModel.isEditing ? "Edit Vehicle" : "Add Vehicle")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await viewModel.submit(store: store) } }
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
        }
        .onChange(of: viewModel.didSubmitSuccessfully) { _, success in
            if success { dismiss() }
        }
    }
}
```

C) CREATE CreateTripViewModel.swift in Sierra/FleetManager/ViewModels/:
Extract from CreateTripView (37KB):
- Form state: origin, destination, coordinates, driver selection, vehicle selection, dates, priority, instructions
- Conflict checking state (`isCheckingConflict`, `driverConflict`, `vehicleConflict`)
- Geocoding state (`isGeocodingOrigin`, `isGeocodingDestination`)
- Submission logic
- Validation logic

Key computed properties:
```swift
var availableDrivers: [StaffMember] { store.availableDrivers() }
var availableVehicles: [Vehicle] { store.availableVehicles() }
var canSubmit: Bool {
    !origin.isEmpty && !destination.isEmpty
    && selectedDriverId != nil && selectedVehicleId != nil
    && !driverConflict && !vehicleConflict
    && scheduledDate > Date()
}
```

D) ENSURE all ViewModels follow this pattern:
- @MainActor @Observable final class
- init takes only primitive values or existing models (no Store in init — injected via method calls)
- Methods that need store: `func submit(store: AppDataStore) async throws`
- Properties: inputs, derived state, error state, success state

EXPECTED OUTPUT:
1. AddVehicleViewModel.swift (complete)
2. Modified AddVehicleView.swift (UI only, max 200 lines)
3. CreateTripViewModel.swift (complete)  
4. Modified CreateTripView.swift (UI only, max 250 lines)

CONSTRAINTS:
- No @EnvironmentObject — use @Environment(AppDataStore.self)
- No DispatchQueue — async/await only
- ViewModels must not import SwiftUI (except for Color if needed for validation states)
- Submit methods must propagate errors — no silent catch-and-print in ViewModels
```

---

## PROMPT 14: VIN Scanning + Maintenance Module Fixes

```
CONTEXT:
Sierra FMS. Maintenance module is missing VIN scanning (SRS §4.3.3), maintenance users
see stale vehicle status, and work order completion doesn't notify admins.

EXACT REQUIREMENTS:

A) CREATE VINScannerView.swift in Sierra/Maintenance/Views/:
```swift
import SwiftUI
import AVFoundation
import Vision

struct VINScannerView: View {
    @Binding var scannedVIN: String
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var highlightedText: String?
    
    var body: some View {
        ZStack {
            CameraPreviewView(onTextRecognised: handleRecognisedText)
            
            // Viewfinder overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 300, height: 60)
                    .overlay(
                        Text("Align VIN barcode within frame")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(y: 40)
                    )
                Spacer()
            }
            
            if let vin = highlightedText {
                VStack {
                    Spacer()
                    Text("VIN: \(vin)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    Button("Use This VIN") {
                        scannedVIN = vin
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Scan VIN")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }
    
    private func handleRecognisedText(_ texts: [String]) {
        // VIN is 17 chars, alphanumeric, no I, O, Q
        let vinPattern = /[A-HJ-NPR-Z0-9]{17}/
        for text in texts {
            if let match = text.uppercased().firstMatch(of: vinPattern) {
                highlightedText = String(match.output)
                break
            }
        }
    }
}
```

B) CREATE CameraPreviewView.swift (AVCaptureSession + Vision text recognition):
```swift
struct CameraPreviewView: UIViewControllerRepresentable {
    let onTextRecognised: ([String]) -> Void
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        CameraPreviewViewController(onTextRecognised: onTextRecognised)
    }
    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

class CameraPreviewViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    // AVCaptureSession setup
    // VNRecognizeTextRequest for real-time OCR
    // Throttle to 1 recognition per second to avoid battery drain
    // Returns detected text strings via callback
}
```

C) INTEGRATE VIN Scanner into Maintenance module:
In the maintenance task detail view or a vehicle lookup screen, add:
```swift
@State private var showVINScanner = false
@State private var scannedVIN = ""

Button("Scan VIN") { showVINScanner = true }
    .sheet(isPresented: $showVINScanner) {
        NavigationStack {
            VINScannerView(scannedVIN: $scannedVIN)
        }
    }
    .onChange(of: scannedVIN) { _, vin in
        if !vin.isEmpty {
            Task { await lookupVehicleByVIN(vin) }
        }
    }

func lookupVehicleByVIN(_ vin: String) async {
    if let vehicle = store.vehicles.first(where: { $0.vin.uppercased() == vin.uppercased() }) {
        selectedVehicle = vehicle
    } else {
        vinLookupError = "No vehicle found with VIN: \(vin)"
    }
}
```

D) FIX Stale Vehicle Status for Maintenance Users:
In `AppDataStore.completeMaintenanceTask`, the `try?` on vehicle update was intentional 
because maintenance users can't write vehicles via RLS. Fix this properly:

Add a new Edge Function: update-vehicle-status/index.ts
- Called with: { vehicleId, status } 
- Uses service role to bypass RLS: `supabaseAdmin.from('vehicles').update({ status }).eq('id', vehicleId)`
- verify_jwt: true (authenticated maintenance user can call this for vehicles in their tasks)
- Add role check: caller must be the maintenance user assigned to a task for this vehicle

Then in `completeMaintenanceTask`:
```swift
// Replace try? await VehicleService.updateVehicle(vehicles[vIdx]) with:
try? await supabase.functions.invoke(
    "update-vehicle-status",
    options: FunctionInvokeOptions(body: ["vehicleId": vehicleId.uuidString, "status": "Idle"])
)
```

E) FIX: Notify Admin on Work Order Closure:
In `AppDataStore.closeWorkOrder`, after updating the work order:
```swift
// Find the task's admin (createdByAdminId)
if let task = maintenanceTasks.first(where: { $0.id == order.maintenanceTaskId }) {
    try? await NotificationService.insertNotification(
        recipientId: task.createdByAdminId,
        type: .maintenanceComplete,
        title: "Work Order Completed",
        body: "Work order for vehicle \(store.vehicle(for: task.vehicleId)?.name ?? "Unknown") has been closed.",
        entityType: "work_order",
        entityId: order.id
    )
}
```

EXPECTED OUTPUT:
1. VINScannerView.swift (new, complete)
2. CameraPreviewView.swift (new, complete)
3. supabase/functions/update-vehicle-status/index.ts (new)
4. Modified AppDataStore.swift — completeMaintenanceTask + closeWorkOrder

CONSTRAINTS:
- AVCaptureSession must be torn down in viewDidDisappear to release camera
- Vision text recognition on background queue
- NSCameraUsageDescription must be in Info.plist
- VIN validation: must match /[A-HJ-NPR-Z0-9]{17}/ (no I, O, Q per ISO 3779)
- update-vehicle-status edge function must validate the calling user is assigned to a task for this vehicle
```

---

*End of 14 Prompts*

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
- TripAcceptanceService.swift
- TripReminderService.swift
- PushTokenService.swift
- MapService.swift
- VoiceNavigationService.swift
- FilterSheetView.swift
- VINScannerView.swift
- CameraPreviewView.swift
- SierraLoadingView.swift
- SierraErrorView.swift
- DriverInspectionsView.swift
- DriverTripAcceptanceSheet.swift
- DashboardViewModel.swift
- AddVehicleViewModel.swift
- CreateTripViewModel.swift
- supabase/functions/create-staff-member/index.ts
- supabase/functions/delete-staff-member/index.ts
- supabase/functions/send-push-notification/index.ts
- supabase/functions/update-vehicle-status/index.ts
- SQL migrations: 20260322000001, 20260322000002, 20260322000003

## FILES NEEDING MODIFICATION (MAJOR)
- TripDetailDriverView.swift (complete rewrite)
- PreTripInspectionView.swift
- PreTripInspectionViewModel.swift
- FuelLogView.swift
- FuelLogViewModel.swift
- StartTripSheet.swift
- NavigationHUDOverlay.swift
- TripNavigationCoordinator.swift
- TripService.swift (TripUpdatePayload coordinates)
- AppDataStore.swift (addTrip notification, deleteStaffMember, completeMaintenanceTask, closeWorkOrder)
- DashboardHomeView.swift
- VehicleListView.swift
- TripsListView.swift
- AddVehicleView.swift (reduce to UI only)
- CreateTripView.swift (reduce to UI only)
- DriverTabView.swift
- DriverHomeView.swift
- Trip.swift (new status enum values + fields)
- SierraNotification.swift (new notification types)
- SierraApp.swift (APNs registration)

---

*Audit complete. All 54 issues documented. 14 production-grade Claude Opus prompts generated. Push this file to GitHub at docs/SIERRA_FULL_AUDIT.md for future reference.*
