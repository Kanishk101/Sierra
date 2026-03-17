# Sierra FMS — Sprint 2 Complete Implementation Context
## Master Reference Document for AI-Assisted Development

---

## 1. Project Overview

Sierra is a Fleet Management System (FMS) iOS application built for logistics and transportation organisations. It is a SwiftUI application following MVVM architecture with Swift Concurrency throughout. The backend is Supabase (Postgres 17, project ID: ldqcdngdlbbiojlnbnjg, region: ap-south-1). The app targets three user roles: Fleet Manager (Admin), Driver, and Maintenance Personnel.

The repository is Kanishk101/Sierra on GitHub, active development branch is main. The app uses @Observable for state management (NOT @ObservableObject/@Published), with AppDataStore as the central singleton state container accessed via AppDataStore.shared. Authentication is handled by AuthManager.shared. The Supabase client is accessed via the global supabase variable defined in SupabaseManager.swift.

Sprint 1 established the foundation: authentication with OTP, role-based routing, staff management (create/approve/reject), vehicle management (CRUD), trip creation and assignment, and onboarding flows for all three roles. Sprint 2 (March 17-22, 2026 deadline) adds the live operational layer — everything that happens when a trip is actually running.

---

## 2. Sprint 2 — What We Are Building

Sprint 2 is divided into five major modules. Every module corresponds to real Jira stories in the Fleet-ManagementSystem project (project key: FMS1). The modules are:

### Module 1: Live Trip and MapKit/Mapbox Navigation
### Module 2: Trip Lifecycle (Driver-side execution flow)
### Module 3: Alerts and SOS
### Module 4: Maintenance Workflow
### Module 5: Dashboard and Reports

Each is described in exhaustive detail in the sections below.

---

## 3. Technology Decisions

### Navigation: Mapbox Navigation SDK v3 (NOT Apple Maps, NOT Google Maps)

Apple MapKit alone cannot provide: multiple route alternatives, green/eco routing, real-time traffic incident alerts with auto-reroute, in-app turn-by-turn navigation steps, toll/highway avoidance as routing parameters, or voice guidance. Apple does not expose the NavigationViewController equivalent publicly.

Google Maps Navigation SDK requires a Fleet licensing contract and is not available free to individual developers. The standard Google Maps SDK only provides map display and basic directions, not in-app navigation.

Mapbox Navigation SDK v3 (from the mapbox-navigation-ios repository, main branch) is fully open source under BSD license and free within the usage tier (50,000 map loads and 100,000 Directions API requests per month). It provides everything needed: in-app turn-by-turn with a single NavigationViewController call, voice guidance built in, automatic rerouting, real-time incident overlays, waypoint/stop sequencing, toll and highway avoidance as RouteOptions parameters, and ETA/distance/arrival time all computed natively.

The installed SPM packages are: MapboxNavigationCore (navigation engine and NavigationViewController), MapboxNavigationUIKit (UI layer for NavigationViewController), MapboxDirections (RouteOptions, Waypoint types), MapboxMaps (map display, MapboxOptions for token). These all come from the single mapbox-navigation-ios package — no separate mapbox-maps-ios needed.

The Mapbox public access token is stored in Config/Secrets.xcconfig (never committed to git, gitignored) and injected into Info.plist at build time via the build variable MAPBOX_ACCESS_TOKEN which maps to the Info.plist key MBXAccessToken. At runtime, SierraApp.swift reads it: MapboxOptions.accessToken = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String ?? "". The Secrets.xcconfig.template file IS committed as a template for teammates.

For the admin-side fleet overview map, MapKit is used (not Mapbox). The admin does not navigate — they only observe vehicles on a map. MapKit handles this perfectly with MKAnnotationView objects updated in real time as Supabase Realtime pushes vehicle coordinate updates. No Mapbox map load costs are incurred for the admin map.

### Real-time Data: Supabase Realtime

All live data flows use Supabase Realtime (WebSocket channels). The existing AppDataStore already has channels for emergency_alerts, staff_members, vehicles, and trips. Sprint 2 adds a notifications channel. Vehicle location data is published by the driver every 5 seconds via a Timer (never more frequently, rate-gated both in the Timer and inside VehicleLocationService) to vehicles.current_latitude and vehicles.current_longitude, which the admin's vehicle channel subscription immediately picks up and moves the map annotation.

### State Management: @Observable AppDataStore

The AppDataStore is declared as @MainActor @Observable final class. There are no @Published property wrappers — this is the modern Swift Observation framework. All UI automatically re-renders when any stored property changes. The class is a singleton (AppDataStore.shared) injected into the view hierarchy via .environment(AppDataStore.shared). Sprint 2 additions to AppDataStore are purely additive — no existing properties or methods are changed or removed.

