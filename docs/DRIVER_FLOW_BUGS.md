# Driver Flow — Bug Report & Fix Spec

Source: PDF screenshots (11 pages) + live code audit of latest commit.
Each bug is numbered, traced to file + line, and includes the exact fix required.

---

## Bug 1 — Trip card shows "Inspect Vehicle" instead of "Accepted" badge (Page 1)

**File:** `Sierra/Driver/Views/DriverTripsListView.swift` → `actionButtons(_:)` → `isAwaitingInspection` branch

**What's happening:**
When a trip is in `.scheduled` state and no pre-inspection has been done
(`isAwaitingInspection = true`), the right button shows an orange "Inspect Vehicle"
capsule that opens `showTripDetail(trip)`. This is wrong.

**What it should show:**
A non-interactive green "Accepted" badge — the trip is accepted, inspection is
for the driver to do separately via View Details. The card should never show
"Inspect Vehicle" as a primary CTA since that action is inside the detail overlay.

**Fix:**
```swift
// Replace the isAwaitingInspection branch:
} else if isAwaitingInspection {
    // Accepted — show passive badge only
    HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold))
        Text("Accepted").font(.system(size: 14, weight: .bold, design: .rounded))
    }
    .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
    .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
```

---

## Bug 2 — "Begin Pre-Trip Inspection" button appears inside TripDetailDriverView (Page 2)

**File:** `Sierra/Driver/Views/TripDetailDriverView.swift` → `actionButtons(_:)` → `.scheduled` case

**What's happening:**
Inside `TripDetailDriverView`, when `trip.preInspectionId == nil`, the view renders:
```swift
actionButton("Begin Pre-Trip Inspection", icon: "checklist", color: SierraTheme.Colors.ember) {
    showPreInspection = true
}
```
This (a) makes a redundant entry point and (b) opens the OLD `PreTripInspectionView`
directly as a `.sheet` without the new 3-page redesign flow.

**What it should show:**
The `TripDetailDriverView` should NOT surface a "Begin Pre-Trip Inspection" button.
The pre-trip inspection entry point lives exclusively in the trip list card's
`TripDetailOverlay` slider. Remove this button entirely from `TripDetailDriverView`.
For the `.scheduled` branch where `preInspectionId == nil`, show a passive
"Inspection Required" info chip instead:

```swift
// Replace the actionButton("Begin Pre-Trip Inspection"...) call with:
HStack(spacing: 8) {
    Image(systemName: "checklist").font(.system(size: 14, weight: .semibold)).foregroundColor(.appOrange)
    Text("Pre-Trip Inspection required before navigating")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(.appTextSecondary)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 14)
.background(RoundedRectangle(cornerRadius: 14).fill(Color.appOrange.opacity(0.07)))
.overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appOrange.opacity(0.2), lineWidth: 1))
```

Also remove the `.sheet(isPresented: $showPreInspection)` block and the `showPreInspection`
`@State` property since that path no longer exists.

---

## Bug 3 — Post-trip inspection opens a blank screen (Page 3)

**File:** `Sierra/Driver/Views/DriverTripsListView.swift` → `.fullScreenCover(isPresented: $showInspection)`

**What's happening:**
When `inspectionMode == .post`, the fullScreenCover presents `PostTripInspectionView`
without a `NavigationStack` wrapper:
```swift
if inspectionMode == .post {
    PostTripInspectionView(tripId: iTrip.id, vehicleId: vehicleUUID, driverId: dId)
        .environment(store)
}
```
`PostTripInspectionView` uses `.navigationTitle()` and `ToolbarItem` which require
a `NavigationStack` to render. Without one, those modifier calls silently fail and
the view body renders into a blank screen with only the system safe area visible.

**Fix:** Wrap in `NavigationStack`:
```swift
if inspectionMode == .post {
    NavigationStack {
        PostTripInspectionView(tripId: iTrip.id, vehicleId: vehicleUUID, driverId: dId)
            .environment(store)
    }
}
```

Note: The `.pre` branch already wraps correctly because `PreTripInspectionView`
doesn't rely on navigation toolbar items.

