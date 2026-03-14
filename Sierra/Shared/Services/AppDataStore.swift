import Foundation
import Supabase

// MARK: - AppDataStore
// Central @Observable data store — single source of truth for the entire app.
// All service calls flow through here. Views and ViewModels never call services directly.


@MainActor
@Observable
final class AppDataStore {

    static let shared = AppDataStore()

    private init() {
        subscribeToEmergencyAlerts()
    }


    // MARK: - Realtime

    private var emergencyAlertsChannel: RealtimeChannelV2?

    // ─────────────────────────────────────────────────────────────
    // MARK: - 17 Data Arrays
    // ─────────────────────────────────────────────────────────────

    // MARK: Staff
    var staff: [StaffMember] = []
    var driverProfiles: [DriverProfile] = []
    var maintenanceProfiles: [MaintenanceProfile] = []
    var staffApplications: [StaffApplication] = []

    // MARK: Vehicles
    var vehicles: [Vehicle] = []
    var vehicleDocuments: [VehicleDocument] = []

    // MARK: Operations
    var trips: [Trip] = []
    var fuelLogs: [FuelLog] = []
    var vehicleInspections: [VehicleInspection] = []
    var proofOfDeliveries: [ProofOfDelivery] = []
    var emergencyAlerts: [EmergencyAlert] = []

    // MARK: Maintenance
    var maintenanceTasks: [MaintenanceTask] = []
    var workOrders: [WorkOrder] = []
    var maintenanceRecords: [MaintenanceRecord] = []
    var partsUsed: [PartUsed] = []

    // MARK: Geofencing
    var geofences: [Geofence] = []
    var geofenceEvents: [GeofenceEvent] = []

    // MARK: Audit
    var activityLogs: [ActivityLog] = []

    // MARK: UI State
    var isLoading: Bool = false
    var loadError: String?

    // ─────────────────────────────────────────────────────────────
    // MARK: - Load Methods
    // ─────────────────────────────────────────────────────────────

    /// Full admin load — all 18 tables in parallel.
    func loadAll() async {
        isLoading = true
        loadError = nil
        do {
            async let staffTask        = StaffMemberService.fetchAllStaffMembers()
            async let driverProfsTask  = DriverProfileService.fetchAllDriverProfiles()
            async let maintProfsTask   = MaintenanceProfileService.fetchAllMaintenanceProfiles()
            async let appsTask         = StaffApplicationService.fetchAllStaffApplications()
            async let vehiclesTask     = VehicleService.fetchAllVehicles()
            async let vehicleDocsTask  = VehicleDocumentService.fetchAllVehicleDocuments()
            async let tripsTask        = TripService.fetchAllTrips()
            async let fuelLogsTask     = FuelLogService.fetchAllFuelLogs()
            async let inspectionsTask  = VehicleInspectionService.fetchAllInspections()
            async let podsTask         = ProofOfDeliveryService.fetchAllProofsOfDelivery()
            async let alertsTask       = EmergencyAlertService.fetchAllEmergencyAlerts()
            async let maintTasksTask   = MaintenanceTaskService.fetchAllMaintenanceTasks()
            async let workOrdersTask   = WorkOrderService.fetchAllWorkOrders()
            async let maintRecsTask    = MaintenanceRecordService.fetchAllMaintenanceRecords()
            async let partsTask        = PartUsedService.fetchAllPartsUsed()
            async let geofencesTask    = GeofenceService.fetchAllGeofences()
            async let geoEventsTask    = GeofenceEventService.fetchAllGeofenceEvents()
            async let activityTask     = ActivityLogService.fetchRecentLogs(limit: 100)

            staff               = try await staffTask
            driverProfiles      = try await driverProfsTask
            maintenanceProfiles = try await maintProfsTask
            staffApplications   = try await appsTask
            vehicles            = try await vehiclesTask
            vehicleDocuments    = try await vehicleDocsTask
            trips               = try await tripsTask
            fuelLogs            = try await fuelLogsTask
            vehicleInspections  = try await inspectionsTask
            proofOfDeliveries   = try await podsTask
            emergencyAlerts     = try await alertsTask
            maintenanceTasks    = try await maintTasksTask
            workOrders          = try await workOrdersTask
            maintenanceRecords  = try await maintRecsTask
            partsUsed           = try await partsTask
            geofences           = try await geofencesTask
            geofenceEvents      = try await geoEventsTask
            activityLogs        = try await activityTask
        } catch {
            loadError = error.localizedDescription
            print("[AppDataStore.loadAll] Error: \(error)")
        }
        isLoading = false
    }