### Database: Supabase Postgres 17 with Triggers

Three Postgres triggers were added in the Sprint 2 schema migration that fire on trips.status transitions: trg_trip_started (Scheduled to Active) sets vehicles.status to Busy and staff_members.availability to On Trip; trg_trip_completed (Active to Completed) updates odometer, total_trips, total_distance_km on vehicles and total_trips_completed, total_distance_km on driver_profiles, and resets both vehicle and driver statuses; trg_trip_cancelled resets vehicle to Idle and driver to Available. This means Swift code must NEVER attempt to update vehicles or staff_members when changing trip status — the triggers do it atomically and any duplicate update would cause a race condition.

There is NO Row Level Security on any table. All data access logic lives entirely in the iOS client. Supabase is a pure data store.

---

## 4. Sprint 2 Schema Changes (Already Applied)

The following changes have already been applied to the live Supabase project via migration:

New tables: vehicle_location_history (GPS breadcrumb trail for active trips), route_deviation_events (structured deviation records per trip with acknowledgement state), notifications (per-user personal inbox, separate from the shared activity_logs audit trail), trip_expenses (toll and parking receipts), spare_parts_requests (pre-approval workflow for parts before use).

New columns on existing tables: staff_members gets failed_login_attempts and account_locked_until for automatic lockout. trips gets origin_latitude, origin_longitude, destination_latitude, destination_longitude (needed for map routing and deviation detection), route_polyline (encoded polyline string for the planned route), driver_rating, driver_rating_note, rated_by_id, rated_at (post-trip rating system). vehicle_inspections gets photo_urls text array (vehicle photos before trip), is_defect_raised boolean, raised_task_id FK to maintenance_tasks. proof_of_deliveries gets delivery_otp_hash, delivery_otp_expires_at, notes. work_orders gets repair_image_urls text array and estimated_completion_at. maintenance_tasks gets approved_by_id, approved_at, rejection_reason. geofences gets geofence_type enum.

New enums: geofence_type (Warehouse, Delivery Point, Restricted Zone, Custom), notification_type (Trip Assigned, Trip Cancelled, Vehicle Assigned, Maintenance Approved, Maintenance Rejected, Maintenance Overdue, SOS Alert, Defect Alert, Route Deviation, Geofence Violation, Inspection Failed, General), trip_expense_type (Toll, Parking, Other), spare_parts_request_status (Pending, Approved, Rejected, Fulfilled). Existing enums extended: emergency_alert_type gains Defect value, activity_type gains Route Deviation value.

---

## 5. Module 1: Live Trip and Mapbox Navigation (Driver Side)

### What It Is

The complete in-app navigation experience for drivers. When a driver starts a trip, they launch a full-screen navigation interface powered entirely by Mapbox — never leaving the Sierra app, never switching to Apple Maps or Google Maps. This is architecturally identical to how Uber or Grab handle in-app navigation.

### Route Options

When the driver taps Start Navigation in StartTripSheet, a single Mapbox Directions API call is made with alternatives=true. The response returns multiple route alternatives. Sierra labels them: Fastest Route (the alternative with lowest duration) and Green Route (the alternative with lowest total distance, which correlates to least fuel consumed since shorter routes avoid unnecessary highway mileage). The driver selects one. This is one API call total — never reactive, never on text input changes, never on state changes.

### Trip Coordinates

The Fleet Manager populates origin_latitude, origin_longitude, destination_latitude, destination_longitude on the trips row when creating the trip (in CreateTripView). These are the coordinates Mapbox uses to build the route. The plain text origin and destination strings already in the table are just for display. The encoded route polyline chosen by the driver is saved to trips.route_polyline for later use in deviation detection.

### Avoidance Options

RouteOptions.roadClassesToAvoid is set based on the driver's preferences in StartTripSheet. Toll avoidance excludes the .toll road class. Highway avoidance excludes the .motorway road class. These are first-class Mapbox SDK parameters — no custom logic needed.

### Waypoints and Stops

The driver can add intermediate stops. Each stop is a Waypoint object added to the RouteOptions waypoints array. Adding a stop triggers a new Directions API call (the only other trigger besides the initial route build). The Add Stop text field has a 500ms debounce using Swift Task cancellation — typing 20 characters fires 1 API call, not 20.

### In-App Navigation UI

