# Phase 2 Safeguards — Services
## Attach these instructions at the END of your Phase 2 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Supabase Realtime channels must be stored and guarded

Every Realtime subscription creates a persistent WebSocket channel. If a subscription method is called more than once (e.g. view re-appears, AppDataStore reinitialised), you get multiple channels firing duplicate events and consuming connections.

Every service method that creates a Realtime channel MUST:
1. Store the channel as a private property on the service: private var notificationChannel: RealtimeChannel?
2. Guard entry: if notificationChannel != nil { return } before creating a new channel
3. Provide a matching unsubscribe method that calls channel.unsubscribe() and sets the property to nil

Claude must implement this pattern for:
- NotificationService.subscribeToNotifications(for:onNew:)
- VehicleLocationService.subscribeToVehicleLocations(onUpdate:)

## SAFEGUARD 2 — Location publish writes are double-gated

VehicleLocationService.publishLocation must be called through a Timer, never directly from a CoreLocation delegate. The service itself must also enforce a minimum interval as a second layer of protection.

Add to VehicleLocationService:
  private var lastPublishTime: Date = .distantPast
  private let minimumPublishIntervalSeconds: TimeInterval = 5.0

At the top of publishLocation:
  guard Date().timeIntervalSince(lastPublishTime) >= minimumPublishIntervalSeconds else { return }
  lastPublishTime = Date()

This means even if the caller ignores the Timer and calls publishLocation every second, the service itself throttles to maximum once per 5 seconds. Belt and suspenders.

## SAFEGUARD 3 — No Mapbox API calls inside any service in this phase

Phases 2 services must contain ZERO calls to any Mapbox URL. All Supabase operations only. Mapbox calls belong exclusively in Phase 4 (StartTripSheet) and Phase 5 (TripNavigationCoordinator).

If Claude writes a URLSession call to api.mapbox.com in any Phase 2 service file, reject it and ask for removal.

## SAFEGUARD 4 — Array column updates use correct Supabase syntax

When updating an array column like photo_urls or repair_image_urls via the Supabase Swift SDK, the value must be encoded as a Swift array directly — do not JSON-encode it as a string. The SDK handles array serialisation automatically.

Correct:
  .update(["photo_urls": photoUrls])  // photoUrls is [String]

Incorrect:
  .update(["photo_urls": try JSONEncoder().encode(photoUrls)])  // wrong, double-encodes

## SAFEGUARD 5 — TripService status updates must set only the status field they intend to change

startTrip, completeTrip, cancelTrip must only update the fields they are responsible for. They must NOT update vehicle.status or staff_members.availability — those are handled by the DB triggers. If the Swift code also tries to update those fields, you get a race condition where the app's update conflicts with the trigger's update.

Specifically:
- startTrip: updates trips.status, trips.actual_start_date, trips.start_mileage ONLY
- completeTrip: updates trips.status, trips.actual_end_date, trips.end_mileage ONLY
- cancelTrip: updates trips.status ONLY

Claude must not add any vehicle or staff_members update calls inside these three methods.

## SAFEGUARD 6 — NotificationService.insertNotification must never throw on failure

Notifications are secondary to the primary action. If inserting a notification fails (network blip), the parent operation (e.g. recording a route deviation) must still succeed. Wrap notification inserts in a do/catch that swallows the error and logs it:

  do {
    try await NotificationService.shared.insertNotification(...)
  } catch {
    print("[NotificationService] Non-fatal: failed to insert notification: \(error)")
  }

This pattern must be used everywhere NotificationService.insertNotification is called from another service.

## SAFEGUARD 7 — RouteDeviationService must calculate distance locally, never via API

The deviation distance (deviationMetres parameter) is computed by the caller (TripNavigationCoordinator in Phase 5) using local polyline math. RouteDeviationService.recordDeviation simply receives that pre-computed number and stores it. The service must not make any network call to compute or validate the distance — it is a pure write operation.

## SAFEGUARD 8 — MaintenanceTaskService approval methods must set all three audit fields atomically

approveTask must set approved_by_id, approved_at, status, AND assigned_to_id in a single .update() call. Not separate calls. If they are split across two .update() calls and the second fails, the row is left in a corrupt half-approved state.

rejectTask must set approved_by_id, approved_at, status = "Cancelled", AND rejection_reason in a single .update() call.

## VERIFICATION CHECKLIST — Before committing

- [ ] Every Realtime channel stored as property with nil guard
- [ ] publishLocation has internal 5-second gate
- [ ] Zero Mapbox API calls in any Phase 2 file
- [ ] Array columns updated as Swift arrays, not JSON strings
- [ ] startTrip/completeTrip/cancelTrip do NOT touch vehicles or staff_members tables
- [ ] Notification inserts wrapped in non-fatal try/catch
- [ ] approveTask and rejectTask each use exactly one .update() call
