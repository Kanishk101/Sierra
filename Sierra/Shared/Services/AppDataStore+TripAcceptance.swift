import Foundation

// MARK: - AppDataStore: Trip Acceptance Lifecycle

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
    // FM-only: transitions a Scheduled trip (legacy, created without a driver)
    // to PendingAcceptance. New trips created via CreateTripViewModel are
    // already PendingAcceptance from INSERT, so this is only needed for legacy rows.

    func dispatchTrip(tripId: UUID) async throws {
        try await TripService.dispatchTrip(tripId: tripId)

        let deadline = Date().addingTimeInterval(TripConstants.acceptanceDeadlineSeconds)
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status = .pendingAcceptance
            trips[idx].acceptanceDeadline = deadline
            trips[idx].updatedAt = Date()
        }

        await TripReminderService.shared.scheduleReminders(for: trips)

        let trip = trips.first { $0.id == tripId }
        if let driverIdStr = trip?.driverId, let driverUUID = UUID(uuidString: driverIdStr) {
            let taskId = trip?.taskId ?? tripId.uuidString
            let origin = trip?.origin ?? "Origin"
            let destination = trip?.destination ?? "Destination"
            try? await NotificationService.insertNotification(
                recipientId: driverUUID,
                type: .tripAssigned,
                title: "New Trip Assigned: \(taskId)",
                body: "\(origin) → \(destination). Please review and accept.",
                entityType: "trip",
                entityId: tripId
            )
        }
    }

    // MARK: - acceptTrip
    // Called when the driver taps "Accept" on a PendingAcceptance trip.
    // DB: sets status = Scheduled (driver accepted = awaiting start window)
    // Local: mirrors DB state — sets status to .scheduled and records acceptedAt.

    func acceptTrip(tripId: UUID) async throws {
        guard let driverId = AuthManager.shared.currentUser?.id else {
            throw AppDataStoreError.notAuthenticated
        }

        try await TripService.acceptTrip(tripId: tripId, driverId: driverId)

        // Mirror DB state: Accepted → Scheduled in local store
        let now = Date()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status     = .scheduled   // matches DB: acceptTrip writes 'Scheduled'
            trips[idx].acceptedAt = now
        }

        await TripReminderService.shared.scheduleReminders(for: trips)

        // Notify fleet managers
        let trip        = trips.first { $0.id == tripId }
        let driverName  = staff.first { $0.id == driverId }?.displayName ?? "Driver"
        let taskId      = trip?.taskId ?? tripId.uuidString
        let destination = trip?.destination ?? "destination"
        await NotificationService.sendToAdmins(
            type: .tripAccepted,
            title: "Trip Accepted: \(taskId)",
            body: "\(driverName) accepted the trip to \(destination).",
            entityType: "trip",
            entityId: tripId
        )
    }
}
