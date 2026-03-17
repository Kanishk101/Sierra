# Phase 3 — AppDataStore Sprint 2 Updates

## Context
Sierra iOS app. AppDataStore is the central @Observable class in Sierra/Shared/Services/AppDataStore.swift.
It holds all in-memory state for the app and is injected via .environment() at the root level.
Read the full current AppDataStore.swift file before making any changes.

## Your tasks

### 1. Add new published properties
Add these new @Published (or stored) properties to AppDataStore, grouped with their related existing properties:

  // Notifications
  var notifications: [SierraNotification] = []
  var unreadNotificationCount: Int { notifications.filter { !$0.isRead }.count }

  // Live trip state (driver side)
  var activeTripLocationHistory: [VehicleLocationHistory] = []
  var currentTripDeviations: [RouteDeviationEvent] = []

  // Trip expenses
  var activeTripExpenses: [TripExpense] = []

  // Maintenance — spare parts
  var sparePartsRequests: [SparePartsRequest] = []

  // Admin fleet map — all vehicle locations live
  var liveVehicleLocations: [Vehicle] = []  // updated by Realtime

### 2. Add notification loading and subscription
Add a method: func loadAndSubscribeNotifications(for userId: UUID)
  - calls NotificationService.fetchNotifications(for:) and sets self.notifications
  - calls NotificationService.subscribeToNotifications(for:onNew:) and prepends new notifications to self.notifications
  - also schedules a local UNUserNotificationCenter notification if the app is in background

### 3. Add vehicle location subscription (admin)
Add a method: func subscribeToLiveVehicleLocations()
  - calls VehicleLocationService.subscribeToVehicleLocations(onUpdate:)
  - updates self.liveVehicleLocations with the incoming updated vehicles

### 4. Add trip lifecycle methods
Add these methods that wrap the new TripService methods:
  func startTrip(tripId: UUID, startMileage: Double) async throws
  func completeTrip(tripId: UUID, endMileage: Double) async throws
  func cancelTrip(tripId: UUID) async throws
  Each should: call the service, then refresh the relevant trip in self.trips array in-place.

### 5. Add location publishing method (driver side)
Add: func publishDriverLocation(vehicleId: UUID, tripId: UUID, latitude: Double, longitude: Double, speedKmh: Double?) async
  - calls VehicleLocationService.publishLocation(...)
  - appends to self.activeTripLocationHistory

### 6. Extend loadInitialData() or equivalent startup method
Ensure that when a user logs in:
  - If role is driver: call loadAndSubscribeNotifications(for: currentUser.id)
  - If role is fleetManager: call loadAndSubscribeNotifications(for: currentUser.id) AND subscribeToLiveVehicleLocations()
  - If role is maintenancePersonnel: call loadAndSubscribeNotifications(for: currentUser.id)

## Important rules
- Do NOT remove or change anything existing in AppDataStore
- Only add new properties and methods
- All new async methods use async/await and propagate throws
- Follow the exact existing code style and formatting

## Output
Write the complete updated AppDataStore.swift and commit to main branch.
