# Sprint 2 — Phase 4: Cleanup, Analytics Wiring + Submission

> **Prerequisite:** Phases 1–3 complete.  
> **This phase covers:** Git hygiene, live dashboard stats, analytics wiring, submission artifacts

---

## Task 11 — Git Hygiene

### 11a — Remove .DS_Store from tracking

```bash
# From repo root
echo "**/.DS_Store" >> .gitignore
git rm --cached .DS_Store Sierra/.DS_Store 2>/dev/null || true
git add .gitignore
git commit -m "chore: remove .DS_Store from tracking"
```

Verify `.gitignore` contains:
```
**/.DS_Store
.DS_Store
```

### 11b — Merge sendEmail.swift into EmailService.swift

1. Open `Sierra/sendEmail.swift` — note its function signature and implementation
2. Open `Sierra/Shared/Services/EmailService.swift` — check if the same function already exists
3. If `EmailService.swift` already has equivalent functionality, simply **delete** `Sierra/sendEmail.swift`
4. If `sendEmail.swift` has unique logic, copy it into `EmailService.swift` as a new method, then delete `sendEmail.swift`
5. Search codebase for any `import` or direct call to `sendEmail` at the root path — update those call sites to use `EmailService`

```bash
# After the Swift changes:
git rm Sierra/sendEmail.swift
git add Sierra/Shared/Services/EmailService.swift
git commit -m "refactor: merge sendEmail.swift into EmailService"
```

### 11c — Delete StaffApplicationStore stub

The Reality Check confirmed `StaffApplicationStore.swift` is an empty deprecated stub with no active usages.

```bash
git rm Sierra/Shared/Services/StaffApplicationStore.swift
git commit -m "chore: remove deprecated StaffApplicationStore stub"
```

Before deleting, confirm with a project-wide search that nothing references `StaffApplicationStore`.

### 11d — Verify OTP compliance

Open `Sierra/Shared/Services/CryptoService.swift`. Confirm:
1. `sha256()` function exists and returns a hex string
2. Search the entire project for `otp` — verify no raw OTP string is stored in `two_factor_sessions` or `proof_of_deliveries`
3. Add a code comment in `CryptoService.swift`:
   ```swift
   // COMPLIANCE: OTP values are NEVER stored raw.
   // Only the SHA-256 hash is persisted to two_factor_sessions.otp_hash
   // and proof_of_deliveries.otp_hash. See Sprint 2 security audit.
   ```

---

## Task 12 — Wire DashboardHomeView Live Stats

### Context

`DashboardHomeView.swift` (19 KB) already has stat card UI. Some values are hardcoded or stale. All required data already lives in `AppDataStore` — just compute from it.

### File to modify

`Sierra/FleetManager/Views/DashboardHomeView.swift`

### Changes

Replace any hardcoded stats with computed values from `AppDataStore`:

```swift
// Active Trips
let activeTrips = store.trips.filter { $0.status == .active }.count

// Available Vehicles (Idle status in your enum)
let availableVehicles = store.vehicles.filter { $0.status == .idle }.count

// Vehicles In Maintenance
let inMaintenanceVehicles = store.vehicles.filter { $0.status == .inMaintenance }.count

// Open Maintenance Requests (Pending status)
let openMaintenanceTasks = store.maintenanceTasks.filter { 
    $0.status == .pending || $0.status == .assigned 
}.count

// Unread Alerts (from AppDataStore.emergencyAlerts)
let unreadAlerts = store.emergencyAlerts.filter { !$0.isAcknowledged }.count
```

These values are already kept live by the realtime channels from Phase 3 — no additional queries needed.

### Verify

- Open FM Dashboard → start a trip from driver side → Active Trips count increments in real time
- Complete a maintenance task → Vehicles In Maintenance count decrements

### Jira stories
FMS1-24, FMS1-19

---

## Task 13 — Analytics and Reports Wiring

### Files to modify

- `Sierra/FleetManager/Views/AnalyticsDashboardView.swift` (32 KB)
- `Sierra/FleetManager/Views/ReportsView.swift` (13 KB)
- `Sierra/FleetManager/Views/DriverHistoryView.swift` (verified functional — confirm only)

### AnalyticsDashboardView

Connect to real data via async fetch calls (one-time on appear, not realtime):

**Fleet usage (trips per vehicle, last 30 days):**
```swift
// In a ViewModel or .task block:
let trips = try await TripService().fetchCompleted(since: Date().addingTimeInterval(-30 * 86400))
let usageByVehicle = Dictionary(grouping: trips, by: \.vehicleId)
    .mapValues(\.count)
```

**Driver performance:**
```swift
let completedTrips = try await TripService().fetchCompleted(since: thirtyDaysAgo)
let tripsPerDriver = Dictionary(grouping: completedTrips, by: \.driverId).mapValues(\.count)
let deviationCounts = try await RouteDeviationService().fetchCountsPerDriver(since: thirtyDaysAgo)
```

**Maintenance history:**
```swift
let completedTasks = try await MaintenanceTaskService().fetchCompleted(since: thirtyDaysAgo)
// Group by vehicle_id for per-vehicle breakdown
```

If the above fetch methods don't exist in the services, add them as simple Supabase queries filtered by `completed_at > thirtyDaysAgo`.

### ReportsView

Wire existing chart/report UI to the same data sources. This view likely already has chart components — connect the data arrays. Reports are one-time fetch on appear, not realtime.

### DriverHistoryView