TripNavigationView is a UIViewControllerRepresentable wrapping Mapbox's NavigationViewController. The NavigationViewController is created exactly once in makeUIViewController — never in updateUIViewController. It provides automatically: turn-by-turn step instructions with voice guidance, live ETA recalculation, automatic rerouting when the driver deviates, incident and construction banners from Mapbox's traffic layer, lane guidance, and arrival detection. Sierra does not re-implement any of this — it delegates entirely to the SDK.

On top of TripNavigationView, a SwiftUI ZStack overlay called NavigationHUDOverlay adds Sierra-branded UI: current step instruction banner at the top, stats row showing distance remaining (formatted as 1.2 km or 340 m), ETA time, and minutes remaining, a speed badge in km/h, an off-route yellow banner when deviation is detected, and a bottom action bar with SOS (red), Report Incident, Add Stop, and End Trip buttons.

### Location Publishing (Critical Rate-Limiting)

A Timer fires every 5 seconds. Inside the timer, the driver's current GPS coordinates are published to Supabase. The Timer is stored as a private property with a nil guard preventing double-start. VehicleLocationService has an additional internal throttle (lastPublishTime + 5 second minimum) as a second defensive layer. At maximum rate this is 1 location write per 5 seconds, or 720 writes per hour per active trip. With 7 active vehicles all navigating simultaneously that is 5,040 writes per hour — well within Supabase free tier limits.

Each location write does two things: inserts a row into vehicle_location_history (breadcrumb trail) and updates current_latitude and current_longitude on the vehicles row. The vehicle update triggers the admin's Realtime subscription and moves their map annotation.

### Deviation Detection (Zero API Cost)

Route deviation is computed entirely on the device using local Haversine math. The planned route polyline (stored in trips.route_polyline as an encoded Google Polyline string) is decoded into an array of CLLocationCoordinate2D on the device. On every location update from NavigationViewController's delegate, the perpendicular distance from the current position to each line segment in the decoded polyline is computed in Swift using the Haversine formula. The minimum distance across all segments is the deviation distance. No API calls. No network requests. Pure math.

If deviation distance exceeds 200 metres AND at least 60 seconds have passed since the last deviation was recorded, a row is inserted into route_deviation_events, an activity_log row of type Route Deviation is inserted, and a notification is inserted for all Fleet Managers. The 60-second cooldown prevents flooding the database with hundreds of deviation records during a prolonged off-route situation.

### Geofencing (CoreLocation CLCircularRegion)

At trip start, all active geofences from AppDataStore.geofences are registered as CLCircularRegion objects with CLLocationManager. When the device triggers a region entry or exit, the app inserts a row into geofence_events and a notification for the Fleet Manager. This is entirely handled by CoreLocation on the device — no continuous polygon checking, no custom algorithms.

---

## 6. Module 1: Admin Fleet Live Map (MapKit)

### What It Is

The Fleet Manager's real-time overview of all vehicles. This is a MapKit Map view (not Mapbox) because the admin does not navigate — they observe. MapKit is free, built into iOS, and perfectly capable of displaying moving annotations.

### Live Vehicle Updates

AppDataStore already has subscribeToVehicleUpdates() which keeps the vehicles array live via Supabase Realtime. The admin fleet map reads from AppDataStore.vehicles directly — no new subscription needed. When a vehicle's current_latitude and current_longitude change (pushed every 5 seconds by the driver), the Realtime event fires, AppDataStore.vehicles is updated, and the map annotation moves.

Vehicle annotations update in-place — the coordinate of the existing annotation is updated, never replaced. Replacing the entire annotation array causes visible flicker for all other vehicles.

### Geofence Overlays

All active geofences are drawn as MKCircle overlays on the admin map. Color coded by type: Warehouse is blue, Delivery Point is green, Restricted Zone is red, Custom is grey. Overlays are added once when geofences load, not re-added on every state change.

### Vehicle Detail on Tap

Tapping a vehicle annotation presents a VehicleMapDetailSheet showing: vehicle info, current trip details if on an active trip, driver name and phone, current speed from the latest vehicle_location_history row, deviation distance if any, ETA, and action buttons (View Full Trip, Send Alert to Driver, Assign to Trip if idle).

### Breadcrumb Trail

When the admin taps a vehicle, the breadcrumb trail (the path taken so far) is loaded from vehicle_location_history for that vehicle and trip. This fetch is on-demand only — never pre-loaded for all vehicles, never on a timer. One tap = one DB query.

### Create Geofence

A floating Create Geofence button opens CreateGeofenceSheet. The admin can tap a point on the map or type an address (geocoded via Mapbox Geocoding API, not Google Maps — same Mapbox token, and CLGeocoder is used for reverse geocoding which is Apple and completely free). Radius is set via slider (100m to 5000m). Type, name, alert on entry/exit toggles. Saved to Supabase via GeofenceService. Validation prevents saving at coordinates (0, 0) or with empty name.

