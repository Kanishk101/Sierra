# Sprint 2 — Phase 2: Fleet Manager Missing Flows

> **Prerequisite:** Phase 1 complete.  
> **This phase covers:** GeofenceListView + GeofenceViewModel, VehicleReassignmentSheet, AlertsViewModel

---

## Context

The Fleet Manager currently:
- ✅ Can create geofences (CreateGeofenceSheet works)
- ❌ Cannot see the list of existing geofences, cannot edit or delete them
- ❌ Has no UI to reassign a vehicle when a pre-trip inspection fails
- ⚠️ Alerts inbox (`AlertsInboxView`) fetches directly without a ViewModel — no realtime, no badge count

---

## Task 4 — GeofenceViewModel + GeofenceListView

### Files to create

- `Sierra/FleetManager/ViewModels/GeofenceViewModel.swift` ← CREATE
- `Sierra/FleetManager/Views/GeofenceListView.swift` ← CREATE

### File to verify/modify

- `Sierra/FleetManager/Views/CreateGeofenceSheet.swift` — verify it saves `radius` (circle geometry). The Figma spec is radius-based, not polygon.

---

### GeofenceViewModel.swift

```swift
@Observable
final class GeofenceViewModel {
    var geofences: [Geofence] = []
    var isLoading = false
    var error: String? = nil
    var showCreateSheet = false
    var selectedGeofence: Geofence? = nil   // for edit
    var deleteConfirmationTarget: Geofence? = nil

    private let service = GeofenceService()

    func loadGeofences() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            geofences = try await service.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleActive(_ geofence: Geofence) async {
        do {
            try await service.setActive(id: geofence.id, isActive: !geofence.isActive)
            await loadGeofences()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ geofence: Geofence) async {
        do {
            try await service.delete(id: geofence.id)
            geofences.removeAll { $0.id == geofence.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### GeofenceListView.swift

```
NavigationStack {
    List {
        ForEach(vm.geofences) { geofence in
            HStack {
                VStack(alignment: .leading) {
                    Text(geofence.name).font(.headline)
                    Text(geofence.type.rawValue + " · " + formatRadius(geofence.radius))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: .init(
                    get: { geofence.isActive },
                    set: { _ in Task { await vm.toggleActive(geofence) } }
                ))
                .labelsHidden()
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    vm.deleteConfirmationTarget = geofence
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    vm.selectedGeofence = geofence
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
    }
    .navigationTitle("Geofences")
    .toolbar {
        ToolbarItem(placement: .primaryAction) {
            Button { vm.showCreateSheet = true } label: {
                Image(systemName: "plus")
            }
        }
    }
    .task { await vm.loadGeofences() }
    .sheet(isPresented: $vm.showCreateSheet) {
        CreateGeofenceSheet()
            .onDisappear { Task { await vm.loadGeofences() } }
    }
    .sheet(item: $vm.selectedGeofence) { geofence in
        CreateGeofenceSheet(editing: geofence)   // pass existing for edit mode
            .onDisappear { Task { await vm.loadGeofences() } }
    }
    .confirmationDialog("Delete Geofence?", ...) {
        Button("Delete", role: .destructive) {
            if let g = vm.deleteConfirmationTarget {
                Task { await vm.delete(g) }
            }
        }
    }
}
```

### CreateGeofenceSheet — verify radius save

Open `CreateGeofenceSheet.swift`. Confirm the Supabase insert includes:
```swift
"radius_metres": .double(radiusValue),
"geofence_type": .string("circle"),
"center_latitude": .double(center.latitude),
"center_longitude": .double(center.longitude),
```
If it saves polygon geometry instead of radius, fix it to match the Figma spec (radius-based circle geofences).

### Wire GeofenceListView into FleetManagerTabView

Navigate to `GeofenceListView` from the Fleet Manager navigation, typically as a tab or a menu item in the dashboard. Check `FleetManagerTabView.swift` — add Geofences as a NavigationLink or tab item matching your existing pattern.

### Verify

- Create a geofence → it appears in the list immediately on sheet dismiss
- Toggle active/inactive → visual reflects change + Supabase `geofences.is_active` updates
- Swipe to delete → confirmation dialog → row removed + DB row deleted
- Inspect Supabase row: `radius_metres` must be set, `geofence_type = circle`

### Jira stories
FMS1-9, FMS1-14

---

## Task 5 — VehicleReassignmentSheet

### Context

When a driver's pre-trip inspection fails, an alert is created. The Fleet Manager sees it in the alerts inbox but currently has **no way to act on it** — there is no UI to reassign a vehicle to the trip. This is an explicit Sprint 2 Figma flow.

### Files to create

- `Sierra/FleetManager/Views/VehicleReassignmentSheet.swift` ← CREATE

### File to modify

- `Sierra/FleetManager/Views/AlertsInboxView.swift` or `AlertDetailView.swift` — present the sheet when alert type is `inspection_fail` / `Inspection Failed`
- `Sierra/Shared/Services/TripService.swift` — add `reassignVehicle(tripId:newVehicleId:)` if missing

---

### VehicleReassignmentSheet.swift

```swift
struct VehicleReassignmentSheet: View {
    let tripId: String
    let alertId: String
    @Environment(AppDataStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var selectedVehicleId: String? = nil
    @State private var isSubmitting = false
    @State private var error: String? = nil

    // Only show Available vehicles
    var availableVehicles: [Vehicle] {
        store.vehicles.filter { $0.status == .idle || $0.status == .active }
        // Use whatever "available for assignment" status value is in your Vehicle model
    }

    var body: some View {
        NavigationStack {
            List(availableVehicles) { vehicle in
                HStack {
                    VStack(alignment: .leading) {
                        Text(vehicle.make + " " + vehicle.model).font(.headline)
                        Text(vehicle.licensePlate).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedVehicleId == vehicle.id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedVehicleId = vehicle.id }
            }
            .navigationTitle("Reassign Vehicle")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        guard let vId = selectedVehicleId else { return }
                        Task { await reassign(vehicleId: vId) }
                    }
                    .disabled(selectedVehicleId == nil || isSubmitting)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private func reassign(vehicleId: String) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await TripService().reassignVehicle(tripId: tripId, newVehicleId: vehicleId)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### TripService — add reassignVehicle if missing

Check `TripService.swift`. If no `reassignVehicle` method exists, add:

```swift
func reassignVehicle(tripId: String, newVehicleId: String) async throws {
    try await supabase
        .from("trips")
        .update(["vehicle_id": newVehicleId])
        .eq("id", value: tripId)
        .execute()
}
```

Note: the DB trigger `trg_trip_started` will handle vehicle status transitions automatically when the trip is eventually started. You do not need to manually update vehicle status here.

### Wire into AlertDetailView

Find where the Fleet Manager views an individual alert. Add:

```swift
@State private var showReassignment = false

// In the view body, when alert.type == .inspectionFailed (or equivalent enum)
if alert.type == .inspectionFailed, let tripId = alert.tripId {
    Button("Reassign Vehicle") {
        showReassignment = true
    }
    .buttonStyle(.borderedProminent)
}

.sheet(isPresented: $showReassignment) {
    if let tripId = alert.tripId {
        VehicleReassignmentSheet(tripId: tripId, alertId: alert.id)
    }
}
```

### Verify

- Simulate a pre-trip inspection failure → alert appears in FM inbox
- Tap alert → "Reassign Vehicle" button visible
- Sheet shows only available vehicles
- Select a vehicle + Confirm → Supabase `trips.vehicle_id` updated → sheet dismisses

### Jira stories
FMS1-36 (pre-trip inspection fail reassignment)

---

## Task 6 — AlertsViewModel

### Context

`AlertsInboxView.swift` currently does direct fetches with local `@State`. There is no ViewModel. This means:
- No realtime updates (new alerts don't appear without a pull-to-refresh)
- No unread badge count for the tab icon
- Alert types (emergency, route deviation, geofence) are not unified

`AppDataStore` already has `emergencyAlerts`, `routeDeviationEvents`, and `geofenceEvents` properties populated by the existing realtime channels.

### File to create

`Sierra/FleetManager/ViewModels/AlertsViewModel.swift` ← CREATE

### File to modify

`Sierra/FleetManager/Views/AlertsInboxView.swift` — swap direct fetch for `AlertsViewModel`

---

### AlertsViewModel.swift

```swift
@Observable
final class AlertsViewModel {
    // Read from AppDataStore — no direct Supabase fetches in the VM
    var emergencyAlerts: [EmergencyAlert] = []
    var routeDeviations: [RouteDeviationEvent] = []
    var geofenceEvents: [GeofenceEvent] = []

    var selectedFilter: AlertFilter = .all
    var isLoading = false
    var error: String? = nil

    enum AlertFilter: String, CaseIterable {
        case all = "All"
        case sos = "SOS"
        case deviation = "Route Deviation"
        case geofence = "Geofence"
    }

    var unreadCount: Int {
        let unreadEmergency = emergencyAlerts.filter { !$0.isAcknowledged }.count
        // Add counts for deviations/geofence events that haven't been seen
        return unreadEmergency
    }

    var filteredAlerts: [any AlertItem] {
        // Merge and sort all three arrays by timestamp descending
        // Filter based on selectedFilter
        // Return as a unified list
        // Define an AlertItem protocol or use a wrapper enum
    }

    func load(from store: AppDataStore) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Initial fetch to populate AppDataStore if not already loaded
            // AppDataStore's realtime channels keep these live after initial load
            emergencyAlerts = try await EmergencyAlertService().fetchAll()
            routeDeviations = try await RouteDeviationService().fetchAll()
            geofenceEvents = try await GeofenceService().fetchEvents()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func acknowledge(_ alert: EmergencyAlert) async {
        do {
            try await EmergencyAlertService().acknowledge(id: alert.id)
            if let idx = emergencyAlerts.firstIndex(where: { $0.id == alert.id }) {
                emergencyAlerts[idx].isAcknowledged = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### AlertsInboxView.swift — refactor

1. Add `@State private var vm = AlertsViewModel()`
2. Replace `.task { directFetch() }` with `.task { await vm.load(from: store) }`
3. Replace the local arrays with `vm.emergencyAlerts`, `vm.routeDeviations`, `vm.geofenceEvents`
4. Add a segmented `Picker` at the top for `vm.selectedFilter`
5. Display `vm.filteredAlerts` in the list

### Wire tab badge

In `FleetManagerTabView.swift`, find the Alerts tab item and add:

```swift
.badge(alertsVM.unreadCount > 0 ? alertsVM.unreadCount : 0)
```

You'll need to make `alertsVM` accessible — either pass it as an environment object or store it in `AppDataStore`.

### Verify

- Open Alerts inbox → all three alert types appear in unified list
- Segmented filter works
- Trigger an SOS from driver → it appears in FM alerts without refresh
- Unread badge count increments on new SOS → decrements after acknowledgement

### Jira stories
FMS1-15, FMS1-45, FMS1-12, FMS1-14

---

## Phase 2 Completion Checklist

- [ ] Geofence list shows all geofences for FM
- [ ] Active/inactive toggle works and persists
- [ ] Geofence create sheet saves radius (not polygon)
- [ ] Delete geofence works with confirmation
- [ ] Vehicle reassignment sheet shows available vehicles
- [ ] Confirming reassignment updates `trips.vehicle_id` in Supabase
- [ ] AlertsViewModel created — no direct fetch in view
- [ ] All three alert types visible in unified inbox
- [ ] Unread badge visible on FM Alerts tab
