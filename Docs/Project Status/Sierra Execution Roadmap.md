# Sierra Sprint 2 — Engineering Execution Roadmap

> **Deadline:** 22 March 2026
> **Generated:** 2026-03-18
> **Author:** Claude (Lead iOS Architect)
> **Rule:** Follow this order exactly. Every step has a blocking dependency on the steps before it.

---

## Phase 1 — Critical Infrastructure

*Nothing in the client app can function correctly until these are in place. Do these first, before writing a single line of Swift.*

---

### Step 1 — Create Trip Status Trigger Migration

**Description**

Create `supabase/migrations/20260318000003_add_trip_triggers.sql`. Implement a PostgreSQL trigger function `handle_trip_status_change()` that fires `AFTER UPDATE OF status ON trips FOR EACH ROW`.

Logic:
- `NEW.status = 'Active'` → `UPDATE vehicles SET status = 'Busy' WHERE id::text = NEW.vehicle_id` and `UPDATE staff_members SET availability = 'Busy' WHERE id::text = NEW.driver_id`
- `NEW.status IN ('Completed', 'Cancelled')` → set both back to `'Available'`

Attach trigger:
```sql
CREATE TRIGGER trip_status_change_trigger
AFTER UPDATE OF status ON trips
FOR EACH ROW EXECUTE FUNCTION handle_trip_status_change();
```

**Why this step comes now**

The architecture rule states vehicle and driver status must NEVER be updated manually from the client. If this trigger does not exist in the migration files before any trip flow is tested, developers will be tempted to add manual status updates in Swift — creating a permanent architecture violation that is hard to undo.

**Files involved**
- `supabase/migrations/20260318000003_add_trip_triggers.sql` ← CREATE

**Jira stories:** FMS1-37, FMS1-38, FMS1-74

**Expected outcome**

Starting or ending a trip from the client automatically transitions vehicle and driver status via the database. No Swift code touches vehicle or driver status directly.

---

### Step 2 — Create Maintenance Status Trigger Migration

**Description**

Create `supabase/migrations/20260318000004_add_maintenance_triggers.sql`. Implement trigger function `handle_maintenance_status_change()` that fires `AFTER UPDATE OF status ON maintenance_tasks FOR EACH ROW`.

Logic:
- `NEW.status = 'Approved'` → `UPDATE vehicles SET status = 'In Maintenance' WHERE id::text = NEW.vehicle_id`
- `NEW.status = 'Completed'` → `UPDATE vehicles SET status = 'Available' WHERE id::text = NEW.vehicle_id`

Also insert a row into `sierra_notifications` on `Completed` to notify the Fleet Manager.

**Why this step comes now**

Fleet Manager maintenance approval and Maintenance Personnel task completion both depend on automatic vehicle status transitions. Must be in place before any maintenance workflow Swift code is written.

**Files involved**
- `supabase/migrations/20260318000004_add_maintenance_triggers.sql` ← CREATE

**Jira stories:** FMS1-13, FMS1-16, FMS1-55, FMS1-56, FMS1-66, FMS1-67

**Expected outcome**

Approving a maintenance request sets the vehicle to In Maintenance. Marking a repair complete returns it to Available. Both happen via DB trigger with zero client-side status mutation.

---

### Step 3 — Create RLS Policy Migration

**Description**

Create `supabase/migrations/20260318000005_add_rls_policies.sql`. Enable RLS on every table and add policies:

```sql
-- vehicles: fleet_manager can read/write all; driver and maintenance can read only
-- trips: fleet_manager full access; driver can read own trips (driver_id = auth.uid())
-- vehicle_location_history: driver can INSERT own rows; fleet_manager can SELECT all
-- emergency_alerts: driver can INSERT; fleet_manager can SELECT all
-- route_deviation_events: driver INSERT; fleet_manager SELECT
-- geofence_events: driver INSERT; fleet_manager SELECT
-- maintenance_tasks: maintenance staff SELECT/UPDATE own assigned tasks; fleet_manager full access
-- sierra_notifications: each user SELECT own (user_id = auth.uid()); system INSERT via service role
-- fuel_logs: driver INSERT/SELECT own rows
-- vehicle_inspections: driver INSERT own; fleet_manager SELECT all
-- proof_of_deliveries: driver INSERT own; fleet_manager SELECT all
-- spare_parts_requests: maintenance INSERT own; fleet_manager SELECT all
-- two_factor_sessions: driver INSERT/SELECT own
```

**Why this step comes now**

Without RLS, any authenticated user can read every row in every table. This must be locked down before any realtime channels are opened, because realtime respects RLS — if RLS is missing, drivers will receive other drivers' location updates.

**Files involved**
- `supabase/migrations/20260318000005_add_rls_policies.sql` ← CREATE

**Jira stories:** All stories involving data reads/writes.

**Expected outcome**

Each role can only access the rows it is authorised to see. Realtime channels will correctly filter events per user.

---

### Step 4 — Create Performance Index Migration

**Description**

Create `supabase/migrations/20260318000006_add_indexes.sql`:

```sql
CREATE INDEX idx_vlh_vehicle_id   ON vehicle_location_history(vehicle_id);
CREATE INDEX idx_vlh_trip_id      ON vehicle_location_history(trip_id);
CREATE INDEX idx_vlh_recorded_at  ON vehicle_location_history(recorded_at DESC);
CREATE INDEX idx_rde_trip_id      ON route_deviation_events(trip_id);
CREATE INDEX idx_ge_vehicle_id    ON geofence_events(vehicle_id);
CREATE INDEX idx_ge_geofence_id   ON geofence_events(geofence_id);
CREATE INDEX idx_mt_assigned_to   ON maintenance_tasks(assigned_to);
CREATE INDEX idx_trips_driver_id  ON trips(driver_id);
CREATE INDEX idx_trips_status     ON trips(status);
CREATE INDEX idx_notif_user_id    ON sierra_notifications(user_id);
```