---

## 7. Module 2: Trip Lifecycle (Driver Side)

### Full Execution Flow

The driver-side trip execution follows this exact sequence: View Assigned Trip in TripDetailDriverView, tap Begin Pre-Trip Inspection, complete PreTripInspectionView (checklist + photos), if result is Passed or Passed with Warnings proceed to StartTripSheet (route options, avoidance settings, odometer input), tap Start Navigation to launch TripNavigationContainerView, navigate to destination, tap Complete Delivery from the navigation HUD, submit ProofOfDeliveryView (photo or signature or OTP), complete PostTripInspectionView, trip ends and the DB trigger fires updating all stats.

### Pre-Trip Inspection

A multi-step form. Step 1 is a checklist of 13 items (Brakes, Tyres, Lights Front, Lights Rear, Horn, Wipers, Mirrors, Fuel Level, Engine Oil, Coolant, Steering, Seatbelt, Dashboard Warning Lights). Each item has a Pass/Fail/Warning segmented picker and optional notes. Step 2 is photo upload — up to 5 photos via PhotosPicker, uploaded sequentially (not concurrently) to Supabase Storage bucket inspection-photos. Step 3 is summary and submit. If any item is Fail, overall result is Failed and the Fleet Manager is notified. If any item is Warning, result is Passed with Warnings. If all Pass, result is Passed.

Photo uploads are sequential in a for-loop with individual catch blocks — a failed photo upload logs the error but does not block the inspection from being submitted. The inspection row is inserted FIRST with all photo URLs, then trips.pre_inspection_id is updated to point to the new inspection ID. This order is critical — never update the trip row first.

If inspection result is Failed, a maintenance task is automatically created with source_inspection_id pointing to this inspection and is_defect_raised set to true on the inspection row.

### OTP Delivery Verification

If the driver selects OTP Verification as the proof of delivery method, the app generates a 6-digit OTP on device, hashes it using the existing CryptoService (already in the codebase at Sierra/Shared/Services/CryptoService.swift), stores the hash in proof_of_deliveries.delivery_otp_hash, and stores now() + 10 minutes in delivery_otp_expires_at. The plaintext OTP is displayed to the driver to read to the recipient. When the driver enters what the recipient says, the app hashes the entered value and compares to the stored hash. The plaintext OTP never touches Supabase.

### Trip Completion Gate

The completeTrip call is blocked until proof_of_delivery_id is non-nil on the trip. The driver cannot end the trip without submitting proof of delivery. This is enforced in the UI by showing an error if the driver tries to skip this step.

---

## 8. Module 3: Alerts and SOS

### Driver-Side SOS

The SOS button is available in the NavigationHUDOverlay during navigation. Pressing it opens SOSAlertSheet — a full-screen red modal (not a small sheet). The driver selects alert type: SOS, Accident, Breakdown, Medical, or Defect. Defect is new in Sprint 2 for vehicle issues noticed mid-trip that don't stop the trip but need FM visibility. The driver optionally adds a description. GPS coordinates are captured from CLLocationManager at time of submission. The send button is disabled on first tap (isSending guard) and re-enabled only on network failure — preventing duplicate alerts. After sending, a confirmation is shown for 3 seconds.

The SOS submission inserts a row into emergency_alerts and inserts a notification of type SOS Alert or Defect Alert for all Fleet Managers and an activity_log row of severity Critical.

### Fleet Manager Alert Inbox

AlertsInboxView is a dedicated tab (bell icon) in FleetManagerTabView showing three sections: Active Emergency Alerts (sorted by triggered_at descending), Unacknowledged Route Deviations (sorted by detected_at), and Overdue Maintenance tasks. All data comes from AppDataStore in-memory arrays — no additional Supabase queries on load.

Reverse geocoding of alert GPS coordinates (to show "near Koramangala, Bangalore" instead of raw coordinates) uses CLGeocoder (Apple, completely free and unlimited for reverse geocoding) not the Mapbox Geocoding API. Results are cached in a dictionary keyed by alert ID so each alert is only geocoded once per session.

AlertDetailView shows an embedded MapKit map pin at the alert location, full driver and vehicle info, and action buttons: Acknowledge (updates status to Acknowledged, sends notification back to driver), Create Maintenance Task (pre-fills from the alert), Resolve, and a Call Driver button using a tel:// URL. The tel:// UIApplication.shared.open() is the only external open call permitted anywhere in the codebase.

### Notification Centre

