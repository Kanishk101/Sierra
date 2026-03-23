# Sierra — Driver Trip Flow: Phase 2
## TripDetailDriverView: Full Lifecycle Enforcement, No Add-Stops, Start Trip Fix

---

## Context & Background

This is Phase 2 of the driver trip flow overhaul. Phase 1 must be complete first — it adds the admin dispatch mechanism and the visible accept CTA on the list. This phase focuses on `TripDetailDriverView.swift` and the start-trip service path.

The Supabase backend is project `ldqcdngdlbbiojlnbnjg`. No RLS. All business logic in Swift.

### What Is Currently Broken in TripDetailDriverView

1. **The `startTrip` service path may not exist.** `TripDetailDriverView` shows a `StartTripSheet` (which calls back via `onComplete`) but it is unclear whether `store.startTrip(tripId:startMileage:)` exists and correctly sets `status = .active`, `actualStartDate = Date()`, and `startMileage`. This must be verified and completed.

2. **The `PostTripInspectionView` sheet close does not advance the trip.** After post-trip inspection completes, the sheet closes but `TripDetailDriverView` does not re-evaluate the action buttons immediately to show `End Trip`. This is a reactive update issue.

3. **The `PreTripInspectionView` `onComplete` callback is used correctly but the trip's `preInspectionId` may not update in the local store.** The pre-inspection submission writes to Supabase but the local `store.trips` array may not have the `preInspectionId` populated after the fact, so the view stays stuck on "Begin Pre-Trip Inspection" even after completion.

4. **`StartTripSheet` is a separate sheet.** The current UX requires the driver to tap "Start Trip", a sheet appears with a confirmation, and only then does navigation begin. This is correct per spec — do not remove it.

5. **The action flow for `.accepted` status is conditional on `trip.preInspectionId != nil`.** This is correct. But if the local trip object doesn't update after inspection submission, the button never advances.

---

## Files to Read First (Required)

Read these files in full before writing any code:

1. `Sierra/Driver/Views/TripDetailDriverView.swift` — the main file being fixed
2. `Sierra/Driver/Views/StartTripSheet.swift` — understand its signature and what it does
3. `Sierra/Driver/Views/PreTripInspectionView.swift` — understand the `onComplete` callback
4. `Sierra/Driver/Views/PostTripInspectionView.swift` — understand how it signals completion
5. `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift` — understand what happens when inspection saves; specifically whether it updates `store.trips[idx].preInspectionId`
6. `Sierra/Shared/Services/AppDataStore.swift` — search for `startTrip`, `endTrip`, `acceptTrip` — understand which methods exist and their exact signatures
7. `Sierra/Shared/Services/AppDataStore+TripAcceptance.swift` — understand `acceptTrip` and `rejectTrip` so `startTrip`/`endTrip` follow the same pattern
8. `Sierra/Shared/Services/TripService.swift` — the low-level Supabase calls; understand `updateTripStatus`, `startTrip`, `endTrip` — check whether these exist
9. `Sierra/Shared/Models/Trip.swift` — confirm all field names, especially `preInspectionId`, `postInspectionId`, `proofOfDeliveryId`, `actualStartDate`, `startMileage`

Do NOT start writing until you have read all of the above.

---

## Part A: Fix or Implement `store.startTrip(tripId:startMileage:)`

### What To Do

Verify whether `AppDataStore` exposes `func startTrip(tripId: UUID, startMileage: Double) async throws`. If it does not exist, add it to `AppDataStore+TripAcceptance.swift` (or a new extension file `AppDataStore+TripLifecycle.swift` if that is cleaner).

The method must:
1. Call `TripService` (or directly call Supabase) to UPDATE the trip row:
   - `status = 'Active'`
   - `actual_start_date = NOW()`
   - `start_mileage = <provided value>`
   - `updated_at = NOW()`
2. Update `store.trips[idx]` locally:
   - `status = .active`
   - `actualStartDate = Date()`
   - `startMileage = startMileage`
   - `updatedAt = Date()`
3. Also update the assigned vehicle's status to `busy` or `active` (check `VehicleService` — there may be a `setVehicleStatus` or similar already present; use it)
4. Also update the driver's availability to `.onTrip` (check `StaffMemberService` for an `updateAvailability` call; use it if it exists)

Follow the exact `async throws` pattern in `AppDataStore+TripAcceptance.swift`. Do not deviate.

---

## Part B: Fix or Implement `store.endTrip(tripId:endMileage:)`

