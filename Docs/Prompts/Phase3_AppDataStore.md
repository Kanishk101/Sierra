# Phase 3 — AppDataStore Sprint 2 Updates (UPDATED — matches actual codebase)

## MANDATORY FIRST STEP
Read Sierra/Shared/Services/AppDataStore.swift completely before writing a single line.
Then list every existing property and method you found. Only then proceed.

## Actual AppDataStore architecture (confirmed from reading the file)

- Class declaration: `@MainActor @Observable final class AppDataStore`
- NO `@Published` wrapper on any property — this is `@Observable`, properties are plain stored vars
- Singleton: `static let shared = AppDataStore()`
- Staff array is named `staff: [StaffMember]` — NOT `staffMembers`
- Supabase client: uses global `supabase` directly, same as all other services
- Realtime channels: typed as `RealtimeChannelV2?`, subscribe with `.subscribeWithError()`
- Auth lives in `AuthManager.shared` — AppDataStore does NOT have a currentUser property
- `subscribeToVehicleUpdates()` already exists — do NOT create a duplicate vehicles channel
- `completeTrip(id:endMileage:)` already exists — rename your new wrapper or extend existing one carefully
- `loadAll()`, `loadDriverData(driverId:)`, `loadMaintenanceData(staffId:)` are the three load methods

## Your tasks — additions only, nothing removed or changed

### 1. Add new stored properties
Add these after the existing data arrays section. No @Published wrapper — plain var:

  var notifications: [SierraNotification] = []
  var activeTripLocationHistory: [VehicleLocationHistory] = []
  var currentTripDeviations: [RouteDeviationEvent] = []
  var activeTripExpenses: [TripExpense] = []
  var sparePartsRequests: [SparePartsRequest] = []

Add computed property:
  var unreadNotificationCount: Int { notifications.filter { !$0.isRead }.count }

Note: liveVehicleLocations is NOT a new array — the existing `vehicles` array already serves this purpose because `subscribeToVehicleUpdates()` already keeps it live via Realtime. The admin fleet map will read from `self.vehicles` directly.

### 2. Add notification channel property and subscription method
Add private channel property:
  private var notificationsChannel: RealtimeChannelV2?
  private var isSubscribedToNotifications = false

Add method: func loadAndSubscribeNotifications(for userId: UUID) async
  - guard !isSubscribedToNotifications else { return }
  - isSubscribedToNotifications = true
  - fetch from NotificationService.fetchNotifications(for: userId) and set self.notifications
  - call NotificationService.subscribeToNotifications(for: userId) with onNew closure that does:
    Task { @MainActor in self.notifications.insert(newNotification, at: 0) }

### 3. Add location publishing method (driver side, non-throwing)
Add: func publishDriverLocation(vehicleId: UUID, tripId: UUID, latitude: Double, longitude: Double, speedKmh: Double?) async
  - do { try await VehicleLocationService.shared.publishLocation(...) } catch { print non-fatal error }
  - on success, append new VehicleLocationHistory entry to activeTripLocationHistory

### 4. Add trip lifecycle wrappers for new TripService methods
These are DIFFERENT from the existing completeTrip(id:endMileage:). Name them to avoid collision:

  func startActiveTrip(tripId: UUID, startMileage: Double) async throws
    — calls TripService.startTrip(tripId:startMileage:)
    — updates trips array in-place: sets status = .active, actualStartDate = Date()

  func endTrip(tripId: UUID, endMileage: Double) async throws
    — calls TripService.completeTrip(tripId:endMileage:)
    — updates trips array in-place: sets status = .completed, actualEndDate = Date()
    — clears: activeTripLocationHistory = [], currentTripDeviations = [], activeTripExpenses = []

  func abortTrip(tripId: UUID) async throws
    — calls TripService.cancelTrip(tripId:)
    — updates trips array in-place: sets status = .cancelled
    — clears: activeTripLocationHistory = [], currentTripDeviations = [], activeTripExpenses = []

### 5. Add unsubscribeAll() for logout cleanup
  func unsubscribeAll()
    — isSubscribedToNotifications = false
    — Task { notificationsChannel?.unsubscribe() }
    — notificationsChannel = nil
  Call this from wherever logout is handled (check AuthManager.shared or ContentView for the logout path)

### 6. Add overdue maintenance check
  func checkOverdueMaintenance() async
    — filters maintenanceTasks where status == .pending and dueDate < Date()
    — for each, checks self.notifications for existing notification with type == .maintenanceOverdue and entityId == task.id
    — if none found, calls NotificationService.insertNotification for fleet managers (non-fatal wrap)

### 7. Wire into existing load methods
In loadAll() — after existing loads succeed, if current user role is fleetManager:
  Task { await loadAndSubscribeNotifications(for: AuthManager.shared.currentUser.id) }

In loadDriverData(driverId:) — after existing loads succeed:
  Task { await loadAndSubscribeNotifications(for: driverId) }

In loadMaintenanceData(staffId:) — after existing loads succeed:
  Task { await loadAndSubscribeNotifications(for: staffId) }

Check AuthManager.shared for the exact property name of the current user's id before wiring.

## Output
Write the complete updated AppDataStore.swift. Read the file first, list what you found, then output the full file with additions only. Commit to main branch.
