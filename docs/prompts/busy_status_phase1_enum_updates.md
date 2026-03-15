# Phase 1 — Enum Updates: Add `.busy` to VehicleStatus & StaffAvailability

> **Model:** Claude Opus 4.6  
> **Scope:** Pure enum / model changes only. Zero UI changes. Zero service changes.  
> **Deliver:** Complete, compilable replacement files only — no stubs, no ellipsis, no TODO comments.

---

## Context

Sierra is an iOS Fleet Management app (SwiftUI, MVVM, `@Observable`, Swift Concurrency, iOS 26+).  
Supabase is the backend. Both `vehicle_status` and `staff_availability` PostgreSQL enums have already been migrated to include the `'Busy'` value. The Swift enums must now match.

The project uses a `SierraStatus` protocol (defined in `Sierra/Shared/Theme/SierraStatusProtocol.swift`) that every status enum conforms to. It requires: `label`, `dotColor`, `backgroundColor`, `foregroundColor`, `showsDot`.

The theme colours available in `SierraTheme.Colors` that are relevant here:
- `alpineMint` — green, used for `.active` / `.available`
- `ember` — orange-red, used for active/warning states
- `emberDark` — darker ember
- `granite` — muted grey
- `warning` — amber
- `danger` — red
- `info` — blue

---

## Files to Read First

Read these files in full before writing any output:

1. `Sierra/Shared/Theme/VehicleStatus.swift`
2. `Sierra/Shared/Theme/DriverStatus.swift`
3. `Sierra/Shared/Models/StaffMember.swift`
4. `Sierra/Shared/Theme/SierraStatusProtocol.swift`

---

## Changes Required

### 1. `Sierra/Shared/Theme/VehicleStatus.swift`

Add `.busy = "Busy"` as a new case to `VehicleStatus`.  
Place it **between** `.idle` and `.inMaintenance` so the sort order reads: `active → idle → busy → inMaintenance → outOfService → decommissioned`.

Add its `SierraStatus` conformance:
- `dotColor`: `SierraTheme.Colors.ember`
- `foregroundColor`: `SierraTheme.Colors.emberDark`
- `icon`: `"road.lanes"`  
- `label`: `"Busy"`
- `accentBorderColor`: `SierraTheme.Colors.ember`

Do not change any other case, colour, or icon.

---

### 2. `Sierra/Shared/Models/StaffMember.swift`

In the `StaffAvailability` enum, add `.busy = "Busy"` as a new case.  
Place it **after** `.available` and **before** `.unavailable`:
```
available → busy → unavailable → onTrip → onTask
```

The `onTrip` case **must be kept** — it still exists in the Supabase enum and may exist in legacy rows. New code will never write `onTrip`; it is read-only for backwards compatibility.

Do not touch any other part of `StaffMember.swift` — not the struct, not the mock data, not the coding keys.

---

### 3. `Sierra/Shared/Theme/DriverStatus.swift`

This is a **display-only** enum used for UI badges. It currently has both `.onTrip` and `.busy` as separate cases with identical colours — consolidate:

- **Remove** the `.onTrip = "On Trip"` case entirely.
- **Keep** `.busy = "Busy"` — this now covers the single concept of "driver is assigned to a trip / actively doing a trip".
- **Add** `.unavailable = "Unavailable"` — a new case for drivers who are on leave / manually set unavailable by admin. Colour: `SierraTheme.Colors.granite`, foreground: `SierraTheme.Colors.granite`.
- Keep all other existing cases (`available`, `offDuty`, `pendingReview`, `rejected`, `inactive`) exactly as they are.

The final case order should be: `available → busy → unavailable → offDuty → pendingReview → rejected → inactive`.

---

## Output Format

Output **three complete Swift files**, each in a fenced code block labelled with the file path. Do not abbreviate any existing code. Every line of the original file that is not explicitly changed must be reproduced exactly.

```
// FILE: Sierra/Shared/Theme/VehicleStatus.swift
...
```

```
// FILE: Sierra/Shared/Models/StaffMember.swift
...
```

```
// FILE: Sierra/Shared/Theme/DriverStatus.swift
...
```

---

## Hard Constraints

- **No UI changes.** No new views, no new modifiers, no layout changes.
- **No service changes.** Do not touch any `*Service.swift` or `AppDataStore.swift`.
- **No mock data changes.** Do not alter any `mockData` or `samples` arrays.
- **Compilable on first pass.** No build errors, no unresolved symbols.
- `StaffAvailability.onTrip` must remain — do not delete it.
