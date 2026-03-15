# Phase 3 — CreateTripView: Overlap Guard & Status Assignment on Trip Creation

> **Model:** Claude Opus 4.6  
> **Scope:** `CreateTripView.swift` — modify the `createTrip()` async method and add one hidden `@State` property. Absolutely no UI changes.  
> **Prerequisite:** Phases 1 and 2 must be applied. `TripService.checkOverlap`, `TripService.markResourcesBusy`, and `StaffAvailability.busy` / `VehicleStatus.busy` must exist.

---

## Context

`CreateTripView.swift` is a 3-step trip creation wizard. Steps 1–3 are the UI. The actual creation happens in the `createTrip()` `@MainActor async` method at the bottom of the file.

**Current `createTrip()` issues to fix:**
1. No overlap check — double-booking is possible.
2. After trip creation, `vehicle.assignedDriverId` is set but `vehicle.status` stays unchanged and `driver.availability` is never updated.

The `Trip` model has `scheduledDate` (start) and `scheduledEndDate: Date?` (end). Currently `scheduledEndDate` is always `nil` because there is no picker for it in the UI. **Do not add a picker.** Instead, add a silent `@State` default of `scheduledDate + 8 hours` that is used only in the business logic.

---

## Files to Read First

Read these files in full before writing any output:

1. `Sierra/FleetManager/Views/CreateTripView.swift`
2. `Sierra/Shared/Services/TripService.swift`  (to see the new methods added in Phase 2)
3. `Sierra/Shared/Models/Trip.swift`

---

## Changes Required

### 1. Add a silent `@State` for scheduled end date

In the `// Step 1 — Trip Details` state block, add:
```swift
@State private var scheduledEndDate: Date = Date().addingTimeInterval(3600 * 8)
```

This is **not wired to any picker or UI element**. It is updated programmatically whenever `scheduledDate` changes (see below) and used only in `createTrip()`.

Anywhere `scheduledDate` is bound to the `DatePicker` in `step1View`, add an `.onChange(of: scheduledDate)` modifier (on the DatePicker or the Form — whichever is cleaner) that keeps `scheduledEndDate` in sync:
```swift
.onChange(of: scheduledDate) { _, newDate in
    scheduledEndDate = newDate.addingTimeInterval(3600 * 8)
}
```

This is the only change to any view body. It is a behaviour modifier, not a visible UI element.

---

### 2. Replace the `createTrip()` method

Replace the entire `createTrip()` method with the updated version below. The logic steps in order:

**a. Overlap check — call before inserting the trip:**
```swift
let conflict = try await TripService.checkOverlap(
    driverId: driverId,
    vehicleId: vehicleId,
    start: scheduledDate,
    end: scheduledEndDate
)
if conflict.driverConflict {
    errorMessage = "This driver already has a trip assigned in that time slot."
    showError = true
    isCreating = false
    return
}
if conflict.vehicleConflict {
    errorMessage = "This vehicle is already assigned to another trip in that time slot."
    showError = true
    isCreating = false
    return
}
```

**b. Build and insert the trip — include `scheduledEndDate`:**

When constructing the `Trip` value, pass `scheduledEndDate: scheduledEndDate` instead of `nil`.

**c. After `store.addTrip(trip)` succeeds — mark resources busy:**
```swift
try await TripService.markResourcesBusy(driverId: driverId, vehicleId: vehicleId)
```

This single call replaces the current manual `v.assignedDriverId = driverId.uuidString` + `store.updateVehicle(v)` block. The `markResourcesBusy` method handles both the driver availability and the vehicle status atomically at the DB level.

For the local in-memory cache (`AppDataStore`), also update it after the service call:
```swift
// Refresh local store cache
if var v = store.vehicle(for: vehicleId) {
    v.status = .busy
    v.assignedDriverId = driverId.uuidString
    await store.updateVehicle(v)
}
if var driver = store.staffMember(for: driverId) {
    driver.availability = .busy
    await store.updateStaffMember(driver)
}
```

Note: Use `try?` or plain `await` (non-throwing) for the local cache updates — a failure to update the in-memory cache is non-fatal since the DB is already updated. Match whatever pattern `AppDataStore` uses for `updateVehicle` / `updateStaffMember`.

**d. Success flow** — unchanged: set `createdTrip = trip` and `showSuccess = true`.

**e. Error handling** — unchanged: catch, set `errorMessage`, `showError = true`.

---

## Output Format

Output the **complete `CreateTripView.swift` file** in a single fenced code block. Every line of the original file that is not changed must be reproduced exactly.

```
// FILE: Sierra/FleetManager/Views/CreateTripView.swift
...
```

---

## Hard Constraints

- **No new visible UI elements.** The `.onChange` modifier is the only addition to any view body.
- **No layout changes.** No new `Section`, `VStack`, `HStack`, `DatePicker`, `TextField`, or any other view.
- **No filter changes.** The driver filter (`availability == .available`) and vehicle filter (`status == .idle || status == .active`) in Steps 2 and 3 stay exactly as they are.
- The `scheduledEndDate` `@State` var must be entirely invisible to the user.
- `markResourcesBusy` must be called **after** `store.addTrip` succeeds — never before.
- All error paths must set `isCreating = false` before returning.
- **Compilable on first pass.**
