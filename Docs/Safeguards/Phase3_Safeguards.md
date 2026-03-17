# Phase 3 Safeguards — AppDataStore
## Attach these instructions at the END of your Phase 3 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Read the FULL existing AppDataStore before touching it

AppDataStore.swift is 30KB+. Claude must read the entire file before writing a single line. The biggest risk in this phase is Claude accidentally overwriting or restructuring existing properties and methods. The only acceptable changes are additions — new properties appended after existing ones, new methods appended at the end.

Instruct Claude explicitly: "Read Sierra/Shared/Services/AppDataStore.swift completely. List every existing @Published property you found before writing any changes. Then show only the NEW code you are adding."

## SAFEGUARD 2 — Subscriptions must check for existing state before initialising

subscribeToLiveVehicleLocations() and loadAndSubscribeNotifications(for:) will be called when the user logs in. If the user logs out and back in, or if the view re-appears, they may be called again. Guard every subscription:

  private var isSubscribedToVehicleLocations = false
  func subscribeToLiveVehicleLocations() {
    guard !isSubscribedToVehicleLocations else { return }
    isSubscribedToVehicleLocations = true
    // ...
  }

Same pattern for notification subscription with a private var isSubscribedToNotifications = false.

Add a corresponding cleanup method: func unsubscribeAll() — called on logout — that sets both flags back to false and calls the service unsubscribe methods.

## SAFEGUARD 3 — activeTripLocationHistory must be cleared when a trip ends

If activeTripLocationHistory is not cleared when a trip completes or cancels, the next trip will display stale breadcrumb data from the previous trip on the admin map.

In completeTrip() and cancelTrip(), after the service call:
  self.activeTripLocationHistory = []
  self.currentTripDeviations = []
  self.activeTripExpenses = []

## SAFEGUARD 4 — liveVehicleLocations must be initialised from existing vehicles, not start empty

When subscribeToLiveVehicleLocations() sets up the Realtime subscription, it only receives UPDATES to vehicle rows. If the admin opens the fleet map and no vehicle has moved yet, liveVehicleLocations would be empty even though vehicles exist in the DB.

Before setting up the subscription, pre-populate:
  self.liveVehicleLocations = self.vehicles  // use the already-loaded vehicles array

Then the Realtime subscription only needs to handle updates to individual vehicles, not the initial population.

## SAFEGUARD 5 — Realtime callbacks must update on MainActor

All Realtime callbacks arrive on a background thread. Any AppDataStore property update that triggers a SwiftUI view re-render must happen on the main thread. Every Realtime callback must dispatch to MainActor:

  Task { @MainActor in
    self.liveVehicleLocations = updatedVehicles
  }

If this is missing, you get purple runtime warnings and potential UI corruption.

## SAFEGUARD 6 — publishDriverLocation must be async but not throw

publishDriverLocation is called from a Timer callback. Timers cannot handle thrown errors. The method must be declared as async (not async throws). Internally wrap the service call:

  func publishDriverLocation(...) async {
    do {
      try await VehicleLocationService.shared.publishLocation(...)
      self.activeTripLocationHistory.append(...)
    } catch {
      print("[AppDataStore] Location publish failed (non-fatal): \(error)")
    }
  }

Never let a location publish failure crash or halt the navigation session.

## SAFEGUARD 7 — checkOverdueMaintenance must be idempotent

This method may be called every time the app foregrounds. It must not insert duplicate "Maintenance Overdue" notifications on every call.

Before inserting a notification, check AppDataStore.notifications for an existing notification with:
  type == .maintenanceOverdue AND entityId == task.id

If one already exists, skip insertion for that task.

## SAFEGUARD 8 — Role-based subscription branching must use the authoritative role from existing currentUser

The existing AppDataStore already has a currentUser or currentStaffMember property. The role-based subscription logic must read from that existing property — never introduce a second source of truth for the user's role. If the existing property is named differently than assumed, Claude must adapt to the actual property name found in the file.

## VERIFICATION CHECKLIST — Before committing

- [ ] Claude listed all existing @Published properties before making changes
- [ ] isSubscribedToVehicleLocations and isSubscribedToNotifications guards exist
- [ ] unsubscribeAll() method added and wired to logout flow
- [ ] activeTripLocationHistory, currentTripDeviations, activeTripExpenses cleared on trip end
- [ ] liveVehicleLocations pre-populated from self.vehicles before Realtime subscription
- [ ] All Realtime callbacks update AppDataStore properties on MainActor
- [ ] publishDriverLocation is async (not async throws) with internal catch
- [ ] checkOverdueMaintenance checks for existing notification before inserting
