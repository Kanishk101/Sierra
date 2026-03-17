# Phase 7 — Maintenance Workflow (Full Implementation)

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Maintenance views: Sierra/Maintenance/Views/, ViewModels: Sierra/Maintenance/ViewModels/ (create if not exists).
Fleet Manager maintenance views: Sierra/FleetManager/Views/.
Existing: MaintenanceDashboardView.swift (thin skeleton), MaintenanceTabView.swift.
Jira stories covered: FMS1-53 through FMS1-68, FMS1-13, FMS1-16.

## MAINTENANCE PERSONNEL SIDE

### Task 1 — MaintenanceDashboardViewModel (Sierra/Maintenance/ViewModels/MaintenanceDashboardViewModel.swift)
ObservableObject with:
  var assignedTasks: [MaintenanceTask] = []
  var filteredTasks: [MaintenanceTask] — filtered by selectedFilter
  var selectedFilter: TaskFilter = .all  // enum: all, pending, inProgress, completed
  var selectedVehicleFilter: UUID? = nil
  var isLoading: Bool = false
  var errorMessage: String? = nil

  func loadTasks(for staffId: UUID) async — fetches tasks where assigned_to_id = staffId
  func filterByStatus(_ filter: TaskFilter)
  func filterByVehicle(_ vehicleId: UUID?)

### Task 2 — Rewrite MaintenanceDashboardView (Sierra/Maintenance/Views/MaintenanceDashboardView.swift)
Full working dashboard showing:
  - Header with "My Tasks" title and task count badge
  - Filter bar: All / Pending / In Progress / Completed segmented control
  - Vehicle filter: horizontal scroll chips of unique vehicles across tasks
  - Task list: each row shows vehicle name+plate, task title, priority badge (color coded), status badge, due date, time since created
  - Pull to refresh
  - Empty state illustration when no tasks match filter
  - Tapping a task → MaintenanceTaskDetailView

### Task 3 — MaintenanceTaskDetailView (new, Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift)
Full detail view for a maintenance task:
  - Task title, description, priority, type, due date
  - Vehicle card: name, plate, model, VIN, current odometer
  - Vehicle history button → shows past maintenance records for this vehicle
  - Status timeline: visual stepper showing Pending → Assigned → In Progress → Completed
  - "Start Work" button (shown when status = Assigned): creates WorkOrder, updates task to In Progress, sets staff availability to On Task
  - "Create Work Order" sheet (embedded below if WO exists):
    - Repair description text editor
    - Estimated completion DatePicker
    - Parts used list (add part rows: name, part number, quantity, unit cost)
    - Spare parts request button: opens SparePartsRequestSheet
    - Repair image upload: PhotosPicker, uploads to "repair-images/{workOrderId}/" in Supabase Storage
    - Labour cost field
    - Technician notes field
    - "Mark Complete" button: updates work order to Completed, task to Completed, creates MaintenanceRecord, sends notification to fleet manager
  - Notify Admin buttons: "Repairs Started" and "Repairs Completed" — inserts notification rows for all fleet managers

### Task 4 — SparePartsRequestSheet (Sierra/Maintenance/Views/SparePartsRequestSheet.swift)
Sheet for requesting spare parts:
  - Part name, part number, quantity stepper, estimated cost, supplier, reason fields
  - Submit button: calls SparePartsRequestService.submitRequest(...)
  - Shows existing requests for this task with their current status

## FLEET MANAGER SIDE — MAINTENANCE

### Task 5 — MaintenanceRequestsView (Sierra/FleetManager/Views/MaintenanceRequestsView.swift)
List of all maintenance tasks for the FM to review:
  - Tabs: Pending Approval / Approved / Rejected / All
  - Each row: vehicle, task title, raised by (driver name), date, priority
  - Tapping → MaintenanceApprovalDetailView

### Task 6 — MaintenanceApprovalDetailView (Sierra/FleetManager/Views/MaintenanceApprovalDetailView.swift)
FM's view of a maintenance request:
  - Full task details
  - If source_alert_id: shows linked emergency alert
  - If source_inspection_id: shows linked inspection with photos
  - Staff picker: shows available maintenance personnel (availability = Available or Unavailable)
  - "Approve & Assign" button: calls MaintenanceTaskService.approveTask(...), sends notification to assigned maintenance person and to the driver who raised it
  - "Reject" button: text field for reason, calls MaintenanceTaskService.rejectTask(...), sends notification to driver
  - If already approved: shows work order status, estimated completion time, repair images

### Task 7 — Wire into FM navigation
Add MaintenanceRequestsView as a tab item in FleetManagerTabView with wrench icon labeled "Maintenance". Place it as the fourth tab.

## Output
Create all view and view model files. Update MaintenanceTabView.swift to route to new MaintenanceDashboardView. Update FleetManagerTabView.swift to add maintenance tab. Commit all to main branch.
