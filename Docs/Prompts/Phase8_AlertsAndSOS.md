# Phase 8 — Alerts & SOS Module

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Jira stories: FMS1-15, FMS1-12, FMS1-25, FMS1-43.
This phase covers: SOS/Defect alert raising (driver), alert receiving and acknowledgement (FM), route deviation alerts, overdue maintenance alerts, and the in-app notification centre for all roles.

## DRIVER SIDE

### Task 1 — SOSAlertSheet (Sierra/Driver/Views/SOSAlertSheet.swift)
A full-screen modal sheet (not a small bottom sheet — this is an emergency) shown when driver presses SOS in NavigationHUDOverlay.

Design: Red background. Large SOS icon.

Content:
  - Title "Emergency Alert"
  - Alert type picker: SOS / Accident / Breakdown / Medical / Defect
  - Description text field (optional, placeholder: "Describe the situation...")
  - Current GPS coordinates are captured automatically from CLLocationManager
  - Large "SEND ALERT" button
  - Cancel button at top

On send:
  - Calls EmergencyAlertService with the current trip_id, vehicle_id, driver_id, GPS coords, alert_type, description
  - Inserts notification for ALL fleet managers with type "SOS Alert" or "Defect Alert" depending on type
  - Inserts activity_log row of severity "Critical"
  - Shows confirmation "Alert Sent — Help is on the way"
  - Dismisses after 3 seconds

### Task 2 — IncidentReportSheet (Sierra/Driver/Views/IncidentReportSheet.swift)
Lighter than SOS. Triggered from "Report Incident" in NavigationHUDOverlay.
  - Incident type: Road Closure / Construction / Accident Ahead / Hazard / Other
  - Notes text field
  - Submit: inserts activity_log row only (not emergency_alert), type "Route Deviation" or appropriate type

## FLEET MANAGER SIDE

### Task 3 — AlertsInboxView (Sierra/FleetManager/Views/AlertsInboxView.swift)
The FM's live alert centre. Shown as a tab (bell icon, "Alerts") in FleetManagerTabView.

Sections:
  1. Active Emergency Alerts (SOS, Accident, Breakdown, Medical, Defect) — sorted by triggered_at DESC
     Each row: red badge, alert type icon, driver name, vehicle plate, "X minutes ago", GPS location as "near {address}" (reverse geocoded using Mapbox)
     
  2. Route Deviations (unacknowledged) — yellow badge
     Each row: deviation distance in metres, trip task_id, driver name, "X minutes ago"
     
  3. Overdue Maintenance — orange badge
     Each row: vehicle name, task title, how many days overdue

Tapping an emergency alert → AlertDetailView
Tapping a deviation → marks acknowledged, shows map pin of where deviation occurred

### Task 4 — AlertDetailView (Sierra/FleetManager/Views/AlertDetailView.swift)
Full detail for an emergency alert:
  - Map pin showing alert GPS location (MapKit MKMapView, small embedded map)
  - Driver info card
  - Vehicle info card
  - Alert type, description, time triggered
  - "Acknowledge" button: calls EmergencyAlertService.acknowledgeAlert(id:acknowledgedBy:), updates status to Acknowledged, sends notification back to driver "Your alert has been received"
  - "Create Maintenance Task" button (shown for Breakdown/Defect): pre-fills MaintenanceTask with source_alert_id
  - "Resolve" button: updates status to Resolved
  - "Call Driver" button: tel:// link with driver phone number

### Task 5 — NotificationCentreView (Sierra/Shared/Views/NotificationCentreView.swift)
Shared across all roles. A list view accessible from a bell icon in the top navigation bar.

  - Shows AppDataStore.notifications sorted by sent_at DESC
  - Unread notifications have a blue dot indicator
  - Each row shows: notification type icon, title, body, "X mins ago"
  - Tapping a notification: marks as read (NotificationService.markAsRead), navigates to entity_type/entity_id if set
  - "Mark all read" button in toolbar
  - Badge count on the tab bar bell icon = AppDataStore.unreadNotificationCount

### Task 6 — Overdue maintenance alert generation
In AppDataStore (or a scheduled check), add:
  func checkOverdueMaintenance() async
  - Queries maintenance_tasks where status = Pending AND due_date < now()
  - For each overdue task, checks if a "Maintenance Overdue" notification already exists for it (entity_id match)
  - If not, inserts a notification for all fleet managers

Call this method when the FM app launches and every time the app foregrounds (using .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))).

### Task 7 — Wire notification badge into all three tab views
Read FleetManagerTabView.swift, DriverTabView.swift, MaintenanceTabView.swift.
Add a bell icon button to the toolbar of each role's root navigation view that presents NotificationCentreView as a sheet.
Show a badge with unreadNotificationCount if > 0.

## Output
Create all files listed. Update FleetManagerTabView.swift to add Alerts tab. Update all three TabView files for notification bell. Commit all to main branch.