A bell icon in every role's navigation bar presents NotificationCentreView. It reads from AppDataStore.notifications (populated and kept live by the Realtime subscription set up at login). Tapping a notification marks it read (one Supabase call) and navigates to the entity_type/entity_id. A Mark All Read button is in the toolbar. The unread count badge on the bell icon reflects AppDataStore.unreadNotificationCount.

### Overdue Maintenance Alerts

checkOverdueMaintenance() is called at FM app launch and every time the app foregrounds (via UIApplication.didBecomeActiveNotification). It filters AppDataStore.maintenanceTasks for Pending tasks past their due_date and checks AppDataStore.notifications in-memory for existing Maintenance Overdue notifications for each task ID. Only inserts new notifications for tasks that don't already have one. No Supabase query for the deduplication check — purely in-memory.

---

## 9. Module 4: Maintenance Workflow

### Maintenance Personnel Dashboard

MaintenanceDashboardView is a full rebuild of the thin skeleton that existed in Sprint 1. It shows the maintenance person's assigned tasks with filter tabs (All, Pending, In Progress, Completed) and vehicle filter chips. Data freshness is throttled — loadTasks() only re-fetches if lastFetchedAt is nil or older than 60 seconds, preventing hammering Supabase on every view appearance.

Tapping a task opens MaintenanceTaskDetailView showing the full task, the vehicle (with VIN, model, odometer), a visual status timeline stepper, and the work order form. The Start Work button is disabled on tap (isStartingWork = true) and checks for an existing work order before creating a new one — enforcing the UNIQUE constraint on work_orders.maintenance_task_id at the app layer before hitting the DB.

Work order fields include repair description, estimated completion time (DatePicker), parts used (add part rows each with name, part number, quantity, unit cost), repair images (PhotosPicker, sequential uploads identical to inspection photos), spare parts request button, labour cost, and technician notes. The parts_cost_total on the work order is always computed from the parts_used rows sum — never a manually editable field. When the maintenance person marks the work order complete, a MaintenanceRecord is created and a notification is sent to all Fleet Managers.

### Fleet Manager Approval Flow

MaintenanceRequestsView is a new tab in FleetManagerTabView showing all maintenance tasks grouped by status (Pending Approval, Approved, Rejected, All). Tapping a task opens MaintenanceApprovalDetailView which shows the full task, any linked inspection with its photos, a staff picker for assigning to a maintenance person, and Approve and Reject buttons.

Approve calls MaintenanceTaskService.approveTask() which in a single .update() call sets status to Assigned, approved_by_id, approved_at, and assigned_to_id. Then sends a notification to the assigned maintenance person and to the driver who originally raised the request. Reject calls rejectTask() which in a single .update() call sets status to Cancelled, approved_by_id, approved_at, and rejection_reason. Then sends a notification to the driver explaining why. Both notification sends are wrapped in non-fatal try/catch — a notification failure never rolls back the approval/rejection.

---

## 10. Module 5: Dashboard and Reports

### Dashboard Live Data

DashboardHomeView stats cards are computed from AppDataStore in-memory arrays — zero extra Supabase queries. Active vehicles count filters vehicles by status Busy or Active. Active trips count filters trips by status Active. Pending approvals sums pending staff applications plus pending maintenance tasks. Overdue maintenance filters maintenance tasks by status Pending and dueDate less than now. Available drivers filters staff by role driver, status Active, and availability Available. The recent activity feed shows the last 10 activityLogs entries already loaded in AppDataStore.

### Analytics Dashboard

AnalyticsDashboardView has a date range picker (Last 7, 30, or 90 days). Filtering is applied to AppDataStore.trips in Swift — NOT by firing new Supabase queries with different date parameters. Trip stats (count, total distance, average duration) are derived from the filtered trips array. Driver performance is a list of all drivers with their computed stats. Maintenance summary uses AppDataStore.maintenanceTasks and AppDataStore.maintenanceRecords. Vehicle status breakdown is a bar chart built with pure SwiftUI GeometryReader bars — no external chart library, or Apple Charts framework if the deployment target is iOS 16+.

### Driver History and Rating

DriverHistoryView loads a specific driver's completed trips from Supabase scoped to that driver with .limit(50) — never loading all trips. The FM can rate any unrated completed trip with a 1-5 star picker plus optional note, which calls TripService.rateDriver() updating driver_rating, driver_rating_note, rated_by_id, rated_at on the trips row. The driver's average_rating in driver_profiles is periodically recomputed in the app from this trip-level data. Average rating computation always excludes nil-rated trips from the denominator.

Driver deactivation shows a confirmation Alert before executing. The deactivation sets staff_members.status to Suspended.