**Why this step comes now**

Location history rows will accumulate at 1 row per vehicle per 5 seconds during every active trip. Without the `vehicle_id` + `recorded_at` indexes, the Fleet Manager live map query (latest position per vehicle) degrades to a full table scan within hours of Sprint 2 going live.

**Files involved**
- `supabase/migrations/20260318000006_add_indexes.sql` ← CREATE

**Jira stories:** FMS1-11

**Expected outcome**

Live map and location history queries remain fast regardless of trip volume.

---

### Step 5 — Revoke anon Role from overlap function

**Description**

Create `supabase/migrations/20260318000007_revoke_anon_overlap.sql`:

```sql
REVOKE EXECUTE ON FUNCTION check_resource_overlap(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM anon;
```

**Why this step comes now**

Migration `20260315000002` incorrectly granted this function to `anon`. Any unauthenticated user can query trip scheduling data. Fix this before any client deployment.

**Files involved**
- `supabase/migrations/20260318000007_revoke_anon_overlap.sql` ← CREATE

**Jira stories:** FMS1-71, FMS1-72

**Expected outcome**

Only authenticated users can call the overlap check function.

---

### Step 6 — Implement RealtimeSubscriptionManager

**Description**

Create `Sierra/Shared/Services/RealtimeSubscriptionManager.swift` as an `@Observable` class. Manage the following Supabase Realtime channels:

| Channel name | Table | Event | Handler |
|---|---|---|---|
| `vehicle-locations` | `vehicle_location_history` | INSERT | Update `AppDataStore.vehicleLocations[vehicleId]` |
| `emergency-alerts` | `emergency_alerts` | INSERT | Append to `AppDataStore.emergencyAlerts` |
| `route-deviations` | `route_deviation_events` | INSERT | Append to `AppDataStore.routeDeviations` |
| `geofence-events` | `geofence_events` | INSERT | Append to `AppDataStore.geofenceEvents` |
| `maintenance-updates` | `maintenance_tasks` | UPDATE | Update matching task in `AppDataStore.maintenanceTasks` |
| `notifications` | `sierra_notifications` | INSERT | Append to `AppDataStore.notifications` |

Expose:
- `func startAll()` — subscribe to all channels; called after successful login
- `func stopAll()` — unsubscribe from all channels; called on logout

Use the global `supabase` client from `SupabaseManager`. Each channel must call `.subscribe()` and handle `.subscribed`, `.channelError` states.

**Why this step comes now**

Every Sprint 2 monitoring feature (live map, alerts, geofence notifications, maintenance updates) reads from these streams. The manager must exist before any ViewModel tries to read realtime data.

**Files involved**
- `Sierra/Shared/Services/RealtimeSubscriptionManager.swift` ← CREATE
- `Sierra/Shared/Services/AppDataStore.swift` ← MODIFY: add `vehicleLocations`, `emergencyAlerts`, `routeDeviations`, `geofenceEvents`, `notifications` published properties
- `Sierra/SierraApp.swift` ← MODIFY: call `realtimeManager.startAll()` after auth success; `stopAll()` on logout

**Jira stories:** FMS1-11, FMS1-12, FMS1-14, FMS1-15, FMS1-45, FMS1-46, FMS1-50, FMS1-77, FMS1-78

**Expected outcome**

Live location updates, SOS alerts, route deviations, geofence events, and in-app notifications all flow into AppDataStore automatically in the background.

---

### Step 7 — Implement LocationPublishingService with 5-second throttle

**Description**

Create `Sierra/Shared/Services/LocationPublishingService.swift`:

```swift
@Observable final class LocationPublishingService {
    private var publishTask: Task<Void, Never>?
    private var pendingLocation: CLLocation?

    func startPublishing(tripId: String, vehicleId: String) {
        publishTask = Task {
            while !Task.isCancelled {
                if let loc = pendingLocation {
                    await insertLocationHistory(tripId: tripId, vehicleId: vehicleId, location: loc)
                    pendingLocation = nil
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func updateLocation(_ location: CLLocation) {
        pendingLocation = location // always holds latest; published on next 5-sec tick
    }

    func stopPublishing() {
        publishTask?.cancel()
        publishTask = nil
    }

    private func insertLocationHistory(tripId: String, vehicleId: String, location: CLLocation) async {
        // supabase.from("vehicle_location_history").insert(...)
    }
}
```

This service is NOT reactive. `updateLocation()` just stores the latest location. The `Task` loop polls on a 5-second clock.

**Why this step comes now**

`TripNavigationCoordinator` will call `updateLocation()` on every Mapbox delegate callback (sub-second frequency). The throttle must exist as a service before the coordinator is wired, or location rows will flood the database.

**Files involved**
- `Sierra/Shared/Services/LocationPublishingService.swift` ← CREATE

**Jira stories:** FMS1-11, FMS1-37

**Expected outcome**

Vehicle location rows are inserted at a maximum rate of once per 5 seconds per active trip, regardless of GPS update frequency.

---

## Phase 2 — Core Driver Trip Lifecycle

*Implement in this exact order. Each step depends on the previous.*

---

### Step 8 — Verify and fix TripNavigationCoordinator Mapbox rules

**Description**

Open `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` and verify:

