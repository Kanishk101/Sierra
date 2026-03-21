# Phase 04 — Reports View: Full Redesign with Paginated Pages, Rich Cards, and Export

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **File to modify:** `Sierra/FleetManager/Views/ReportsView.swift`
- **SRS Reference:** §4.1.9 — System shall generate reports for driver performance, vehicle usage, and vehicle maintenance history
- **Data sources:** All in-memory from `AppDataStore` — no new Supabase calls on this screen

---

## Current State (Problems)

`ReportsView.swift` (16.6KB) has:
- A segmented picker for Fleet/Driver/Maintenance tabs
- A second segmented picker for date range
- Content rendered as `VStack` card stacks inside a `ScrollView`
- Basic stat numbers with minimal visual hierarchy
- Export button that only appears inline per-section

Problems:
1. The double-picker layout wastes space and looks dense
2. Cards are informational but generic — no visual differentiation, no icons, no trend indicators
3. Driver Activity section shows a flat picker + list — not engaging
4. No overall summary / KPI section visible first
5. Export feels like an afterthought (hidden in each section)

---

## Required Architecture: Paginated TabView with Page Control

Replace the segmented picker + ScrollView pattern with a **`TabView` with `.page` style** giving distinct, scrollable pages:

```swift
TabView(selection: $currentPage) {
    overviewPage        // Page 0: KPI overview + date range selector
    fleetUsagePage      // Page 1: Fleet stats
    driverActivityPage  // Page 2: Driver performance
    maintenancePage     // Page 3: Maintenance stats
    exportPage          // Page 4: Export controls
}
.tabViewStyle(.page)
.indexViewStyle(.page(backgroundDisplayMode: .always))  // shows the dot indicators
```

Keep total pages to **5** (including Export). Each page fills the screen with a single focused topic. The dot page control at the bottom tells the user where they are.

---

## Page Designs

### Page 0: Overview / KPI Summary
**Purpose:** Give the fleet manager a 30-second snapshot of fleet health.

Content layout:
```
[ Date Range Picker — segmented: 7 Days / 30 Days / 90 Days ]

[ KPI Row — 3 large stat cards ]
  Active Trips    Vehicles Online    Pending Tasks
     (count)          (count)           (count)

[ KPI Row — 3 large stat cards ]
  Completed Trips   Total Distance   Avg Trip Duration
  (in range count)    (km, range)      (hrs:min)

[ Quick health indicators ]
  [ Documents Expiring Soon: N  →  View ]
  [ Emergency Alerts Active:  N  →  View ]
  [ Overdue Maintenance:      N  →  View ]
```

Each KPI card style:
- Large bold number (font `.title` weight `.bold`)
- Label below in `.caption` `.secondary`
- Subtle background `Color(.secondarySystemGroupedBackground)` rounded 16pt
- Icon above the number using SF Symbol, tinted `.orange`

### Page 1: Fleet Usage
**Purpose:** Understand how vehicles are being used.

Content:
- Vehicle utilisation bar chart (Chart framework `BarMark`) — x: vehicle name, y: total trips in range
- Top 5 vehicles by distance table (name, plate, km, trip count)
- Fuel consumption summary: total litres logged, average price/litre, total spend (₹) for the range
- Status distribution: repeat the fleet donut chart from AnalyticsDashboardView but simplified (just counts, no interaction needed here)
- Export CSV button for Fleet data at the bottom of the page

### Page 2: Driver Activity
**Purpose:** Performance review per driver.

Content:
- Driver picker (`.menu` style Picker) with "All Drivers" + each driver by name
- When a specific driver is selected, show that driver's metrics:
  - Trips completed, distance, avg duration, on-time %, deviation count, fuel efficiency
  - A horizontal bar comparing their metrics to fleet average (simple progress-bar style)
  - Recent trip list (last 5 trips with status and route)
- When "All Drivers" selected, show the full driver table from `AnalyticsDashboardView.driverActivityRows` (already computed correctly)
- Rating display: `trip.driverRating: Int?` — show star rating if present, "Not rated" if nil
- Export CSV button for Driver data

### Page 3: Maintenance
**Purpose:** Understand maintenance patterns and costs.

Content:
- Summary row: Tasks created (range), completed, avg resolution time, overdue count
- Cost breakdown: total labour cost + total parts cost + grand total for maintenance in range
- Vehicle-by-vehicle maintenance history table: vehicle name, service count, total cost, last service date
- Urgency breakdown: count of tasks by priority (Low/Medium/High/Urgent) — simple horizontal stacked bar
- Export CSV button for Maintenance data

### Page 4: Export
**Purpose:** Dedicated export centre — one place to export any report type.

Content:
```
[ Section header: "Export Reports" ]

[ Date Range Picker ]

[ List of export options as rich rows ]
  ┌─────────────────────────────────────────┐
  │  📊  Trip Report         → Export CSV  │
  │      NN trips • NN km • 30 day range    │
  ├─────────────────────────────────────────┤
  │  ⛽  Fuel Log Report     → Export CSV  │
  │      NN logs • ₹NNN total spend         │
  ├─────────────────────────────────────────┤
  │  🔧  Maintenance Report  → Export CSV  │
  │      NN tasks • ₹NNN total cost         │
  ├─────────────────────────────────────────┤
  │  👤  Driver Activity     → Export CSV  │
  │      NN drivers • NN completed trips    │
  └─────────────────────────────────────────┘
```

Each row taps to trigger the `UIActivityViewController` with the CSV. Tapping "Export CSV" on a row shows a confirmation with the record count before exporting.

---

## Navigation Wiring

The existing toolbar share button (`.topBarTrailing`) should remain and open the Export page directly:
```swift
Button { currentPage = 4 } label: {
    Image(systemName: "square.and.arrow.up")
}
```

The existing CSV generators (`generateFleetCSV()`, `generateFuelCSV()`, `generateDriverCSV()`, `generateMaintenanceCSV()`) must be preserved exactly — they are correct. Only the presentation layer changes.

---

## Constraints
- `ReportsView.swift` only — no other files
- All data from `AppDataStore` in-memory. No new Supabase calls.
- Use `Charts` framework for any charts (already imported)
- `TabView(style: .page)` with dot indicators
- `@Observable` only, no `@Published`
- Do NOT remove `driverRating` references — `Trip.driverRating: Int?` exists in the model and DB
- Keep `navigationTitle("Reports")` and `.navigationBarTitleDisplayMode(.inline)`
- Page transitions should use default `.page` style (horizontal swipe) — no custom animations needed

## Verification Checklist
- [ ] 5 pages rendered via `TabView(.page)` with dot page indicators
- [ ] Page 0 KPI cards update when date range changes
- [ ] Page 2 driver picker correctly filters to the selected driver's metrics
- [ ] All 4 export functions produce correct CSV output via `UIActivityViewController`
- [ ] Export page shows correct record counts for each report type
- [ ] Build clean, zero Chart framework warnings