### Reports Export

ReportsView generates CSV strings in memory from AppDataStore data plus a scoped Supabase query for fuel_logs and trip_expenses (not loaded in AppDataStore normally). CSV is shared via UIActivityViewController with the CSV string as the activity item. No file system writes, no FileManager, no Documents directory. The CSV generates synchronously from in-memory data. Three report types: Fleet Usage, Driver Activity, and Maintenance.

---

## 11. New Swift Models Required (Phase 1)

The following new Swift model files must be created in Sierra/Shared/Models/:

VehicleLocationHistory.swift — models the vehicle_location_history table. Fields: id UUID, vehicleId UUID, tripId UUID optional, driverId UUID optional, latitude Double, longitude Double, speedKmh Double optional, recordedAt Date, createdAt Date. All using snake_case CodingKeys.

RouteDeviationEvent.swift — models route_deviation_events. Fields: id UUID, tripId UUID, driverId UUID, vehicleId UUID, latitude Double, longitude Double, deviationDistanceM Double, isAcknowledged Bool default false, acknowledgedBy UUID optional, acknowledgedAt Date optional, detectedAt Date, createdAt Date.

SierraNotification.swift — MUST be named SierraNotification not Notification to avoid collision with Foundation.Notification. Fields: id UUID, recipientId UUID, type NotificationType enum, title String, body String, entityType String optional, entityId UUID optional, isRead Bool, readAt Date optional, sentAt Date, createdAt Date. NotificationType enum with raw String values matching Postgres exactly including spaces: "Trip Assigned", "Trip Cancelled", "Vehicle Assigned", "Maintenance Approved", "Maintenance Rejected", "Maintenance Overdue", "SOS Alert", "Defect Alert", "Route Deviation", "Geofence Violation", "Inspection Failed", "General".

TripExpense.swift — models trip_expenses. Fields: id UUID, tripId UUID, driverId UUID, vehicleId UUID, expenseType TripExpenseType enum, amount Double, receiptUrl String optional, notes String optional, loggedAt Date, createdAt Date. TripExpenseType enum: Toll, Parking, Other with raw values matching exactly.

SparePartsRequest.swift — models spare_parts_requests. Fields: id UUID, maintenanceTaskId UUID, workOrderId UUID optional, requestedById UUID, partName String, partNumber String optional, quantity Int, estimatedUnitCost Double optional, supplier String optional, reason String, status SparePartsRequestStatus enum, reviewedBy UUID optional, reviewedAt Date optional, rejectionReason String optional, fulfilledAt Date optional, createdAt Date, updatedAt Date.

The following existing models must be updated with new columns:

Trip.swift — add: originLatitude Double optional, originLongitude Double optional, destinationLatitude Double optional, destinationLongitude Double optional, routePolyline String optional, driverRating Int optional, driverRatingNote String optional, ratedById UUID optional, ratedAt Date optional.

VehicleInspection.swift — add: photoUrls [String] default empty array, isDefectRaised Bool default false, raisedTaskId UUID optional.

ProofOfDelivery.swift — add: deliveryOtpHash String optional, deliveryOtpExpiresAt Date optional, notes String optional.

WorkOrder.swift — add: repairImageUrls [String] default empty array, estimatedCompletionAt Date optional.

MaintenanceTask.swift — add: approvedById UUID optional, approvedAt Date optional, rejectionReason String optional.

Geofence.swift — add: geofenceType GeofenceType enum default .custom. GeofenceType enum with raw values: "Warehouse", "Delivery Point" (with space), "Restricted Zone" (with space), "Custom".

EmergencyAlert.swift — add Defect case to the emergency alert type enum with raw value "Defect".

ActivityLog.swift — add Route Deviation case to the activity type enum with raw value "Route Deviation" (with space).

StaffMember.swift — add: failedLoginAttempts Int default 0, accountLockedUntil Date optional.

---

## 12. New Swift Services Required (Phase 2)

All services use the global supabase variable (NOT SupabaseManager.shared.client). Realtime subscriptions use RealtimeChannelV2 and .subscribeWithError() as seen in AppDataStore's existing subscriptions.

NotificationService.swift — fetch, markAsRead, markAllAsRead, insertNotification, subscribeToNotifications (creates RealtimeChannelV2 with nil guard and stores as private property), unsubscribeFromNotifications.

VehicleLocationService.swift — publishLocation (inserts to vehicle_location_history AND updates vehicles coordinates, with internal 5-second throttle via lastPublishTime guard), fetchLocationHistory.

