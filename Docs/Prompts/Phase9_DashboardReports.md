# Phase 9 — Dashboard & Reports Module

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Jira stories: FMS1-8, FMS1-10, FMS1-17, FMS1-19, FMS1-20, FMS1-21, FMS1-24.
Existing files to read first: AnalyticsDashboardView.swift, DashboardHomeView.swift, StaffListView.swift, TripsListView.swift.

## Task 1 — Wire Real Data into DashboardHomeView
Read the current DashboardHomeView.swift. It likely has hardcoded/mock stats.
Replace all mock data with live queries from AppDataStore:

Dashboard summary cards:
  - Total Active Vehicles: AppDataStore.vehicles.filter { $0.status == .busy || $0.status == .active }.count
  - Active Trips: AppDataStore.trips.filter { $0.status == .active }.count
  - Pending Approvals: AppDataStore.staffApplications.filter { $0.status == .pending }.count + maintenance tasks pending
  - Overdue Maintenance: maintenance tasks where due_date < now() and status != completed
  - Available Drivers: AppDataStore.staffMembers.filter { $0.role == .driver && $0.availability == .available }.count

Recent Activity feed: show last 10 rows from AppDataStore.activityLogs (already loaded), formatted by activity type with appropriate icons and colors.

## Task 2 — Full AnalyticsDashboardView (Sierra/FleetManager/Views/AnalyticsDashboardView.swift)
Rebuild the analytics view with real data. Sections:

Section 1 — Fleet Usage (date range picker: Last 7 days / Last 30 days / Last 90 days)
  - Total trips completed in range
  - Total distance driven (km) — sum of (end_mileage - start_mileage) for completed trips in range
  - Average trip duration
  - Top 3 most used vehicles (by total_trips)

Section 2 — Driver Performance
  - List of all active drivers with: name, total trips, total distance, average rating (stars), availability status
  - Tap a driver → DriverHistoryView

Section 3 — Maintenance Summary
  - Total tasks this month: Completed / In Progress / Pending
  - Average resolution time (completed_at - created_at for completed tasks)
  - Total maintenance cost (sum of total_cost from maintenance_records in range)
  - Vehicles with upcoming service due (distance-based or date-based from vehicle docs expiry)

Section 4 — Vehicle Status Breakdown
  - Horizontal bar chart (built with SwiftUI GeometryReader bars, no external chart library):
    Active, Idle, In Maintenance, Out of Service counts

## Task 3 — DriverHistoryView (Sierra/FleetManager/Views/DriverHistoryView.swift)
The FM's view of a specific driver's history (FMS1-10):
  - Driver profile card: photo, name, phone, joined date, license info
  - Stats row: total trips, total distance, average rating
  - Trip history list: each completed trip with date, origin→destination, distance, duration, rating given
  - "Rate this driver" option on any completed unrated trip — star picker + note → calls TripService.rateDriver(...)
  - "Deactivate Driver" button: calls StaffMemberService to set status = Suspended (FMS1-8), sends notification to driver

## Task 4 — VehicleStatusView (Sierra/FleetManager/Views/VehicleStatusView.swift) (FMS1-19)
Dedicated view for vehicle status management:
  - Shows all vehicles grouped by status (Active/Idle/In Maintenance/Out of Service/Decommissioned)
  - Each vehicle card: plate, name, model, current odometer, last trip date, document expiry warnings
  - Color-coded status chips
  - Quick action buttons: Mark Out of Service, Mark Idle, View Documents
  - Tap → VehicleDetailView (already exists)

## Task 5 — ReportsView rebuild (Sierra/FleetManager/Views/ReportsView.swift) (FMS1-20, FMS1-21)
Replace stub with working reports:

Fleet Usage Report:
  - Date range picker
  - Generates a summary: trips count, total distance, fuel consumption (sum from fuel_logs), total expenses (sum from trip_expenses), number of incidents
  - Export button: formats data as CSV string and shares via UIActivityViewController

Driver Activity Report:
  - Driver picker
  - Shows: trips in range, distances, ratings, incidents raised, inspection pass rate
  - Export button: same CSV share mechanism

Maintenance Report:
  - Date range picker
  - Tasks by status, total cost, parts used list
  - Export button

## Task 6 — Driver History: Previous Trips (FMS1-79, driver side)
Add to DriverHomeView or DriverTabView: a "Trip History" tab showing the driver's completed trips.
List each trip: date, origin→destination, distance, duration, proof of delivery status.
Tapping shows a read-only TripDetailDriverView.

## Output
Update DashboardHomeView.swift, AnalyticsDashboardView.swift, ReportsView.swift.
Create DriverHistoryView.swift, VehicleStatusView.swift.
Update DriverTabView.swift to add trip history tab.
Commit all to main branch.
