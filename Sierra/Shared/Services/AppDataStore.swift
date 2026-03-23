import Foundation
import Supabase

@MainActor
@Observable
final class AppDataStore {

    static let shared = AppDataStore()

    // MARK: - init
    private init() {}

    // MARK: - Realtime channels
    private var emergencyAlertsChannel: RealtimeChannelV2?
    private var staffMembersChannel:   RealtimeChannelV2?
    private var vehiclesChannel:        RealtimeChannelV2?
    private var tripsChannel:           RealtimeChannelV2?
    private var notificationsChannel:   RealtimeChannelV2?
    private var subscribedNotificationsUserId: UUID?

    // MARK: - Data Arrays
    var staff: [StaffMember] = []
    var driverProfiles: [DriverProfile] = []
    var maintenanceProfiles: [MaintenanceProfile] = []
    var staffApplications: [StaffApplication] = []
    var vehicles: [Vehicle] = []
    var vehicleDocuments: [VehicleDocument] = []
    var trips: [Trip] = []
    var fuelLogs: [FuelLog] = []
    var vehicleInspections: [VehicleInspection] = []
    var proofOfDeliveries: [ProofOfDelivery] = []
    var emergencyAlerts: [EmergencyAlert] = []
    var maintenanceTasks: [MaintenanceTask] = []
    var workOrders: [WorkOrder] = []
    var maintenanceRecords: [MaintenanceRecord] = []
    var partsUsed: [PartUsed] = []
    var geofences: [Geofence] = []
    var geofenceEvents: [GeofenceEvent] = []
    var activityLogs: [ActivityLog] = []
    var notifications: [SierraNotification] = []
    var activeTripLocationHistory: [VehicleLocationHistory] = []
    var currentTripDeviations: [RouteDeviationEvent] = []
    var activeTripExpenses: [TripExpense] = []
    var sparePartsRequests: [SparePartsRequest] = []
    var vehicleLocations: [String: VehicleLocationHistory] = [:]
    var routeDeviationEvents: [RouteDeviationEvent] = []
    var isLoading: Bool = false
    var loadError: String?

    // MARK: - loadAll (Fleet Manager)

    func loadAll() async {
        guard !isLoading else { return }
        await tearDownRealtimeChannels()
        isLoading = true
        loadError = nil

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
        async let routeDevsTask    = RouteDeviationService.fetchAllDeviations()
        async let sparePartsTask   = SparePartsRequestService.fetchAllSparePartsRequests()

        var errors: [String] = []
        do { staff               = try await staffTask }        catch { errors.append("staff: \(error.localizedDescription)") }
        do { driverProfiles      = try await driverProfsTask }  catch { errors.append("driverProfiles: \(error.localizedDescription)") }
        do { maintenanceProfiles = try await maintProfsTask }   catch { errors.append("maintenanceProfiles: \(error.localizedDescription)") }
        do { staffApplications   = try await appsTask }         catch { errors.append("staffApplications: \(error.localizedDescription)") }
        do { vehicles            = try await vehiclesTask }     catch { errors.append("vehicles: \(error.localizedDescription)") }
        do { vehicleDocuments    = try await vehicleDocsTask }  catch { errors.append("vehicleDocuments: \(error.localizedDescription)") }
        do { trips               = try await tripsTask }        catch { errors.append("trips: \(error.localizedDescription)") }
        do { fuelLogs            = try await fuelLogsTask }     catch { errors.append("fuelLogs: \(error.localizedDescription)") }
        do { vehicleInspections  = try await inspectionsTask }  catch { errors.append("vehicleInspections: \(error.localizedDescription)") }
        do { proofOfDeliveries   = try await podsTask }         catch { errors.append("proofOfDeliveries: \(error.localizedDescription)") }
        do { emergencyAlerts     = try await alertsTask }       catch { errors.append("emergencyAlerts: \(error.localizedDescription)") }
        do { maintenanceTasks    = try await maintTasksTask }   catch { errors.append("maintenanceTasks: \(error.localizedDescription)") }
        do { workOrders          = try await workOrdersTask }   catch { errors.append("workOrders: \(error.localizedDescription)") }
        do { maintenanceRecords  = try await maintRecsTask }    catch { errors.append("maintenanceRecords: \(error.localizedDescription)") }
        do { partsUsed           = try await partsTask }        catch { errors.append("partsUsed: \(error.localizedDescription)") }
        do { geofences           = try await geofencesTask }    catch { errors.append("geofences: \(error.localizedDescription)") }
        do { geofenceEvents      = try await geoEventsTask }    catch { errors.append("geofenceEvents: \(error.localizedDescription)") }
        do { activityLogs        = try await activityTask }     catch { errors.append("activityLogs: \(error.localizedDescription)") }
        do { routeDeviationEvents = try await routeDevsTask }   catch { errors.append("routeDeviationEvents: \(error.localizedDescription)") }
        do { sparePartsRequests  = try await sparePartsTask }   catch { errors.append("sparePartsRequests: \(error.localizedDescription)") }

        if !errors.isEmpty {
            loadError = "Partial load failure: \(errors.joined(separator: "; "))"
            print("[AppDataStore.loadAll] Partial errors: \(errors)")
        }
        isLoading = false

        // Background housekeeping
        Task.detached(priority: .background) {
            struct PurgeParams: Encodable { let days_to_keep: Int }
            _ = try? await supabase.rpc("purge_old_location_history", params: PurgeParams(days_to_keep: 30)).execute()
            _ = try? await supabase.rpc("purge_expired_password_reset_tokens").execute()
        }

        subscribeToEmergencyAlerts()
        subscribeToStaffMemberUpdates()
        subscribeToVehicleUpdates()
        subscribeToTripUpdates()
        if let userId = AuthManager.shared.currentUser?.id {
            await loadAndSubscribeNotifications(for: userId)
        }
    }