RouteDeviationService.swift — recordDeviation (inserts to route_deviation_events, inserts activity_log, inserts notifications for fleet managers — notifications wrapped in non-fatal catch), fetchDeviations, acknowledgeDeviation.

TripExpenseService.swift — logExpense, fetchExpenses.

SparePartsRequestService.swift — submitRequest, fetchRequests, approveRequest, rejectRequest, markFulfilled.

Updated existing services:

TripService.swift additions: startTrip (updates status to Active and actual_start_date and start_mileage ONLY — triggers handle vehicle and driver, never update those here), completeTrip (updates status to Completed and actual_end_date and end_mileage ONLY), cancelTrip (updates status to Cancelled ONLY), updateTripCoordinates, rateDriver.

VehicleInspectionService.swift: submitInspectionWithPhotos with photo_urls as Swift [String] array directly.

MaintenanceTaskService.swift: approveTask (single .update() call), rejectTask (single .update() call).

WorkOrderService.swift: updateRepairImages, setEstimatedCompletion.

---

## 13. AppDataStore Additions (Phase 3)

AppDataStore is @MainActor @Observable. No @Published anywhere. Staff array is named staff (not staffMembers). Auth from AuthManager.shared.

New stored properties to add (plain var, no wrapper): notifications [SierraNotification], activeTripLocationHistory [VehicleLocationHistory], currentTripDeviations [RouteDeviationEvent], activeTripExpenses [TripExpense], sparePartsRequests [SparePartsRequest].

New computed property: unreadNotificationCount Int (filters notifications for isRead == false).

Note: liveVehicleLocations is NOT a new property. The existing vehicles array already serves this purpose because subscribeToVehicleUpdates() already keeps it live.

New methods: loadAndSubscribeNotifications(for userId: UUID) async (with isSubscribedToNotifications guard), publishDriverLocation(vehicleId:tripId:latitude:longitude:speedKmh:) async non-throwing (internal catch), startActiveTrip(tripId:startMileage:) async throws (different from existing completeTrip), endTrip(tripId:endMileage:) async throws (clears location history and deviations and expenses), abortTrip(tripId:) async throws (also clears), unsubscribeAll() for logout, checkOverdueMaintenance() async (in-memory deduplication).

Wired into existing load methods: loadAll, loadDriverData, loadMaintenanceData each get a Task block appending loadAndSubscribeNotifications after their existing code.

---

## 14. File Structure for Sprint 2

New files to be created:

Sierra/Shared/Models/VehicleLocationHistory.swift
Sierra/Shared/Models/RouteDeviationEvent.swift
Sierra/Shared/Models/SierraNotification.swift
Sierra/Shared/Models/TripExpense.swift
Sierra/Shared/Models/SparePartsRequest.swift
Sierra/Shared/Services/NotificationService.swift
Sierra/Shared/Services/VehicleLocationService.swift
Sierra/Shared/Services/RouteDeviationService.swift
Sierra/Shared/Services/TripExpenseService.swift
Sierra/Shared/Services/SparePartsRequestService.swift
Sierra/Shared/Views/NotificationCentreView.swift
Sierra/Driver/ViewModels/TripNavigationCoordinator.swift
Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift
Sierra/Driver/Views/TripDetailDriverView.swift
Sierra/Driver/Views/PreTripInspectionView.swift
Sierra/Driver/Views/PostTripInspectionView.swift
Sierra/Driver/Views/StartTripSheet.swift
Sierra/Driver/Views/ProofOfDeliveryView.swift
Sierra/Driver/Views/TripNavigationView.swift
Sierra/Driver/Views/NavigationHUDOverlay.swift
Sierra/Driver/Views/TripNavigationContainerView.swift
Sierra/Driver/Views/SOSAlertSheet.swift
Sierra/Driver/Views/IncidentReportSheet.swift
Sierra/FleetManager/Views/FleetLiveMapView.swift
Sierra/FleetManager/Views/VehicleMapDetailSheet.swift
Sierra/FleetManager/Views/CreateGeofenceSheet.swift
Sierra/FleetManager/Views/MaintenanceRequestsView.swift
Sierra/FleetManager/Views/MaintenanceApprovalDetailView.swift
Sierra/FleetManager/Views/AlertsInboxView.swift
Sierra/FleetManager/Views/AlertDetailView.swift
Sierra/FleetManager/Views/DriverHistoryView.swift
Sierra/FleetManager/Views/VehicleStatusView.swift
Sierra/FleetManager/ViewModels/FleetLiveMapViewModel.swift
Sierra/Maintenance/ViewModels/MaintenanceDashboardViewModel.swift
Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift
Sierra/Maintenance/Views/SparePartsRequestSheet.swift

---

