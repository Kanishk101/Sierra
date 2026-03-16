# Phase 1 — Status Enum Domain Fixes
## Add `onTrip` to `DriverStatus` + `busy` to `VehicleStatus`

---

## Context

You are working on the **Sierra Fleet Management System** iOS app (SwiftUI, MVVM, iOS 26+).  
This is a targeted, surgical diff-based fix. Do not touch any file not listed below.  
Do not change any visual styling, colors, fonts, or layout.

We have cross-referenced our codebase against a sibling repo (`mantosh23/Fleetora`) which added  
two new enum cases that better model real fleet domain logic:

1. `DriverStatus.onTrip` — a driver who is actively on a trip is **not** merely "unavailable",  
   they are specifically `onTrip`. This replaces the less specific `.unavailable` case.
2. `VehicleStatus.busy` — a vehicle that is currently assigned to an active trip  
   is in a `busy` state distinct from `idle` (parked, not assigned) or `active` (just powered on).

---

## File 1 of 2 — `Sierra/Shared/Theme/DriverStatus.swift`

### Current State (your file)

```swift
import SwiftUI

// MARK: - Driver Status

enum DriverStatus: String, SierraStatus, CaseIterable, Codable {
    case available     = "Available"
    case busy          = "Busy"
    case unavailable   = "Unavailable"
    case offDuty       = "Off Duty"
    case pendingReview = "Pending Review"
    case rejected      = "Rejected"
    case inactive      = "Inactive"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineMint
        case .busy:          SierraTheme.Colors.ember
        case .unavailable:   SierraTheme.Colors.granite
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineDark
        case .busy:          SierraTheme.Colors.emberDark
        case .unavailable:   SierraTheme.Colors.granite
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var showsDot: Bool { true }

    var icon: String? { nil }
}
```

### Required Changes

1. **Add** `case onTrip = "On Trip"` after `case available`.
2. **Remove** `case unavailable = "Unavailable"` — this is being retired in favour of `onTrip`.
3. In `dotColor`: add `case .onTrip: SierraTheme.Colors.ember` and remove the `.unavailable` arm.
4. In `foregroundColor`: add `case .onTrip: SierraTheme.Colors.emberDark` and remove `.unavailable`.
5. **Keep** `showsDot` and `icon` — do not remove them.

### Target State

```swift
import SwiftUI

// MARK: - Driver Status

enum DriverStatus: String, SierraStatus, CaseIterable, Codable {
    case available     = "Available"
    case onTrip        = "On Trip"
    case busy          = "Busy"
    case offDuty       = "Off Duty"
    case pendingReview = "Pending Review"
    case rejected      = "Rejected"
    case inactive      = "Inactive"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineMint
        case .onTrip:        SierraTheme.Colors.ember
        case .busy:          SierraTheme.Colors.ember
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineDark
        case .onTrip:        SierraTheme.Colors.emberDark
        case .busy:          SierraTheme.Colors.emberDark
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var showsDot: Bool { true }

    var icon: String? { nil }
}
```

---

## File 2 of 2 — `Sierra/Shared/Theme/VehicleStatus.swift`

### Current State (your file)

```swift
import SwiftUI

// MARK: - Vehicle Status
// Maps to PostgreSQL enum: vehicle_status
// Values: Active | Idle | In Maintenance | Out of Service | Decommissioned

enum VehicleStatus: String, SierraStatus, CaseIterable, Codable {
    case active          = "Active"
    case idle            = "Idle"
    case inMaintenance   = "In Maintenance"
    case outOfService    = "Out of Service"
    case decommissioned  = "Decommissioned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineMint
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineDark
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var icon: String? {
        switch self {
        case .active:         "truck.box.fill"
        case .idle:           "parkingsign.circle"
        case .inMaintenance:  "wrench.fill"
        case .outOfService:   "xmark.octagon.fill"
        case .decommissioned: "archivebox.fill"
        }
    }

    var showsDot: Bool { true }

    /// Convenience: border accent color (used on VehicleCard left border).
    var accentBorderColor: Color { dotColor }
}
```

### Required Changes

1. **Add** `case busy = "Busy"` after `case active`.
2. In `dotColor`: add `case .busy: SierraTheme.Colors.warning`.
3. In `foregroundColor`: add `case .busy: SierraTheme.Colors.warning`.
4. In `icon`: add `case .busy: "bolt.fill"`.
5. **Keep** `showsDot`, `accentBorderColor`, and all existing cases intact.

### Target State

```swift
import SwiftUI

// MARK: - Vehicle Status
// Maps to PostgreSQL enum: vehicle_status
// Values: Active | Busy | Idle | In Maintenance | Out of Service | Decommissioned

enum VehicleStatus: String, SierraStatus, CaseIterable, Codable {
    case active          = "Active"
    case busy            = "Busy"
    case idle            = "Idle"
    case inMaintenance   = "In Maintenance"
    case outOfService    = "Out of Service"
    case decommissioned  = "Decommissioned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineMint
        case .busy:           SierraTheme.Colors.warning
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineDark
        case .busy:           SierraTheme.Colors.warning
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var icon: String? {
        switch self {
        case .active:         "truck.box.fill"
        case .busy:           "bolt.fill"
        case .idle:           "parkingsign.circle"
        case .inMaintenance:  "wrench.fill"
        case .outOfService:   "xmark.octagon.fill"
        case .decommissioned: "archivebox.fill"
        }
    }

    var showsDot: Bool { true }

    /// Convenience: border accent color (used on VehicleCard left border).
    var accentBorderColor: Color { dotColor }
}
```

---

## Downstream Impact — Exhaustive Search Required

After making both file changes above, search the **entire codebase** for all switch statements  
that switch over `DriverStatus` or `VehicleStatus`. Every exhaustive switch must be updated:

- Any switch on `DriverStatus` that previously had a `.unavailable` arm must be updated  
  to `.onTrip` (and potentially `.busy` if not already present).
- Any switch on `VehicleStatus` that is exhaustive must add a `.busy` arm.
- If any switch uses `@unknown default`, no change is needed there.

Common files to check:
- `Sierra/Shared/Theme/SierraBadge.swift`
- `Sierra/FleetManager/Views/StaffListView.swift`
- `Sierra/FleetManager/Views/VehicleListView.swift`
- `Sierra/FleetManager/Views/DashboardHomeView.swift`
- `Sierra/FleetManager/ViewModels/` — any VM filtering by status
- `Sierra/Driver/` — any view that displays driver status

Do **not** change any UI layout, colors, or component structure outside of what is described here.

---

## Success Criteria

- [ ] `DriverStatus` has 7 cases: `available`, `onTrip`, `busy`, `offDuty`, `pendingReview`, `rejected`, `inactive`
- [ ] `DriverStatus` has NO `unavailable` case anywhere
- [ ] `VehicleStatus` has 6 cases: `active`, `busy`, `idle`, `inMaintenance`, `outOfService`, `decommissioned`
- [ ] All downstream exhaustive switches compile with no warnings
- [ ] Zero visual/layout/theme changes introduced