1. Mapbox Directions API is called **once** in a non-reactive context (not inside a Combine publisher, not inside `onChange`, not inside a computed property). It must be called from an explicit `async` function triggered by a user action.
2. `NavigationViewController` is instantiated **only** inside `makeUIViewController` in `TripNavigationView.swift`, not stored in the coordinator or created elsewhere.
3. Wire `LocationPublishingService.updateLocation()` to the Mapbox `NavigationViewControllerDelegate.navigationViewController(_:didUpdate:)` callback. Do not call `publishLocation()` — just call `updateLocation()` to pass the latest CLLocation to the service.
4. Call `locationPublisher.startPublishing(tripId:vehicleId:)` when trip status becomes Active.
5. Call `locationPublisher.stopPublishing()` when trip ends.

If any of the above violations exist, fix them now.

**Why this step comes now**

Navigation is the runtime core of the driver flow. All downstream features (deviation detection, geofence monitoring, POD) depend on navigation running cleanly without API spam or rendering bugs.

**Files involved**
- `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` ← MODIFY
- `Sierra/Driver/Views/TripNavigationView.swift` ← VERIFY / MODIFY

**Jira stories:** FMS1-37, FMS1-39

**Expected outcome**

Mapbox navigation runs without reactive API calls. Location data flows into `LocationPublishingService` on every GPS update. Publishing to Supabase happens on the 5-second tick.

---

### Step 9 — Create DriverHomeViewModel

**Description**

Create `Sierra/Driver/ViewModels/DriverHomeViewModel.swift` as an `@Observable` class.

Responsibilities:
- Load assigned trip from `AppDataStore.assignedTrip` (already fetched on login)
- `toggleAvailability()` → calls `StaffMemberService.updateAvailability()` with the new status; does NOT touch vehicles table
- `var unreadAlertCount: Int` → computed from `AppDataStore.notifications.filter { !$0.isRead }.count`
- Expose `var currentTrip: Trip?`, `var driverAvailability: StaffAvailability`

**Why this step comes now**

`DriverHomeView` is the root of the driver flow. All other driver ViewModels read state that originates here. It must exist before any driver views are wired.

**Files involved**
- `Sierra/Driver/ViewModels/DriverHomeViewModel.swift` ← CREATE
- `Sierra/Driver/Views/DriverHomeView.swift` ← MODIFY: inject and use `DriverHomeViewModel`

**Jira stories:** FMS1-37, FMS1-38, FMS1-40, FMS1-75

**Expected outcome**

`DriverHomeView` renders live trip assignment and availability toggle backed by real data.

---

### Step 10 — Verify PreTripInspectionViewModel photo upload is sequential

**Description**

Open `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift`. Verify that photo uploads are sequential:

```swift
// CORRECT — sequential
for photo in inspectionPhotos {
    let url = await VehicleInspectionService.uploadPhoto(photo)
    uploadedURLs.append(url)
}

// WRONG — parallel (must not exist)
async let url1 = uploadPhoto(photo1)
async let url2 = uploadPhoto(photo2)
```

If parallel uploads exist, refactor to sequential. After upload, call `VehicleInspectionService.submitInspection()`. If inspection result is `failed`, the ViewModel must insert a row into `emergency_alerts` (defect alert) so the Fleet Manager is notified via the realtime channel set up in Step 6.

**Why this step comes now**

Pre-trip inspection is the gate before trip start. It must be fully functional and compliant before `StartTripSheet` is tested.

**Files involved**
- `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift` ← MODIFY
- `Sierra/Driver/Views/PreTripInspectionView.swift` ← VERIFY wiring

**Jira stories:** FMS1-36, FMS1-18, FMS1-43

**Expected outcome**

Photos upload one-at-a-time. A failed inspection creates a defect alert visible to the Fleet Manager in real time.

---

### Step 11 — Verify StartTripSheet calls TripService not manual status update

**Description**

Open `Sierra/Driver/Views/StartTripSheet.swift`. Verify:

1. The "Start Trip" action calls `TripService.startTrip(tripId:)` which does a Supabase UPDATE `trips SET status = 'Active'`.
2. There is NO direct call to update `vehicles` or `staff_members` status from Swift code. The DB trigger from Step 1 handles those transitions.
3. After the trip starts, `LocationPublishingService.startPublishing(tripId:vehicleId:)` is called via `TripNavigationCoordinator`.

Fix any violations found.

**Why this step comes now**

Trip start is the entry point of the active driver flow. If the DB trigger (Step 1) is in place and this call is correct, all downstream status transitions are automatic.

**Files involved**
- `Sierra/Driver/Views/StartTripSheet.swift` ← VERIFY / MODIFY
- `Sierra/Shared/Services/TripService.swift` ← VERIFY `startTrip()` exists

**Jira stories:** FMS1-37, FMS1-74

**Expected outcome**

Tapping "Start Trip" sets `trips.status = 'Active'`, which triggers vehicle → Busy and driver → Busy automatically.

---

### Step 12 — Implement RouteDeviationBannerView and wire to RouteDeviationService

**Description**

Create `Sierra/Driver/Views/RouteDeviationBannerView.swift`. This is an overlay banner (not a sheet) that appears when `AppDataStore.routeDeviations` has a new unacknowledged event for the current trip.

Wire `RouteDeviationService` inside `TripNavigationCoordinator`:
- On each `updateLocation()` call, check if the current CLLocation is within the allowed corridor of the planned route polyline (use Mapbox geometry utilities).
- If deviation exceeds threshold (e.g., 200m), call `RouteDeviationService.recordDeviation(tripId:location:)` which inserts into `route_deviation_events`.
- The realtime channel from Step 6 will deliver this event to both the driver (banner) and the Fleet Manager (alert inbox).

