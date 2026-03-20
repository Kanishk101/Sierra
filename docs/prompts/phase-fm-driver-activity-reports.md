# Phase: Fleet Manager Driver Activity Reports

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-21 (In Progress)

## Problem
`AnalyticsDashboardView.swift` (32KB) exists. Its completeness is unknown.
Jira FMS1-21 is In Progress — driver-specific performance analytics may be
partial or missing.

## Audit First
Before writing any code, read `AnalyticsDashboardView.swift` in full and identify:
- Which sections are complete and connected to live data from AppDataStore.
- Which sections use hardcoded/mock data.
- Which sections are missing entirely (e.g. per-driver performance breakdown).

## Required Driver Activity Report content (FMS1-21)
1. Per-driver summary: trips completed, total distance, avg trip duration,
   on-time completion rate (actual end <= scheduled end date).
2. Deviation frequency per driver (count of routeDeviationEvents per driver).
3. Fuel efficiency per driver: total litres consumed, total km driven,
   km-per-litre ratio.
4. Sortable/filterable table: by driver name, total trips, distance, deviation count.

## Data Sources (all in AppDataStore)
- `trips` — filter by driverId, status == .completed
- `routeDeviationEvents` — filter by driverId (now loaded in loadAll)
- `fuelLogs` — filter by driverId
- `staff` — driver names

## Constraints
- Modify only `AnalyticsDashboardView.swift`.
- Do NOT remove or change any existing complete sections.
- Do NOT add SPM dependencies.
- @Observable pattern, no @Published.
- No hardcoded data — all values must derive from AppDataStore arrays.
