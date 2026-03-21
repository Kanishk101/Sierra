# Phase 09 — Maintenance Dashboard: Frontend Improvements and Cross-Role Consistency

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `MaintenanceDashboardView.swift`, `MaintenanceTaskDetailView.swift`, `SparePartsRequestSheet.swift`
- **SRS Reference:** §4.3 — Maintenance Personnel: task management, activity tracking, VIN scanning, work order management, breakdown handling

---

## Audit of Current State

`MaintenanceDashboardView.swift` (31.6KB after Phase 02 additions) now has 4 tabs: Tasks, Work Orders, VIN Scanner, Profile. This is solid implementation. The issues are:

1. **Profile tab** is inconsistent with admin profile style — it's a plain `VStack` while admin uses a modal sheet. The profile tab itself is fine (it IS a tab), but the UI within it needs polishing.
2. **Tasks tab** filter bar was chip-based — Phase 03 addresses this.
3. **Work Orders tab** navigation link uses `UUID` for `MaintenanceTaskDetailView` — this could conflict if a `navigationDestination(for: UUID.self)` exists elsewhere in the stack.
4. **`MaintenanceTaskDetailView.swift`** (11.7KB) — needs verification that work order actions (Start, Update, Close) are wired to `AppDataStore` not direct service calls.
5. **`SparePartsRequestSheet.swift`** (5.9KB) — needs verification that submission calls `AppDataStore.addSparePartsRequest()` not direct service.

---

## Fix 1 — Profile Tab Visual Polish

The profile tab content looks plain. Apply these improvements to `profileTab` in `MaintenanceDashboardView.swift`:

- Add a gradient header background (matching the admin's `DashboardHomeView` header feel) behind the avatar circle
- Show certification type and expiry date from `store.maintenanceProfile(for: currentUserId)` if available:
  ```swift
  if let profile = store.maintenanceProfile(for: currentUserId) {
      infoRow("Certification", profile.certificationType)
      infoRow("Cert Expiry", profile.certificationExpiry.formatted(.dateTime.day().month(.abbreviated).year()))
      infoRow("Experience", "\(profile.yearsOfExperience) years")
      if !profile.specializations.isEmpty {
          Text(profile.specializations.joined(separator: ", "))
              .font(.caption)
              .foregroundStyle(.secondary)
      }
  }
  ```
- Show tasks completed count: `store.workOrders.filter { $0.assignedToId == currentUserId && $0.status == .closed }.count`
- Show notification bell button in the profile tab toolbar (matching Tasks tab)

---

## Fix 2 — Work Orders Tab Navigation

The Work Orders tab uses `NavigationLink(value: wo.maintenanceTaskId)` which relies on the outer `NavigationStack`'s `.navigationDestination(for: UUID.self)`. Since `MaintenanceDashboardView` is a `TabView` (not a NavigationStack directly), the destination needs to be declared **per NavigationStack** (each tab wraps its own `NavigationStack`).

Verify that the Work Orders tab's `NavigationStack` has:
```swift
.navigationDestination(for: UUID.self) { taskId in
    if let task = store.maintenanceTasks.first(where: { $0.id == taskId }) {
        MaintenanceTaskDetailView(task: task)
    }
}
```

If `MaintenanceDashboardView` currently has a single `.navigationDestination` at the `TabView` level, it won't work. Each `NavigationStack` (one per tab) needs its own destination. Verify and fix.

---

## Fix 3 — `MaintenanceTaskDetailView` — Verify AppDataStore Wiring

Open `Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift` and audit:
- Work order status update (Start/In Progress/On Hold/Complete): Must call `store.updateWorkOrder(_:)`, not `WorkOrderService.updateWorkOrder(_:)` directly
- Closing a work order: Must call `store.closeWorkOrder(id:)` which updates both DB and in-memory array
- Parts used: Adding a part must call `store.addPartUsed(_:)` which updates `partsUsed` array AND recalculates `workOrders[idx].partsCostTotal`
- Spare parts request submission: Must call `store.addSparePartsRequest(_:)` not `SparePartsRequestService.submitRequest` directly

For each case that calls the service directly, replace with the AppDataStore method.

---

## Fix 4 — `SparePartsRequestSheet` — Verify AppDataStore Wiring

Open `Sierra/Maintenance/Views/SparePartsRequestSheet.swift` and check the submit action. It should use:
```swift
try await store.addSparePartsRequest(SparePartsRequest(
    id: UUID(),
    maintenanceTaskId: taskId,
    workOrderId: workOrder?.id,   // nil is fine — see Phase 01 Bug 1 fix
    requestedById: currentUserId,
    ...
))
```

If it calls `SparePartsRequestService.submitRequest(...)` directly, replace with `store.addSparePartsRequest(_:)`.

---

## Fix 5 — VIN Scanner Tab: Handle Permission Denial Gracefully

The current `ScannerViewController` in `MaintenanceDashboardView.swift` shows "Camera not available" if the device has no camera. But it does not handle the case where camera **permission is denied** (user previously denied access).

Add a permission check before starting the session:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        setupCamera()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted { self?.setupCamera() }
                else { self?.showPermissionDeniedUI() }
            }
        }
    case .denied, .restricted:
        showPermissionDeniedUI()
    @unknown default:
        showPermissionDeniedUI()
    }
}

private func showPermissionDeniedUI() {
    let label = UILabel()
    label.text = "Camera access denied.\nGo to Settings > Sierra to enable camera access."
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = UIColor.systemBackground
    view.addSubview(label)
    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
    
    let settingsButton = UIButton(type: .system)
    settingsButton.setTitle("Open Settings", for: .normal)
    settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(settingsButton)
    NSLayoutConstraint.activate([
        settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        settingsButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20)
    ])
}

@objc private func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

---

## Fix 6 — Cross-Role UI Consistency Checklist

Verify that these elements are visually consistent across all three dashboards (Admin, Driver, Maintenance):

| Element | Admin | Driver | Maintenance |
|---|---|---|---|
| Notification bell | ✅ toolbar top-right | Add (Phase 08) | ✅ Tasks tab toolbar |
| Profile access | Header button / sheet | Header button (Phase 08) | Profile tab |
| Colour accent | Orange | Orange | Orange |
| Tab bar tint | Orange | Orange | Orange |
| Loading states | `isLoading` spinner | — | ✅ in Tasks tab |
| Pull-to-refresh | ✅ various views | ✅ DriverTripsListView | ✅ Work Orders tab |
| Empty states | ✅ `ContentUnavailableView` | ✅ | ✅ |

For any cell showing `—` in the table, implement the missing element.

---

## Constraints
- `@Observable` only, no `@Published`
- Do not change the 4-tab structure of `MaintenanceDashboardView` (Tasks, Work Orders, VIN Scanner, Profile)
- Do not change `MaintenanceProfileEditView` — already correct from the previous commit
- All AppDataStore wiring must use existing methods — no new AppDataStore methods needed for this phase

## Verification Checklist
- [ ] Profile tab shows certification info, tasks completed count
- [ ] Work Orders tab `navigationDestination` is scoped to its own `NavigationStack`
- [ ] Starting/updating/closing work orders updates `store.workOrders` array in-memory
- [ ] Adding parts updates `store.partsUsed` and recalculates `partsCostTotal`
- [ ] `SparePartsRequestSheet` uses `store.addSparePartsRequest(_:)` 
- [ ] VIN Scanner shows permission-denied UI with Settings link when camera access denied
- [ ] Notification bell present on all 3 role dashboards
- [ ] Orange tint consistent across all views
- [ ] Build clean, zero warnings