**Why this step comes now**

Location publishing (Step 7) and navigation coordinator (Step 8) must be running before deviation can be detected. The realtime channel (Step 6) must exist for the alert to reach the Fleet Manager.

**Files involved**
- `Sierra/Driver/Views/RouteDeviationBannerView.swift` ← CREATE
- `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` ← MODIFY: add deviation check
- `Sierra/Shared/Services/RouteDeviationService.swift` ← VERIFY `recordDeviation()` exists

**Jira stories:** FMS1-12, FMS1-50

**Expected outcome**

Driver sees a banner when off-route. Fleet Manager receives a deviation alert in real time.

---

### Step 13 — Implement GeofenceMonitorService and driver geofence notifications

**Description**

Create `Sierra/Shared/Services/GeofenceMonitorService.swift`. On `updateLocation()` (called from TripNavigationCoordinator):

- Fetch active geofences from `AppDataStore.geofences`
- For each geofence, compute whether the current location is inside the polygon/circle
- On state transition (outside → inside or inside → outside):
  - Call `GeofenceEventService.recordEvent(geofenceId:vehicleId:tripId:eventType:location:)` which inserts into `geofence_events`
  - The realtime channel from Step 6 delivers this event to both the driver (notification) and the Fleet Manager (alert inbox)

**Why this step comes now**

Geofence monitoring requires active location updates (Step 7/8), loaded geofences in AppDataStore, and the realtime channel (Step 6) to dispatch events.

**Files involved**
- `Sierra/Shared/Services/GeofenceMonitorService.swift` ← CREATE
- `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` ← MODIFY: call GeofenceMonitorService on each location update
- `Sierra/Shared/Services/GeofenceEventService.swift` ← VERIFY `recordEvent()` exists

**Jira stories:** FMS1-14, FMS1-77, FMS1-78

**Expected outcome**

When a vehicle enters or exits a geofenced zone, both the driver and Fleet Manager are notified in real time.

---

### Step 14 — Create ProofOfDeliveryViewModel

**Description**

Create `Sierra/Driver/ViewModels/ProofOfDeliveryViewModel.swift` as an `@Observable` class.

Responsibilities:
- `capturedPhotos: [UIImage]` — photo proofs
- `signatureData: Data?` — signature bitmap
- `enteredOTP: String` — raw OTP from user input (never stored to DB)
- `submitPOD()`:
  1. Upload photos **sequentially** using `for photo in capturedPhotos { await upload(photo) }`
  2. Hash OTP: `let otpHash = CryptoService.sha256(enteredOTP)` — store ONLY `otpHash`
  3. Call `TwoFactorSessionService.verifyAndConsume(hash: otpHash)` to validate
  4. Call `ProofOfDeliveryService.submit(tripId:photoURLs:signatureURL:otpHash:)`
  5. Call `TripService.completeDelivery(tripId:)` → updates `trips.status = 'Completed'` → DB trigger handles vehicle and driver status

**Why this step comes now**

POD is the penultimate step of the trip lifecycle. The sequential photo upload rule and OTP hashing rule are critical compliance requirements.

**Files involved**
- `Sierra/Driver/ViewModels/ProofOfDeliveryViewModel.swift` ← CREATE
- `Sierra/Driver/Views/ProofOfDeliveryView.swift` ← MODIFY: inject and use `ProofOfDeliveryViewModel`
- `Sierra/Shared/Services/CryptoService.swift` ← VERIFY `sha256()` exists

**Jira stories:** FMS1-40, FMS1-44

**Expected outcome**

Delivery completion uploads photos one-at-a-time, stores only an OTP hash, and triggers automatic status transitions via DB trigger.

---

### Step 15 — Create PostTripInspectionViewModel

**Description**

Create `Sierra/Driver/ViewModels/PostTripInspectionViewModel.swift` as an `@Observable` class.

Responsibilities:
- Mirrors `PreTripInspectionViewModel` structure
- Sequential photo upload
- On `failed` result: call `EmergencyAlertService.createDefectAlert(vehicleId:description:location:)`
- On completion: call `TripService.endTrip(tripId:finalOdometer:)` → updates `trips.status = 'Completed'` if not already completed

**Why this step comes now**

Post-trip inspection is the final step of the driver trip lifecycle. It is only reachable after POD (Step 14).

**Files involved**
- `Sierra/Driver/ViewModels/PostTripInspectionViewModel.swift` ← CREATE
- `Sierra/Driver/Views/PostTripInspectionView.swift` ← MODIFY: inject and use `PostTripInspectionViewModel`

**Jira stories:** FMS1-36, FMS1-38

**Expected outcome**

Post-trip inspection is functional. Trip ends cleanly. Defects raise alerts to Fleet Manager.

---

### Step 16 — Create FuelLogViewModel and FuelLogView

**Description**

Create `Sierra/Driver/ViewModels/FuelLogViewModel.swift` and `Sierra/Driver/Views/FuelLogView.swift`.

ViewModel responsibilities:
- `quantity: Double`, `costPerLitre: Double`, `totalCost: Double` (computed)
- `receiptImage: UIImage?`
- `odometerAtFillup: Int`
- `submitLog()`:
  1. Upload receipt image (single image, direct upload — no loop needed)
  2. Call `FuelLogService.createLog(tripId:quantity:cost:receiptURL:odometer:)`

View: form with numeric fields for quantity/cost, photo picker for receipt, odometer field.

**Why this step comes now**