Verify whether `AppDataStore.endTrip(tripId:endMileage:)` exists. If not, add it following the same pattern as Part A.

The method must:
1. UPDATE the trip row in Supabase:
   - `status = 'Completed'`
   - `actual_end_date = NOW()`
   - `end_mileage = <provided value>`
   - `updated_at = NOW()`
2. Update `store.trips[idx]` locally
3. Set the vehicle back to `status = .idle` (use VehicleService)
4. Set the driver availability back to `.available` (use StaffMemberService)

---

## Part C: Fix Pre-Inspection Completion — Ensure `preInspectionId` Updates in Local Store

### The Problem

When `PreTripInspectionView` completes (its `onComplete` callback fires), the inspection record has been saved to Supabase with the `trip_id` set. But:
- `TripDetailDriverView` checks `trip.preInspectionId != nil` to decide whether to show "Start Trip" instead of "Begin Pre-Trip Inspection"
- If `store.trips[idx].preInspectionId` is `nil` in the local store after inspection submission, the view stays stuck

### Fix

In `PreTripInspectionViewModel`, after a successful inspection save, the ViewModel must:
1. Retrieve the inspection's UUID (from the Supabase insert response or from a local UUID generated before the call)
2. Update `AppDataStore.shared.trips` array: find the trip by `tripId` and set `preInspectionId = inspectionId`
3. The `updatedAt` field on the trip should also be updated locally

If `VehicleInspectionService` already returns the saved inspection object, extract the `id` from it and propagate it. Read `VehicleInspectionService.swift` to understand the return type.

The same fix applies to post-trip inspection — after post-inspection saves, `store.trips[idx].postInspectionId` must be set.

---

## Part D: Full Lifecycle Flow Enforcement in TripDetailDriverView

The existing `actionButtons(_:)` function in `TripDetailDriverView` already has the correct structural logic. This part is about hardening it so the gates work correctly end-to-end.

### Required Behavior Per Status

**`.scheduled`** — Trip is assigned but admin hasn't dispatched yet.
- Show: An informational card (not a button) with icon `clock.badge.questionmark`, text "Awaiting Dispatch", subtitle "Your fleet manager will send this trip for your review shortly."
- Show NO action buttons.

**`.pendingAcceptance`** — Admin has dispatched the trip; driver must accept or reject.
- Show: Large green "Accept Trip" button (full width, 56pt tall, green background, `checkmark.circle.fill` icon)
- Show below it: A smaller outlined red "Reject Trip" button that opens the rejection reason sheet
- Show the acceptance deadline timer if `trip.acceptanceDeadline != nil`

**`.accepted`** — Driver accepted. Must do pre-trip inspection before starting.
- If `trip.preInspectionId == nil`: Show "Begin Pre-Trip Inspection" button (ember/orange color, `checklist` icon)
  - When tapped: present `PreTripInspectionView` as a sheet
  - Note: do NOT show a "Start Trip" button here — the inspection is required first
- If `trip.preInspectionId != nil`: Show "Start Trip" button (alpineMint/green color, `play.fill` icon)
  - When tapped: present `StartTripSheet` as a sheet
  - `StartTripSheet`'s `onComplete` callback should call `store.startTrip(tripId:startMileage:)` then dismiss the sheet
  - After dismissal, `TripDetailDriverView` should show the navigation state

**`.active`** — Trip is running.
- Show: Pulsing "Navigate" button (full width, 56pt, alpineMint gradient background)
  - When tapped: open `TripNavigationContainerView` fullscreen
- Below Navigate, show the delivery/inspection/end-trip chain:
  - If `trip.proofOfDeliveryId == nil`: Show "Complete Delivery" button (ember color)
  - Else if `trip.postInspectionId == nil`: Show "Post-Trip Inspection (Required)" button (info/blue color)
  - Else: Show "End Trip" button (indigo gradient)
- Always show during active: "Log Fuel" button and "Report Issue" button (these stay unchanged)

**`.completed`** — Show completion summary card. No action buttons.

**`.rejected`** — Show rejected banner with reason. No action buttons.

**`.cancelled`** — Show cancelled banner. No action buttons.

### Flow Steps Card

