import Foundation
import UserNotifications

// MARK: - LocalNotificationService
//
// Delivers notification banners using UNUserNotificationCenter — no APNs,
// no paid Apple Developer Program required. Banners look and behave
// identically to remote push notifications (title, body, sound, badge).
//
// Usage: call LocalNotificationService.notify(title:body:identifier:)
// from AppDataStore wherever an event should show a banner.
// The identifier is used for deduplication — scheduling the same identifier
// twice replaces the first rather than showing a duplicate.

struct LocalNotificationService {

    // MARK: - Fire a banner

    static func notify(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        delaySeconds: TimeInterval = 0.1
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        // A tiny delay lets the current UI settle before the banner drops in,
        // which avoids the banner appearing while a sheet/alert is still animating.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delaySeconds, 0.1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[LocalNotificationService] Failed to schedule: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Convenience wrappers for each event type
    // These mirror the notification types already inserted into the Supabase
    // `notifications` table — we just also fire a local banner for the
    // on-device experience.

    static func notifyTripAssigned(taskId: String, origin: String, destination: String, tripId: UUID) {
        notify(
            title: "New Trip Assigned: \(taskId)",
            body: "\(origin) → \(destination)",
            identifier: "trip-assigned-\(tripId.uuidString)"
        )
    }

    static func notifyTripAccepted(taskId: String, driverName: String, tripId: UUID) {
        notify(
            title: "Trip Accepted",
            body: "\(driverName) accepted trip \(taskId)",
            identifier: "trip-accepted-\(tripId.uuidString)"
        )
    }

    static func notifyTripRejected(taskId: String, driverName: String, reason: String, tripId: UUID) {
        notify(
            title: "Trip Rejected",
            body: "\(driverName) rejected \(taskId): \(reason)",
            identifier: "trip-rejected-\(tripId.uuidString)"
        )
    }

    static func notifyEmergencyAlert(driverName: String, alertId: UUID) {
        notify(
            title: "\u{1F6A8} Emergency Alert",
            body: "\(driverName) has triggered an SOS alert. Tap to act now.",
            identifier: "emergency-\(alertId.uuidString)"
        )
    }

    static func notifyApplicationApproved() {
        notify(
            title: "Application Approved",
            body: "Your Sierra FMS application has been approved.",
            identifier: "app-approved-\(UUID().uuidString)"
        )
    }

    static func notifyMaintenanceOverdue(taskTitle: String, taskId: UUID) {
        notify(
            title: "Maintenance Overdue",
            body: "Task \"\(taskTitle)\" is past its due date.",
            identifier: "maint-overdue-\(taskId.uuidString)"
        )
    }

    static func notifyWorkOrderCompleted(vehicleName: String, workOrderId: UUID) {
        notify(
            title: "Work Order Completed",
            body: "Maintenance on \(vehicleName) has been closed.",
            identifier: "wo-complete-\(workOrderId.uuidString)"
        )
    }

    // MARK: - Generic forwarding for Realtime notifications
    // Called from AppDataStore.loadAndSubscribeNotifications when a new
    // SierraNotification arrives via Realtime — fires the banner so the
    // user sees it immediately without opening the notifications sheet.

    static func notifyFromSierraNotification(_ notification: SierraNotification) {
        notify(
            title: notification.title,
            body: notification.body,
            identifier: "realtime-\(notification.id.uuidString)"
        )
    }
}
