# Phase: Fleet Manager Reports Export (Excel/CSV)

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-23

## Problem
`ReportsView.swift` (13KB) exists and renders in-app analytics/charts.
There is no export to Excel or CSV functionality — FMS1-23 is unimplemented.

## Scope
Add export capability to `ReportsView.swift`. No new files unless a dedicated
export ViewModel is warranted.

### Exports Required
1. **Trip Report** — columns: taskId, driverName, vehicleplate, origin, destination,
   scheduledDate, actualStartDate, actualEndDate, distanceKm, status, priority.
2. **Fuel Log Report** — columns: date, driverName, vehiclePlate, litres, cost, pricePerLitre,
   odometerAtFill, fuelStation.
3. **Maintenance Report** — columns: taskTitle, vehicleName, vehiclePlate, assignedTo,
   priority, status, dueDate, completedAt, labourCost, partsCost, totalCost.

### Implementation
- Use `UniformTypeIdentifiers` + `UIActivityViewController` for sharing.
- Generate CSV strings in Swift (no third-party library needed).
- Add an export toolbar button (share icon) to the ReportsView NavigationStack.
- Tapping it presents an action sheet: "Export Trips", "Export Fuel Logs",
  "Export Maintenance" — each generates the relevant CSV and triggers
  `UIActivityViewController`.
- Date formatting: ISO 8601 (`yyyy-MM-dd HH:mm`).
- Lookup driver/vehicle names from `AppDataStore.shared`.

## Constraints
- Only modify `ReportsView.swift`.
- Do NOT add SPM dependencies.
- Do NOT change existing charts/display in ReportsView.
- @Observable pattern, no @Published.
