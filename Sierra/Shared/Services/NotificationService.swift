import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - NotificationService
//
// NOTIFICATION DELIVERY ARCHITECTURE:
//
// Immediate notifications (no scheduled_for):
//   INSERT → trg_push_on_notification_insert → pg_net → send-push-notification
//   is_delivered defaults to TRUE so the trigger fires immediately.
//
// Scheduled notifications (1-hour accept reminder, 30-min pre-inspection):
//   Queued by trg_fn_queue_trip_notifications with is_delivered=FALSE.
//   Delivery path A: trg_push_on_notification_delivered fires when is_delivered
//     flips TRUE — requires app.service_role_key to be set in DB (ALTER DATABASE).
//   Delivery path B: deliver-scheduled-notifications edge function, called by
//     the iOS app on every login and foreground resume. Guaranteed to work
//     even without DB-level service_role_key setting.
//
// LOCAL NOTIFICATIONS (UNUserNotificationCenter):
//   TripReminderService schedules UNCalendarNotificationTrigger entries at
//   T-1hr and T-30min. These fire even if the app is backgrounded and the
//   DB push path is unavailable (no APNs configured yet).

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private var notificationChannel: RealtimeChannelV2?

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static var lastDeliveryRunAt: Date?
    private static let minDeliveryRunInterval: TimeInterval = 20
    private static var deliveryUnauthorizedBackoffUntil: Date?

    // MARK: - Deliver scheduled notifications
    //
    // Calls the deliver-scheduled-notifications edge function to flip any
    // past-due scheduled notifications to is_delivered=TRUE, which fires
    // the pg_net push trigger for each one.
    // Non-fatal: failures are logged and silently swallowed.

    @MainActor
    static func deliverScheduledNotifications() async {
        guard AuthManager.shared.currentUser != nil else { return }
        if let backoffUntil = deliveryUnauthorizedBackoffUntil, Date() < backoffUntil {
            return
        }
        if let last = lastDeliveryRunAt,
           Date().timeIntervalSince(last) < minDeliveryRunInterval {
            return
        }
        lastDeliveryRunAt = Date()

        do {
            let options = try await SupabaseManager.functionOptionsNoBody()
            struct DeliveryResult: Decodable { let delivered: Int; let pushSent: Int? }
            let result: DeliveryResult = try await supabase.functions.invoke(
                "deliver-scheduled-notifications",
                options: options
            )
            #if DEBUG
            print("[NotificationService] Delivery run: delivered=\(result.delivered) pushSent=\(result.pushSent ?? 0)")
            #endif
        } catch {
            // Non-fatal — local UNUserNotificationCenter reminders are the fallback
            let description = String(describing: error)
            if description.contains("401") || description.contains("Unauthorized") {
                // Avoid hammering edge function with bad token / unauthorized context.
                deliveryUnauthorizedBackoffUntil = Date().addingTimeInterval(5 * 60)
            }
            #if DEBUG
            print("[NotificationService] deliver-scheduled-notifications non-fatal: \(error)")
            #endif
        }
    }

    // MARK: - Fetch
    //
    // Triggers scheduled notification delivery first (best-effort), then fetches.
    // This ensures any past-due reminders appear immediately in the notification
    // bell rather than waiting for the next background delivery pass.

    static func fetchNotifications(for recipientId: UUID) async throws -> [SierraNotification] {
        // Best-effort delivery pass before fetch
        await deliverScheduledNotifications()

        return try await supabase
            .from("notifications")
            .select()
            .eq("recipient_id", value: recipientId.uuidString)
            .order("sent_at", ascending: false)
            .limit(200)
            .execute()
            .value
    }

    // MARK: - Mark As Read

    static func markAsRead(id: UUID) async throws {
        struct Payload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        try await supabase
            .from("notifications")
            .update(Payload(is_read: true, read_at: iso.string(from: Date())))
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func markAllAsRead(for recipientId: UUID) async throws {
        struct Payload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        try await supabase
            .from("notifications")
            .update(Payload(is_read: true, read_at: iso.string(from: Date())))
            .eq("recipient_id", value: recipientId.uuidString)
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Insert
    //
    // is_delivered is explicitly set to TRUE for immediate notifications
    // so the trg_push_on_notification_insert trigger fires correctly.
    // Scheduled notifications (queued by DB trigger) set is_delivered=FALSE
    // and are handled by the deliver-scheduled-notifications edge function.

    static func insertNotification(
        recipientId: UUID,
        type: NotificationType,
        title: String,
        body: String,
        entityType: String?,
        entityId: UUID?
    ) async throws {
        struct Payload: Encodable {
            let recipient_id: String
            let type: String
            let title: String
            let body: String
            let entity_type: String?
            let entity_id: String?
            let is_read: Bool
            let is_delivered: Bool
            let sent_at: String
        }
        try await supabase
            .from("notifications")
            .insert(Payload(
                recipient_id: recipientId.uuidString,
                type:         type.rawValue,
                title:        title,
                body:         body,
                entity_type:  entityType,
                entity_id:    entityId?.uuidString,
                is_read:      false,
                is_delivered: true,   // immediate — trigger fires push right away
                sent_at:      iso.string(from: Date())
            ))
            .execute()
    }

    // MARK: - Realtime Subscribe
    //
    // Server-side filter: only INSERT events for this specific recipient are
    // delivered over the WebSocket. Prevents data leakage.

    func subscribeToNotifications(for recipientId: UUID, onNew: @escaping (SierraNotification) -> Void) {
        if notificationChannel != nil { return }

        let channel = supabase.channel("notifications_channel_\(recipientId.uuidString.prefix(8))")
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table:  "notifications",
            filter: "recipient_id=eq.\(recipientId.uuidString)"
        ) { action in
            let rawRecord = action.record
            Task { @MainActor in
                if let data         = try? JSONEncoder().encode(rawRecord),
                   let notification = try? JSONDecoder().decode(SierraNotification.self, from: data) {
                    onNew(notification)
                }
            }
        }
        // Also listen for UPDATEs on own notifications so that when
        // a scheduled notification flips is_delivered=TRUE the in-app
        // bell gets it without requiring a full data reload.
        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table:  "notifications",
            filter: "recipient_id=eq.\(recipientId.uuidString)"
        ) { action in
            let rawRecord = action.record
            Task { @MainActor in
                if let data         = try? JSONEncoder().encode(rawRecord),
                   let notification = try? JSONDecoder().decode(SierraNotification.self, from: data) {
                    // Only surface if newly delivered (is_delivered just flipped TRUE)
                    if notification.isDelivered == true && notification.isRead == false {
                        onNew(notification)
                    }
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() }
            catch {
                #if DEBUG
                print("[NotificationService] Channel error: \(error)")
                #endif
            }
            self.notificationChannel = channel
        }
    }

    func unsubscribeFromNotifications() {
        guard let channel = notificationChannel else { return }
        Task { await channel.unsubscribe() }
        notificationChannel = nil
    }
}