## 15. Critical Implementation Rules

These rules must be enforced in every phase without exception:

Supabase client: Always use the global supabase variable. Never SupabaseManager.shared.client.

DB triggers: Never update vehicles.status or staff_members.availability from Swift code when changing trip status. The three DB triggers (trg_trip_started, trg_trip_completed, trg_trip_cancelled) handle this atomically. Duplicating these updates in Swift creates race conditions.

Location publishing rate: Maximum once per 5 seconds enforced at both the Timer level and inside VehicleLocationService. This is the single most important billing safeguard.

Mapbox Directions API calls: Triggered only by explicit user action (tap "Preview Route" or "Start Navigation" button) and by adding a stop. Never reactive, never on toggle changes, never in .onChange handlers, never on .onAppear, never in computed properties.

Deviation detection: computeMinDistanceToRoute() is pure synchronous local Haversine math. Zero URLSession calls, zero async operations. Only the downstream RouteDeviationService.recordDeviation call is async.

NavigationViewController: Created exactly once in makeUIViewController. The updateUIViewController body is empty. Never recreated on state changes.

Notifications: insertNotification calls are always wrapped in non-fatal do/catch. A notification failure never propagates up to fail the parent operation.

Photo uploads: Always sequential for-loop, never concurrent TaskGroup or async let array.

OTP: Hash stored in DB, plaintext only in device memory and shown once to driver. Never logged.

No maps URLs: UIApplication.shared.open() is permitted only for tel:// links to call the driver. Never used to open Apple Maps, Google Maps, or any external navigation app.

AppDataStore @Observable: No @Published wrappers. No ObservableObject. Properties are plain stored vars. The class is @MainActor so all mutations are safe on the main thread.

Array column updates in Supabase: Pass Swift [String] arrays directly to .update() or .insert(). Never JSON-encode them as strings first.

---

## 16. Jira Stories Covered by Sprint 2

Fleet Manager stories: FMS1-8 (deactivate drivers), FMS1-9 (define geofence boundaries), FMS1-10 (view driver history), FMS1-11 (see vehicle location during active trip), FMS1-12 (receive route deviation alert), FMS1-13 (review and approve maintenance requests), FMS1-14 (create zones with entry/exit alerts), FMS1-15 (receive SOS and defect alerts), FMS1-16 (reject maintenance requests), FMS1-17 (track vehicle service history), FMS1-19 (view vehicle status), FMS1-20 (generate fleet usage reports), FMS1-21 (access driver activity reports), FMS1-24 (view dashboard summary), FMS1-25 (receive overdue maintenance alerts).

Driver stories: FMS1-18 (upload vehicle condition photos before trip), FMS1-36 (pre-trip inspection), FMS1-37 (start trip), FMS1-38 (end trip), FMS1-39 (see assigned route), FMS1-40 (mark delivery complete), FMS1-77 (notified when entering geofence), FMS1-78 (notified when leaving geofence), FMS1-79 (view previous trips).

Maintenance Personnel stories: FMS1-53 (see assigned maintenance requests), FMS1-54 (view vehicle issue details), FMS1-55 (update maintenance request status), FMS1-56 (mark repairs complete), FMS1-57 (add repair notes), FMS1-58 (upload repair images), FMS1-59 (view vehicle maintenance history), FMS1-60 (estimate repair time), FMS1-61 (request spare parts), FMS1-62 (record spare parts used), FMS1-63 (filter by vehicle), FMS1-64 (filter by status), FMS1-65 (view maintenance schedules), FMS1-66 (notify admin when repairs start), FMS1-67 (notify admin when repairs complete), FMS1-68 (generate repair reports).

---

## 17. Build and Run Requirements

The app requires a physical iOS device for testing navigation and location. The Simulator cannot test background location updates, CLCircularRegion geofencing, or Mapbox NavigationViewController rendering accurately.

Xcode minimum version: 16 (for Swift 6 concurrency features used throughout the codebase).

Mapbox token: Must be set in Config/Secrets.xcconfig (copy from Config/Secrets.xcconfig.template). Token is read at runtime via Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken"). The Info.plist has the build variable $(MAPBOX_ACCESS_TOKEN) which Xcode substitutes from the xcconfig at build time.

Background capabilities required (already set in Info.plist UIBackgroundModes): location, fetch. These are needed for the navigation timer to continue publishing location when the app is backgrounded during a trip.

Location authorization: The app requests Always authorization before starting navigation. Without Always authorization, location updates stop when the app is backgrounded. The NSLocationAlwaysAndWhenInUseUsageDescription key in Info.plist must have a meaningful description explaining why background tracking is needed.
