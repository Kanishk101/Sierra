# Phase 2 — Sprint 2 Services

## Context
Sierra iOS app, SwiftUI + MVVM + Swift Concurrency, Supabase backend.
Repo: Kanishk101/Sierra, main branch.
Supabase project ID: ldqcdngdlbbiojlnbnjg.

All services live in Sierra/Shared/Services/. They use SupabaseManager.shared.client (a Supabase Swift SDK client) to perform database operations using async/await. The pattern is:

  try await SupabaseManager.shared.client
      .from("table_name")
      .select()
      .eq("column", value: someValue)
      .execute()
      .value

Inserts use .insert(encodable). Updates use .update(encodable).eq(). Realtime uses .channel().onPostgresChanges().subscribe().

No RLS policies exist. All tables are accessible without auth filtering. Do not add any auth.uid() filtering.

## Task 1 — Create NEW service files

### NotificationService.swift (Sierra/Shared/Services/NotificationService.swift)
Methods:
- fetchNotifications(for recipientId: UUID) async throws -> [SierraNotification]
- markAsRead(notificationId: UUID) async throws
- markAllAsRead(for recipientId: UUID) async throws
- insertNotification(recipientId: UUID, type: NotificationType, title: String, body: String, entityType: String?, entityId: UUID?) async throws
- subscribeToNotifications(for recipientId: UUID, onNew: @escaping (SierraNotification) -> Void) — sets up Supabase Realtime channel listening for INSERT on notifications table filtered by recipient_id

### VehicleLocationService.swift (Sierra/Shared/Services/VehicleLocationService.swift)
Methods:
- publishLocation(vehicleId: UUID, tripId: UUID, driverId: UUID, latitude: Double, longitude: Double, speedKmh: Double?) async throws
  — writes to vehicle_location_history AND updates vehicles.current_latitude, vehicles.current_longitude
- fetchLocationHistory(vehicleId: UUID, tripId: UUID) async throws -> [VehicleLocationHistory]
- subscribeToVehicleLocations(onUpdate: @escaping ([Vehicle]) -> Void) — Supabase Realtime on vehicles table UPDATE, returns updated vehicle array

### RouteDeviationService.swift (Sierra/Shared/Services/RouteDeviationService.swift)
Methods:
- recordDeviation(tripId: UUID, driverId: UUID, vehicleId: UUID, latitude: Double, longitude: Double, deviationMetres: Double) async throws
  — inserts into route_deviation_events AND inserts activity_log of type "Route Deviation" AND inserts notification for all fleet managers
- fetchDeviations(for tripId: UUID) async throws -> [RouteDeviationEvent]
- acknowledgeDeviation(id: UUID, by adminId: UUID) async throws

### TripExpenseService.swift (Sierra/Shared/Services/TripExpenseService.swift)
Methods:
- logExpense(tripId: UUID, driverId: UUID, vehicleId: UUID, type: TripExpenseType, amount: Double, receiptUrl: String?, notes: String?) async throws
- fetchExpenses(for tripId: UUID) async throws -> [TripExpense]

### SparePartsRequestService.swift (Sierra/Shared/Services/SparePartsRequestService.swift)
Methods:
- submitRequest(maintenanceTaskId: UUID, workOrderId: UUID?, requestedById: UUID, partName: String, partNumber: String?, quantity: Int, estimatedUnitCost: Double?, supplier: String?, reason: String) async throws
- fetchRequests(for maintenanceTaskId: UUID) async throws -> [SparePartsRequest]
- approveRequest(id: UUID, reviewedBy: UUID) async throws
- rejectRequest(id: UUID, reviewedBy: UUID, reason: String) async throws
- markFulfilled(id: UUID) async throws

## Task 2 — Update EXISTING service files

### TripService.swift — add these methods:
- startTrip(tripId: UUID, startMileage: Double) async throws
  — updates trips.status to "Active", sets actual_start_date = now(), start_mileage
  — the DB trigger handles vehicle/driver status automatically
- completeTrip(tripId: UUID, endMileage: Double) async throws
  — updates trips.status to "Completed", sets actual_end_date = now(), end_mileage
- cancelTrip(tripId: UUID) async throws
  — updates trips.status to "Cancelled"
- updateTripCoordinates(tripId: UUID, originLat: Double, originLng: Double, destLat: Double, destLng: Double, routePolyline: String) async throws
  — updates the four coordinate columns and route_polyline on the trips row
- rateDriver(tripId: UUID, rating: Int, note: String?, ratedById: UUID) async throws
  — updates driver_rating, driver_rating_note, rated_by_id, rated_at on the trips row

### VehicleInspectionService.swift — add:
- submitInspectionWithPhotos(tripId: UUID, vehicleId: UUID, driverId: UUID, type: String, result: String, items: [[String:String]], photoUrls: [String], defectsReported: String?, notes: String?) async throws -> VehicleInspection
  — inserts inspection row with photo_urls array

### MaintenanceTaskService.swift — add:
- approveTask(taskId: UUID, approvedById: UUID, assignedToId: UUID) async throws
  — updates status to "Assigned", sets approved_by_id, approved_at, assigned_to_id
- rejectTask(taskId: UUID, approvedById: UUID, reason: String) async throws
  — updates status to "Cancelled", sets approved_by_id, approved_at, rejection_reason

### WorkOrderService.swift — add:
- updateRepairImages(workOrderId: UUID, imageUrls: [String]) async throws
  — updates repair_image_urls array column
- setEstimatedCompletion(workOrderId: UUID, estimatedAt: Date) async throws

## Output
Write complete, compilable Swift files for all new services and the updated sections of existing services. Commit all to main branch. Follow the exact code style of existing service files in the repo.