The Reality Check confirmed this is already functional. Just verify:
- It queries `trips WHERE driver_id = :id ORDER BY scheduled_date DESC`
- It displays the results correctly
- If the query uses a hardcoded driver ID placeholder, update it to use the selected driver's actual ID

### Jira stories
FMS1-20, FMS1-21, FMS1-10, FMS1-17

---

## Task 14 — Submission Artifacts

### 14a — Memory Profile Screenshot

Required by SRS section 5.3.

1. Run the app in Xcode on a physical device or simulator
2. Navigate through a full trip flow: Login → Start Trip → Navigate → End Trip → Post-Inspection
3. In Xcode: **Product → Profile → Leaks** (or use the Memory Graph Debugger)
4. Also run: **Debug → Memory Graph Debugger** during active navigation
5. Take a screenshot showing:
   - Zero leaked objects in the Leaks instrument, OR
   - The Memory Graph with no red leak indicators
6. Save as `Docs/MemoryProfile_Sprint2.png` and commit

**What to watch for:**
- `TripNavigationCoordinator` — check for retain cycles between the coordinator and `CLLocationManager` delegate (use `[weak self]` in all delegate callbacks)
- `RealtimeSubscriptionManager` — channels must not retain view references
- `AppDataStore` — should be a singleton; confirm no duplicate instances

### 14b — Flow Diagram

Required by SRS section 5.4.

The Figma FigJam board (`b77le46eYMiVfLuHcwMGdW`) already has a comprehensive flow diagram covering all three roles. For submission:

1. Export the FigJam flow diagram as a PDF or PNG from Figma (File → Export)
2. Rename to `Docs/Sierra_FlowDiagram_Sprint2.pdf`
3. Commit to the public docs repo

Alternatively, if an updated diagram is needed to reflect Sprint 2 additions:
- Add the Geofence flow (FM creates → vehicle enters/exits → driver notified)
- Add the Maintenance request flow (Driver raises → FM approves → Maintenance assigned → Completed → vehicle available)
- Add the SOS flow (Driver triggers → FM receives realtime alert → acknowledges)

### 14c — App Video Demo

Required by SRS section 5.2. Script:

1. **Fleet Manager login** → Dashboard with live stats
2. **Create a trip** — assign driver + vehicle, set schedule
3. **Driver login** → Accept trip → Pre-trip inspection (pass) → Start trip
4. **Navigation screen** → show Mapbox route active, location updating
5. **Proof of delivery** — OTP or photo
6. **Post-trip inspection** — raise a maintenance issue
7. **FM maintenance view** — approve the maintenance task
8. **Maintenance Personnel login** → see assigned task → update to In Progress → Complete
9. **FM Dashboard** — vehicle status back to Available in real time
10. **Geofence demo** — FM creates geofence → driver triggers entry → FM receives alert
11. **SOS demo** — Driver hits SOS → FM receives real-time alert

Record at 1080p, max 5 minutes.

---

## Final Submission Checklist

### Code Quality
- [ ] Zero `// TODO:` or `// FIXME:` comments in production paths
- [ ] No `print()` statements outside `#if DEBUG` blocks
- [ ] No SwiftUI layout constraint warnings in console during demo flow
- [ ] No memory leaks in Instruments Leaks run
- [ ] No `fatalError()` or force-unwraps (`!`) in service/ViewModel layer

### Security
- [ ] OTP never stored raw — only SHA-256 hash in DB
- [ ] `anon` role cannot call `check_resource_overlap` (verified in Supabase)
- [ ] All 24 tables have role-scoped RLS (not blanket public)
- [ ] No hardcoded credentials or API keys in codebase

### Architecture
- [ ] No manual vehicle or driver status updates from Swift — all via DB triggers
- [ ] No second `@Observable` store exists (StaffApplicationStore deleted)
- [ ] All photo uploads use sequential `for` loops, not `async let`
- [ ] `supabase` client accessed only via `SupabaseManager` singleton

### Features (SRS v2 Sprint 2 scope)
- [ ] Driver: Pre-trip inspection
- [ ] Driver: Start trip + Mapbox navigation
- [ ] Driver: Proof of delivery (OTP/photo)
- [ ] Driver: Post-trip inspection + maintenance request
- [ ] Driver: Fuel logging
- [ ] Driver: SOS alert
- [ ] Driver: Geofence notifications
- [ ] Fleet Manager: Live map (realtime vehicle locations)
- [ ] Fleet Manager: Geofence create/list/edit/delete
- [ ] Fleet Manager: Maintenance approval/rejection
- [ ] Fleet Manager: Vehicle reassignment on inspection fail
- [ ] Fleet Manager: Alerts inbox (SOS + deviation + geofence unified)
- [ ] Fleet Manager: Dashboard live stats
- [ ] Fleet Manager: Analytics + reports
- [ ] Maintenance: Task dashboard
- [ ] Maintenance: Task detail + update status
- [ ] Maintenance: Work order management
- [ ] All roles: In-app notification banners

### Submission files
- [ ] `Docs/MemoryProfile_Sprint2.png` — in repo
- [ ] `Docs/Sierra_FlowDiagram_Sprint2.pdf` — in repo
- [ ] App video demo recorded (1080p, ≤5 min)
- [ ] Codebase clean and committed on `main`

---

## Jira Stories Covered This Phase

FMS1-20 (fleet analytics), FMS1-21 (driver reports), FMS1-24 (dashboard stats), FMS1-10 (driver history), FMS1-17 (vehicle reports), Architecture compliance
