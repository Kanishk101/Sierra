import Foundation

// MARK: - AppDataStore: Trip Acceptance Lifecycle
// Separated into its own file to keep AppDataStore.swift manageable.
// These methods are added as an extension so the main file is untouched.

// MARK: - AppDataStoreError

enum AppDataStoreError: LocalizedError {
    case notAuthenticated
    case tripNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No authenticated user. Please sign in and try again."
        case .tripNotFound(let id):
            return "Trip \(id.uuidString) not found in local store."
        }
    }
}

extension AppDataStore {

    // MARK: - dispatchTrip
    // Called by the fleet manager to transition a Scheduled trip to PendingAcceptance.
    // 1. Calls TripService (targeted UPDATE setting status + acceptance_deadline)
    // 2. Updates local trips array
    // 3. Schedules trip reminders
    // 4. Notifies the assigned driver

    func dispatchTrip(tripId: UUID) async throws {
        try await TripService.dispatchTrip(tripId: tripId)

        // Update local state
        // BUG-12 FIX: Use centralized constant instead of hardcoded value
        let deadline = Date().addingTimeInterval(TripConstants.acceptanceDeadlineSeconds)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status = .pendingAcceptance
            trips[idx].acceptanceDeadline = deadline
            trips[idx].updatedAt = Date()
        }

        // Schedule local reminders for the dispatched trip
        await TripReminderService.shared.scheduleReminders(for: trips)

        // Notify the assigned driver
        let trip = trips.first { $0.id == tripId }
        if let driverIdStr = trip?.driverId,
           let driverUUID = UUID(uuidString: driverIdStr) {
            let taskId = trip?.taskId ?? tripId.uuidString
            let destination = trip?.destination ?? "destination"
            try? await NotificationService.insertNotification(
                recipientId: driverUUID,
                type: .general,
                title: "New Trip Assigned: \(taskId)",
                body: "You have a new trip to \(destination). Please accept or decline within 24 hours.",
                entityType: "trip",
                entityId: tripId
            )
        }
    }

    // MARK: - acceptTrip
    // Called when the driver taps \u201cAccept\u201d on a PendingAcceptance trip.
    // 1. Calls TripService (targeted UPDATE with driver_id safety filter)
    // 2. Updates local trips array
    // 3. Notifies all admins

    func acceptTrip(tripId: UUID) async throws {
        guard let driverId = AuthManager.shared.currentUser?.id else {
            throw AppDataStoreError.notAuthenticated
        }

        // Service call — throws TripServiceError.driverMismatch if driver_id doesn't match
        try await TripService.acceptTrip(tripId: tripId, driverId: driverId)

        // Update local state — driver has accepted; trip is now Scheduled (awaiting time window)
        let now = Date()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status     = .scheduled
            trips[idx].acceptedAt = now
        }

        // Reschedule reminders so the newly-accepted trip gets its notifications
        await TripReminderService.shared.scheduleReminders(for: trips)

        // Notify admins
        let trip        = trips.first { $0.id == tripId }
        let driverName  = staff.first { $0.id == driverId }?.displayName ?? "Driver"
        let taskId      = trip?.taskId ?? tripId.uuidString
        let destination = trip?.destination ?? "destination"

        for admin in staff.filter({ $0.role == .fleetManager }) {
            try? await NotificationService.insertNotification(
                recipientId: admin.id,
                type: .general,
                title: "Trip Accepted: \(taskId)",
                body: "\(driverName) accepted the trip to \(destination).",
                entityType: "trip",
                entityId: tripId
            )
        }
    }

    // MARK: - rejectTrip
    // Called when the driver taps \u201cReject\u201d and provides a reason.
    // 1. Calls TripService (targeted UPDATE with driver_id safety filter)
    // 2. Updates local trips array
    // 3. Notifies all admins with the rejection reason so they can reassign

    func rejectTrip(tripId: UUID, reason: String) async throws {
        guard let driverId = AuthManager.shared.currentUser?.id else {
            throw AppDataStoreError.notAuthenticated
        }

        // Validate reason is non-empty before hitting the DB
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            throw NSError(
                domain: "SierraFMS",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "A rejection reason is required."]
            )
        }

        try await TripService.rejectTrip(tripId: tripId, driverId: driverId, reason: trimmedReason)

        // Update local state
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status         = .rejected
            trips[idx].rejectedReason = trimmedReason
        }

        // Cancel any pending reminders for this trip
        TripReminderService.shared.cancelReminders(for: tripId)

        // Notify admins with the reason so they can act
        let trip        = trips.first { $0.id == tripId }
        let driverName  = staff.first { $0.id == driverId }?.displayName ?? "Driver"
        let taskId      = trip?.taskId ?? tripId.uuidString
        let destination = trip?.destination ?? "destination"

        for admin in staff.filter({ $0.role == .fleetManager }) {
            try? await NotificationService.insertNotification(
                recipientId: admin.id,
                type: .general,
                title: "Trip Rejected: \(taskId)",
                body: "\(driverName) rejected the trip to \(destination). Reason: \(trimmedReason)",
                entityType: "trip",
                entityId: tripId
            )
        }
    }
}