The existing `flowStepsCard(_:)` shows a 7-step checklist. This is correct and should remain. Ensure the step completion booleans are correct:
- Step 1 "Accept Trip": done when `status != .scheduled && status != .pendingAcceptance`
- Step 2 "Pre-Trip Inspection": done when `preInspectionId != nil`
- Step 3 "Start Trip": done when `status == .active || status == .completed`
- Step 4 "Navigate": done when `status == .completed`
- Step 5 "Complete Delivery": done when `proofOfDeliveryId != nil`
- Step 6 "Post-Trip Inspection": done when `postInspectionId != nil`
- Step 7 "End Trip": done when `status == .completed`

### Trip Progress Indicator (NEW)

Add a **trip progress bar** to `TripDetailDriverView`, displayed just above the `flowStepsCard`. This is a visual representation of where the driver is in the lifecycle.

Compute progress as a `Double` in range `[0.0, 1.0]`:

```swift
private func tripProgress(_ trip: Trip) -> Double {
    switch trip.status {
    case .scheduled:         return 0.0
    case .pendingAcceptance: return 0.1
    case .accepted:          return trip.preInspectionId != nil ? 0.3 : 0.2
    case .active:
        if trip.postInspectionId != nil { return 0.85 }
        if trip.proofOfDeliveryId != nil { return 0.70 }
        return 0.50
    case .completed:         return 1.0
    case .rejected, .cancelled: return 0.0
    }
}
```

UI implementation:

```swift
private func tripProgressBar(_ trip: Trip) -> some View {
    let progress = tripProgress(trip)
    let pct = Int(progress * 100)
    return VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text("Trip Progress")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            Text("\(pct)%")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SierraTheme.Colors.alpineMint, SierraTheme.Colors.ember],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 10)
                    .animation(.spring(duration: 0.6), value: progress)
            }
        }
        .frame(height: 10)
    }
    .padding(14)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
}
```

Insert `tripProgressBar(trip)` in the main `ScrollView` VStack between `vehicleCard` and `flowStepsCard`.

---

## Part E: Remove "Add Stop" From NavigationHUDOverlay

In `Sierra/Driver/Views/NavigationHUDOverlay.swift`:

1. Remove the `actionButton("Add Stop", ...)` call from the `actionBar` HStack entirely.
2. Remove the `@State private var showAddStop = false` state variable.
3. Remove the `.sheet(isPresented: $showAddStop)` modifier.
4. Remove the entire `private var addStopSheet: some View` computed property.
5. Remove the `@State private var stopAddress = ""` variable.
6. Remove the `@State private var geocodeTask: Task<Void, Never>?` variable.
7. Remove the `@State private var geocodedResults: [GeocodedStop] = []` variable.
8. Remove the `GeocodedStop` struct (it is defined at the bottom of the file — delete it entirely).
9. Remove the `private func geocodeAddress(_:)` method.

Also in `TripNavigationCoordinator.swift`:
- The `addStop(latitude:longitude:name:)` method can remain as it is used for deviation rerouting logic. Do NOT remove it from the coordinator.
- But remove any direct call sites from the NavigationHUDOverlay since the sheet is gone.

---

## Compile Requirements

- No `@Published`, `@StateObject`, or `@ObservedObject` — all `@Observable`
- All async calls wrapped in `do { try await } catch { }` or propagated as `async throws`
- All store mutations on `@MainActor`
- No force unwraps in new code
- No new SPM dependencies

---

## Files To Modify

1. `Sierra/Driver/Views/TripDetailDriverView.swift` — lifecycle flow + progress bar
2. `Sierra/Driver/Views/NavigationHUDOverlay.swift` — remove Add Stop entirely
3. `Sierra/Shared/Services/AppDataStore+TripAcceptance.swift` (or a new `AppDataStore+TripLifecycle.swift`) — add `startTrip` and `endTrip` if missing
4. `Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift` — propagate `preInspectionId` back to store
5. `Sierra/Driver/Views/PostTripInspectionView.swift` — if needed, propagate `postInspectionId` back to store (read the file to determine if it already does this)

## Files To NOT Touch
- `Sierra/Shared/Models/Trip.swift`
- `Sierra/Driver/Views/DriverTripsListView.swift` (done in Phase 1)
- `Sierra/FleetManager/Views/TripDetailView.swift` (done in Phase 1)
- `Sierra/Driver/Views/DriverTripAcceptanceSheet.swift`
- Any auth, onboarding, or maintenance views

---

## Output Requirements

Produce full, ready-to-compile file content for every modified file. Do not produce diffs or partial snippets. Commit to `main` on `Kanishk101/Sierra` using `github:push_files` with message: `feat(driver): Phase 2 — full lifecycle flow enforcement + progress bar + remove add-stops`.
