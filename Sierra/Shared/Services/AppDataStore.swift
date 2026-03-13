import Foundation

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
        staff[index].status = .suspended
        staff[index].rejectionReason = reason
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
            && !activeDriverIds.contains(member.id)
        }
    }

    /// Returns vehicles that are active or idle and not currently assigned.
    func availableVehicles() -> [Vehicle] {
        vehicles.filter { vehicle in
            (vehicle.status == .active || vehicle.status == .idle)
            && vehicle.assignedDriverId == nil
        }
    }

    /// Returns the first active or scheduled trip for a given driver UUID.
    func activeTrip(forDriverId id: UUID) -> Trip? {
        trips.first { trip in
            trip.driverId == id
            && (trip.status == .active || trip.status == .scheduled)
        }
    }

    /// Returns the first active or scheduled trip for a given driver UUID string (legacy compat).
    func activeTrip(forDriverId id: String) -> Trip? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return activeTrip(forDriverId: uuid)
    }

    /// Look up a vehicle by its UUID.
    func vehicle(forId id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    /// Look up a vehicle by its UUID string (legacy compat).
    func vehicle(forId id: String) -> Vehicle? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return vehicle(forId: uuid)
    }

    /// Look up a staff member by their UUID.
    func staffMember(forId id: UUID) -> StaffMember? {
        staff.first { $0.id == id }
    }

    /// Look up a staff member by their UUID string (legacy compat).
    func staffMember(forId id: String) -> StaffMember? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return staffMember(forId: uuid)
    }
}
