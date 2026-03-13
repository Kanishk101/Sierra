import Foundation

// MARK: - AppDataStore
// Central @Observable data store — single source of truth for the entire app.
// All service calls flow through here. Views and ViewModels never call services directly.

@MainActor @Observable
final class AppDataStore {

    static let shared = AppDataStore()

    // ─────────────────────────────────────────────────────────────
    // MARK: - 17 Data Arrays
    // ─────────────────────────────────────────────────────────────

    // Staff
    var staff: [StaffMember] = []
    var driverProfiles: [DriverProfile] = []
    var maintenanceProfiles: [MaintenanceProfile] = []
    var staffApplications: [StaffApplication] = []

    // Vehicles
    var vehicles: [Vehicle] = []
    var vehicleDocuments: [VehicleDocument] = []

    // Operations
    var trips: [Trip] = []
    var fuelLogs: [FuelLog] = []
    var vehicleInspections: [VehicleInspection] = []
    var proofOfDeliveries: [ProofOfDelivery] = []
    var emergencyAlerts: [EmergencyAlert] = []

    // Maintenance
    var maintenanceTasks: [MaintenanceTask] = []
    var workOrders: [WorkOrder] = []
    var maintenanceRecords: [MaintenanceRecord] = []
    var partsUsed: [PartUsed] = []

    // Geofencing
    var geofences: [Geofence] = []
    var geofenceEvents: [GeofenceEvent] = []

    // Audit
    var activityLogs: [ActivityLog] = []

    // ─────────────────────────────────────────────────────────────
    // MARK: - Loading State
    // ─────────────────────────────────────────────────────────────

    var isLoading: Bool = false
    var loadError: String? = nil

    private init() {}

    // ─────────────────────────────────────────────────────────────
    // MARK: - Initial Load
    // ─────────────────────────────────────────────────────────────

    /// Fetches core data needed for any role on first launch.
    /// Call from SierraApp or ContentView via `.task { await AppDataStore.shared.loadAll() }`.
    func loadAll() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let fetchedVehicles      = VehicleService.fetchAllVehicles()
            async let fetchedStaff         = StaffMemberService.fetchAllStaff()
            async let fetchedTrips         = TripService.fetchAllTrips()
            async let fetchedTasks         = MaintenanceTaskService.fetchAllTasks()
            async let fetchedGeofences     = GeofenceService.fetchAllGeofences()
            async let fetchedLogs          = ActivityLogService.fetchRecent(limit: 50)
            async let fetchedApplications  = StaffApplicationService.fetchAllApplications()
            async let fetchedDocuments     = VehicleDocumentService.fetchAllDocuments()
            async let fetchedWorkOrders    = WorkOrderService.fetchAllWorkOrders()
            async let fetchedAlerts        = EmergencyAlertService.fetchAllAlerts()

