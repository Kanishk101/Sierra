# Phase 2 — Sprint 2 Services (UPDATED — matches actual codebase)

## Context
Sierra iOS app, SwiftUI + MVVM + Swift Concurrency, Supabase backend.
Repo: Kanishk101/Sierra, main branch.
Supabase project ID: ldqcdngdlbbiojlnbnjg.

## CRITICAL — Read existing services before writing anything
Before writing any code, read these files to understand the exact patterns used:
- Sierra/Shared/Services/TripService.swift
- Sierra/Shared/Services/VehicleService.swift
- Sierra/Shared/Services/EmergencyAlertService.swift
- Sierra/Shared/Services/ActivityLogService.swift

## Actual code patterns in this codebase (NOT generic assumptions)

Services use the global `supabase` Supabase client directly — NOT `SupabaseManager.shared.client`.
The `supabase` global is defined in SupabaseManager.swift. Read that file to confirm the exact variable name.

The pattern used throughout all existing services is:
  try await supabase
      .from("table_name")
      .select()
      .eq("column", value: someValue)
      .execute()
      .value

Realtime uses `RealtimeChannelV2` and `.subscribeWithError()` — read AppDataStore.swift to see the exact pattern used in subscribeToEmergencyAlerts() and subscribeToVehicleUpdates() and match it exactly.

No RLS policies exist. No auth.uid() filtering anywhere.

Auth lives in AuthManager.shared — NOT AppDataStore. If you need the current user's ID in a service, it comes from the call site, never looked up internally.

## Task 1 — Create NEW service files

### NotificationService.swift (Sierra/Shared/Services/NotificationService.swift)
Methods:
- fetchNotifications(for recipientId: UUID) async throws -> [SierraNotification]
- markAsRead(notificationId: UUID) async throws
- markAllAsRead(for recipientId: UUID) async throws
- insertNotification(recipientId: UUID, type: NotificationType, title: String, body: String, entityType: String?, entityId: UUID?) async throws
- subscribeToNotifications(for recipientId: UUID, onNew: @escaping (SierraNotification) -> Void)
  — creates a RealtimeChannelV2 for INSERT on notifications table
  — stores channel as private var notificationChannel: RealtimeChannelV2?
  — guards: if notificationChannel != nil { return }
  — uses .subscribeWithError() pattern matching AppDataStore.subscribeToEmergencyAlerts exactly
- unsubscribeFromNotifications() — calls channel.unsubscribe() and sets notificationChannel = nil

### VehicleLocationService.swift (Sierra/Shared/Services/VehicleLocationService.swift)
Methods:
- publishLocation(vehicleId: UUID, tripId: UUID, driverId: UUID, latitude: Double, longitude: Double, speedKmh: Double?) async throws
  — inserts into vehicle_location_history
  — updates vehicles SET current_latitude = latitude, current_longitude = longitude WHERE id = vehicleId
  — internal throttle: private var lastPublishTime: Date = .distantPast, minimum 5 seconds between calls
- fetchLocationHistory(vehicleId: UUID, tripId: UUID) async throws -> [VehicleLocationHistory]
- unsubscribe() for cleanup

### RouteDeviationService.swift (Sierra/Shared/Services/RouteDeviationService.swift)
Methods:
- recordDeviation(tripId: UUID, driverId: UUID, vehicleId: UUID, latitude: Double, longitude: Double, deviationMetres: Double) async throws
  — inserts into route_deviation_events
  — inserts into activity_logs type "Route Deviation"
  — calls NotificationService.insertNotification for fleet managers (wrap in non-fatal try/catch)
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

Read each file fully before modifying. Add only the new methods listed — do not touch existing methods.

### TripService.swift — add:
- startTrip(tripId: UUID, startMileage: Double) async throws
  — updates trips SET status = "Active", actual_start_date = now(), start_mileage WHERE id = tripId
  — DB triggers handle vehicle + driver status automatically — do NOT update vehicles or staff_members here
- completeTrip(tripId: UUID, endMileage: Double) async throws
  — updates trips SET status = "Completed", actual_end_date = now(), end_mileage WHERE id = tripId
  — DB triggers handle all stat updates — do NOT update vehicles or staff_members here
- cancelTrip(tripId: UUID) async throws
  — updates trips SET status = "Cancelled" WHERE id = tripId only
- updateTripCoordinates(tripId: UUID, originLat: Double, originLng: Double, destLat: Double, destLng: Double, routePolyline: String) async throws
- rateDriver(tripId: UUID, rating: Int, note: String?, ratedById: UUID) async throws
  — updates driver_rating, driver_rating_note, rated_by_id, rated_at in single .update() call

### VehicleInspectionService.swift — add:
- submitInspectionWithPhotos(..., photoUrls: [String], ...) async throws -> VehicleInspection
  — adds photo_urls, is_defect_raised, raised_task_id to the insert payload
  — photo_urls passed as Swift [String] array directly, not JSON-encoded

### MaintenanceTaskService.swift — add:
- approveTask(taskId: UUID, approvedById: UUID, assignedToId: UUID) async throws
  — single .update() call: status="Assigned", approved_by_id, approved_at=now(), assigned_to_id
- rejectTask(taskId: UUID, approvedById: UUID, reason: String) async throws
  — single .update() call: status="Cancelled", approved_by_id, approved_at=now(), rejection_reason

### WorkOrderService.swift — add:
- updateRepairImages(workOrderId: UUID, imageUrls: [String]) async throws
- setEstimatedCompletion(workOrderId: UUID, estimatedAt: Date) async throws

## Output
Complete compilable Swift files. Match the exact supabase client access pattern from existing files. Commit all to main branch.