    /// Driver-specific load — only data relevant to a single driver.
    func loadDriverData(driverId: UUID) async {
        isLoading = true
        do {
            async let vehiclesTask     = VehicleService.fetchAllVehicles()
            async let tripsTask        = TripService.fetchTrips(driverId: driverId)
            async let fuelLogsTask     = FuelLogService.fetchFuelLogs(driverId: driverId)
            async let inspectionsTask  = VehicleInspectionService.fetchAllInspections()
            async let driverProfTask   = DriverProfileService.fetchDriverProfile(staffMemberId: driverId)

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

    /// Maintenance-personnel-specific load.
    func loadMaintenanceData(staffId: UUID) async {
        isLoading = true
        do {
            async let vehiclesTask   = VehicleService.fetchAllVehicles()
            async let workOrdersTask = WorkOrderService.fetchWorkOrders(assignedToId: staffId)
            async let maintTasksTask = MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
            async let maintRecsTask  = MaintenanceRecordService.fetchMaintenanceRecords(performedById: staffId)
            async let partsTask      = PartUsedService.fetchAllPartsUsed()
            async let maintProfTask  = MaintenanceProfileService.fetchMaintenanceProfile(staffMemberId: staffId)

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

    // ─────────────────────────────────────────────────────────────
    // MARK: - Staff CRUD
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
        staff.removeAll                { $0.id == id }
        driverProfiles.removeAll       { $0.staffMemberId == id }
        maintenanceProfiles.removeAll  { $0.staffMemberId == id }
        staffApplications.removeAll    { $0.staffMemberId == id }
    }

    // MARK: Driver Profile

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

    // MARK: Maintenance Profile

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
    // MARK: - Staff Applications CRUD
    // ─────────────────────────────────────────────────────────────

    func addStaffApplication(_ app: StaffApplication) async throws {
        try await StaffApplicationService.addStaffApplication(app)
        staffApplications.insert(app, at: 0)
    }

    func updateStaffApplication(_ app: StaffApplication) async throws {
        try await StaffApplicationService.updateStaffApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == app.id }) {
            staffApplications[idx] = app
        }
    }

    func approveStaffApplication(id: UUID, reviewedBy adminId: UUID) async throws {
        guard let idx = staffApplications.firstIndex(where: { $0.id == id }) else { return }
        var app = staffApplications[idx]
        app.status          = .approved
        app.rejectionReason = nil
        app.reviewedBy      = adminId
        app.reviewedAt      = Date()
        try await StaffApplicationService.updateStaffApplication(app)
        staffApplications[idx] = app

        try await AuthUserService.setApprovalStatus(
            id: app.staffMemberId,
            approved: true,
            rejectionReason: nil
        )
        if let staffIdx = staff.firstIndex(where: { $0.id == app.staffMemberId }) {
            staff[staffIdx].isApproved = true
        }
    }

    func rejectStaffApplication(id: UUID, reason: String, reviewedBy adminId: UUID) async throws {
        guard let idx = staffApplications.firstIndex(where: { $0.id == id }) else { return }
        var app = staffApplications[idx]
        app.status          = .rejected
        app.rejectionReason = reason
        app.reviewedBy      = adminId
        app.reviewedAt      = Date()
        try await StaffApplicationService.updateStaffApplication(app)
        staffApplications[idx] = app

        try await AuthUserService.setApprovalStatus(
            id: app.staffMemberId,
            approved: false,
            rejectionReason: reason
        )
        if let staffIdx = staff.firstIndex(where: { $0.id == app.staffMemberId }) {
            staff[staffIdx].isApproved      = false
            staff[staffIdx].rejectionReason = reason
        }
    }

    var pendingApplicationsCount: Int {
        staffApplications.filter { $0.status == .pending }.count
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Vehicle CRUD
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
        vehicles.removeAll        { $0.id == id }
        vehicleDocuments.removeAll { $0.vehicleId == id }
    }

    func assignVehicleToDriver(vehicleId: UUID, driverId: UUID?) async throws {
        try await VehicleService.assignDriver(vehicleId: vehicleId, driverId: driverId)
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            vehicles[idx].assignedDriverId = driverId?.uuidString
        }
    }

    // MARK: Vehicle Documents