Fuel logging is a standalone driver feature with no dependencies on navigation or realtime. It's implemented here because the core trip lifecycle (Steps 8–15) is now complete and this is the next driver story.

**Files involved**
- `Sierra/Driver/ViewModels/FuelLogViewModel.swift` ← CREATE
- `Sierra/Driver/Views/FuelLogView.swift` ← CREATE
- `Sierra/Driver/Views/DriverHomeView.swift` ← MODIFY: add fuel log entry point (button or tab)

**Jira stories:** FMS1-48, FMS1-49

**Expected outcome**

Driver can log fuel quantities, costs, receipts, and odometer readings.

---

### Step 17 — Create DriverMaintenanceRequestView

**Description**

Create `Sierra/Driver/Views/DriverMaintenanceRequestView.swift`.

Fields:
- Issue description (text)
- Severity picker (Low / Medium / High / Critical)
- Vehicle (pre-filled from current assignment)
- Photos (optional, sequential upload)

On submit: call `MaintenanceTaskService.createRequest(vehicleId:description:severity:photoURLs:requestedByDriver:true)` which inserts into `maintenance_tasks` with status `Pending Approval`. The insert triggers a `sierra_notifications` row for the Fleet Manager.

**Why this step comes now**

Driver can now create a maintenance request from within the app. Fleet Manager sees it in the approval queue (Phase 3 Step 21 wires that up).

**Files involved**
- `Sierra/Driver/Views/DriverMaintenanceRequestView.swift` ← CREATE
- `Sierra/Driver/Views/DriverHomeView.swift` ← MODIFY: add maintenance request entry point

**Jira stories:** FMS1-47

**Expected outcome**

Driver submits a maintenance request. It appears in the Fleet Manager's pending approvals queue.

---

### Step 18 — Complete DriverTripHistoryView

**Description**

Open `Sierra/Driver/Views/DriverTripHistoryView.swift` (currently 2.9 KB stub). Wire it to `TripService.fetchCompletedTrips(driverId:)` which queries `trips WHERE driver_id = auth.uid() AND status = 'Completed' ORDER BY scheduled_date DESC`.

Display: trip date, destination, distance, duration, status badge.

**Why this step comes now**

Trip history has no dependencies on any realtime or active-trip infrastructure. It is the last remaining driver-facing view.

**Files involved**
- `Sierra/Driver/Views/DriverTripHistoryView.swift` ← MODIFY (complete stub)
- `Sierra/Shared/Services/TripService.swift` ← MODIFY: add `fetchCompletedTrips(driverId:)`

**Jira stories:** FMS1-42, FMS1-79

**Expected outcome**

Driver can review all past trips with dates, destinations, and durations.

---

## Phase 3 — Fleet Manager Monitoring

*Realtime infrastructure from Phase 1 must be complete before any step in this phase.*

---

### Step 19 — Wire FleetLiveMapViewModel to realtime vehicle location stream

**Description**

Open `Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift` (currently 2.7 KB). Replace any polling `Timer` with observation of `AppDataStore.vehicleLocations` (a `[String: VehicleLocationHistory]` dictionary populated by the realtime channel from Step 6).

Expose:
- `var vehicleAnnotations: [VehicleMapAnnotation]` — computed from `AppDataStore.vehicleLocations.values`
- `var activeTrips: [Trip]` — filtered from `AppDataStore.trips` where `status == .active`
- `func centerMap(on vehicleId: String)` — programmatic camera movement

**Why this step comes now**

The realtime subscription (Step 6) and location publishing (Step 7) are now in place. This ViewModel simply reads the stream.

**Files involved**
- `Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift` ← MODIFY
- `Sierra/FleetManager/Views/FleetLiveMapView.swift` ← VERIFY/MODIFY: binds to ViewModel annotations

**Jira stories:** FMS1-11

**Expected outcome**

Fleet Manager sees vehicle pins move on the map in real time as drivers publish location updates.

---

### Step 20 — Create AlertsViewModel and wire AlertsInboxView

**Description**

Create `Sierra/FleetManager/ViewModels/AlertsViewModel.swift` as an `@Observable` class.

Reads from:
- `AppDataStore.emergencyAlerts` (SOS)
- `AppDataStore.routeDeviations`
- `AppDataStore.geofenceEvents`

Expose:
- `var allAlerts: [AlertItem]` — unified sorted list (most recent first)
- `var unreadCount: Int` — for tab badge
- `func markRead(id: String)` → Supabase UPDATE `emergency_alerts / route_deviation_events SET acknowledged = true`
- `func acknowledgeAlert(id: String, action: String)` → same, with action note

Wire `AlertsInboxView` and `AlertDetailView` to use `AlertsViewModel`.

**Why this step comes now**

Realtime channels (Step 6) already populate the alert streams in AppDataStore. This ViewModel is the reader layer between the streams and the UI.

**Files involved**
- `Sierra/FleetManager/ViewModels/AlertsViewModel.swift` ← CREATE
- `Sierra/FleetManager/Views/AlertsInboxView.swift` ← MODIFY
- `Sierra/FleetManager/Views/AlertDetailView.swift` ← MODIFY

**Jira stories:** FMS1-15, FMS1-12, FMS1-14

**Expected outcome**

Fleet Manager sees a unified real-time alert inbox with SOS, route deviation, and geofence breach events.

---

### Step 21 — Create GeofenceViewModel and GeofenceListView

**Description**

Create `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift` as an `@Observable` class.

