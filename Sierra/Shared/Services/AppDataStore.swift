import Foundation

// MARK: - Maintenance Task (placeholder for Phase 5)

enum TaskPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"
}

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case pending    = "Pending"
    case inProgress = "In Progress"
    case completed  = "Completed"
}

struct MaintenanceTask: Identifiable, Codable {
    let id: UUID
    var vehicleId: String
    var assignedToId: String?
    var title: String
    var taskDescription: String
    var priority: TaskPriority
    var status: MaintenanceTaskStatus
    var createdDate: Date
    var dueDate: Date
}

// MARK: - App Data Store

/// Centralized, observable data store for all app entities.
/// Injected into the SwiftUI hierarchy via `.environment(AppDataStore.shared)`.
@MainActor @Observable
final class AppDataStore {

    static let shared = AppDataStore()

    // MARK: - Data Arrays

    var vehicles: [Vehicle] = Vehicle.mockData
    var staff: [StaffMember] = StaffMember.samples
    var trips: [Trip] = Trip.mockData
    var maintenanceTasks: [MaintenanceTask] = []

    private init() {}

    // ─────────────────────────────────
    // MARK: - Vehicles
    // ─────────────────────────────────

    func addVehicle(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index] = vehicle
    }

    func deleteVehicle(id: UUID) {
        vehicles.removeAll { $0.id == id }
    }

    // ─────────────────────────────────
    // MARK: - Staff
    // ─────────────────────────────────

    func approveStaff(id: UUID) {
        guard let index = staff.firstIndex(where: { $0.id == id }) else { return }
        staff[index].status = .active
    }

    func rejectStaff(id: UUID, reason: String) {
        guard let index = staff.firstIndex(where: { $0.id == id }) else { return }
        staff[index].status = .suspended // use suspended as "rejected" for now
    }

    func removeStaff(id: UUID) {
        staff.removeAll { $0.id == id }
    }

    func suspendStaff(id: UUID) {
        guard let index = staff.firstIndex(where: { $0.id == id }) else { return }
        staff[index].status = .suspended
    }

    func updateStaff(_ member: StaffMember) {
        guard let index = staff.firstIndex(where: { $0.id == member.id }) else { return }
        staff[index] = member
    }

    // ─────────────────────────────────
    // MARK: - Trips
    // ─────────────────────────────────

    func addTrip(_ trip: Trip) {
        trips.append(trip)
    }

    func updateTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
    }

    func cancelTrip(id: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[index].status = .cancelled
    }

    // ─────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────

    /// Returns approved drivers not currently on an active trip.
    func availableDrivers() -> [StaffMember] {
        let activeDriverIds = Set(
            trips
                .filter { $0.status == .active || $0.status == .scheduled }
                .compactMap { $0.driverId }
        )
        return staff.filter { member in
            member.role == .driver
            && member.status == .active
            && member.availability == .available
            && !activeDriverIds.contains(member.id.uuidString)
        }
    }

    /// Returns vehicles that are active or idle and not currently assigned.
    func availableVehicles() -> [Vehicle] {
        vehicles.filter { vehicle in
            (vehicle.status == .active || vehicle.status == .idle)
            && vehicle.assignedDriverId == nil
        }
    }

    /// Returns the first active or scheduled trip for a given driver ID.
    func activeTrip(forDriverId id: String) -> Trip? {
        trips.first { trip in
            trip.driverId == id
            && (trip.status == .active || trip.status == .scheduled)
        }
    }

    /// Look up a vehicle by its UUID string.
    func vehicle(forId id: String) -> Vehicle? {
        vehicles.first { $0.id.uuidString == id }
    }

    /// Look up a staff member by their UUID string.
    func staffMember(forId id: String) -> StaffMember? {
        staff.first { $0.id.uuidString == id }
    }
}