---

## Bug 4 — "Completed" filter shows trips before post-trip inspection is done (Page 4)

**File:** `Sierra/Driver/Views/DriverTripsListView.swift` → `filtered` computed property

**What's happening:**
The filter `selectedStatus == .completed` matches any trip whose `trip.status == .completed`,
regardless of whether `postInspectionId` is set. So a trip that ended navigation
but hasn't done post-trip inspection appears as "Completed" in the filter — the
card correctly shows a "Post-Trip Inspection" slider, but the filter label is wrong.

The SRS and design intent: a trip is only truly "Completed" once `postInspectionId != nil`.
Trips in the interim state (`status == .completed`, `postInspectionId == nil`) should
not surface under a "Completed" filter — they should appear in the default "All" list
or a separate "Pending Inspection" state.

**Fix — option A (recommended):** Treat `status == .completed && postInspectionId == nil` as
a separate display state. In the `filtered` guard:
```swift
// In the filter guard, replace the status check:
if let s = selectedStatus {
    let normalised = trip.status.normalized
    if s == .completed {
        // Only show as completed if post-inspection is done
        guard normalised == .completed && trip.postInspectionId != nil else { return false }
    } else {
        guard normalised == s.normalized else { return false }
    }
}
```

**Fix — option B:** Add `.pendingPostInspection` as a virtual filter item in the menu
that matches `status == .completed && postInspectionId == nil`.

---

## Bug 5 — Left card button should be "Navigate" (not "View Details") for accepted+ready trips (Page 8)

**File:** `Sierra/Driver/Views/DriverTripsListView.swift` → `actionButtons(_:)` → `isAwaitingWindow` and `isReadyToStart` branches

**What's happening:**
For `isReadyToStart` (inspection done, within 30-min window), the LEFT button is
"View Details" and the RIGHT is a `NavigationLink` "Start Trip". Per the redesign:

- The "View Details" `NavigationLink` (which goes to the full `TripDetailDriverView`
  screen) is a redundant screen — the driver doesn't need that intermediate view.
- The right-side CTA for ready trips should be "Navigate" (launches navigation directly).
- The left button stays "View Details" only when the trip is not yet actionable.

**Correct button mapping per design:**

| State | Left button | Right button |
|-------|-------------|---------------|
| PendingAcceptance | View Details | Accept Trip |
| Scheduled, no inspection | View Details | Accepted (badge) |
| Scheduled, inspection done, not in window | View Details | Starts HH:MM |
| Scheduled, inspection done, in window | Navigate (launches nav) | Accepted (badge) |
| Active | Navigate | (none, or secondary) |

**Fix for `isReadyToStart` branch:**
```swift
} else if isReadyToStart {
    // LEFT: Navigate directly — skip TripDetailDriverView entirely
    Button {
        navigationTrip = trip
        showNavigation = true
    } label: {
        HStack(spacing: 6) {
            Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
            Text("Navigate").font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color(red: 0.90, green: 0.22, blue: 0.18)))
    }
    .buttonStyle(.plain)

    // RIGHT: Passive accepted badge
    HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold))
        Text("Accepted").font(.system(size: 14, weight: .bold, design: .rounded))
    }
    .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
    .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
```

Remove the `NavigationLink(value: trip.id)` Start Trip link entirely from the card.
The `TripDetailDriverView` can still be reached via "View Details" when not in the ready state.

---

## Bug 6 — Pre-trip inspection design is wrong (Pages 5, 6, 7, 9, 10, 11)

**Files:** `Sierra/Driver/Views/PreTripInspectionView.swift`,
`Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift`

This is a full redesign of the pre-trip inspection flow. The current implementation
has odometer reading at the top of page 1 which is wrong. The correct 3-page flow is:

### Page 1 — Vehicle checklist
- List of toggle items: Brakes, Tyres, Lights (Front), Lights (Rear), Horn, Wipers,
  Mirrors, Fuel Levels, Engine Oil, Coolant, Steering