    // MARK: - loadDriverData

    func loadDriverData(driverId: UUID) async {
        guard !isLoading else { return }
        await tearDownRealtimeChannels()
        isLoading = true

        async let selfMemberTask  = StaffMemberService.fetchStaffMember(id: driverId)
        async let vehiclesTask    = VehicleService.fetchAllVehicles()
        async let tripsTask       = TripService.fetchTrips(driverId: driverId)
        async let fuelLogsTask    = FuelLogService.fetchFuelLogs(driverId: driverId)
        async let inspectionsTask = VehicleInspectionService.fetchAllInspections()
        async let driverProfTask  = DriverProfileService.fetchDriverProfile(staffMemberId: driverId)

        do { if let m = try await selfMemberTask { staff = [m] } }
            catch { print("[loadDriverData] staff: \(error)") }
        do { vehicles = try await vehiclesTask }           catch { print("[loadDriverData] vehicles: \(error)") }
        do { trips = try await tripsTask }                 catch { print("[loadDriverData] trips: \(error)") }
        do { fuelLogs = try await fuelLogsTask }           catch { print("[loadDriverData] fuelLogs: \(error)") }
        do { vehicleInspections = try await inspectionsTask } catch { print("[loadDriverData] inspections: \(error)") }
        do { if let p = try await driverProfTask { driverProfiles = [p] } }
            catch { print("[loadDriverData] driverProfile: \(error)") }

        isLoading = false
        subscribeToTripUpdates()
        await loadAndSubscribeNotifications(for: driverId)
        await TripReminderService.shared.requestAuthorizationIfNeeded()
        await TripReminderService.shared.scheduleReminders(for: trips)
    }

    // MARK: - loadMaintenanceData

    func loadMaintenanceData(staffId: UUID) async {
        guard !isLoading else { return }
        await tearDownRealtimeChannels()
        isLoading = true

        async let selfMemberTask = StaffMemberService.fetchStaffMember(id: staffId)
        async let vehiclesTask   = VehicleService.fetchAllVehicles()
        async let workOrdersTask = WorkOrderService.fetchWorkOrders(assignedToId: staffId)
        async let maintTasksTask = MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
        async let maintRecsTask  = MaintenanceRecordService.fetchMaintenanceRecords(performedById: staffId)
        async let partsTask      = PartUsedService.fetchAllPartsUsed()
        async let maintProfTask  = MaintenanceProfileService.fetchMaintenanceProfile(staffMemberId: staffId)
        async let sparePartsTask = SparePartsRequestService.fetchAllRequests(requestedById: staffId)

        do { if let m = try await selfMemberTask { staff = [m] } }
            catch { print("[loadMaintenanceData] staff: \(error)") }
        do { vehicles = try await vehiclesTask }              catch { print("[loadMaintenanceData] vehicles: \(error)") }
        do { workOrders = try await workOrdersTask }          catch { print("[loadMaintenanceData] workOrders: \(error)") }
        do { maintenanceTasks = try await maintTasksTask }    catch { print("[loadMaintenanceData] maintenanceTasks: \(error)") }
        do { maintenanceRecords = try await maintRecsTask }   catch { print("[loadMaintenanceData] maintenanceRecords: \(error)") }
        do { partsUsed = try await partsTask }                catch { print("[loadMaintenanceData] partsUsed: \(error)") }
        do { if let p = try await maintProfTask { maintenanceProfiles = [p] } }
            catch { print("[loadMaintenanceData] maintenanceProfile: \(error)") }
        do { sparePartsRequests = try await sparePartsTask }  catch { print("[loadMaintenanceData] sparePartsRequests: \(error)") }

        isLoading = false
        await loadAndSubscribeNotifications(for: staffId)
    }

    // MARK: - Realtime teardown

    private func tearDownRealtimeChannels() async {
        if let ch = emergencyAlertsChannel { await ch.unsubscribe(); emergencyAlertsChannel = nil }
        if let ch = staffMembersChannel   { await ch.unsubscribe(); staffMembersChannel = nil }
        if let ch = vehiclesChannel        { await ch.unsubscribe(); vehiclesChannel = nil }
        if let ch = tripsChannel           { await ch.unsubscribe(); tripsChannel = nil }
        if let ch = notificationsChannel   { await ch.unsubscribe(); notificationsChannel = nil }
        subscribedNotificationsUserId = nil
        NotificationService.shared.unsubscribeFromNotifications()
    }

    // MARK: - Staff CRUD

    func addStaffMember(_ member: StaffMember) async throws {
        try await StaffMemberService.addStaffMember(member)
        staff.append(member)
    }
    func updateStaffMember(_ member: StaffMember) async throws {
        try await StaffMemberService.updateStaffMember(member)
        if let idx = staff.firstIndex(where: { $0.id == member.id }) { staff[idx] = member }
    }

    func deleteStaffMember(id: UUID) async throws {
        try await StaffMemberService.deleteStaffMember(id: id)
        staff.removeAll               { $0.id == id }
        driverProfiles.removeAll      { $0.staffMemberId == id }
        maintenanceProfiles.removeAll { $0.staffMemberId == id }
        staffApplications.removeAll   { $0.staffMemberId == id }
    }