Responsibilities:
- `fetchGeofences()` → `GeofenceService.fetchAll()` → populates `AppDataStore.geofences`
- `createGeofence(name:polygon:)` → `GeofenceService.create()`
- `updateGeofence(id:name:polygon:)` → `GeofenceService.update()`
- `deleteGeofence(id:)` → `GeofenceService.delete()`

Create `Sierra/FleetManager/Views/GeofenceListView.swift`:
- List of all geofences with name, zone type, and event count
- Tap → navigate to `CreateGeofenceSheet` in edit mode
- Swipe to delete

Wire `FleetManagerTabView` or `DashboardHomeView` to navigate to `GeofenceListView`.

**Why this step comes now**

Geofence monitoring (Step 13) requires geofences to exist in the database. Fleet Manager creates them here. `CreateGeofenceSheet` already exists; this step wraps it in a list with full CRUD.

**Files involved**
- `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift` ← CREATE
- `Sierra/FleetManager/Views/GeofenceListView.swift` ← CREATE
- `Sierra/FleetManager/Views/FleetManagerTabView.swift` ← MODIFY: add Geofences nav entry

**Jira stories:** FMS1-9, FMS1-14

**Expected outcome**

Fleet Manager can create, view, edit, and delete geofenced zones. Geofences are available to the driver-side monitor.

---

### Step 22 — Create MaintenanceApprovalViewModel and complete approval flow

**Description**

Create `Sierra/FleetManager/ViewModels/MaintenanceApprovalViewModel.swift` as an `@Observable` class.

Responsibilities:
- `fetchPendingRequests()` → `MaintenanceTaskService.fetchPending()` → filters `maintenance_tasks WHERE status = 'Pending Approval'`
- `approveRequest(id:assignedTo:)` → `MaintenanceTaskService.approve(id:assignedTo:)` → UPDATE `status = 'Approved'` → DB trigger (Step 2) sets vehicle to In Maintenance
- `rejectRequest(id:reason:)` → `MaintenanceTaskService.reject(id:reason:)` → UPDATE `status = 'Rejected'`
- After approve/reject, inserts into `sierra_notifications` to inform driver and maintenance staff

Wire `MaintenanceApprovalDetailView` and `MaintenanceRequestsView` to use this ViewModel.

**Why this step comes now**

The DB trigger (Step 2) is in place. This ViewModel is the client-side layer that calls the approve/reject actions. Maintenance staff workflow (Phase 4) depends on approved tasks existing.

**Files involved**
- `Sierra/FleetManager/ViewModels/MaintenanceApprovalViewModel.swift` ← CREATE
- `Sierra/FleetManager/Views/MaintenanceApprovalDetailView.swift` ← MODIFY
- `Sierra/FleetManager/Views/MaintenanceRequestsView.swift` ← MODIFY

**Jira stories:** FMS1-13, FMS1-16

**Expected outcome**

Fleet Manager can approve or reject maintenance requests. Approved requests auto-transition vehicle to In Maintenance via DB trigger.

---

## Phase 4 — Maintenance Workflow

*Requires approved maintenance tasks to exist (Phase 3 Step 22) and the realtime channel (Phase 1 Step 6).*

---

### Step 23 — Create MaintenanceTaskDetailViewModel

**Description**

Create `Sierra/Maintenance/ViewModels/MaintenanceTaskDetailViewModel.swift` as an `@Observable` class.

Responsibilities:
- `loadTask(id:)` → `MaintenanceTaskService.fetchTask(id:)` → loads task, associated vehicle, work order
- `startRepair()` → UPDATE `maintenance_tasks SET status = 'In Progress'` → inserts `sierra_notifications` row for Fleet Manager ("Repair started")
- `addNote(text:)` → `MaintenanceRecordService.addRecord(taskId:note:)` → inserts into `maintenance_records`
- `uploadRepairImage(data:)` → sequential upload to Supabase Storage `maintenance-images` bucket → append URL to `maintenance_records`
- `submitSparePartsRequest(parts:)` → `SparePartsRequestService.create(taskId:parts:)`
- `recordPartsUsed(parts:)` → `PartUsedService.recordParts(taskId:parts:)`
- `completeRepair()` → UPDATE `maintenance_tasks SET status = 'Completed'` → DB trigger (Step 2) returns vehicle to Available → inserts `sierra_notifications` for Fleet Manager

Do NOT manually update `vehicles.status`. The trigger handles it.

**Why this step comes now**

`MaintenanceTaskDetailView` is 18 KB and already exists but has no ViewModel. This is the missing binding layer for the entire maintenance workflow.

**Files involved**
- `Sierra/Maintenance/ViewModels/MaintenanceTaskDetailViewModel.swift` ← CREATE
- `Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift` ← MODIFY: inject and use ViewModel

**Jira stories:** FMS1-53, FMS1-54, FMS1-55, FMS1-56, FMS1-57, FMS1-60

**Expected outcome**

Maintenance personnel can view task details, start repairs, add notes, and mark complete — all triggering correct vehicle status transitions automatically.

---

### Step 24 — Wire MaintenanceDashboardViewModel to realtime task stream

**Description**

Open `Sierra/Maintenance/ViewModels/MaintenanceDashboardViewModel.swift` (currently 2.2 KB stub). Wire it to:
- `AppDataStore.maintenanceTasks` (populated by realtime UPDATE channel from Step 6)
- Filter to tasks where `assigned_to = currentUser.id`
- Expose `filterByStatus(status:) -> [MaintenanceTask]`
- Expose `filterByVehicle(vehicleId:) -> [MaintenanceTask]`
- Expose `sortedByPriority: [MaintenanceTask]`

**Why this step comes now**

