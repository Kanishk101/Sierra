# Phase 4 — Trip Lifecycle: Status Release on Cancel & Completion

> **Model:** Claude Opus 4.6  
> **Scope:** `TripDetailView.swift` (admin cancel) and `DriverHomeView.swift` (driver availability toggle guard). No UI changes anywhere.  
> **Prerequisite:** Phases 1–3 must be applied. `TripService.releaseResources` must exist.

---

## Context

### Why this phase is needed

When a trip is cancelled or completed, the driver's `availability` must return to `available` and the vehicle's `status` must return to `idle`. Without this, the resources stay `busy` forever and can never be assigned to a new trip.

### Current state of `TripDetailView.swift`

`cancelTrip()` already does a **partial** release — it sets `driver.availability = .available` and `vehicle.status = .idle` manually via `store.updateStaffMember` / `store.updateVehicle`. However:
1. It does not call `TripService.releaseResources` at the DB level — only the in-memory store is updated.
2. There is no equivalent logic for trip **completion** (there is no "Complete Trip" button for admin yet — that is out of scope for this phase; completion is handled by the driver side and is not yet implemented).

### Current state of `DriverHomeView.swift`

The availability toggle calls `store.updateDriverAvailability(staffId:available:)`. If a driver is `busy` (assigned to a trip), the toggle must **not** let them set themselves to `unavailable` or `available` — they must finish the trip first. There is currently no guard.

---

## Files to Read First

Read these files in full before writing any output:

1. `Sierra/FleetManager/Views/TripDetailView.swift`
2. `Sierra/Driver/Views/DriverHomeView.swift`
3. `Sierra/Shared/Services/TripService.swift`  (to confirm `releaseResources` signature)
4. `Sierra/Shared/Services/AppDataStore.swift`  (to confirm `updateDriverAvailability`, `updateStaffMember`, `updateVehicle` signatures)

---

## Changes Required

### File 1: `Sierra/FleetManager/Views/TripDetailView.swift`

#### Change — `cancelTrip()` method

The current `cancelTrip()` updates the in-memory store but never calls the DB. Replace its resource-release block with a call to `TripService.releaseResources` **followed by** a local store cache update.

New `cancelTrip()` structure (keep all existing logic, just replace the resource-release block):

```swift
@MainActor
private func cancelTrip() async {
    guard var t = trip else { return }

    // 1. Release at DB level first
    if let dIdStr = t.driverId,
       let dUUID  = UUID(uuidString: dIdStr),
       let vIdStr = t.vehicleId,
       let vUUID  = UUID(uuidString: vIdStr) {
        try? await TripService.releaseResources(driverId: dUUID, vehicleId: vUUID)
    }

    // 2. Sync local in-memory cache
    if let dIdStr = t.driverId,
       let dUUID = UUID(uuidString: dIdStr),
       var driver = store.staffMember(for: dUUID) {
        driver.availability = .available
        try? await store.updateStaffMember(driver)
    }
    if let vIdStr = t.vehicleId,
       let vUUID = UUID(uuidString: vIdStr),
       var vehicle = store.vehicle(for: vUUID) {
        vehicle.assignedDriverId = nil
        vehicle.status = .idle
        try? await store.updateVehicle(vehicle)
    }

    // 3. Cancel the trip record
    t.status = .cancelled
    do {
        try await store.updateTrip(t)
        dismiss()
    } catch {
        print("[TripDetailView] Cancel trip error: \(error)")
    }
}
```

Do not change any other part of `TripDetailView.swift`.

---

### File 2: `Sierra/Driver/Views/DriverHomeView.swift`

#### Change — Availability toggle guard

In `availabilityCard`, the `Toggle` binding currently calls `store.updateDriverAvailability(staffId: id, available: newValue)` unconditionally.

Add a guard: **if the driver is `busy` (assigned to a trip), the toggle should do nothing and silently return.** This is a business logic guard — not a UI disable (do not grey out the toggle or add any visual indicator — that is a UI concern out of scope).

In the `set:` closure of the `Binding`, add before the `Task { }` block:
```swift
// Guard: driver is busy on a trip — availability cannot be changed manually
guard driverMember?.availability != .busy else { return }
```

This is the only change to `DriverHomeView.swift`.

---

## Output Format

Output **two complete Swift files**, each in its own fenced code block, labelled with the file path:

```
// FILE: Sierra/FleetManager/Views/TripDetailView.swift
...
```

```
// FILE: Sierra/Driver/Views/DriverHomeView.swift
...
```

Every line of each file that is not changed must be reproduced exactly.

---

## Hard Constraints

- **No UI changes** in either file. No new views, modifiers, alerts, buttons, or layout elements.
- `TripService.releaseResources` must be called **before** updating the local cache — DB first, cache second.
- The guard in `DriverHomeView` must be a silent `return` — no alert, no sheet, no visual change.
- `try?` (not `try`) on `TripService.releaseResources` — a DB failure should not block the local cancellation flow.
- **Compilable on first pass.**