    func addVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.addVehicleDocument(doc)
        vehicleDocuments.append(doc)
    }

    func updateVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.updateVehicleDocument(doc)
        if let idx = vehicleDocuments.firstIndex(where: { $0.id == doc.id }) {
            vehicleDocuments[idx] = doc
        }
    }

    func deleteVehicleDocument(id: UUID) async throws {
        try await VehicleDocumentService.deleteVehicleDocument(id: id)
        vehicleDocuments.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Trip CRUD
    // ─────────────────────────────────────────────────────────────

    func addTrip(_ trip: Trip) async throws {
        try await TripService.addTrip(trip)
        trips.insert(trip, at: 0)
    }

    func updateTrip(_ trip: Trip) async throws {
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx] = trip
        }
    }

    func updateTripStatus(id: UUID, status: TripStatus) async throws {
        try await TripService.updateTripStatus(id: id, status: status)
        if let idx = trips.firstIndex(where: { $0.id == id }) {
            trips[idx].status = status
            if status == .active {
                trips[idx].actualStartDate = Date()
            } else if status == .completed {
                trips[idx].actualEndDate = Date()
            }
        }
    }

    func deleteTrip(id: UUID) async throws {
        try await TripService.deleteTrip(id: id)
        trips.removeAll { $0.id == id }
    }

    func completeTrip(id: UUID, endMileage: Double) async throws {
        guard let idx = trips.firstIndex(where: { $0.id == id }) else { return }
        var trip = trips[idx]
        trip.status       = .completed
        trip.actualEndDate = Date()
        trip.endMileage   = endMileage
        try await TripService.updateTrip(trip)
        trips[idx] = trip

        // Update vehicle odometer and trip count
        if let vehicleIdStr = trip.vehicleId,
           let vehicleId    = UUID(uuidString: vehicleIdStr),
           let vIdx         = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            vehicles[vIdx].odometer   = endMileage
            vehicles[vIdx].totalTrips += 1
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fuel Logs
    // ─────────────────────────────────────────────────────────────

    func addFuelLog(_ log: FuelLog) async throws {
        try await FuelLogService.addFuelLog(log)
        fuelLogs.insert(log, at: 0)
    }

    func deleteFuelLog(id: UUID) async throws {
        try await FuelLogService.deleteFuelLog(id: id)
        fuelLogs.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Vehicle Inspections
    // ─────────────────────────────────────────────────────────────

    func addVehicleInspection(_ inspection: VehicleInspection) async throws {
        try await VehicleInspectionService.addInspection(inspection)
        vehicleInspections.append(inspection)

        // Link inspection to trip
        let tripId = inspection.tripId
        if let tripIdx = trips.firstIndex(where: { $0.id == tripId }) {
            if inspection.type == .preTripInspection {
                trips[tripIdx].preInspectionId  = inspection.id
            } else {
                trips[tripIdx].postInspectionId = inspection.id
            }
            try await TripService.updateTrip(trips[tripIdx])
        }

        // If failed, put vehicle in maintenance
        if inspection.overallResult == .failed {
            if let vIdx = vehicles.firstIndex(where: { $0.id == inspection.vehicleId }) {
                vehicles[vIdx].status = .inMaintenance
                try? await VehicleService.updateVehicle(vehicles[vIdx])
            }
        }
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
        // Link POD to the trip
        if let tripIdx = trips.firstIndex(where: { $0.id == pod.tripId }) {
            trips[tripIdx].proofOfDeliveryId = pod.id
            try await TripService.updateTrip(trips[tripIdx])
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Emergency Alerts
    // ─────────────────────────────────────────────────────────────

    func addEmergencyAlert(_ alert: EmergencyAlert) async throws {
        try await EmergencyAlertService.addEmergencyAlert(alert)
        emergencyAlerts.insert(alert, at: 0)
    }

    func acknowledgeAlert(id: UUID, acknowledgedBy adminId: UUID) async throws {
        try await EmergencyAlertService.acknowledgeAlert(id: id, acknowledgedBy: adminId)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx].status         = .acknowledged
            emergencyAlerts[idx].acknowledgedBy = adminId
            emergencyAlerts[idx].acknowledgedAt = Date()
        }
    }

    func resolveAlert(id: UUID) async throws {
        try await EmergencyAlertService.resolveAlert(id: id)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx].status     = .resolved
            emergencyAlerts[idx].resolvedAt = Date()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Maintenance Tasks
    // ─────────────────────────────────────────────────────────────

    func addMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.addMaintenanceTask(task)
        maintenanceTasks.insert(task, at: 0)

        // Put vehicle in maintenance
        if let idx = vehicles.firstIndex(where: { $0.id == task.vehicleId }) {
            vehicles[idx].status = .inMaintenance
            try? await VehicleService.updateVehicle(vehicles[idx])
        }
    }

    func updateMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.updateMaintenanceTask(task)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == task.id }) {
            maintenanceTasks[idx] = task
        }
    }

    func completeMaintenanceTask(id: UUID) async throws {
        try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: id, status: .completed)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == id }) {
            maintenanceTasks[idx].status      = .completed
            maintenanceTasks[idx].completedAt = Date()

            // Revert vehicle to idle
            let vehicleId = maintenanceTasks[idx].vehicleId
            if let vIdx = vehicles.firstIndex(where: { $0.id == vehicleId }) {
                vehicles[vIdx].status = .idle
                try? await VehicleService.updateVehicle(vehicles[vIdx])
            }
        }
    }

    func deleteMaintenanceTask(id: UUID) async throws {
        try await MaintenanceTaskService.deleteMaintenanceTask(id: id)
        maintenanceTasks.removeAll { $0.id == id }
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
        guard let idx = workOrders.firstIndex(where: { $0.id == id }) else { return }
        var order = workOrders[idx]
        order.status      = .closed
        order.completedAt = Date()
        try await WorkOrderService.updateWorkOrder(order)
        workOrders[idx] = order
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Maintenance Records
    // ─────────────────────────────────────────────────────────────

    func addMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await MaintenanceRecordService.addMaintenanceRecord(record)
        maintenanceRecords.insert(record, at: 0)
    }

    func updateMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await MaintenanceRecordService.updateMaintenanceRecord(record)
        if let idx = maintenanceRecords.firstIndex(where: { $0.id == record.id }) {
            maintenanceRecords[idx] = record
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Parts Used
    // ─────────────────────────────────────────────────────────────

    func addPartUsed(_ part: PartUsed) async throws {
        try await PartUsedService.addPartUsed(part)
        partsUsed.append(part)
        // Recalculate work order parts cost
        let total = partsUsed
            .filter   { $0.workOrderId == part.workOrderId }
            .reduce(0) { $0 + $1.totalCost }
        if let idx = workOrders.firstIndex(where: { $0.id == part.workOrderId }) {
            workOrders[idx].partsCostTotal = total
            try? await WorkOrderService.updateWorkOrder(workOrders[idx])
        }
    }

    func deletePartUsed(id: UUID) async throws {
        guard let part = partsUsed.first(where: { $0.id == id }) else { return }
        let workOrderId = part.workOrderId
        try await PartUsedService.deletePartUsed(id: id)
        partsUsed.removeAll { $0.id == id }
        // Recalculate after removal
        let total = partsUsed
            .filter   { $0.workOrderId == workOrderId }
            .reduce(0) { $0 + $1.totalCost }
        if let idx = workOrders.firstIndex(where: { $0.id == workOrderId }) {
            workOrders[idx].partsCostTotal = total
            try? await WorkOrderService.updateWorkOrder(workOrders[idx])
        }
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

    func toggleGeofence(id: UUID) async throws {
        guard let idx = geofences.firstIndex(where: { $0.id == id }) else { return }
        let newState = !geofences[idx].isActive
        try await GeofenceService.toggleGeofence(id: id, isActive: newState)
        geofences[idx].isActive = newState
    }

    // Geofence Events

    func addGeofenceEvent(_ event: GeofenceEvent) async throws {
        try await GeofenceEventService.addGeofenceEvent(event)
        geofenceEvents.append(event)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Activity Logs
    // ─────────────────────────────────────────────────────────────

    func refreshActivityLogs() async {
        do {
            activityLogs = try await ActivityLogService.fetchRecentLogs(limit: 100)
        } catch {
            print("[AppDataStore] Activity log refresh failed: \(error)")
        }
    }

    func markActivityLogRead(id: UUID) async throws {
        try await ActivityLogService.markAsRead(id: id)
        if let idx = activityLogs.firstIndex(where: { $0.id == id }) {
            activityLogs[idx].isRead = true
        }
    }

    func markAllActivityLogsRead() async throws {
        try await ActivityLogService.markAllAsRead()
        for idx in activityLogs.indices {
            activityLogs[idx].isRead = true
        }
    }

    var unreadActivityCount: Int {
        activityLogs.filter { !$0.isRead }.count
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Lookup Helpers
    // NOTE: All methods use explicit named parameters to avoid collision
    // with stored array property names.
    // ─────────────────────────────────────────────────────────────

    func driverProfile(for staffId: UUID) -> DriverProfile? {
        driverProfiles.first { $0.staffMemberId == staffId }
    }

    func maintenanceProfile(for staffId: UUID) -> MaintenanceProfile? {
        maintenanceProfiles.first { $0.staffMemberId == staffId }
    }

    func vehicleDocuments(forVehicle vehicleId: UUID) -> [VehicleDocument] {
        vehicleDocuments.filter { $0.vehicleId == vehicleId }
    }

    func trips(forDriver driverId: UUID) -> [Trip] {
        trips.filter { $0.driverId == driverId.uuidString }
    }

    func fuelLogs(forDriver driverId: UUID) -> [FuelLog] {
        fuelLogs.filter { $0.driverId == driverId }
    }

    func fuelLogs(forVehicle vehicleId: UUID) -> [FuelLog] {
        fuelLogs.filter { $0.vehicleId == vehicleId }
    }

    func workOrders(forStaff staffId: UUID) -> [WorkOrder] {
        workOrders.filter { $0.assignedToId == staffId }
    }

    func maintenanceTasks(forVehicle vehicleId: UUID) -> [MaintenanceTask] {
        maintenanceTasks.filter { $0.vehicleId == vehicleId }
    }

    func maintenanceRecords(forVehicle vehicleId: UUID) -> [MaintenanceRecord] {
        maintenanceRecords.filter { $0.vehicleId == vehicleId }
    }

    func partsUsed(forWorkOrder workOrderId: UUID) -> [PartUsed] {
        partsUsed.filter { $0.workOrderId == workOrderId }
    }

    func inspections(forTrip tripId: UUID) -> [VehicleInspection] {
        vehicleInspections.filter { $0.tripId == tripId }
    }

    func preInspection(forTrip tripId: UUID) -> VehicleInspection? {
        vehicleInspections.first { $0.tripId == tripId && $0.type == .preTripInspection }
    }

    func postInspection(forTrip tripId: UUID) -> VehicleInspection? {
        vehicleInspections.first { $0.tripId == tripId && $0.type == .postTripInspection }
    }

    func activeEmergencyAlerts() -> [EmergencyAlert] {
        emergencyAlerts.filter { $0.status == .active }
    }

    func geofenceEvents(forVehicle vehicleId: UUID) -> [GeofenceEvent] {
        geofenceEvents.filter { $0.vehicleId == vehicleId }
    }

    func recentActivityLogs(limit: Int = 20) -> [ActivityLog] {
        Array(activityLogs.prefix(limit))
    }

    func documentsExpiringSoon() -> [VehicleDocument] {
        vehicleDocuments.filter { $0.isExpiringSoon || $0.isExpired }
    }

    func vehicle(for id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    func staffMember(for id: UUID) -> StaffMember? {
        staff.first { $0.id == id }
    }

    func trip(for id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    func application(for staffMemberId: UUID) -> StaffApplication? {
        staffApplications
            .filter { $0.staffMemberId == staffMemberId }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func activeTrip(forDriverId driverId: String) -> Trip? {
        trips.first { $0.driverId == driverId && ($0.status == .active || $0.status == .scheduled) }
    }

    func workOrder(forMaintenanceTask taskId: UUID) -> WorkOrder? {
        workOrders.first { $0.maintenanceTaskId == taskId }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Computed Aggregates
    // ─────────────────────────────────────────────────────────────

    var pendingCount: Int { pendingApplicationsCount }

    var activeTripsCount: Int {
        trips.filter { $0.status == .active }.count
    }

    var vehiclesInMaintenance: [Vehicle] {
        vehicles.filter { $0.status == .inMaintenance }
    }

    var overdueTrips: [Trip] {
        trips.filter { $0.isOverdue }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Realtime — Emergency Alerts
    // ─────────────────────────────────────────────────────────────

    private func subscribeToEmergencyAlerts() {
        let channel = supabase.channel("emergency_alerts_channel")
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "emergency_alerts") { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let newAlert = try? JSONDecoder().decode(EmergencyAlert.self, from: data) {
                    self.emergencyAlerts.insert(newAlert, at: 0)
                }
            }
        }
        Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("[AppDataStore] Emergency alerts channel error: \(error)")
            }
            await MainActor.run { self.emergencyAlertsChannel = channel }
        }
    }
}