`MaintenanceTaskDetailViewModel` (Step 23) handles individual tasks. This step makes the dashboard list reactive and filterable.

**Files involved**
- `Sierra/Maintenance/ViewModels/MaintenanceDashboardViewModel.swift` ← MODIFY
- `Sierra/Maintenance/Views/MaintenanceDashboardView.swift` ← MODIFY: add filter controls

**Jira stories:** FMS1-53, FMS1-63, FMS1-64

**Expected outcome**

Maintenance dashboard shows only the current user's assigned tasks, updates in real time when tasks change, and supports filtering by vehicle and status.

---

### Step 25 — Create RepairImageUploadView

**Description**

Create `Sierra/Maintenance/Views/RepairImageUploadView.swift`:
- Camera picker + photo library picker
- Image preview grid
- "Upload" button triggers `MaintenanceTaskDetailViewModel.uploadRepairImage()` for each image **sequentially** (one at a time)
- Shows per-image upload progress indicator
- Presented as a sheet from `MaintenanceTaskDetailView`

**Why this step comes now**

`MaintenanceTaskDetailViewModel.uploadRepairImage()` (Step 23) provides the upload action. This view is the UI surface for it.

**Files involved**
- `Sierra/Maintenance/Views/RepairImageUploadView.swift` ← CREATE
- `Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift` ← MODIFY: add "Add Photos" button that presents this sheet

**Jira stories:** FMS1-58

**Expected outcome**

Maintenance personnel can photograph repair work and upload images one-at-a-time attached to the maintenance record.

---

### Step 26 — Create SparePartsViewModel and wire SparePartsRequestSheet

**Description**

Create `Sierra/Maintenance/ViewModels/SparePartsViewModel.swift` as an `@Observable` class.

Responsibilities:
- `pendingParts: [PartEntry]` — list of parts being requested
- `addPart(name:quantity:estimatedCost:)`
- `removePart(at:)`
- `submitRequest(taskId:)` → `SparePartsRequestService.create(taskId:parts:pendingParts)`
- `recordUsed(taskId:)` → `PartUsedService.recordParts(taskId:parts:pendingParts)` (after repair)

Wire `SparePartsRequestSheet` to inject and use `SparePartsViewModel`.

**Why this step comes now**

`MaintenanceTaskDetailViewModel` calls `submitSparePartsRequest()` which delegates to this ViewModel. The sheet + ViewModel are the UI layer for that call.

**Files involved**
- `Sierra/Maintenance/ViewModels/SparePartsViewModel.swift` ← CREATE
- `Sierra/Maintenance/Views/SparePartsRequestSheet.swift` ← MODIFY: inject SparePartsViewModel

**Jira stories:** FMS1-61, FMS1-62

**Expected outcome**

Maintenance personnel can request spare parts and record parts used against a maintenance task.

---

## Phase 5 — Notification System

*Realtime channel is already running (Step 6). This phase wires the notification UI layer.*

---

### Step 27 — Create SOSAlertViewModel and wire SOSAlertSheet

**Description**

Create `Sierra/Driver/ViewModels/SOSAlertViewModel.swift` as an `@Observable` class.

Responsibilities:
- `currentLocation: CLLocation?` — updated from `TripNavigationCoordinator`
- `triggerSOS(tripId:vehicleId:)`:
  1. Call `EmergencyAlertService.createSOSAlert(driverId:vehicleId:tripId:latitude:longitude:)`
  2. This inserts into `emergency_alerts`
  3. Realtime channel (Step 6) immediately delivers the event to Fleet Manager's `AppDataStore.emergencyAlerts`
  4. `AlertsViewModel` (Step 20) surfaces it in the alerts inbox

Wire `SOSAlertSheet` to use `SOSAlertViewModel`.

**Why this step comes now**

The realtime delivery chain (Step 6 → Step 20) is now complete. This step wires the trigger end.

**Files involved**
- `Sierra/Driver/ViewModels/SOSAlertViewModel.swift` ← CREATE
- `Sierra/Driver/Views/SOSAlertSheet.swift` ← MODIFY: inject SOSAlertViewModel

**Jira stories:** FMS1-45, FMS1-15

**Expected outcome**

Driver taps SOS → Fleet Manager receives real-time alert in their inbox within seconds.

---

### Step 28 — Implement in-app notification banner for Driver and Maintenance

**Description**

`AppDataStore.notifications` is already populated by the realtime `sierra_notifications` channel (Step 6). Implement a notification banner overlay in:
- `DriverTabView.swift` — show banner when new notification arrives
- `MaintenanceTabView.swift` — show banner when task is assigned or updated

The banner should:
- Appear as a slide-down overlay with title + body
- Auto-dismiss after 4 seconds
- Tap to navigate to the relevant screen

Also update tab badges: `DriverTabView` and `MaintenanceTabView` should show unread notification count on the relevant tab icon.

**Why this step comes now**

Notifications are the final delivery surface for all realtime events. All upstream publishers (Steps 10, 22, 23, 27) are now in place.

**Files involved**
- `Sierra/Driver/DriverTabView.swift` ← MODIFY: add notification overlay + badge
- `Sierra/Maintenance/MaintenanceTabView.swift` ← MODIFY: add notification overlay + badge
- `Sierra/Shared/Views/NotificationBannerView.swift` ← CREATE

**Jira stories:** FMS1-46, FMS1-15, FMS1-66, FMS1-67

**Expected outcome**

All three user roles receive in-app notification banners for relevant events. Tab icons show unread badge counts.

---

### Step 29 — Merge StaffApplicationStore into AppDataStore

**Description**

