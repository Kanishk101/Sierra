# Sierra — Driver Trip Flow: Phase 1
## Trip List: Admin Dispatch Gate + Visible Accept CTA on Driver Side

---

## Context & Background

This prompt targets the Sierra iOS app (SwiftUI, MVVM, `@Observable`, Supabase backend, no RLS). The project lives at `Kanishk101/Sierra` on GitHub, `main` branch. The Supabase backend is project ID `ldqcdngdlbbiojlnbnjg`.

### What Is Currently Broken

**Root problem:** Every trip that an admin creates enters the database with `status = 'Scheduled'`. There is no mechanism anywhere in the app that transitions a trip from `Scheduled` to `PendingAcceptance`. The `PendingAcceptance` status exists in both the Swift `TripStatus` enum and the Postgres `trip_status` enum, but it is never actually set on any real trip. Because the driver-side list and detail views only show the Accept/Reject flow for `pendingAcceptance` trips, and no trip ever reaches that status, the driver sees every assigned trip stuck on "Awaiting Assignment" with zero actionable options.

**Secondary visual problem:** Even if a trip did reach `pendingAcceptance`, the driver trip list shows no visible "Accept" button on the row itself — the entire row is a tappable button that silently opens `DriverTripAcceptanceSheet`. There is no visible call-to-action, so the driver has no idea the row is interactive.

### Intended Full Trip Lifecycle (Pre-requisite for Phases 2 and 3)

```
Admin creates trip (assigns driver + vehicle)
    ↓  status = Scheduled
Admin dispatches trip to driver
    ↓  status = PendingAcceptance  ← THIS TRANSITION DOES NOT EXIST YET
Driver accepts trip
    ↓  status = Accepted
Driver completes pre-trip inspection
    ↓  trip.preInspectionId set
Driver starts trip
    ↓  status = Active
Driver navigates (Mapbox full-screen)
Driver completes delivery (ProofOfDelivery captured)
    ↓  trip.proofOfDeliveryId set
Driver completes post-trip inspection
    ↓  trip.postInspectionId set
Driver ends trip
    ↓  status = Completed
```

---

## Files to Read First (Required)

Before writing a single line of code, fetch and read these files in full:

1. `Sierra/FleetManager/Views/TripDetailView.swift` — admin trip detail, where the Dispatch button will be added
2. `Sierra/Shared/Services/TripService.swift` — where `dispatchTrip()` must be added
3. `Sierra/Shared/Services/AppDataStore.swift` — the shared data store; verify `acceptTrip(tripId:)` and `rejectTrip(tripId:reason:)` already exist
4. `Sierra/Shared/Services/AppDataStore+TripAcceptance.swift` — the acceptance-specific extension; understand how accept/reject are implemented so dispatch follows the same pattern
5. `Sierra/Driver/Views/DriverTripsListView.swift` — driver list view that needs the visible CTA added
6. `Sierra/Driver/Views/DriverTripAcceptanceSheet.swift` — the acceptance sheet already built; understand its API signature
7. `Sierra/Shared/Models/Trip.swift` — confirm `TripStatus` cases and `acceptanceDeadline` field

Do NOT assume what is in these files. Read them. The actual implementations may differ from what you expect.

---

## Part A: Admin Side — Add "Dispatch to Driver" Button in TripDetailView (Admin)

### What To Do

In `Sierra/FleetManager/Views/TripDetailView.swift` (the **admin** trip detail view, not the driver one), add a **"Dispatch to Driver"** button that is visible only when:
- `trip.status == .scheduled`
- `trip.driverId != nil` (a driver is assigned)
- `trip.vehicleId != nil` (a vehicle is assigned)

When tapped, this button calls `store.dispatchTrip(tripId:)` (see Part B below), which transitions the trip to `pendingAcceptance` in Supabase and sets `acceptanceDeadline` to `Date() + 24 hours`.

**Visual design:**
- Large, full-width button
- Use `.teal` background color
- Icon: `paperplane.fill`
- Label: `"Dispatch to Driver"`
- Show a `ProgressView` spinner while the async call is in flight (use local `@State var isDispatching = false`)
- On error: show a `.alert` with the error message (reuse the existing error alert pattern if one already exists in this file; if not, add one)
- Button must be `disabled` while `isDispatching == true`

**Placement:** The button should appear in the action section of the admin trip detail view, near the bottom, alongside any existing action buttons. Read the file to find the correct placement — do NOT guess or overwrite existing action buttons.

### What NOT To Do
- Do not change the admin's trip creation flow (`CreateTripView.swift`). The trip should still be created as `Scheduled`.
- Do not add an auto-dispatch on creation. The admin explicitly chooses when to dispatch.
- Do not modify any views other than `TripDetailView.swift` for this part.

---

## Part B: Service Layer — Add `dispatchTrip(tripId:)` to AppDataStore

### What To Do

