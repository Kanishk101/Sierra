# Fix 5 — AppDataStore: Consistent Parameter Types for Trip Lookup Helpers

## File
`Sierra/Shared/Services/AppDataStore.swift`

## Problem

Trip lookup helpers are inconsistent:

```swift
// Takes UUID — consistent with other helpers
func trips(forDriver driverId: UUID) -> [Trip] {
    trips.filter { $0.driverId == driverId.uuidString }
}

// Takes String — inconsistent
func activeTrip(forDriverId driverId: String) -> Trip? {
    trips.first { $0.driverId == driverId && ($0.status == .active || $0.status == .scheduled) }
}
```

Call sites have to know whether to pass a `UUID` or a `String` for the same FK.
If a call site passes a `UUID` directly to `activeTrip(forDriverId:)` Swift will
not warn — it'll just call `.description` which produces the wrong format
(`"Optional(...)"` instead of the bare UUID string).

## Fix

Change `activeTrip(forDriverId:)` to accept `UUID` and convert internally,
matching every other lookup helper:

```swift
func activeTrip(forDriverId driverId: UUID) -> Trip? {
    trips.first {
        $0.driverId == driverId.uuidString
        && ($0.status == .active || $0.status == .scheduled)
    }
}
```

Find all call sites of `activeTrip(forDriverId:)` in the codebase and update them
to pass a `UUID` instead of a `String`. Typically this is called from `DriverHomeView`
or similar with `AuthManager.shared.currentUser?.id` which is already a `UUID`.