`Sierra/Shared/Services/StaffApplicationStore.swift` (254 bytes) is a second `@Observable` store, violating the singleton rule. Move its state properties into `AppDataStore`. Update all references. Delete `StaffApplicationStore.swift`.

**Why this step comes now**

All realtime wiring and ViewModel work is complete. This is a clean-up of an architectural violation that could cause subtle state bugs during testing.

**Files involved**
- `Sierra/Shared/Services/StaffApplicationStore.swift` ← DELETE
- `Sierra/Shared/Services/AppDataStore.swift` ← MODIFY: absorb StaffApplicationStore state
- Any views referencing `StaffApplicationStore` ← MODIFY

**Jira stories:** Architecture compliance

**Expected outcome**

Single `@Observable` AppDataStore singleton. No second store exists.

---

## Phase 6 — Dashboard & Analytics

*All data sources are live by this point. This phase wires existing UI shells to real queries.*

---

### Step 30 — Wire DashboardHomeView stats to live DB queries

**Description**

Open `Sierra/FleetManager/Views/DashboardHomeView.swift` (19 KB). Connect the summary stats cards to real Supabase queries via AppDataStore:

- **Active Trips:** `AppDataStore.trips.filter { $0.status == .active }.count`
- **Available Vehicles:** `AppDataStore.vehicles.filter { $0.status == .available }.count`
- **Vehicles in Maintenance:** `AppDataStore.vehicles.filter { $0.status == .inMaintenance }.count`
- **Open Maintenance Requests:** `AppDataStore.maintenanceTasks.filter { $0.status == .pendingApproval }.count`
- **Unread Alerts:** `AppDataStore.emergencyAlerts.filter { !$0.acknowledged }.count`

All of these collections are already populated and kept live by `RealtimeSubscriptionManager`. No new queries needed — just compute from existing AppDataStore state.

**Why this step comes now**

All data streams are live. The dashboard just reads computed values.

**Files involved**
- `Sierra/FleetManager/Views/DashboardHomeView.swift` ← MODIFY

**Jira stories:** FMS1-24, FMS1-19

**Expected outcome**

Fleet Manager dashboard shows live fleet statistics that update in real time as trips start/end and maintenance states change.

---

### Step 31 — Wire AnalyticsDashboardView and ReportsView to real data

**Description**

Open `Sierra/FleetManager/Views/AnalyticsDashboardView.swift` (32 KB) and `ReportsView.swift` (13 KB). Implement data queries via `TripService` and `MaintenanceRecordService`:

- **Fleet usage:** trips count per vehicle in last 30 days
  ```sql
  SELECT vehicle_id, COUNT(*) FROM trips
  WHERE scheduled_date > now() - interval '30 days'
  GROUP BY vehicle_id
  ```
- **Driver performance:** trips completed per driver, on-time rate, deviation event count
- **Maintenance history:** completed maintenance tasks per vehicle, average repair time

These are one-time `async` fetch calls triggered on view appear. Not realtime.

Also implement `DriverHistoryView.swift` (11 KB — already exists): ensure it queries `trips WHERE driver_id = :id ORDER BY scheduled_date DESC` and displays trip history correctly.

**Why this step comes now**

Analytics queries run against historical data that exists from all the Sprint 2 trips. This is the final layer.

**Files involved**
- `Sierra/FleetManager/Views/AnalyticsDashboardView.swift` ← MODIFY
- `Sierra/FleetManager/Views/ReportsView.swift` ← MODIFY
- `Sierra/FleetManager/Views/DriverHistoryView.swift` ← VERIFY/MODIFY

**Jira stories:** FMS1-20, FMS1-21, FMS1-10, FMS1-17

**Expected outcome**

Fleet Manager can view fleet usage charts, driver performance summaries, and vehicle maintenance history.

---

### Step 32 — Git hygiene and architecture cleanup

**Description**

1. Move `Sierra/sendEmail.swift` → merge into `Sierra/Shared/Services/EmailService.swift`, delete root file
2. Add `**/.DS_Store` to `.gitignore`
3. Run `git rm --cached .DS_Store Sierra/.DS_Store` and commit
4. Verify `CryptoService.swift` `sha256()` is used and OTP is never stored raw in `two_factor_sessions` — add a code comment confirming compliance

**Why this step comes now**

All features are implemented. Final clean-up before demo.

**Files involved**
- `.gitignore` ← MODIFY
- `Sierra/sendEmail.swift` ← DELETE
- `Sierra/Shared/Services/EmailService.swift` ← MODIFY
- `Sierra/Shared/Services/CryptoService.swift` ← VERIFY

**Jira stories:** Architecture compliance

**Expected outcome**

Clean repository. No stray files. OTP compliance confirmed.

---

## Execution Summary

| Phase | Steps | Key Blocker Resolved |
|---|---|---|
| 1 — Infrastructure | 1–7 | DB triggers, RLS, indexes, realtime channels, location throttle |
| 2 — Driver Trip | 8–18 | Full trip lifecycle end-to-end |
| 3 — Fleet Manager | 19–22 | Live map, alerts, geofences, maintenance approvals |
| 4 — Maintenance | 23–26 | Task detail, repair images, parts workflow |
| 5 — Notifications | 27–29 | SOS, banners, store cleanup |
| 6 — Analytics | 30–32 | Dashboard stats, reports, git cleanup |

**Total steps:** 32
**Deadline:** 22 March 2026

> Every step in Phase 1 is a hard prerequisite for every step in every subsequent phase. Do not begin Phase 2 until all 7 Phase 1 steps are complete and deployed to the Supabase project.
