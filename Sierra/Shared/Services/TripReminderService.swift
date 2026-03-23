import Foundation
import UserNotifications

// MARK: - TripReminderService
// Schedules LOCAL UNUserNotificationCenter reminders for upcoming trips.
// No APNs / server required — fully offline-capable.
//
// Timing aligned with DB trigger (trg_fn_queue_trip_notifications):
//   T-1 hour  : "Accept your trip" reminder — driver must accept before trip starts
//   T-30 min  : "Pre-trip inspection due" — driver must complete inspection
//
// These local notifications fire even when the app is backgrounded.
// The DB notifications table is synced via deliver-due-notifications edge fn on load.

@MainActor
final class TripReminderService {

    static let shared = TripReminderService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

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
    /// upcoming trip within the next 24 hours.
    /// Covers: scheduled, pendingAcceptance, accepted.
    func scheduleReminders(for trips: [Trip]) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            await requestAuthorizationIfNeeded()
            return
        }

        // Remove stale trip reminder notifications
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.map { $0.identifier }.filter { $0.hasPrefix("trip-reminder-") }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        let now = Date()
        let upcoming = trips.filter {
            ($0.status == .accepted || $0.status == .scheduled || $0.status == .pendingAcceptance)
                && $0.scheduledDate > now
                && $0.scheduledDate < now.addingTimeInterval(24 * 3600)
        }

        for trip in upcoming {
            // T-1hr: acceptance reminder (mirrors DB trigger timing)
            let oneHourBefore = trip.scheduledDate.addingTimeInterval(-1 * 3600)
            if oneHourBefore > now {
                await scheduleLocalNotification(
                    id: "trip-reminder-1h-\(trip.id)",
                    title: "\u{23F0} Trip starts in 1 hour",
                    body: "Please accept your trip from \(trip.origin) to \(trip.destination) — it starts at \(trip.scheduledDate.formatted(.dateTime.hour().minute())).",
                    fireDate: oneHourBefore
                )
            }

            // T-30min: pre-inspection reminder (mirrors DB trigger timing)
            let thirtyMinBefore = trip.scheduledDate.addingTimeInterval(-30 * 60)
            if thirtyMinBefore > now {
                await scheduleLocalNotification(
                    id: "trip-reminder-30m-\(trip.id)",
                    title: "\u{1F50D} Pre-trip inspection due",
                    body: "Your trip to \(trip.destination) starts in 30 minutes. Complete your pre-trip inspection now to start on time.",
                    fireDate: thirtyMinBefore
                )
            }
        }
    }

    // MARK: - Cancel Reminders

    func cancelReminders(for tripId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "trip-reminder-1h-\(tripId)",
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