- Each item is an `HStack` with name + `Toggle`
- When toggle is turned **OFF**: the row expands inline to show:
  - `Status` picker: **Warn** | **Fail** (segmented-style)
  - `Issue Details` text field (multiline)
  - If any item is **Fail**: bottom button changes to **"Change Vehicle Alert"** (red)
  - If any item is **Warn** but no Fail: bottom button is **"Send Alert to Fleet Manager"** (orange)
  - If all pass: bottom button is **"Next →"** (orange)
- **No odometer reading on this page**

### Page 2 — Media uploads
- **Upload Fuel Status** — camera capture (photo, not scan)
- **Upload Odometer Readings** — camera capture (photo, not scan)
- No text input, no scan flow
- Button: **"Next →"**

### Page 3 — Driver's Signature
- `DrawingCanvas` (finger-drawn signature on white background)
- Label: "Sign above to confirm inspection"
- Clear button top-right
- Button: **"Complete Inspection"** (disabled until signature present)
- On submit: show **"Inspection Complete!"** success modal with "Done" button
  (matches page 11 design)

### Implementation notes
- Remove `OdometerReadingSection` from page 1 entirely
- Remove `MachineReadableCodeScanner` from page 1 (odometer OCR is dead)
- The `inspectionType` param still differentiates pre vs post — post-trip inspection
  reuses the same view (already the pattern in `PostTripInspectionView`)
- Signature canvas: use `PKCanvasView` wrapped in `UIViewRepresentable`
  (requires `import PencilKit`). Store the signature as a `UIImage` → upload to
  Supabase storage, save URL in the inspection record.
- The "Change Vehicle Alert" button should call the existing vehicle-replacement
  flow / alert the FM — wire to `store.flagVehicleIssue()` or equivalent.

### Files to change
1. `PreTripInspectionView.swift` — full page restructure per above
2. `PreTripInspectionViewModel.swift` — remove odometer scan logic from inspection;
   add signature data storage
3. `PostTripInspectionView.swift` — the `.inspecting` phase now embeds the
   redesigned `PreTripInspectionView`; the `.enteringOdometer` phase can be
   collapsed into page 2 of the pre-trip view (odometer photo upload)

---

## Bug 7 — Stats bar label says "Active" but counts Scheduled+Active (minor display)

**File:** `Sierra/Driver/Views/DriverTripsListView.swift` → `activeCount`

```swift
private var activeCount: Int {
    driverTrips.filter { $0.status == .scheduled || $0.status == .active }.count
}
```

The label renders as "ACTIVE" but counts both `.scheduled` and `.active`. Per the
design (page 1), the third stat shows "ACCEPTED" not "ACTIVE". Change the label
from `"Active"` to `"Accepted"` in `statItem(...)` call, and change the count to
only count `.scheduled` trips (accepted + awaiting start):

```swift
private var acceptedCount: Int {
    driverTrips.filter { $0.status == .scheduled && $0.acceptedAt != nil }.count
}
// In statsBar:
statItem(value: "\(acceptedCount)", label: "Accepted", icon: "checkmark.seal.fill", color: ...)
```

---

## Summary — files to change

| File | Bugs fixed |
|------|------------|
| `DriverTripsListView.swift` | Bug 1, 3, 4, 5, 7 |
| `TripDetailDriverView.swift` | Bug 2 |
| `PreTripInspectionView.swift` | Bug 6 (full redesign) |
| `PreTripInspectionViewModel.swift` | Bug 6 (remove odometer scan) |
| `PostTripInspectionView.swift` | Bug 3, Bug 6 (page 2 restructure) |

---

## Priority order

```
P0 — Bug 3: Blank post-trip screen (NavigationStack missing) — 1 line fix, do immediately
P0 — Bug 2: Remove "Begin Pre-Trip Inspection" from TripDetailDriverView — prevents wrong flow
P1 — Bug 1: Accepted badge instead of Inspect Vehicle on card
P1 — Bug 5: Navigate button for ready trips
P1 — Bug 4: Completed filter gate on postInspectionId
P2 — Bug 6: Pre-trip inspection full redesign (3-page flow)
P3 — Bug 7: Stats bar label "Accepted" not "Active"
```