Add a new extension method to `AppDataStore` in `AppDataStore+TripAcceptance.swift`. Follow the exact same async-throws pattern already present in that file for `acceptTrip` and `rejectTrip`.

```swift
// In AppDataStore+TripAcceptance.swift

func dispatchTrip(tripId: UUID) async throws {
    let deadline = Date().addingTimeInterval(24 * 3600) // 24-hour response window
    try await SupabaseManager.client
        .from("trips")
        .update([
            "status": TripStatus.pendingAcceptance.rawValue,
            "acceptance_deadline": ISO8601DateFormatter().string(from: deadline),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ])
        .eq("id", value: tripId.uuidString)
        .execute()
    // Update local store
    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
        trips[idx].status = .pendingAcceptance
        trips[idx].acceptanceDeadline = deadline
        trips[idx].updatedAt = Date()
    }
}
```

**Important notes:**
- Check how `SupabaseManager.client` is accessed in the existing acceptance methods — use the exact same access pattern. Do not invent a different call style.
- Use `ISO8601DateFormatter` only if that is the pattern already in use in that file. If the existing code uses Supabase's type-safe update syntax with typed structs, follow that pattern instead. Read first.
- The local store update (the `if let idx` part) must happen on `@MainActor`. Check whether the extension is already marked `@MainActor` or if this needs a `Task { @MainActor in ... }` wrapper.

---

## Part C: Driver Side — Add Visible "Accept Trip" Button to Trip Row in DriverTripsListView

### Current State

In `DriverTripsListView.swift`, when `trip.status == .pendingAcceptance`, the entire row is wrapped in a `Button` that opens `DriverTripAcceptanceSheet`. The row visually looks identical to all other trips, with only a status badge text "Pending Acceptance" in orange. There is no visible button labeled "Accept" on the card.

### What To Do

For rows where `trip.status == .pendingAcceptance`, modify the `tripRow(_:)` helper to append an inline "Accept Trip" button **below** the existing row content (inside the same card VStack, below the existing HStack), before the closing card background modifier.

The button must:
- Be full-width within the card, with 16pt horizontal insets
- Height: 44pt
- Background: `Color.green` with `RoundedRectangle(cornerRadius: 10, style: .continuous)`
- Label: `HStack` with `Image(systemName: "checkmark.circle.fill")` + `Text("Accept Trip")` in `.white` bold font
- On tap: set `acceptanceTrip = trip` (the existing `@State` that drives the sheet)
- The overall row tap behavior (the `Button` wrapping the whole row) should remain unchanged — the new button is additive

Also ensure the `deadlineBadge(deadline:)` view (already in the file) is shown **above** the accept button, not below it.

### Do NOT Change
- Do not change the `NavigationLink` behavior for non-`pendingAcceptance` trips
- Do not change `DriverTripAcceptanceSheet` at all in this phase
- Do not change the `.sheet(item: $acceptanceTrip)` modifier — it already works correctly

---

## Part D: Admin Trip Detail — "Dispatch" State Reflection

After `dispatchTrip` is called, the admin trip detail view should update to show the current status correctly. Specifically:
- The status badge/banner should update to show `Pending Acceptance` in orange
- The "Dispatch to Driver" button should no longer be visible (because `trip.status != .scheduled` now)
- If the admin detail view does not reactively observe `store.trips`, add a lookup like `let trip = store.trips.first { $0.id == tripId }` and make sure the view body reads from this reactive property. Do not store a local copy of the trip that doesn't update.

---

## Compile Requirements

- All new code must compile without warnings
- Use `@Observable` pattern — no `@Published` anywhere
- All async methods must be `async throws` and called with `do { try await } catch { }`
- All UI updates from async callbacks must happen on `@MainActor`
- Do not introduce any new SPM dependencies
- Do not use `@StateObject` or `@ObservedObject` — the project is fully `@Observable`

---

## Files To Modify

1. `Sierra/FleetManager/Views/TripDetailView.swift` — add Dispatch button
2. `Sierra/Shared/Services/AppDataStore+TripAcceptance.swift` — add `dispatchTrip(tripId:)` method
3. `Sierra/Driver/Views/DriverTripsListView.swift` — add visible Accept CTA on pending rows

## Files To NOT Touch
- `Sierra/Driver/Views/DriverTripAcceptanceSheet.swift`
- `Sierra/Driver/Views/TripDetailDriverView.swift`
- `Sierra/FleetManager/Views/CreateTripView.swift`
- `Sierra/Shared/Models/Trip.swift`
- Any navigation or tab view files

---

## Output Requirements

Produce the complete, ready-to-compile content for each of the three modified files. No diffs, no partial snippets — full file content for each. Do not truncate. Commit to `main` branch on `Kanishk101/Sierra` using `github:push_files` in a single commit with message: `feat(driver): Phase 1 — admin dispatch gate + visible accept CTA on driver trip list`.