            (vehicles,
             staff,
             trips,
             maintenanceTasks,
             geofences,
             activityLogs,
             staffApplications,
             vehicleDocuments,
             workOrders,
             emergencyAlerts) = try await (
                fetchedVehicles,
                fetchedStaff,
                fetchedTrips,
                fetchedTasks,
                fetchedGeofences,
                fetchedLogs,
                fetchedApplications,
                fetchedDocuments,
                fetchedWorkOrders,
                fetchedAlerts
            )
        } catch {
            loadError = error.localizedDescription
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Role-Specific Load Methods
    // ─────────────────────────────────────────────────────────────

    /// Loads data specific to a logged-in driver. Call after login when role == .driver.
    func loadDriverData(driverId: UUID) async {
        do {
            async let fetchedTrips       = TripService.fetchTrips(driverId: driverId)
            async let fetchedFuelLogs    = FuelLogService.fetchFuelLogs(driverId: driverId)
            async let fetchedAlerts      = EmergencyAlertService.fetchAlerts(driverId: driverId)
            async let fetchedProfile     = DriverProfileService.fetchDriverProfile(staffMemberId: driverId)

            let (t, fl, ea, dp) = try await (fetchedTrips, fetchedFuelLogs, fetchedAlerts, fetchedProfile)
            trips         = t
            fuelLogs      = fl
            emergencyAlerts = ea
            driverProfiles  = [dp]
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Loads data specific to a maintenance technician. Call after login when role == .maintenancePersonnel.
    func loadMaintenanceData(staffId: UUID) async {
        do {
            async let fetchedTasks      = MaintenanceTaskService.fetchTasks(assignedToId: staffId)
            async let fetchedWorkOrders = WorkOrderService.fetchWorkOrders(assignedToId: staffId)
            async let fetchedProfile    = MaintenanceProfileService.fetchMaintenanceProfile(staffMemberId: staffId)
            async let fetchedRecords    = MaintenanceRecordService.fetchAllRecords()

            let (tasks, orders, profile, records) = try await (fetchedTasks, fetchedWorkOrders, fetchedProfile, fetchedRecords)
            maintenanceTasks     = tasks
            workOrders           = orders
            maintenanceProfiles  = [profile]
            maintenanceRecords   = records
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Loads everything. Call after login when role == .fleetManager.
    func loadAdminData() async {
        await loadAll()
        do {
            async let fetchedDriverProfiles = DriverProfileService.fetchAllDriverProfiles()
            async let fetchedMaintProfiles  = MaintenanceProfileService.fetchAllMaintenanceProfiles()
            async let fetchedRecords        = MaintenanceRecordService.fetchAllRecords()

            let (dp, mp, mr) = try await (fetchedDriverProfiles, fetchedMaintProfiles, fetchedRecords)
            driverProfiles      = dp
            maintenanceProfiles = mp
            maintenanceRecords  = mr
            // Note: fuelLogs, vehicleInspections, geofenceEvents, partsUsed are loaded on-demand
        } catch {
            loadError = error.localizedDescription
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - On-Demand Load Helpers
    // ─────────────────────────────────────────────────────────────

    /// Loads all fuel logs for a vehicle (lazy, call from fuel log view).
    func loadFuelLogs(for vehicleId: UUID) async throws {
        fuelLogs = try await FuelLogService.fetchFuelLogs(vehicleId: vehicleId)
    }

    /// Loads all inspections for a trip (lazy, call when a trip is selected).
    func loadInspections(for tripId: UUID) async throws {
        vehicleInspections = try await VehicleInspectionService.fetchInspections(tripId: tripId)
    }

    /// Loads geofence events for a vehicle (lazy, call from geofence history view).
    func loadGeofenceEvents(for vehicleId: UUID) async throws {
        geofenceEvents = try await GeofenceEventService.fetchEvents(vehicleId: vehicleId)
    }

    /// Loads parts used for a work order (lazy, call when work order detail is opened).
    func loadPartsUsed(for workOrderId: UUID) async throws {
        partsUsed = try await PartUsedService.fetchParts(workOrderId: workOrderId)
    }

    /// Loads all driver profiles (lazy, call from admin staff review screen).
    func loadDriverProfiles() async throws {
        driverProfiles = try await DriverProfileService.fetchAllDriverProfiles()
    }

    /// Loads all maintenance profiles (lazy, call from admin staff review screen).
    func loadMaintenanceProfiles() async throws {
        maintenanceProfiles = try await MaintenanceProfileService.fetchAllMaintenanceProfiles()
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Vehicles
    // ─────────────────────────────────────────────────────────────

    func addVehicle(_ vehicle: Vehicle) async throws {
        try await VehicleService.addVehicle(vehicle)
        vehicles.append(vehicle)
    }

    func updateVehicle(_ vehicle: Vehicle) async throws {
        try await VehicleService.updateVehicle(vehicle)
        if let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[idx] = vehicle
        }
    }

    func deleteVehicle(id: UUID) async throws {
        try await VehicleService.deleteVehicle(id: id)
        vehicles.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Vehicle Documents
    // ─────────────────────────────────────────────────────────────

    func addVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.addDocument(doc)
        vehicleDocuments.append(doc)
    }

    func updateVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.updateDocument(doc)
        if let idx = vehicleDocuments.firstIndex(where: { $0.id == doc.id }) {
            vehicleDocuments[idx] = doc
        }
    }

    func deleteVehicleDocument(id: UUID) async throws {
        try await VehicleDocumentService.deleteDocument(id: id)
        vehicleDocuments.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Staff Members
    // ─────────────────────────────────────────────────────────────

    func addStaffMember(_ member: StaffMember) async throws {
        try await StaffMemberService.addStaffMember(member)
        staff.append(member)
    }

    func updateStaffMember(_ member: StaffMember) async throws {
        try await StaffMemberService.updateStaffMember(member)
        if let idx = staff.firstIndex(where: { $0.id == member.id }) {
            staff[idx] = member
        }
    }

    func deleteStaffMember(id: UUID) async throws {
        try await StaffMemberService.deleteStaffMember(id: id)
        staff.removeAll { $0.id == id }
    }

    func approveStaff(id: UUID) async throws {
        guard var member = staff.first(where: { $0.id == id }) else { return }
        member.status     = .active
        member.isApproved = true
        try await StaffMemberService.updateStaffMember(member)
        if let idx = staff.firstIndex(where: { $0.id == id }) {
            staff[idx] = member
        }
    }

    func rejectStaff(id: UUID, reason: String) async throws {
        guard var member = staff.first(where: { $0.id == id }) else { return }
        member.status          = .suspended
        member.rejectionReason = reason
        try await StaffMemberService.updateStaffMember(member)
        if let idx = staff.firstIndex(where: { $0.id == id }) {
            staff[idx] = member
        }
    }

    func suspendStaff(id: UUID) async throws {
        guard var member = staff.first(where: { $0.id == id }) else { return }
        member.status = .suspended
        try await StaffMemberService.updateStaffMember(member)
        if let idx = staff.firstIndex(where: { $0.id == id }) {
            staff[idx] = member
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Driver Profiles
    // ─────────────────────────────────────────────────────────────

    func addDriverProfile(_ profile: DriverProfile) async throws {
        try await DriverProfileService.addDriverProfile(profile)
        driverProfiles.append(profile)
    }

    func updateDriverProfile(_ profile: DriverProfile) async throws {
        try await DriverProfileService.updateDriverProfile(profile)
        if let idx = driverProfiles.firstIndex(where: { $0.id == profile.id }) {
            driverProfiles[idx] = profile
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Maintenance Profiles
    // ─────────────────────────────────────────────────────────────

    func addMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await MaintenanceProfileService.addMaintenanceProfile(profile)
        maintenanceProfiles.append(profile)
    }

    func updateMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await MaintenanceProfileService.updateMaintenanceProfile(profile)
        if let idx = maintenanceProfiles.firstIndex(where: { $0.id == profile.id }) {
            maintenanceProfiles[idx] = profile
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Staff Applications
    // ─────────────────────────────────────────────────────────────

    func addStaffApplication(_ application: StaffApplication) async throws {
        try await StaffApplicationService.addApplication(application)
        staffApplications.insert(application, at: 0)
    }

    func approveApplication(id: UUID) async throws {
        guard var app = staffApplications.first(where: { $0.id == id }) else { return }
        app.status     = .approved
        app.reviewedAt = Date()
        try await StaffApplicationService.updateApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            staffApplications[idx] = app
        }
    }

    func rejectApplication(id: UUID, reason: String) async throws {
        guard var app = staffApplications.first(where: { $0.id == id }) else { return }
        app.status          = .rejected
        app.rejectionReason = reason
        app.reviewedAt      = Date()
        try await StaffApplicationService.updateApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            staffApplications[idx] = app
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Trips
    // ─────────────────────────────────────────────────────────────

    func addTrip(_ trip: Trip) async throws {
        try await TripService.addTrip(trip)
        trips.append(trip)
    }

    func updateTrip(_ trip: Trip) async throws {
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx] = trip
        }
    }

    func cancelTrip(id: UUID) async throws {
        guard var trip = trips.first(where: { $0.id == id }) else { return }
        trip.status = .cancelled
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == id }) {
            trips[idx] = trip
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fuel Logs
    // ─────────────────────────────────────────────────────────────

    func addFuelLog(_ log: FuelLog) async throws {
        try await FuelLogService.addFuelLog(log)
        fuelLogs.append(log)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Vehicle Inspections
    // ─────────────────────────────────────────────────────────────

    func addVehicleInspection(_ inspection: VehicleInspection) async throws {
        try await VehicleInspectionService.addInspection(inspection)
        vehicleInspections.append(inspection)
    }

    func updateVehicleInspection(_ inspection: VehicleInspection) async throws {
        try await VehicleInspectionService.updateInspection(inspection)
        if let idx = vehicleInspections.firstIndex(where: { $0.id == inspection.id }) {
            vehicleInspections[idx] = inspection
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Proof of Delivery
    // ─────────────────────────────────────────────────────────────

    func addProofOfDelivery(_ pod: ProofOfDelivery) async throws {
        try await ProofOfDeliveryService.addProofOfDelivery(pod)
        proofOfDeliveries.append(pod)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Emergency Alerts
    // ─────────────────────────────────────────────────────────────

    func addEmergencyAlert(_ alert: EmergencyAlert) async throws {
        try await EmergencyAlertService.addAlert(alert)
        emergencyAlerts.append(alert)
    }

    func acknowledgeAlert(id: UUID, byAdminId adminId: UUID) async throws {
        guard var alert = emergencyAlerts.first(where: { $0.id == id }) else { return }
        alert.status          = .acknowledged
        alert.acknowledgedBy  = adminId
        alert.acknowledgedAt  = Date()
        try await EmergencyAlertService.updateAlert(alert)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx] = alert
        }
    }

    func resolveAlert(id: UUID) async throws {
        guard var alert = emergencyAlerts.first(where: { $0.id == id }) else { return }
        alert.status     = .resolved
        alert.resolvedAt = Date()
        try await EmergencyAlertService.updateAlert(alert)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx] = alert
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Maintenance Tasks
    // ─────────────────────────────────────────────────────────────

    func addMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.addTask(task)
        maintenanceTasks.append(task)
    }

    func updateMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.updateTask(task)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == task.id }) {
            maintenanceTasks[idx] = task
        }
    }

    func cancelMaintenanceTask(id: UUID) async throws {
        guard var task = maintenanceTasks.first(where: { $0.id == id }) else { return }
        task.status = .cancelled
        try await MaintenanceTaskService.updateTask(task)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == id }) {
            maintenanceTasks[idx] = task
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Work Orders
    // ─────────────────────────────────────────────────────────────

    func addWorkOrder(_ order: WorkOrder) async throws {
        try await WorkOrderService.addWorkOrder(order)
        workOrders.append(order)
    }

    func updateWorkOrder(_ order: WorkOrder) async throws {
        try await WorkOrderService.updateWorkOrder(order)
        if let idx = workOrders.firstIndex(where: { $0.id == order.id }) {
            workOrders[idx] = order
        }
    }

    func closeWorkOrder(id: UUID) async throws {
        guard var order = workOrders.first(where: { $0.id == id }) else { return }
        order.status      = .closed
        order.completedAt = Date()
        try await WorkOrderService.updateWorkOrder(order)
        if let idx = workOrders.firstIndex(where: { $0.id == id }) {
            workOrders[idx] = order
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Parts Used
    // ─────────────────────────────────────────────────────────────

    func addPartUsed(_ part: PartUsed) async throws {
        try await PartUsedService.addPart(part)
        partsUsed.append(part)
    }

    func deletePartUsed(id: UUID) async throws {
        try await PartUsedService.deletePart(id: id)
        partsUsed.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Maintenance Records
    // ─────────────────────────────────────────────────────────────

    func addMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await MaintenanceRecordService.addRecord(record)
        maintenanceRecords.append(record)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Geofences
    // ─────────────────────────────────────────────────────────────

    func addGeofence(_ geofence: Geofence) async throws {
        try await GeofenceService.addGeofence(geofence)
        geofences.append(geofence)
    }

    func updateGeofence(_ geofence: Geofence) async throws {
        try await GeofenceService.updateGeofence(geofence)
        if let idx = geofences.firstIndex(where: { $0.id == geofence.id }) {
            geofences[idx] = geofence
        }
    }

    func deleteGeofence(id: UUID) async throws {
        try await GeofenceService.deleteGeofence(id: id)
        geofences.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Geofence Events
    // ─────────────────────────────────────────────────────────────

    func addGeofenceEvent(_ event: GeofenceEvent) async throws {
        try await GeofenceEventService.addEvent(event)
        geofenceEvents.append(event)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Activity Logs
    // ─────────────────────────────────────────────────────────────

    func addActivityLog(_ log: ActivityLog) async throws {
        try await ActivityLogService.addLog(log)
        activityLogs.insert(log, at: 0)
    }

    func markActivityAsRead(id: UUID) async throws {
        try await ActivityLogService.markAsRead(id: id)
        if let idx = activityLogs.firstIndex(where: { $0.id == id }) {
            activityLogs[idx].isRead = true
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Lookup Helpers (Pure Swift, synchronous)
    // ─────────────────────────────────────────────────────────────

    // MARK: Staff

    func staffMember(for id: UUID) -> StaffMember? {
        staff.first { $0.id == id }
    }

    /// Legacy string-based overload for backward compatibility with existing views.
    func staffMember(forId id: String) -> StaffMember? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return staffMember(for: uuid)
    }

    /// Legacy overload preserved to avoid breaking call sites.
    func staffMember(forIdString id: String) -> StaffMember? {
        staffMember(forId: id)
    }

    func driverProfile(for staffId: UUID) -> DriverProfile? {
        driverProfiles.first { $0.staffMemberId == staffId }
    }

    func maintenanceProfile(for staffId: UUID) -> MaintenanceProfile? {
        maintenanceProfiles.first { $0.staffMemberId == staffId }
    }

    /// Returns all active, available drivers not currently on an active or scheduled trip.
    func availableDrivers() -> [StaffMember] {
        let busyIds = Set(
            trips
                .filter { $0.status == .active || $0.status == .scheduled }
                .compactMap { $0.driverId }
        )
        return staff.filter { m in
            m.role         == .driver
            && m.status    == .active
            && m.availability == .available
            && !busyIds.contains(m.id)
        }
    }

    // MARK: Vehicles

    func vehicle(for id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    /// Legacy string-based overload.
    func vehicle(forId id: String) -> Vehicle? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return vehicle(for: uuid)
    }

    /// Legacy overload.
    func vehicle(forIdString id: String) -> Vehicle? {
        vehicle(forId: id)
    }

    /// Returns vehicles that are active or idle and not currently assigned to a driver.
    func availableVehicles() -> [Vehicle] {
        vehicles.filter { v in
            (v.status == .active || v.status == .idle) && v.assignedDriverId == nil
        }
    }

    func vehicleDocuments(for vehicleId: UUID) -> [VehicleDocument] {
        vehicleDocuments.filter { $0.vehicleId == vehicleId }
    }

    func documentsExpiringSoon(withinDays days: Int = 30) -> [VehicleDocument] {
        let cutoff = Date().addingTimeInterval(Double(days) * 86400)
        return vehicleDocuments.filter { $0.expiryDate <= cutoff && $0.expiryDate >= Date() }
    }

    // MARK: Trips

    func trips(for driverId: UUID) -> [Trip] {
        trips.filter { $0.driverId == driverId }
    }

    func trips(forVehicle vehicleId: UUID) -> [Trip] {
        trips.filter { $0.vehicleId == vehicleId }
    }

    func activeTrip(for driverId: UUID) -> Trip? {
        trips.first { $0.driverId == driverId && ($0.status == .active || $0.status == .scheduled) }
    }

    /// Legacy overload for views using String driver IDs.
    func activeTrip(forDriverId id: UUID) -> Trip? {
        activeTrip(for: id)
    }

    /// Legacy string-based overload.
    func activeTrip(forDriverId id: String) -> Trip? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return activeTrip(for: uuid)
    }

    func trip(forTaskId taskId: String) -> Trip? {
        trips.first { $0.taskId == taskId }
    }

    // MARK: Fuel Logs

    func fuelLogs(for driverId: UUID) -> [FuelLog] {
        fuelLogs.filter { $0.driverId == driverId }
    }

    func fuelLogs(forVehicleId vehicleId: UUID) -> [FuelLog] {
        fuelLogs.filter { $0.vehicleId == vehicleId }
    }

    // MARK: Inspections

    func inspections(for tripId: UUID) -> [VehicleInspection] {
        vehicleInspections.filter { $0.tripId == tripId }
    }

    func preInspection(for tripId: UUID) -> VehicleInspection? {
        vehicleInspections.first { $0.tripId == tripId && $0.type == .preTrip }
    }

    func postInspection(for tripId: UUID) -> VehicleInspection? {
        vehicleInspections.first { $0.tripId == tripId && $0.type == .postTrip }
    }

    // MARK: Proof of Delivery

    func proofOfDelivery(for tripId: UUID) -> ProofOfDelivery? {
        proofOfDeliveries.first { $0.tripId == tripId }
    }

    // MARK: Emergency Alerts

    func activeAlerts() -> [EmergencyAlert] {
        emergencyAlerts.filter { $0.status == .active }
    }

    func alerts(for driverId: UUID) -> [EmergencyAlert] {
        emergencyAlerts.filter { $0.driverId == driverId }
    }

    // MARK: Maintenance

    func maintenanceTasks(for vehicleId: UUID) -> [MaintenanceTask] {
        maintenanceTasks.filter { $0.vehicleId == vehicleId }
    }

    func maintenanceTasks(forAssignedId staffId: UUID) -> [MaintenanceTask] {
        maintenanceTasks.filter { $0.assignedToId == staffId }
    }

    func workOrder(for maintenanceTaskId: UUID) -> WorkOrder? {
        workOrders.first { $0.maintenanceTaskId == maintenanceTaskId }
    }

    func workOrders(for staffId: UUID) -> [WorkOrder] {
        workOrders.filter { $0.assignedToId == staffId }
    }

    func maintenanceRecords(for vehicleId: UUID) -> [MaintenanceRecord] {
        maintenanceRecords.filter { $0.vehicleId == vehicleId }
    }

    func partsUsed(for workOrderId: UUID) -> [PartUsed] {
        partsUsed.filter { $0.workOrderId == workOrderId }
    }

    // MARK: Geofencing

    func geofenceEvents(for vehicleId: UUID) -> [GeofenceEvent] {
        geofenceEvents.filter { $0.vehicleId == vehicleId }
    }

    func geofenceEvents(forGeofenceId geofenceId: UUID) -> [GeofenceEvent] {
        geofenceEvents.filter { $0.geofenceId == geofenceId }
    }

    func activeGeofences() -> [Geofence] {
        geofences.filter { $0.isActive }
    }

    // MARK: Activity Logs

    func recentActivityLogs(limit: Int = 20) -> [ActivityLog] {
        Array(activityLogs.prefix(limit))
    }

    func unreadActivityLogs() -> [ActivityLog] {
        activityLogs.filter { !$0.isRead }
    }

    // MARK: Applications

    func pendingApplications() -> [StaffApplication] {
        staffApplications.filter { $0.status == .pending }
    }

    func application(for staffMemberId: UUID) -> StaffApplication? {
        staffApplications.first { $0.staffMemberId == staffMemberId }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Business Logic Methods
    // ─────────────────────────────────────────────────────────────

    /// Assigns a vehicle and driver to a trip, updating all three entities atomically.
    /// - Sets trip.driverId and trip.vehicleId
    /// - Sets vehicle.assignedDriverId and vehicle.status → .active
    /// - Sets driver.availability → .onTrip
    /// - Appends an ActivityLog entry
    func assignVehicleToTrip(tripId: UUID, vehicleId: UUID, driverId: UUID) async throws {
        guard var trip    = trips.first(where: { $0.id == tripId }),
              var vehicle = vehicles.first(where: { $0.id == vehicleId }),
              var driver  = staff.first(where: { $0.id == driverId })
        else { return }

        trip.driverId            = driverId
        trip.vehicleId           = vehicleId
        vehicle.assignedDriverId = driverId
        vehicle.status           = .active
        driver.availability      = .onTrip

        try await TripService.updateTrip(trip)
        try await VehicleService.updateVehicle(vehicle)
        try await StaffMemberService.updateStaffMember(driver)

        if let idx = trips.firstIndex(where: { $0.id == tripId })       { trips[idx]    = trip }
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleId }) { vehicles[idx] = vehicle }
        if let idx = staff.firstIndex(where: { $0.id == driverId })     { staff[idx]    = driver }

        let log = ActivityLog(
            id: UUID(),
            type: .tripStarted,
            title: "Vehicle Assigned",
            description: "Vehicle \(vehicle.name) assigned to driver \(driver.name ?? "Unknown") for trip.",
            actorId: nil,
            entityType: "trip",
            entityId: tripId,
            severity: .info,
            isRead: false,
            timestamp: Date(),
            createdAt: Date()
        )
        try await addActivityLog(log)
    }

    /// Marks a trip as completed, releases the vehicle and driver, and increments driver stats.
    /// - Sets trip.status → .completed, trip.actualEndDate → now
    /// - Sets vehicle.status → .idle, vehicle.assignedDriverId → nil
    /// - Sets driver.availability → .available
    /// - Increments driverProfile.totalTripsCompleted
    /// - Appends an ActivityLog entry
    func completeTrip(tripId: UUID) async throws {
        guard var trip = trips.first(where: { $0.id == tripId }) else { return }

        let vehicleId = trip.vehicleId
        let driverId  = trip.driverId

        trip.status        = .completed
        trip.actualEndDate = Date()
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) { trips[idx] = trip }

        if let vid = vehicleId, var vehicle = vehicles.first(where: { $0.id == vid }) {
            vehicle.status           = .idle
            vehicle.assignedDriverId = nil
            try await VehicleService.updateVehicle(vehicle)
            if let idx = vehicles.firstIndex(where: { $0.id == vid }) { vehicles[idx] = vehicle }
        }

        if let did = driverId, var driver = staff.first(where: { $0.id == did }) {
            driver.availability = .available
            try await StaffMemberService.updateStaffMember(driver)
            if let idx = staff.firstIndex(where: { $0.id == did }) { staff[idx] = driver }

            // Increment driver profile trip count
            if var profile = driverProfiles.first(where: { $0.staffMemberId == did }) {
                profile.totalTripsCompleted += 1
                try await DriverProfileService.updateDriverProfile(profile)
                if let idx = driverProfiles.firstIndex(where: { $0.staffMemberId == did }) {
                    driverProfiles[idx] = profile
                }
            }
        }

        let driverName = driverId.flatMap { staffMember(for: $0)?.name } ?? "Unknown"
        let log = ActivityLog(
            id: UUID(),
            type: .tripCompleted,
            title: "Trip Completed",
            description: "Trip completed by \(driverName).",
            actorId: driverId,
            entityType: "trip",
            entityId: tripId,
            severity: .info,
            isRead: false,
            timestamp: Date(),
            createdAt: Date()
        )
        try await addActivityLog(log)
    }

    /// Approves a staff application, activates the staff member, and logs the action.
    func approveStaffApplication(applicationId: UUID) async throws {
        guard let app = staffApplications.first(where: { $0.id == applicationId }) else { return }

        try await approveApplication(id: applicationId)
        try await approveStaff(id: app.staffMemberId)

        let memberName = staffMember(for: app.staffMemberId)?.name ?? app.staffMemberId.uuidString
        let log = ActivityLog(
            id: UUID(),
            type: .staffApproved,
            title: "Application Approved",
            description: "\(memberName)'s application has been approved.",
            actorId: nil,
            entityType: "staff_application",
            entityId: applicationId,
            severity: .info,
            isRead: false,
            timestamp: Date(),
            createdAt: Date()
        )
        try await addActivityLog(log)
    }

    /// Rejects a staff application with a reason, updates the staff member record, and logs the action.
    func rejectStaffApplication(applicationId: UUID, reason: String) async throws {
        guard let app = staffApplications.first(where: { $0.id == applicationId }) else { return }

        try await rejectApplication(id: applicationId, reason: reason)
        try await rejectStaff(id: app.staffMemberId, reason: reason)

        let memberName = staffMember(for: app.staffMemberId)?.name ?? app.staffMemberId.uuidString
        let log = ActivityLog(
            id: UUID(),
            type: .staffRejected,
            title: "Application Rejected",
            description: "\(memberName)'s application was rejected. Reason: \(reason)",
            actorId: nil,
            entityType: "staff_application",
            entityId: applicationId,
            severity: .warning,
            isRead: false,
            timestamp: Date(),
            createdAt: Date()
        )
        try await addActivityLog(log)
    }
}
