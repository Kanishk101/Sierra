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
    private var maintenanceTasksChannel: RealtimeChannelV2?
    private var workOrdersChannel:       RealtimeChannelV2?
    private var sparePartsChannel:       RealtimeChannelV2?
    private var partsUsedChannel:        RealtimeChannelV2?
    private var inventoryPartsChannel:   RealtimeChannelV2?
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
    var inventoryParts: [InventoryPart] = []
    var workOrderPhases: [WorkOrderPhase] = []
    var vehicleLocations: [String: VehicleLocationHistory] = [:]
    var routeDeviationEvents: [RouteDeviationEvent] = []
    var isLoading: Bool = false
    var loadError: String?
    private var lastDriverRefreshAt: Date?
    private var sentOverdueTripResponseAlerts: Set<UUID> = []
    private var deliveredRealtimeNotificationIds: Set<UUID> = []

    /// Shared refresh cadence for driver screens.
    var driverRefreshInterval: TimeInterval { 10 }

    private func sortTripsByAssignmentRecency() {
        trips.sort { Trip.isMoreRecentlyAssigned($0, than: $1) }
    }

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
        async let inventoryTask    = InventoryPartService.fetchAllInventoryParts()

        var errors: [String] = []
        do { staff               = try await staffTask }        catch { errors.append("staff: \(error.localizedDescription)") }
        do { driverProfiles      = try await driverProfsTask }  catch { errors.append("driverProfiles: \(error.localizedDescription)") }
        do { maintenanceProfiles = try await maintProfsTask }   catch { errors.append("maintenanceProfiles: \(error.localizedDescription)") }
        do { staffApplications   = try await appsTask }         catch { errors.append("staffApplications: \(error.localizedDescription)") }
        do { vehicles            = try await vehiclesTask }     catch { errors.append("vehicles: \(error.localizedDescription)") }
        do { vehicleDocuments    = try await vehicleDocsTask }  catch { errors.append("vehicleDocuments: \(error.localizedDescription)") }
        do { trips               = try await tripsTask; sortTripsByAssignmentRecency() }        catch { errors.append("trips: \(error.localizedDescription)") }
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
        do { inventoryParts      = try await inventoryTask }    catch { errors.append("inventoryParts: \(error.localizedDescription)") }

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
        subscribeToMaintenanceRealtime(staffId: nil)
        if let userId = AuthManager.shared.currentUser?.id {
            await loadAndSubscribeNotifications(for: userId)
        }
    }

    // MARK: - loadDriverData

    func loadDriverData(driverId: UUID, surfaceErrors: Bool = true) async {
        guard !isLoading else { return }
        await tearDownRealtimeChannels()
        isLoading = true
        if surfaceErrors { loadError = nil }

        async let selfMemberTask  = StaffMemberService.fetchStaffMember(id: driverId)
        async let vehiclesTask    = VehicleService.fetchAllVehicles()
        async let tripsTask       = TripService.fetchTrips(driverId: driverId)
        async let fuelLogsTask    = FuelLogService.fetchFuelLogs(driverId: driverId)
        async let inspectionsTask = VehicleInspectionService.fetchAllInspections()
        async let driverProfTask  = DriverProfileService.fetchDriverProfile(staffMemberId: driverId)

        // H-01 FIX: Collect errors and set loadError (was print-only, never surfaced to UI)
        var errors: [String] = []
        do { if let m = try await selfMemberTask { staff = [m] } }
            catch { errors.append("Staff: \(error.localizedDescription)") }
        do { vehicles = try await vehiclesTask }           catch { errors.append("Vehicles: \(error.localizedDescription)") }
        do { trips = try await tripsTask; sortTripsByAssignmentRecency() }                 catch { errors.append("Trips: \(error.localizedDescription)") }
        do { fuelLogs = try await fuelLogsTask }           catch { errors.append("Fuel logs: \(error.localizedDescription)") }
        do { vehicleInspections = try await inspectionsTask } catch { errors.append("Inspections: \(error.localizedDescription)") }
        do { if let p = try await driverProfTask { driverProfiles = [p] } }
            catch { errors.append("Profile: \(error.localizedDescription)") }

        if surfaceErrors {
            loadError = errors.isEmpty
                ? nil
                : "Some data failed to load: \(errors.joined(separator: "; "))"
        }

        isLoading = false
        subscribeToTripUpdates()
        await loadAndSubscribeNotifications(for: driverId)
        await TripReminderService.shared.requestAuthorizationIfNeeded()
        await TripReminderService.shared.scheduleReminders(for: trips)
        await checkOverdueTripResponses()
    }

    /// Driver refresh with shared throttling.
    /// Set `force` to true for user-initiated pull-to-refresh.
    func refreshDriverData(driverId: UUID, force: Bool = false) async {
        if !force,
           let last = lastDriverRefreshAt,
           Date().timeIntervalSince(last) < driverRefreshInterval {
            return
        }
        guard !isLoading else { return }
        lastDriverRefreshAt = Date()
        await loadDriverData(driverId: driverId, surfaceErrors: force)
    }

    // MARK: - loadMaintenanceData

    func loadMaintenanceData(staffId: UUID) async {
        guard !isLoading else { return }
        await tearDownRealtimeChannels()
        isLoading = true
        loadError = nil

        async let selfMemberTask = StaffMemberService.fetchStaffMember(id: staffId)
        async let vehiclesTask   = VehicleService.fetchAllVehicles()
        async let workOrdersTask = WorkOrderService.fetchWorkOrders(assignedToId: staffId)
        async let maintTasksTask = MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
        async let maintRecsTask  = MaintenanceRecordService.fetchMaintenanceRecords(performedById: staffId)
        async let partsTask      = PartUsedService.fetchAllPartsUsed()
        async let maintProfTask  = MaintenanceProfileService.fetchMaintenanceProfile(staffMemberId: staffId)
        // Inventory tab needs full pipeline visibility (pending approvals, on-order, deliveries),
        // so fetch all spare parts requests instead of only current staff requests.
        async let sparePartsTask = SparePartsRequestService.fetchAllRequests()
        async let inventoryTask  = InventoryPartService.fetchAllInventoryParts()

        var errors: [String] = []
        do { if let m = try await selfMemberTask { staff = [m] } }
            catch { errors.append("Staff: \(error.localizedDescription)") }
        do { vehicles = try await vehiclesTask }
            catch { errors.append("Vehicles: \(error.localizedDescription)") }
        do { workOrders = try await workOrdersTask }
            catch { errors.append("Work orders: \(error.localizedDescription)") }
        do { maintenanceTasks = try await maintTasksTask }
            catch { errors.append("Maintenance tasks: \(error.localizedDescription)") }
        do { maintenanceRecords = try await maintRecsTask }
            catch { errors.append("Maintenance records: \(error.localizedDescription)") }
        do { partsUsed = try await partsTask }
            catch { errors.append("Parts used: \(error.localizedDescription)") }
        do { if let p = try await maintProfTask { maintenanceProfiles = [p] } }
            catch { errors.append("Maintenance profile: \(error.localizedDescription)") }
        do { sparePartsRequests = try await sparePartsTask }
            catch { errors.append("Spare parts requests: \(error.localizedDescription)") }
        do { inventoryParts = try await inventoryTask }
            catch { errors.append("Inventory parts: \(error.localizedDescription)") }

        if !errors.isEmpty {
            loadError = "Some maintenance data failed to load: \(errors.joined(separator: "; "))"
            print("[loadMaintenanceData] Partial errors: \(errors)")
        }

        isLoading = false
        subscribeToMaintenanceRealtime(staffId: staffId)
        await loadAndSubscribeNotifications(for: staffId)
    }

    // MARK: - Realtime teardown

    private func tearDownRealtimeChannels() async {
        if let ch = emergencyAlertsChannel { await ch.unsubscribe(); emergencyAlertsChannel = nil }
        if let ch = staffMembersChannel   { await ch.unsubscribe(); staffMembersChannel = nil }
        if let ch = vehiclesChannel        { await ch.unsubscribe(); vehiclesChannel = nil }
        if let ch = tripsChannel           { await ch.unsubscribe(); tripsChannel = nil }
        if let ch = notificationsChannel   { await ch.unsubscribe(); notificationsChannel = nil }
        if let ch = maintenanceTasksChannel { await ch.unsubscribe(); maintenanceTasksChannel = nil }
        if let ch = workOrdersChannel       { await ch.unsubscribe(); workOrdersChannel = nil }
        if let ch = sparePartsChannel       { await ch.unsubscribe(); sparePartsChannel = nil }
        if let ch = partsUsedChannel        { await ch.unsubscribe(); partsUsedChannel = nil }
        if let ch = inventoryPartsChannel   { await ch.unsubscribe(); inventoryPartsChannel = nil }
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

    // MARK: - Inventory Parts (Admin CRUD)

    func createInventoryPart(
        partName: String,
        partNumber: String?,
        supplier: String?,
        category: String?,
        unit: String,
        currentQuantity: Int,
        reorderLevel: Int,
        onOrderQuantity: Int,
        expectedArrivalAt: Date?,
        compatibleVehicleIds: [UUID],
        isActive: Bool
    ) async throws {
        let created = try await InventoryPartService.createInventoryPart(
            partName: partName,
            partNumber: partNumber,
            supplier: supplier,
            category: category,
            unit: unit,
            currentQuantity: currentQuantity,
            reorderLevel: reorderLevel,
            onOrderQuantity: onOrderQuantity,
            expectedArrivalAt: expectedArrivalAt,
            compatibleVehicleIds: compatibleVehicleIds,
            isActive: isActive
        )
        inventoryParts.insert(created, at: 0)
    }

    func updateInventoryPart(
        id: UUID,
        partName: String,
        partNumber: String?,
        supplier: String?,
        category: String?,
        unit: String,
        currentQuantity: Int,
        reorderLevel: Int,
        onOrderQuantity: Int,
        expectedArrivalAt: Date?,
        compatibleVehicleIds: [UUID],
        isActive: Bool
    ) async throws {
        let updated = try await InventoryPartService.updateInventoryPart(
            id: id,
            partName: partName,
            partNumber: partNumber,
            supplier: supplier,
            category: category,
            unit: unit,
            currentQuantity: currentQuantity,
            reorderLevel: reorderLevel,
            onOrderQuantity: onOrderQuantity,
            expectedArrivalAt: expectedArrivalAt,
            compatibleVehicleIds: compatibleVehicleIds,
            isActive: isActive
        )
        if let idx = inventoryParts.firstIndex(where: { $0.id == id }) {
            inventoryParts[idx] = updated
        } else {
            inventoryParts.insert(updated, at: 0)
        }
    }

    func deleteInventoryPart(id: UUID) async throws {
        try await InventoryPartService.deleteInventoryPart(id: id)
        inventoryParts.removeAll { $0.id == id }
    }

    // MARK: - Staff Applications

    private enum StaffApplicationFlowError: LocalizedError {
        case applicationNotFound

        var errorDescription: String? {
            switch self {
            case .applicationNotFound:
                return "Application was not found. Please refresh and try again."
            }
        }
    }

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
        var app: StaffApplication
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            app = staffApplications[idx]
        } else if let fresh = try await StaffApplicationService.fetchStaffApplication(id: id) {
            app = fresh
            staffApplications.append(fresh)
        } else {
            throw StaffApplicationFlowError.applicationNotFound
        }
        app.status = .approved; app.rejectionReason = nil; app.reviewedBy = adminId; app.reviewedAt = Date()

        // 1. Mark application as approved in staff_applications table
        try await StaffApplicationService.updateStaffApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            staffApplications[idx] = app
        } else {
            staffApplications.append(app)
        }

        // 2. Set is_approved, status=Active, availability=Available in staff_members
        try await StaffMemberService.setApprovalStatus(staffId: app.staffMemberId, approved: true, rejectionReason: nil)

        // 3. Copy personal data + create driver/maintenance profile row.
        // Non-fatal: approval should not be blocked by profile-copy edge cases.
        do {
            try await StaffMemberService.copyApplicationDataToProfile(app)
        } catch {
            print("[AppDataStore.approveStaffApplication] Non-fatal profile copy error: \(error)")
        }

        // 4. Update local store (optimistic)
        if let si = staff.firstIndex(where: { $0.id == app.staffMemberId }) {
            staff[si].isApproved            = true
            staff[si].status                = .active
            staff[si].availability          = .available
            staff[si].isProfileComplete     = true
            staff[si].phone                 = app.phone
            staff[si].dateOfBirth           = app.dateOfBirth
            staff[si].gender                = app.gender
            staff[si].address               = app.address
            staff[si].emergencyContactName  = app.emergencyContactName
            staff[si].emergencyContactPhone = app.emergencyContactPhone
            staff[si].aadhaarNumber         = app.aadhaarNumber
            staff[si].profilePhotoUrl       = app.profilePhotoUrl
        }

        // 5. Reconcile from backend so admin UI and driver-side login use canonical values.
        if let refreshedApp = try await StaffApplicationService.fetchStaffApplication(id: id) {
            if let ai = staffApplications.firstIndex(where: { $0.id == refreshedApp.id }) {
                staffApplications[ai] = refreshedApp
            } else {
                staffApplications.append(refreshedApp)
            }
        }
        if let refreshedMember = try await StaffMemberService.fetchStaffMember(id: app.staffMemberId) {
            if let si = staff.firstIndex(where: { $0.id == refreshedMember.id }) {
                staff[si] = refreshedMember
            } else {
                staff.append(refreshedMember)
            }
        }

        // 6. Notify the driver
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
        var app: StaffApplication
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            app = staffApplications[idx]
        } else if let fresh = try await StaffApplicationService.fetchStaffApplication(id: id) {
            app = fresh
            staffApplications.append(fresh)
        } else {
            throw StaffApplicationFlowError.applicationNotFound
        }
        app.status = .rejected; app.rejectionReason = reason; app.reviewedBy = adminId; app.reviewedAt = Date()
        try await StaffApplicationService.updateStaffApplication(app)
        if let idx = staffApplications.firstIndex(where: { $0.id == id }) {
            staffApplications[idx] = app
        } else {
            staffApplications.append(app)
        }
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
        sortTripsByAssignmentRecency()
        // Trigger-safe fallback: ensure driver sees assignment notification.
        // If backend trigger already inserted one, helper is duplicate-safe.
        if let driverIdStr = trip.driverId, let driverUUID = UUID(uuidString: driverIdStr) {
            await NotificationService.notifyDriverTripAssignedIfNeeded(recipientId: driverUUID, trip: trip)
            LocalNotificationService.notifyTripAssigned(
                taskId: trip.taskId, origin: trip.origin,
                destination: trip.destination, tripId: trip.id
            )
        }
    }
    func updateTrip(_ trip: Trip) async throws {
        try await TripService.updateTrip(trip)
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) { trips[idx] = trip }
        sortTripsByAssignmentRecency()
    }
    func updateTripStatus(id: UUID, status: TripStatus) async throws {
        try await TripService.updateTripStatus(id: id, status: status)
        if let idx = trips.firstIndex(where: { $0.id == id }) {
            trips[idx].status = status
            if status == .active    { trips[idx].actualStartDate = Date() }
            if status == .completed { trips[idx].actualEndDate   = Date() }
        }
        sortTripsByAssignmentRecency()
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
            // Use targeted partial update to avoid trigger rejection
            try await TripService.setInspectionId(tripId: tripId, inspectionId: inspection.id, type: inspection.type)
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
        let saved = try await ProofOfDeliveryService.addProofOfDelivery(pod)

        if let idx = proofOfDeliveries.firstIndex(where: { $0.tripId == saved.tripId }) {
            proofOfDeliveries[idx] = saved
        } else {
            proofOfDeliveries.append(saved)
        }

        if let tripIdx = trips.firstIndex(where: { $0.id == saved.tripId }) {
            trips[tripIdx].proofOfDeliveryId = saved.id
            // Use targeted partial update to avoid trigger rejection
            try await TripService.setProofOfDeliveryId(tripId: saved.tripId, podId: saved.id)
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
                    struct VSResponse: Decodable { let success: Bool? }
                    let opts = try await SupabaseManager.functionOptions(
                        body: VehicleStatusPayload(vehicleId: vehicleId.uuidString, status: "Idle")
                    )
                    let _: VSResponse = try await supabase.functions.invoke("update-vehicle-status", options: opts)
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
            // Notify technician (non-blocking)
            let req = sparePartsRequests[idx]
            Task {
                try? await NotificationService.insertNotification(
                    recipientId: req.requestedById,
                    type: .partsApproved,
                    title: "Parts Approved",
                    body: "\(req.partName) x\(req.quantity) \u{2013} approved",
                    entityType: "spare_parts_request",
                    entityId: req.id
                )
            }
        }
    }
    func rejectSparePartsRequest(id: UUID, reviewedBy adminId: UUID, reason: String) async throws {
        try await SparePartsRequestService.rejectRequest(id: id, reviewedBy: adminId, reason: reason)
        if let idx = sparePartsRequests.firstIndex(where: { $0.id == id }) {
            sparePartsRequests[idx].status = .rejected
            sparePartsRequests[idx].reviewedBy = adminId
            sparePartsRequests[idx].reviewedAt = Date()
            sparePartsRequests[idx].rejectionReason = reason
            // Notify technician (non-blocking)
            let req = sparePartsRequests[idx]
            Task {
                try? await NotificationService.insertNotification(
                    recipientId: req.requestedById,
                    type: .partsRejected,
                    title: "Parts Request Rejected",
                    body: "\(req.partName) x\(req.quantity) \u{2013} \(reason)",
                    entityType: "spare_parts_request",
                    entityId: req.id
                )
            }
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
    func trips(forDriver driverId: UUID) -> [Trip] {
        trips
            .filter { $0.driverId?.lowercased() == driverId.uuidString.lowercased() }
            .sorted { Trip.isMoreRecentlyAssigned($0, than: $1) }
    }
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
    func availableDrivers() -> [StaffMember] {
        let activeDriverIds = Set(
            trips
                .filter { $0.status.normalized == .active }
                .compactMap(\.driverUUID)
        )
        return staff.filter {
            $0.role == .driver
            && $0.status == .active
            && $0.availability == .available
            && !activeDriverIds.contains($0.id)
        }
    }

    func availableVehicles() -> [Vehicle] {
        let activeVehicleIds = Set(
            trips
                .filter { $0.status.normalized == .active }
                .compactMap(\.vehicleUUID)
        )
        return vehicles.filter {
            $0.status == .idle
            && $0.assignedDriverId == nil
            && !activeVehicleIds.contains($0.id)
        }
    }
    func activeTrip(forDriverId driverId: UUID) -> Trip? {
        trips(forDriver: driverId).first {
            $0.driverId?.lowercased() == driverId.uuidString.lowercased() && $0.status.isActionable
        }
    }
    func workOrder(forMaintenanceTask taskId: UUID) -> WorkOrder? { workOrders.first { $0.maintenanceTaskId == taskId } }
    func sparePartsRequests(forTask taskId: UUID) -> [SparePartsRequest] { sparePartsRequests.filter { $0.maintenanceTaskId == taskId } }
    func sparePartsRequests(forWorkOrder woId: UUID) -> [SparePartsRequest] { sparePartsRequests.filter { $0.workOrderId == woId } }
    func pendingSparePartsRequests() -> [SparePartsRequest] { sparePartsRequests.filter { $0.status == .pending } }
    func phases(forWorkOrder woId: UUID) -> [WorkOrderPhase] { workOrderPhases.filter { $0.workOrderId == woId }.sorted { $0.phaseNumber < $1.phaseNumber } }

    func loadWorkOrderPhases(workOrderId: UUID) async {
        do {
            let phases = try await WorkOrderPhaseService().fetchPhases(workOrderId: workOrderId)
            await MainActor.run {
                workOrderPhases.removeAll { $0.workOrderId == workOrderId }
                workOrderPhases.append(contentsOf: phases)
            }
        } catch {
            print("[AppDataStore] loadWorkOrderPhases error: \(error.localizedDescription)")
        }
    }

    func completePhase(_ phase: WorkOrderPhase) async throws {
        guard let personnelId = AuthManager.shared.currentUser?.id else { return }
        try await WorkOrderPhaseService().completePhase(phaseId: phase.id, completedById: personnelId)
        await MainActor.run {
            if let idx = workOrderPhases.firstIndex(where: { $0.id == phase.id }) {
                workOrderPhases[idx].isCompleted = true
                workOrderPhases[idx].completedAt = Date()
                workOrderPhases[idx].completedById = personnelId
            }
        }
    }

    func createPhase(
        workOrderId: UUID,
        phaseNumber: Int,
        title: String,
        description: String?,
        estimatedMinutes: Int?
    ) async throws {
        let created = try await WorkOrderPhaseService().createPhase(
            workOrderId: workOrderId,
            phaseNumber: phaseNumber,
            title: title,
            description: description,
            estimatedMinutes: estimatedMinutes
        )
        workOrderPhases.append(created)
    }

    func updatePhasePlan(
        phaseId: UUID,
        phaseNumber: Int,
        title: String,
        description: String?,
        estimatedMinutes: Int?
    ) async throws {
        try await WorkOrderPhaseService().updatePhase(
            phaseId: phaseId,
            phaseNumber: phaseNumber,
            title: title,
            description: description,
            estimatedMinutes: estimatedMinutes
        )
        if let idx = workOrderPhases.firstIndex(where: { $0.id == phaseId }) {
            workOrderPhases[idx].phaseNumber = phaseNumber
            workOrderPhases[idx].title = title
            workOrderPhases[idx].description = description
            workOrderPhases[idx].estimatedMinutes = estimatedMinutes
        }
    }
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
                    self.sortTripsByAssignmentRecency()
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
                    self.sortTripsByAssignmentRecency()
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Trips channel: \(error)") }
            await MainActor.run { self.tripsChannel = channel }
        }
    }

    // MARK: - Realtime — Maintenance Tables

    private func subscribeToMaintenanceRealtime(staffId: UUID?) {
        subscribeToMaintenanceTaskUpdates(staffId: staffId)
        subscribeToWorkOrderUpdates(staffId: staffId)
        subscribeToSparePartsUpdates(staffId: staffId)
        subscribeToPartsUsedUpdates()
        subscribeToInventoryPartsUpdates()
    }

    private func subscribeToMaintenanceTaskUpdates(staffId: UUID?) {
        let channel = supabase.channel("maintenance_tasks_updates_channel")

        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "maintenance_tasks") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshMaintenanceTasks(staffId: staffId) }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "maintenance_tasks") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshMaintenanceTasks(staffId: staffId) }
        }

        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Maintenance tasks channel: \(error)") }
            await MainActor.run { self.maintenanceTasksChannel = channel }
        }
    }

    private func subscribeToWorkOrderUpdates(staffId: UUID?) {
        let channel = supabase.channel("work_orders_updates_channel")

        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "work_orders") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshWorkOrders(staffId: staffId) }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "work_orders") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshWorkOrders(staffId: staffId) }
        }

        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Work orders channel: \(error)") }
            await MainActor.run { self.workOrdersChannel = channel }
        }
    }

    private func subscribeToSparePartsUpdates(staffId: UUID?) {
        let channel = supabase.channel("spare_parts_requests_updates_channel")

        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "spare_parts_requests") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshSparePartsRequests(staffId: staffId) }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "spare_parts_requests") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshSparePartsRequests(staffId: staffId) }
        }

        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Spare parts channel: \(error)") }
            await MainActor.run { self.sparePartsChannel = channel }
        }
    }

    private func subscribeToPartsUsedUpdates() {
        let channel = supabase.channel("parts_used_updates_channel")

        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "parts_used") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshPartsUsed() }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "parts_used") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshPartsUsed() }
        }

        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Parts used channel: \(error)") }
            await MainActor.run { self.partsUsedChannel = channel }
        }
    }

    private func subscribeToInventoryPartsUpdates() {
        let channel = supabase.channel("inventory_parts_updates_channel")

        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "inventory_parts") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshInventoryParts() }
        }
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "inventory_parts") { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshInventoryParts() }
        }

        Task {
            do { try await channel.subscribeWithError() } catch { print("[AppDataStore] Inventory parts channel: \(error)") }
            await MainActor.run { self.inventoryPartsChannel = channel }
        }
    }

    private func refreshMaintenanceTasks(staffId: UUID?) async {
        do {
            if let staffId {
                maintenanceTasks = try await MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
            } else {
                maintenanceTasks = try await MaintenanceTaskService.fetchAllMaintenanceTasks()
            }
        } catch {
            print("[AppDataStore] Refresh maintenance tasks failed: \(error)")
        }
    }

    private func refreshWorkOrders(staffId: UUID?) async {
        do {
            if let staffId {
                workOrders = try await WorkOrderService.fetchWorkOrders(assignedToId: staffId)
            } else {
                workOrders = try await WorkOrderService.fetchAllWorkOrders()
            }
        } catch {
            print("[AppDataStore] Refresh work orders failed: \(error)")
        }
    }

    private func refreshSparePartsRequests(staffId: UUID?) async {
        do {
            if staffId == nil {
                sparePartsRequests = try await SparePartsRequestService.fetchAllSparePartsRequests()
            } else {
                sparePartsRequests = try await SparePartsRequestService.fetchAllRequests()
            }
        } catch {
            print("[AppDataStore] Refresh spare parts requests failed: \(error)")
        }
    }

    private func refreshPartsUsed() async {
        do {
            partsUsed = try await PartUsedService.fetchAllPartsUsed()
        } catch {
            print("[AppDataStore] Refresh parts used failed: \(error)")
        }
    }

    private func refreshInventoryParts() async {
        do {
            inventoryParts = try await InventoryPartService.fetchAllInventoryParts()
        } catch {
            print("[AppDataStore] Refresh inventory parts failed: \(error)")
        }
    }

    // MARK: - Notifications

    func loadAndSubscribeNotifications(for userId: UUID, forceRefresh: Bool = false) async {
        let isSameUser = (subscribedNotificationsUserId == userId)
        if isSameUser && !forceRefresh { return }
        if !isSameUser {
            NotificationService.shared.unsubscribeFromNotifications()
            subscribedNotificationsUserId = userId
            notifications = []
        }
        do {
            notifications = try await NotificationService.fetchNotifications(for: userId)
            notifications.sort { $0.sentAt > $1.sentAt }
        } catch {
            print("[AppDataStore] Failed to fetch notifications: \(error)")
        }
        if !isSameUser {
            NotificationService.shared.subscribeToNotifications(for: userId) { [weak self] newNotification in
                guard let self else { return }
                Task { @MainActor in
                    if let existingIndex = self.notifications.firstIndex(where: { $0.id == newNotification.id }) {
                        self.notifications[existingIndex] = newNotification
                    } else {
                        self.notifications.insert(newNotification, at: 0)
                        if self.deliveredRealtimeNotificationIds.insert(newNotification.id).inserted {
                            LocalNotificationService.notifyFromSierraNotification(newNotification)
                        }
                    }
                    self.notifications.sort { $0.sentAt > $1.sentAt }
                }
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
        // C-04 FIX: Guard against nil auth instead of UUID() fallback
        guard let driverId = AuthManager.shared.currentUser?.id else { return }
        do {
            try await VehicleLocationService.shared.publishLocation(
                vehicleId: vehicleId, tripId: tripId,
                driverId: driverId,
                latitude: latitude, longitude: longitude, speedKmh: speedKmh
            )
            let entry = VehicleLocationHistory(
                id: UUID(), vehicleId: vehicleId, tripId: tripId,
                driverId: driverId,
                latitude: latitude, longitude: longitude,
                speedKmh: speedKmh, recordedAt: Date(), createdAt: Date()
            )
            activeTripLocationHistory.append(entry)
        } catch { print("[AppDataStore] Location publish failed (non-fatal): \(error)") }
    }

    private enum StartTripPreflightError: LocalizedError {
        case tripNotFound
        case invalidStatus(String)
        case missingAssignment
        case tripNotAccepted
        case missingPreInspection
        case scheduledStartNotReached(Date)
        case driverUnavailable
        case vehicleUnavailable
        case resourceConflict

        var errorDescription: String? {
            switch self {
            case .tripNotFound:
                return "Trip not found."
            case .invalidStatus(let status):
                return "Trip cannot be started from status \(status)."
            case .missingAssignment:
                return "Trip is missing driver or vehicle assignment."
            case .tripNotAccepted:
                return "Trip must be accepted before it can start."
            case .missingPreInspection:
                return "Complete pre-trip inspection before starting."
            case .scheduledStartNotReached(let startAt):
                return "Trip navigation can start only at \(startAt.formatted(.dateTime.hour().minute()))."
            case .driverUnavailable:
                return "Driver is not available to start this trip."
            case .vehicleUnavailable:
                return "Vehicle is not available to start this trip."
            case .resourceConflict:
                return "Driver or vehicle has another active trip."
            }
        }
    }

    private func validateStartTripPreflight(tripId: UUID) async throws -> (trip: Trip, driverId: UUID, vehicleId: UUID) {
        guard let idx = trips.firstIndex(where: { $0.id == tripId }) else {
            throw StartTripPreflightError.tripNotFound
        }
        let trip = trips[idx]
        let normalized = trip.status.normalized
        guard normalized == .scheduled || normalized == .active else {
            throw StartTripPreflightError.invalidStatus(trip.status.rawValue)
        }
        guard let driverId = trip.driverUUID, let vehicleId = trip.vehicleUUID else {
            throw StartTripPreflightError.missingAssignment
        }
        guard trip.acceptedAt != nil else {
            throw StartTripPreflightError.tripNotAccepted
        }
        guard trip.preInspectionId != nil else {
            throw StartTripPreflightError.missingPreInspection
        }
        if trip.scheduledDate > Date() {
            throw StartTripPreflightError.scheduledStartNotReached(trip.scheduledDate)
        }

        if let driver = staff.first(where: { $0.id == driverId }) {
            guard driver.status == .active else { throw StartTripPreflightError.driverUnavailable }
            if normalized == .scheduled {
                guard driver.availability == .available else {
                    throw StartTripPreflightError.driverUnavailable
                }
            }
        }
        if let vehicle = vehicles.first(where: { $0.id == vehicleId }) {
            if normalized == .scheduled {
                guard vehicle.status == .idle else {
                    throw StartTripPreflightError.vehicleUnavailable
                }
            }
        }

        let hasDriverConflict = trips.contains {
            $0.id != tripId && $0.status.normalized == .active && $0.driverUUID == driverId
        }
        let hasVehicleConflict = trips.contains {
            $0.id != tripId && $0.status.normalized == .active && $0.vehicleUUID == vehicleId
        }
        if hasDriverConflict || hasVehicleConflict {
            throw StartTripPreflightError.resourceConflict
        }

        return (trip, driverId, vehicleId)
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
        let preflight = try await validateStartTripPreflight(tripId: tripId)
        try await TripService.startTrip(tripId: tripId, startMileage: startMileage)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status = .active
            trips[idx].actualStartDate = Date()
            trips[idx].startMileage = startMileage
        }

        if let startedTrip = trips.first(where: { $0.id == tripId }) {
            let driverName = staff.first(where: { $0.id == preflight.driverId })?.displayName ?? "Driver"
            await NotificationService.notifyAdminsTripStartedIfNeeded(trip: startedTrip, driverName: driverName)
        }

        // Set driver to Busy
        try? await {
            let _ = try await StaffMemberService.setAvailability(staffId: preflight.driverId, availability: .busy)
            if let si = self.staff.firstIndex(where: { $0.id == preflight.driverId }) {
                self.staff[si].availability = .busy
            }
        }()

        // Set vehicle to Busy
        try? await {
            try await VehicleService.setStatus(vehicleId: preflight.vehicleId, status: .busy)
            if let vi = self.vehicles.firstIndex(where: { $0.id == preflight.vehicleId }) {
                self.vehicles[vi].status = .busy
            }
        }()
    }

    func endTrip(tripId: UUID, endMileage: Double? = nil) async throws {
        try await TripService.completeTrip(tripId: tripId, endMileage: endMileage)
        var completedTrip: Trip?
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            let driverIdStr = trips[idx].driverId
            let vehicleId = trips[idx].vehicleUUID
            trips[idx].status = .completed
            trips[idx].actualEndDate = Date()
            if let endMileage {
                trips[idx].endMileage = endMileage
            }
            completedTrip = trips[idx]
            // Set driver back to Available
            if let driverIdStr, let driverId = UUID(uuidString: driverIdStr) {
                try? await {
                    let _ = try await StaffMemberService.setAvailability(staffId: driverId, availability: .available)
                    if let si = self.staff.firstIndex(where: { $0.id == driverId }) {
                        self.staff[si].availability = .available
                    }
                }()
            }
            if let vehicleId {
                try? await {
                    try await VehicleService.setStatus(vehicleId: vehicleId, status: .idle)
                    if let vi = self.vehicles.firstIndex(where: { $0.id == vehicleId }) {
                        self.vehicles[vi].status = .idle
                    }
                }()
            }
        }
        if let completedTrip {
            let driverName = completedTrip.driverUUID
                .flatMap { id in staff.first(where: { $0.id == id })?.displayName } ?? "Driver"
            await NotificationService.notifyAdminsTripEndedIfNeeded(trip: completedTrip, driverName: driverName)
        }
        activeTripLocationHistory = []; currentTripDeviations = []; activeTripExpenses = []
    }

    func finalizeCompletedTrip(tripId: UUID, endMileage: Double) async throws {
        try await TripService.updateCompletedTripDetails(tripId: tripId, endMileage: endMileage)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].endMileage = endMileage
        }
    }

    func recordTripEndOdometer(tripId: UUID, endMileage: Double) async throws {
        try await TripService.recordEndOdometer(tripId: tripId, endMileage: endMileage)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].endMileage = endMileage
        }
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

    // MARK: - Overdue Trip Response Check

    func checkOverdueTripResponses() async {
        let overduePendingTrips = trips.filter {
            $0.status.normalized == .pendingAcceptance && $0.isResponseOverdue
        }

        let overdueIds = Set(overduePendingTrips.map(\.id))
        sentOverdueTripResponseAlerts = sentOverdueTripResponseAlerts.intersection(overdueIds)

        for trip in overduePendingTrips where !sentOverdueTripResponseAlerts.contains(trip.id) {
            await NotificationService.notifyAdminsTripResponseOverdueIfNeeded(for: trip)
            sentOverdueTripResponseAlerts.insert(trip.id)
        }
    }

    // MARK: - Full Cleanup

    func unsubscribeAll() {
        Task { await tearDownRealtimeChannels() }
        activeTripLocationHistory = []; currentTripDeviations = []; activeTripExpenses = []; notifications = []
    }
}
