# Phase 2 — TripService: Overlap Check & Resource State Methods

> **Model:** Claude Opus 4.6  
> **Scope:** `TripService.swift` only — add three new static methods. Do not modify any existing method.  
> **Prerequisite:** Phase 1 must be applied first (`StaffAvailability.busy` and `VehicleStatus.busy` must exist).

---

## Context

Sierra uses Supabase as its backend. The global `supabase` constant (a `SupabaseClient`) is defined in `SupabaseManager.swift` and is available in all service files. The project uses Swift Concurrency throughout — all async work is `async throws`.

### Supabase project URL
`https://ldqcdngdlbbiojlnbnjg.supabase.co`

### Deployed Edge Function
Name: `check-resource-overlap`  
Verify JWT: `true` — the Supabase Swift SDK sends the current session JWT automatically.  
Expected POST body (JSON):
```json
{
  "driver_id":        "<UUID string>",
  "vehicle_id":       "<UUID string>",
  "start":            "<ISO-8601 datetime>",
  "end":              "<ISO-8601 datetime>",
  "exclude_trip_id":  "<UUID string or null>"
}
```
Expected response (JSON):
```json
{
  "driver_conflict":  true,
  "vehicle_conflict": false
}
```

### ISO formatter
`TripService.swift` already defines a file-private `iso: ISO8601DateFormatter` with `[.withInternetDateTime, .withFractionalSeconds]`. Reuse it.

---

## Files to Read First

Read these files in full before writing any output:

1. `Sierra/Shared/Services/TripService.swift`
2. `Sierra/Shared/Services/VehicleService.swift`
3. `Sierra/Shared/Services/StaffMemberService.swift`
4. `Sierra/Shared/Models/StaffMember.swift`  (for `StaffAvailability` enum)
5. `Sierra/Shared/Theme/VehicleStatus.swift`  (for `VehicleStatus` enum)

---

## Changes Required

Add **three new static methods** to the `TripService` struct. All are `async throws`. Place them in a new `// MARK: - Busy Status Helpers` section at the bottom of the struct, above the `// MARK: Task ID Helper` section.

---

### Method 1 — `checkOverlap`

```swift
static func checkOverlap(
    driverId: UUID,
    vehicleId: UUID,
    start: Date,
    end: Date,
    excludingTripId: UUID? = nil
) async throws -> (driverConflict: Bool, vehicleConflict: Bool)
```

**Implementation:**

Call the `check-resource-overlap` Edge Function via `supabase.functions.invoke`. Build the JSON body as a `[String: AnyJSON]` dictionary using the Supabase Swift SDK's `AnyJSON` type (or encode to `Data` via `JSONEncoder` and pass as `.data(Data)`). Decode the response body to a local `Decodable` struct:

```swift
struct OverlapResult: Decodable {
    let driverConflict: Bool
    let vehicleConflict: Bool
    enum CodingKeys: String, CodingKey {
        case driverConflict  = "driver_conflict"
        case vehicleConflict = "vehicle_conflict"
    }
}
```

Return `(result.driverConflict, result.vehicleConflict)`.

The `functions.invoke` call pattern in the Supabase Swift SDK:
```swift
let response: FunctionInvokeOptions = .init(body: payload)
let result = try await supabase.functions.invoke("check-resource-overlap", options: response)
// result.data is Data — decode with JSONDecoder
```

If the SDK version in use accepts `body` as `some Encodable`, encode the body struct directly. Check how existing Edge Function calls are made elsewhere in the codebase (e.g., `EmailService.swift`) and follow the same pattern exactly.

---

### Method 2 — `markResourcesBusy`

```swift
static func markResourcesBusy(driverId: UUID, vehicleId: UUID) async throws
```

**Implementation:**

Two sequential Supabase table updates (not concurrent — keep them serial to avoid race conditions):

1. Update `staff_members` where `id = driverId`: set `availability = 'Busy'`
2. Update `vehicles` where `id = vehicleId`: set `status = 'Busy'`

Use the same update pattern already used in `StaffMemberService` and `VehicleService`. Use raw string values `"Busy"` in the payload struct `rawValue` fields — do not reference the enum directly here to keep the service layer decoupled from UI models.

```swift
// Payload structs (file-private to TripService.swift)
fileprivate struct AvailabilityPayload: Encodable {
    let availability: String
}
fileprivate struct VehicleStatusPayload: Encodable {
    let status: String
}
```

---

### Method 3 — `releaseResources`

```swift
static func releaseResources(driverId: UUID, vehicleId: UUID) async throws
```

**Implementation:**

Mirror of `markResourcesBusy` but in reverse:
1. Update `staff_members` where `id = driverId`: set `availability = 'Available'`
2. Update `vehicles` where `id = vehicleId`: set `status = 'Idle'`, set `assigned_driver_id = null`

For the vehicle update, use a combined payload:
```swift
fileprivate struct VehicleReleasePayload: Encodable {
    let status: String
    let assignedDriverId: String?
    enum CodingKeys: String, CodingKey {
        case status
        case assignedDriverId = "assigned_driver_id"
    }
}
// Instantiate as: VehicleReleasePayload(status: "Idle", assignedDriverId: nil)
```

---

## Output Format

Output the **complete `TripService.swift` file** in a single fenced code block. Every existing line must be reproduced exactly. Only the three new methods and their supporting file-private structs are additions.

```
// FILE: Sierra/Shared/Services/TripService.swift
...
```

---

## Hard Constraints

- Do **not** modify any existing method signature or body.
- Do **not** add any `import` statement that isn't already present.
- Do **not** reference `VehicleStatus` or `StaffAvailability` enums directly — use raw string values in Encodable payloads.
- The three new methods must be `static` and `async throws`.
- `OverlapResult`, `AvailabilityPayload`, `VehicleStatusPayload`, `VehicleReleasePayload` must be `fileprivate` or `private` — not exposed beyond this file.
- **Compilable on first pass.** No build errors.
