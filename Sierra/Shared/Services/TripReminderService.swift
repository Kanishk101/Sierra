import Foundation
import UserNotifications

// MARK: - TripReminderService
// Schedules LOCAL UNUserNotificationCenter reminders for upcoming trips.
// No APNs / server required — fully offline-capable.
// All methods that touch UNUserNotificationCenter are @MainActor per Apple guidelines.

@MainActor
final class TripReminderService {

    static let shared = TripReminderService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

    /// Requests notification authorization if not already granted.
    /// Should be called once after the driver signs in.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[TripReminderService] Auth request failed: \(error)")
        }
    }

    // MARK: - Schedule Reminders

    /// Cancels all existing trip reminders then schedules new ones for any
    /// accepted/scheduled trip within the next 24 hours.
    func scheduleReminders(for trips: [Trip]) async {
        // Ensure we have permission
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            await requestAuthorizationIfNeeded()
            return
        }

        // Remove old trip reminder notifications
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix("trip-reminder-") }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        // Schedule for trips starting within the next 24 hours
        let now = Date()
        let upcoming = trips.filter {
            ($0.status == .accepted || $0.status == .scheduled)
                && $0.scheduledDate > now
                && $0.scheduledDate < now.addingTimeInterval(24 * 3600)
        }

        for trip in upcoming {
            // 2-hour reminder
            let twoHourBefore = trip.scheduledDate.addingTimeInterval(-2 * 3600)
            if twoHourBefore > now {
                await scheduleLocalNotification(
                    id: "trip-reminder-2h-\(trip.id)",
                    title: "Trip Starting in 2 Hours",
                    body: "Your trip from \(trip.origin) to \(trip.destination) starts at \(trip.scheduledDate.formatted(.dateTime.hour().minute())).",
                    fireDate: twoHourBefore
                )
            }

            // 30-minute reminder
            let thirtyMinBefore = trip.scheduledDate.addingTimeInterval(-30 * 60)
            if thirtyMinBefore > now {
                await scheduleLocalNotification(
                    id: "trip-reminder-30m-\(trip.id)",
                    title: "Trip Starting Soon",
                    body: "Your trip to \(trip.destination) starts in 30 minutes. Complete your pre-trip inspection now.",
                    fireDate: thirtyMinBefore
                )
            }
        }
    }

    // MARK: - Cancel Reminders

    /// Cancels both reminders for a specific trip (called on reject/cancel).
    func cancelReminders(for tripId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "trip-reminder-2h-\(tripId)",
            "trip-reminder-30m-\(tripId)"
        ])
    }

    // MARK: - Private

    private func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("[TripReminderService] Failed to schedule \(id): \(error)")
        }
    }
}