    // MARK: - updateDriverAvailability
    //
    // AVAILABILITY RULES (30-minute gate):
    //   • Going Available   → always allowed (unless already available)
    //   • Going Unavailable → BLOCKED if the driver has an active trip
    //                        BLOCKED if a scheduled/accepted trip starts <= 30 min from now
    //                        ALLOWED otherwise (even with future trips)
    //
    // This check is authoritative here.  DriverHomeView duplicates it locally
    // for immediate UI feedback before the async call.

    func updateDriverAvailability(staffId: UUID, available: Bool) async throws {
        let confirmedRaw = try await StaffMemberService.updateAvailability(staffId: staffId, available: available)
        let confirmedAvailability = StaffAvailability(rawValue: confirmedRaw) ?? (available ? .available : .unavailable)
        if let idx = staff.firstIndex(where: { $0.id == staffId }) { staff[idx].availability = confirmedAvailability }
    }

    func addDriverProfile(_ profile: DriverProfile) async throws {
        try await DriverProfileService.addDriverProfile(profile); driverProfiles.append(profile)
    }
    func updateDriverProfile(_ profile: DriverProfile) async throws {
        try await DriverProfileService.updateDriverProfile(profile)
        if let idx = driverProfiles.firstIndex(where: { $0.id == profile.id }) { driverProfiles[idx] = profile }
    }
    func addMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await MaintenanceProfileService.addMaintenanceProfile(profile); maintenanceProfiles.append(profile)
    }
    func updateMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await MaintenanceProfileService.updateMaintenanceProfile(profile)
        if let idx = maintenanceProfiles.firstIndex(where: { $0.id == profile.id }) { maintenanceProfiles[idx] = profile }
    }

    // MARK: - Staff Applications

    func addStaffApplication(_ app: StaffApplication) async throws {
        try await StaffApplicationService.addStaffApplication(app); staffApplications.insert(app, at: 0)
    }
    func updateStaffApplication(_ app: StaffApplication) async throws {
        try await StaffApplicationService.updateStaffApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == app.id }) { staffApplications[idx] = app }
    }

    // MARK: approveStaffApplication
    //
    // FIX: now also copies ALL personal + role-specific data from staff_applications
    // to staff_members (and creates driver_profiles / maintenance_profiles row).
    // Previously the approve button only set is_approved=true and status=Active but
    // left every personal field blank and never created the profile row.

    func approveStaffApplication(id: UUID, reviewedBy adminId: UUID) async throws {
        guard let idx = staffApplications.firstIndex(where: { $0.id == id }) else { return }
        var app = staffApplications[idx]
        app.status = .approved; app.rejectionReason = nil; app.reviewedBy = adminId; app.reviewedAt = Date()

        // 1. Mark application as approved in staff_applications table
        try await StaffApplicationService.updateStaffApplication(app)
        staffApplications[idx] = app

        // 2. Set is_approved, status=Active, availability=Available in staff_members
        try await StaffMemberService.setApprovalStatus(staffId: app.staffMemberId, approved: true, rejectionReason: nil)

        // 3. Copy personal data + create driver/maintenance profile row
        //    (Non-fatal: approval is already committed above; profile copy is best-effort
        //     but we still throw so the UI can surface any problem.)
        try await StaffMemberService.copyApplicationDataToProfile(app)

        // 4. Update local store
        if let si = staff.firstIndex(where: { $0.id == app.staffMemberId }) {
            staff[si].isApproved         = true
            staff[si].status             = .active
            staff[si].availability       = .available
            staff[si].isProfileComplete  = true
            staff[si].phone              = app.phone
            staff[si].dateOfBirth        = app.dateOfBirth
            staff[si].gender             = app.gender
            staff[si].address            = app.address
            staff[si].emergencyContactName  = app.emergencyContactName
            staff[si].emergencyContactPhone = app.emergencyContactPhone
            staff[si].aadhaarNumber      = app.aadhaarNumber
            staff[si].profilePhotoUrl    = app.profilePhotoUrl
        }

        // 5. Notify the driver
        try? await NotificationService.insertNotification(
            recipientId: app.staffMemberId, type: .general,
            title: "Application Approved",
            body: "Your Sierra FMS application has been approved. You can now receive trip assignments.",
            entityType: "staff_application", entityId: id
        )
        LocalNotificationService.notifyApplicationApproved()
    }

    func setStaffStatus(staffId: UUID, status: StaffStatus) async throws {
        try await StaffMemberService.setStatus(staffId: staffId, status: status)
        if let idx = staff.firstIndex(where: { $0.id == staffId }) { staff[idx].status = status }
    }
    func rejectStaffApplication(id: UUID, reason: String, reviewedBy adminId: UUID) async throws {
        guard let idx = staffApplications.firstIndex(where: { $0.id == id }) else { return }
        var app = staffApplications[idx]
        app.status = .rejected; app.rejectionReason = reason; app.reviewedBy = adminId; app.reviewedAt = Date()
        try await StaffApplicationService.updateStaffApplication(app)
        staffApplications[idx] = app
        try await StaffMemberService.setApprovalStatus(staffId: app.staffMemberId, approved: false, rejectionReason: reason)
        if let si = staff.firstIndex(where: { $0.id == app.staffMemberId }) {
            staff[si].isApproved = false; staff[si].rejectionReason = reason; staff[si].status = .suspended
        }
    }
    var pendingApplicationsCount: Int { staffApplications.filter { $0.status == .pending }.count }

    // MARK: - Vehicle CRUD

    func addVehicle(_ vehicle: Vehicle) async throws {
        try await VehicleService.addVehicle(vehicle); vehicles.append(vehicle)
    }
    func updateVehicle(_ vehicle: Vehicle) async throws {
        try await VehicleService.updateVehicle(vehicle)
        if let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) { vehicles[idx] = vehicle }
    }
    func deleteVehicle(id: UUID) async throws {
        try await VehicleService.deleteVehicle(id: id)
        vehicles.removeAll { $0.id == id }; vehicleDocuments.removeAll { $0.vehicleId == id }
    }
    func assignVehicleToDriver(vehicleId: UUID, driverId: UUID?) async throws {
        try await VehicleService.assignDriver(vehicleId: vehicleId, driverId: driverId)
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            vehicles[idx].assignedDriverId = driverId?.uuidString
        }
    }
    func addVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.addVehicleDocument(doc); vehicleDocuments.append(doc)
    }
    func updateVehicleDocument(_ doc: VehicleDocument) async throws {
        try await VehicleDocumentService.updateVehicleDocument(doc)
        if let idx = vehicleDocuments.firstIndex(where: { $0.id == doc.id }) { vehicleDocuments[idx] = doc }
    }
    func deleteVehicleDocument(id: UUID) async throws {
        try await VehicleDocumentService.deleteVehicleDocument(id: id)
        vehicleDocuments.removeAll { $0.id == id }
    }

    // MARK: - Trip CRUD

    func addTrip(_ trip: Trip) async throws {
        try await TripService.addTrip(trip)
        trips.insert(trip, at: 0)
        if let driverIdStr = trip.driverId, let driverUUID = UUID(uuidString: driverIdStr) {
            let dateStr = trip.scheduledDate.formatted(.dateTime.month().day().hour().minute())
            try? await NotificationService.insertNotification(
                recipientId: driverUUID, type: .tripAssigned,
                title: "New Trip Assigned: \(trip.taskId)",
                body: "Trip from \(trip.origin) to \(trip.destination) on \(dateStr)",
                entityType: "trip", entityId: trip.id
            )
            LocalNotificationService.notifyTripAssigned(
                taskId: trip.taskId, origin: trip.origin,
                destination: trip.destination, tripId: trip.id
            )
        }
    }
    func updateTrip(_ trip: Trip) async throws {
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) { trips[idx] = trip }
    }
    func updateTripStatus(id: UUID, status: TripStatus) async throws {
        try await TripService.updateTripStatus(id: id, status: status)
        if let idx = trips.firstIndex(where: { $0.id == id }) {
            trips[idx].status = status
            if status == .active    { trips[idx].actualStartDate = Date() }
            if status == .completed { trips[idx].actualEndDate   = Date() }
        }
    }
    func deleteTrip(id: UUID) async throws {
        try await TripService.deleteTrip(id: id); trips.removeAll { $0.id == id }
    }

    // MARK: - Fuel Logs

    func addFuelLog(_ log: FuelLog) async throws {
        try await FuelLogService.addFuelLog(log); fuelLogs.insert(log, at: 0)
    }
    func deleteFuelLog(id: UUID) async throws {
        try await FuelLogService.deleteFuelLog(id: id); fuelLogs.removeAll { $0.id == id }
    }

    // MARK: - Vehicle Inspections

    func addVehicleInspection(_ inspection: VehicleInspection) async throws {
        try await VehicleInspectionService.addInspection(inspection)
        vehicleInspections.append(inspection)
        let tripId = inspection.tripId
        if let tripIdx = trips.firstIndex(where: { $0.id == tripId }) {
            if inspection.type == .preTripInspection { trips[tripIdx].preInspectionId = inspection.id }
            else { trips[tripIdx].postInspectionId = inspection.id }
            try await TripService.updateTrip(trips[tripIdx])
        }
        if inspection.overallResult == .failed,
           let vIdx = vehicles.firstIndex(where: { $0.id == inspection.vehicleId }) {
            vehicles[vIdx].status = .inMaintenance
            try? await VehicleService.updateVehicle(vehicles[vIdx])
        }
    }
    func updateVehicleInspection(_ inspection: VehicleInspection) async throws {
        try await VehicleInspectionService.updateInspection(inspection)
        if let idx = vehicleInspections.firstIndex(where: { $0.id == inspection.id }) { vehicleInspections[idx] = inspection }
    }

    // MARK: - Proof of Delivery

    func addProofOfDelivery(_ pod: ProofOfDelivery) async throws {
        try await ProofOfDeliveryService.addProofOfDelivery(pod)
        proofOfDeliveries.append(pod)
        if let tripIdx = trips.firstIndex(where: { $0.id == pod.tripId }) {
            trips[tripIdx].proofOfDeliveryId = pod.id
            try await TripService.updateTrip(trips[tripIdx])
        }
    }

    // MARK: - Emergency Alerts

    func addEmergencyAlert(_ alert: EmergencyAlert) async throws {
        try await EmergencyAlertService.addEmergencyAlert(alert)
        emergencyAlerts.insert(alert, at: 0)
        let driverName = staff.first { $0.id == alert.driverId }?.displayName ?? "A driver"
        for admin in staff.filter({ $0.role == .fleetManager }) {
            try? await NotificationService.insertNotification(
                recipientId: admin.id, type: .emergency,
                title: "\u{1F6A8} Emergency Alert",
                body: "\(driverName) has triggered an SOS alert. Tap to act now.",
                entityType: "emergency_alert", entityId: alert.id
            )
        }
        LocalNotificationService.notifyEmergencyAlert(driverName: driverName, alertId: alert.id)
    }
    func acknowledgeAlert(id: UUID, acknowledgedBy adminId: UUID) async throws {
        try await EmergencyAlertService.acknowledgeAlert(id: id, acknowledgedBy: adminId)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx].status = .acknowledged
            emergencyAlerts[idx].acknowledgedBy = adminId
            emergencyAlerts[idx].acknowledgedAt = Date()
        }
    }
    func resolveAlert(id: UUID) async throws {
        try await EmergencyAlertService.resolveAlert(id: id)
        if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
            emergencyAlerts[idx].status = .resolved; emergencyAlerts[idx].resolvedAt = Date()
        }
    }

    // MARK: - Maintenance Tasks

    func addMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.addMaintenanceTask(task)
        maintenanceTasks.insert(task, at: 0)
        if let idx = vehicles.firstIndex(where: { $0.id == task.vehicleId }) {
            vehicles[idx].status = .inMaintenance
            try? await VehicleService.updateVehicle(vehicles[idx])
        }
    }
    func updateMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await MaintenanceTaskService.updateMaintenanceTask(task)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == task.id }) { maintenanceTasks[idx] = task }
    }

    func completeMaintenanceTask(id: UUID) async throws {
        try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: id, status: .completed)
        if let idx = maintenanceTasks.firstIndex(where: { $0.id == id }) {
            maintenanceTasks[idx].status = .completed; maintenanceTasks[idx].completedAt = Date()
            let vehicleId = maintenanceTasks[idx].vehicleId
            if vehicles.firstIndex(where: { $0.id == vehicleId }) != nil {

                struct VehicleStatusPayload: Encodable {
                    let vehicleId: String
                    let status: String
                }

                do {
                    let opts = try await SupabaseManager.functionOptions(
                        body: VehicleStatusPayload(vehicleId: vehicleId.uuidString, status: "Idle")
                    )
                    struct VSResponse: Decodable { let success: Bool? }
                    let _: VSResponse = try await supabase.functions.invoke(
                        "update-vehicle-status",
                        options: opts
                    )
                    if let vIdx = vehicles.firstIndex(where: { $0.id == vehicleId }) { vehicles[vIdx].status = .idle }
                } catch {
                    print("[AppDataStore.completeMaintenanceTask] Non-fatal: vehicle status update failed: \(error)")
                }
            }
        }
    }

    func deleteMaintenanceTask(id: UUID) async throws {
        try await MaintenanceTaskService.deleteMaintenanceTask(id: id)
        maintenanceTasks.removeAll { $0.id == id }
    }

    // MARK: - Work Orders

    func addWorkOrder(_ order: WorkOrder) async throws {
        try await WorkOrderService.addWorkOrder(order); workOrders.append(order)
    }
    func updateWorkOrder(_ order: WorkOrder) async throws {
        try await WorkOrderService.updateWorkOrder(order)
        if let idx = workOrders.firstIndex(where: { $0.id == order.id }) { workOrders[idx] = order }
    }
    func closeWorkOrder(id: UUID) async throws {
        guard let idx = workOrders.firstIndex(where: { $0.id == id }) else { return }
        var order = workOrders[idx]
        order.status = .closed; order.completedAt = Date()
        try await WorkOrderService.updateWorkOrder(order)
        workOrders[idx] = order
        if let taskIdx = maintenanceTasks.firstIndex(where: { $0.id == order.maintenanceTaskId }) {
            maintenanceTasks[taskIdx].status = .completed; maintenanceTasks[taskIdx].completedAt = Date()
            try? await MaintenanceTaskService.updateMaintenanceTask(maintenanceTasks[taskIdx])
            let task = maintenanceTasks[taskIdx]
            let vehicleName = vehicle(for: task.vehicleId)?.name ?? "Unknown"
            try? await NotificationService.insertNotification(
                recipientId: task.createdByAdminId, type: .maintenanceComplete,
                title: "Work Order Completed",
                body: "Work order for vehicle \(vehicleName) has been closed.",
                entityType: "work_order", entityId: order.id
            )
            LocalNotificationService.notifyWorkOrderCompleted(vehicleName: vehicleName, workOrderId: order.id)
        }
    }

    // MARK: - Maintenance Records

    func addMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await MaintenanceRecordService.addMaintenanceRecord(record)
        maintenanceRecords.insert(record, at: 0)
    }
    func updateMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await MaintenanceRecordService.updateMaintenanceRecord(record)
        if let idx = maintenanceRecords.firstIndex(where: { $0.id == record.id }) { maintenanceRecords[idx] = record }
    }

    // MARK: - Parts Used

    func addPartUsed(_ part: PartUsed) async throws {
        try await PartUsedService.addPartUsed(part)
        partsUsed.append(part)
        let total = partsUsed.filter { $0.workOrderId == part.workOrderId }.reduce(0) { $0 + $1.totalCost }
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
        let total = partsUsed.filter { $0.workOrderId == workOrderId }.reduce(0) { $0 + $1.totalCost }
        if let idx = workOrders.firstIndex(where: { $0.id == workOrderId }) {
            workOrders[idx].partsCostTotal = total
            try? await WorkOrderService.updateWorkOrder(workOrders[idx])
        }
    }

    // MARK: - Spare Parts Requests

    func addSparePartsRequest(_ request: SparePartsRequest) async throws {
        try await SparePartsRequestService.submitRequest(
            maintenanceTaskId: request.maintenanceTaskId,
            workOrderId: request.workOrderId,
            requestedById: request.requestedById,
            partName: request.partName,
            partNumber: request.partNumber,
            quantity: request.quantity,
            estimatedUnitCost: request.estimatedUnitCost,
            supplier: request.supplier,
            reason: request.reason
        )
        sparePartsRequests.insert(request, at: 0)
    }
    func approveSparePartsRequest(id: UUID, reviewedBy adminId: UUID) async throws {
        try await SparePartsRequestService.approveRequest(id: id, reviewedBy: adminId)
        if let idx = sparePartsRequests.firstIndex(where: { $0.id == id }) {
            sparePartsRequests[idx].status = .approved
            sparePartsRequests[idx].reviewedBy = adminId
            sparePartsRequests[idx].reviewedAt = Date()
        }
    }
    func rejectSparePartsRequest(id: UUID, reviewedBy adminId: UUID, reason: String) async throws {
        try await SparePartsRequestService.rejectRequest(id: id, reviewedBy: adminId, reason: reason)
        if let idx = sparePartsRequests.firstIndex(where: { $0.id == id }) {
            sparePartsRequests[idx].status = .rejected
            sparePartsRequests[idx].reviewedBy = adminId
            sparePartsRequests[idx].reviewedAt = Date()
            sparePartsRequests[idx].rejectionReason = reason
        }
    }

    // MARK: - Geofences

    func addGeofence(_ geofence: Geofence) async throws {
        try await GeofenceService.addGeofence(geofence); geofences.append(geofence)
    }
    func updateGeofence(_ geofence: Geofence) async throws {
        try await GeofenceService.updateGeofence(geofence)
        if let idx = geofences.firstIndex(where: { $0.id == geofence.id }) { geofences[idx] = geofence }
    }
    func deleteGeofence(id: UUID) async throws {
        try await GeofenceService.deleteGeofence(id: id); geofences.removeAll { $0.id == id }
    }
    func toggleGeofence(id: UUID) async throws {
        guard let idx = geofences.firstIndex(where: { $0.id == id }) else { return }
        let newState = !geofences[idx].isActive
        try await GeofenceService.toggleGeofence(id: id, isActive: newState)
        geofences[idx].isActive = newState
    }
    func addGeofenceEvent(_ event: GeofenceEvent) async throws {
        try await GeofenceEventService.addGeofenceEvent(event); geofenceEvents.append(event)
    }

    // MARK: - Activity Logs

    func refreshActivityLogs() async {
        do { activityLogs = try await ActivityLogService.fetchRecentLogs(limit: 100) }
        catch { print("[AppDataStore] Activity log refresh: \(error)") }
    }
    func markActivityLogRead(id: UUID) async throws {
        try await ActivityLogService.markAsRead(id: id)
        if let idx = activityLogs.firstIndex(where: { $0.id == id }) { activityLogs[idx].isRead = true }
    }
    func markAllActivityLogsRead() async throws {
        try await ActivityLogService.markAllAsRead()
        for idx in activityLogs.indices { activityLogs[idx].isRead = true }
    }
    var unreadActivityCount: Int { activityLogs.filter { !$0.isRead }.count }
    var unreadNotificationCount: Int { notifications.filter { !$0.isRead }.count }

    // MARK: - Lookup Helpers

    func driverProfile(for staffId: UUID) -> DriverProfile? { driverProfiles.first { $0.staffMemberId == staffId } }
    func maintenanceProfile(for staffId: UUID) -> MaintenanceProfile? { maintenanceProfiles.first { $0.staffMemberId == staffId } }
    func vehicleDocuments(forVehicle vehicleId: UUID) -> [VehicleDocument] { vehicleDocuments.filter { $0.vehicleId == vehicleId } }
    func trips(forDriver driverId: UUID) -> [Trip] { trips.filter { $0.driverId?.lowercased() == driverId.uuidString.lowercased() } }
    func fuelLogs(forDriver driverId: UUID) -> [FuelLog] { fuelLogs.filter { $0.driverId == driverId } }
    func fuelLogs(forVehicle vehicleId: UUID) -> [FuelLog] { fuelLogs.filter { $0.vehicleId == vehicleId } }
    func workOrders(forStaff staffId: UUID) -> [WorkOrder] { workOrders.filter { $0.assignedToId == staffId } }
    func maintenanceTasks(forVehicle vehicleId: UUID) -> [MaintenanceTask] { maintenanceTasks.filter { $0.vehicleId == vehicleId } }
    func maintenanceRecords(forVehicle vehicleId: UUID) -> [MaintenanceRecord] { maintenanceRecords.filter { $0.vehicleId == vehicleId } }
    func partsUsed(forWorkOrder workOrderId: UUID) -> [PartUsed] { partsUsed.filter { $0.workOrderId == workOrderId } }
    func inspections(forTrip tripId: UUID) -> [VehicleInspection] { vehicleInspections.filter { $0.tripId == tripId } }
    func preInspection(forTrip tripId: UUID) -> VehicleInspection? { vehicleInspections.first { $0.tripId == tripId && $0.type == .preTripInspection } }
    func postInspection(forTrip tripId: UUID) -> VehicleInspection? { vehicleInspections.first { $0.tripId == tripId && $0.type == .postTripInspection } }
    func activeEmergencyAlerts() -> [EmergencyAlert] { emergencyAlerts.filter { $0.status == .active } }
    func geofenceEvents(forVehicle vehicleId: UUID) -> [GeofenceEvent] { geofenceEvents.filter { $0.vehicleId == vehicleId } }
    func recentActivityLogs(limit: Int = 20) -> [ActivityLog] { Array(activityLogs.prefix(limit)) }
    func documentsExpiringSoon() -> [VehicleDocument] { vehicleDocuments.filter { $0.isExpiringSoon || $0.isExpired } }
    func vehicle(for id: UUID) -> Vehicle? { vehicles.first { $0.id == id } }
    func staffMember(for id: UUID) -> StaffMember? { staff.first { $0.id == id } }
    func trip(for id: UUID) -> Trip? { trips.first { $0.id == id } }
    func application(for staffMemberId: UUID) -> StaffApplication? {
        staffApplications.filter { $0.staffMemberId == staffMemberId }.sorted { $0.createdAt > $1.createdAt }.first
    }
    func availableDrivers() -> [StaffMember] { staff.filter { $0.role == .driver && $0.status == .active && $0.availability == .available } }
    func availableVehicles() -> [Vehicle] { vehicles.filter { $0.status == .idle && $0.assignedDriverId == nil } }
    func activeTrip(forDriverId driverId: UUID) -> Trip? {
        trips.first {
            $0.driverId?.lowercased() == driverId.uuidString.lowercased() && $0.status.isActionable
        }
    }
    func workOrder(forMaintenanceTask taskId: UUID) -> WorkOrder? { workOrders.first { $0.maintenanceTaskId == taskId } }
    func sparePartsRequests(forTask taskId: UUID) -> [SparePartsRequest] { sparePartsRequests.filter { $0.maintenanceTaskId == taskId } }
    func pendingSparePartsRequests() -> [SparePartsRequest] { sparePartsRequests.filter { $0.status == .pending } }
    func routeDeviations(forTrip tripId: UUID) -> [RouteDeviationEvent] { routeDeviationEvents.filter { $0.tripId == tripId } }

    // MARK: - Computed Aggregates

    var pendingCount: Int { pendingApplicationsCount }
    var activeTripsCount: Int { trips.filter { $0.status.isActionable }.count }
    var vehiclesInMaintenance: [Vehicle] { vehicles.filter { $0.status == .inMaintenance } }
    var overdueTrips: [Trip] { trips.filter { $0.isOverdue } }

    // MARK: - Realtime — Emergency Alerts

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
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Emergency alerts channel: \(error)") }
            await MainActor.run { self.emergencyAlertsChannel = channel }
        }
    }

    // MARK: - Realtime — Staff Members UPDATE

    private func subscribeToStaffMemberUpdates() {
        let channel = supabase.channel("staff_members_updates_channel")
        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "staff_members") { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                guard let idValue = action.record["id"],
                      case let .string(idString) = idValue,
                      let updatedId = UUID(uuidString: idString) else { return }
                if let fresh = try? await StaffMemberService.fetchStaffMember(id: updatedId),
                   let idx = self.staff.firstIndex(where: { $0.id == updatedId }) {
                    self.staff[idx] = fresh
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Staff members channel: \(error)") }
            await MainActor.run { self.staffMembersChannel = channel }
        }
    }

    // MARK: - Realtime — Vehicles UPDATE

    private func subscribeToVehicleUpdates() {
        let channel = supabase.channel("vehicles_updates_channel")
        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "vehicles") { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                guard let idValue = action.record["id"],
                      case let .string(idString) = idValue,
                      let updatedId = UUID(uuidString: idString) else { return }
                if let fresh = try? await VehicleService.fetchVehicle(id: updatedId),
                   let idx = self.vehicles.firstIndex(where: { $0.id == updatedId }) {
                    self.vehicles[idx] = fresh
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Vehicles channel: \(error)") }
            await MainActor.run { self.vehiclesChannel = channel }
        }
    }

    // MARK: - Realtime — Trips (UPDATE + INSERT)

    private func subscribeToTripUpdates() {
        let channel = supabase.channel("trips_updates_channel")
        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "trips") { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                guard let idValue = action.record["id"],
                      case let .string(idString) = idValue,
                      let updatedId = UUID(uuidString: idString) else { return }
                if let fresh = try? await TripService.fetchTrip(id: updatedId),
                   let idx = self.trips.firstIndex(where: { $0.id == updatedId }) {
                    self.trips[idx] = fresh
                }
            }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "trips") { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                guard let idValue = action.record["id"],
                      case let .string(idString) = idValue,
                      let newId = UUID(uuidString: idString) else { return }
                guard !self.trips.contains(where: { $0.id == newId }) else { return }
                if let fresh = try? await TripService.fetchTrip(id: newId) {
                    self.trips.insert(fresh, at: 0)
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Trips channel: \(error)") }
            await MainActor.run { self.tripsChannel = channel }
        }
    }

    // MARK: - Notifications

    func loadAndSubscribeNotifications(for userId: UUID) async {
        if subscribedNotificationsUserId == userId { return }
        NotificationService.shared.unsubscribeFromNotifications()
        subscribedNotificationsUserId = userId
        notifications = []
        do {
            notifications = try await NotificationService.fetchNotifications(for: userId)
        } catch {
            print("[AppDataStore] Failed to fetch notifications: \(error)")
        }
        NotificationService.shared.subscribeToNotifications(for: userId) { [weak self] newNotification in
            guard let self else { return }
            Task { @MainActor in
                self.notifications.insert(newNotification, at: 0)
                LocalNotificationService.notifyFromSierraNotification(newNotification)
            }
        }
    }

    func markNotificationRead(id: UUID) async throws {
        try await NotificationService.markAsRead(id: id)
        if let idx = notifications.firstIndex(where: { $0.id == id }) { notifications[idx].isRead = true }
    }
    func clearAllNotifications(userId: UUID) async throws {
        try await supabase.from("notifications").delete().eq("recipient_id", value: userId.uuidString).execute()
        notifications = []
    }

    // MARK: - Location Publishing

    func publishDriverLocation(vehicleId: UUID, tripId: UUID, latitude: Double, longitude: Double, speedKmh: Double?) async {
        do {
            try await VehicleLocationService.shared.publishLocation(
                vehicleId: vehicleId, tripId: tripId,
                driverId: AuthManager.shared.currentUser?.id ?? UUID(),
                latitude: latitude, longitude: longitude, speedKmh: speedKmh
            )
            let entry = VehicleLocationHistory(
                id: UUID(), vehicleId: vehicleId, tripId: tripId,
                driverId: AuthManager.shared.currentUser?.id,
                latitude: latitude, longitude: longitude,
                speedKmh: speedKmh, recordedAt: Date(), createdAt: Date()
            )
            activeTripLocationHistory.append(entry)
        } catch { print("[AppDataStore] Location publish failed (non-fatal): \(error)") }
    }

    // MARK: - Trip Lifecycle
    //
    // AVAILABILITY MANAGEMENT:
    //   startActiveTrip  → sets driver to .busy   (they are on a trip)
    //   endTrip          → sets driver to .available (trip done)
    //   abortTrip        → sets driver to .available (trip cancelled)
    //
    // These are best-effort (non-fatal if availability update fails).

    func startActiveTrip(tripId: UUID, startMileage: Double) async throws {
        try await TripService.startTrip(tripId: tripId, startMileage: startMileage)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status = .active
            trips[idx].actualStartDate = Date()
            trips[idx].startMileage = startMileage
            // Set driver to Busy
            if let driverIdStr = trips[idx].driverId, let driverId = UUID(uuidString: driverIdStr) {
                try? await {
                    let _ = try await StaffMemberService.setAvailability(staffId: driverId, availability: .busy)
                    if let si = self.staff.firstIndex(where: { $0.id == driverId }) {
                        self.staff[si].availability = .busy
                    }
                }()
            }
        }
    }

    func endTrip(tripId: UUID, endMileage: Double) async throws {
        try await TripService.completeTrip(tripId: tripId, endMileage: endMileage)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            let driverIdStr = trips[idx].driverId
            trips[idx].status = .completed
            trips[idx].actualEndDate = Date()
            trips[idx].endMileage = endMileage
            // Set driver back to Available
            if let driverIdStr, let driverId = UUID(uuidString: driverIdStr) {
                try? await {
                    let _ = try await StaffMemberService.setAvailability(staffId: driverId, availability: .available)
                    if let si = self.staff.firstIndex(where: { $0.id == driverId }) {
                        self.staff[si].availability = .available
                    }
                }()
            }
        }
        activeTripLocationHistory = []; currentTripDeviations = []; activeTripExpenses = []
    }

    func abortTrip(tripId: UUID) async throws {
        try await TripService.cancelTrip(tripId: tripId)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            let driverIdStr = trips[idx].driverId
            trips[idx].status = .cancelled
            // Set driver back to Available
            if let driverIdStr, let driverId = UUID(uuidString: driverIdStr) {
                try? await {
                    let _ = try await StaffMemberService.setAvailability(staffId: driverId, availability: .available)
                    if let si = self.staff.firstIndex(where: { $0.id == driverId }) {
                        self.staff[si].availability = .available
                    }
                }()
            }
        }
        TripReminderService.shared.cancelReminders(for: tripId)
        activeTripLocationHistory = []; currentTripDeviations = []; activeTripExpenses = []
    }

    // MARK: - Overdue Maintenance Check

    func checkOverdueMaintenance() async {
        guard subscribedNotificationsUserId != nil else { return }
        let overdueTasks = maintenanceTasks.filter { $0.status == .pending && $0.dueDate < Date() }
        for task in overdueTasks {
            let alreadyNotified = notifications.contains { $0.type == .maintenanceOverdue && $0.entityId == task.id }
            guard !alreadyNotified else { continue }
            do {
                try await NotificationService.insertNotification(
                    recipientId: task.createdByAdminId, type: .maintenanceOverdue,
                    title: "Maintenance Overdue",
                    body: "Task \"\(task.title)\" is past its due date.",
                    entityType: "maintenance_task", entityId: task.id
                )
                LocalNotificationService.notifyMaintenanceOverdue(taskTitle: task.title, taskId: task.id)
            } catch {
                print("[AppDataStore] Non-fatal: overdue notification failed: \(error)")
            }
        }
    }

    // MARK: - Expiring Documents Check

    func checkExpiringDocuments() async {
        guard subscribedNotificationsUserId != nil else { return }

        let adminIds = staff
            .filter { $0.role == .fleetManager && $0.status == .active }
            .map { $0.id }
        guard !adminIds.isEmpty else { return }

        let expiringDocs = documentsExpiringSoon()
        guard !expiringDocs.isEmpty else { return }

        for doc in expiringDocs {
            let alreadyNotified = notifications.contains {
                $0.type == .documentExpiry && $0.entityId == doc.id
            }
            guard !alreadyNotified else { continue }

            let vehicleName = vehicles.first { $0.id == doc.vehicleId }?.name ?? "Unknown vehicle"
            let statusLabel = doc.isExpired ? "EXPIRED" : "expiring soon"
            let expiryStr   = doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year())

            for adminId in adminIds {
                try? await NotificationService.insertNotification(
                    recipientId: adminId,
                    type: .documentExpiry,
                    title: "Document \(statusLabel): \(doc.documentType.rawValue)",
                    body: "\(vehicleName) — \(doc.documentType.rawValue) \(statusLabel). Expires \(expiryStr).",
                    entityType: "vehicle_document",
                    entityId: doc.id
                )
            }
        }
    }

    // MARK: - Full Cleanup

    func unsubscribeAll() {
        Task { await tearDownRealtimeChannels() }
        activeTripLocationHistory = []; currentTripDeviations = []; activeTripExpenses = []; notifications = []
    }
}
