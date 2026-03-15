# Fix 1 — AppDataStore: Load Own Staff Row in Driver/Maintenance Sessions

## File
`Sierra/Shared/Services/AppDataStore.swift`

## Problem
`loadDriverData()` and `loadMaintenanceData()` never populate `store.staff`.
`DriverProfileViewModel.submitProfile()` and `MaintenanceProfileViewModel.submitProfile()` both do:
```swift
if var member = AppDataStore.shared.staffMember(for: user.id) { ... }
```
`staffMember(for:)` searches `store.staff`. Since `store.staff` is empty for driver/maintenance
sessions, this lookup always returns `nil`. The member's name, phone, gender, address, etc.
never get written back to `staff_members` after onboarding. The personal details land only
in `staff_applications`, not in the `staff_members` row.

## Fix

Add a `StaffMemberService.fetchStaffMember(id:)` call inside both load methods,
populating a single-element `staff` array with the current user's own row.

### `loadDriverData(driverId:)` — updated

```swift
func loadDriverData(driverId: UUID) async {
    isLoading = true
    do {
        async let selfMemberTask = StaffMemberService.fetchStaffMember(id: driverId)
        async let vehiclesTask   = VehicleService.fetchAllVehicles()
        async let tripsTask      = TripService.fetchTrips(driverId: driverId)
        async let fuelLogsTask   = FuelLogService.fetchFuelLogs(driverId: driverId)
        async let inspectionsTask = VehicleInspectionService.fetchAllInspections()
        async let driverProfTask  = DriverProfileService.fetchDriverProfile(staffMemberId: driverId)

        if let selfMember = try await selfMemberTask {
            staff = [selfMember]   // single-element — own row only
        }
        vehicles           = try await vehiclesTask
        trips              = try await tripsTask
        fuelLogs           = try await fuelLogsTask
        vehicleInspections = try await inspectionsTask
        if let prof = try await driverProfTask {
            driverProfiles = [prof]
        }
    } catch {
        loadError = error.localizedDescription
        print("[AppDataStore.loadDriverData] Error: \(error)")
    }
    isLoading = false
}
```

### `loadMaintenanceData(staffId:)` — updated

```swift
func loadMaintenanceData(staffId: UUID) async {
    isLoading = true
    do {
        async let selfMemberTask = StaffMemberService.fetchStaffMember(id: staffId)
        async let vehiclesTask   = VehicleService.fetchAllVehicles()
        async let workOrdersTask = WorkOrderService.fetchWorkOrders(assignedToId: staffId)
        async let maintTasksTask = MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
        async let maintRecsTask  = MaintenanceRecordService.fetchMaintenanceRecords(performedById: staffId)
        async let partsTask      = PartUsedService.fetchAllPartsUsed()
        async let maintProfTask  = MaintenanceProfileService.fetchMaintenanceProfile(staffMemberId: staffId)

        if let selfMember = try await selfMemberTask {
            staff = [selfMember]   // single-element — own row only
        }
        vehicles           = try await vehiclesTask
        workOrders         = try await workOrdersTask
        maintenanceTasks   = try await maintTasksTask
        maintenanceRecords = try await maintRecsTask
        partsUsed          = try await partsTask
        if let prof = try await maintProfTask {
            maintenanceProfiles = [prof]
        }
    } catch {
        loadError = error.localizedDescription
        print("[AppDataStore.loadMaintenanceData] Error: \(error)")
    }
    isLoading = false
}
```

## Why this is the right fix
`staffMember(for:)` is the only lookup used inside onboarding submit to get the current
member's row before patching it. Loading just the one row is cheap and targeted.
`store.staff` is intentionally a single-element array in driver/maintenance sessions
— it's not a full staff roster, just the minimum needed for self-patching.
