import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - NotificationService
// Manages CRUD and Realtime for the notifications table.
// Uses a class (not struct) to hold Realtime channel state.

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private var notificationChannel: RealtimeChannelV2?

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Fetch

    static func fetchNotifications(for recipientId: UUID) async throws -> [SierraNotification] {
        try await supabase
            .from("notifications")
            .select()
            .eq("recipient_id", value: recipientId.uuidString)
            .order("sent_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Mark As Read

    static func markAsRead(notificationId: UUID) async throws {
        struct Payload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        try await supabase
            .from("notifications")
            .update(Payload(is_read: true, read_at: iso.string(from: Date())))
            .eq("id", value: notificationId.uuidString)
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
            let sent_at: String
        }
        try await supabase
            .from("notifications")
            .insert(Payload(
                recipient_id: recipientId.uuidString,
                type: type.rawValue,
                title: title,
                body: body,
                entity_type: entityType,
                entity_id: entityId?.uuidString,
                is_read: false,
                sent_at: iso.string(from: Date())
            ))
            .execute()
    }

    // MARK: - Realtime

    func subscribeToNotifications(for recipientId: UUID, onNew: @escaping (SierraNotification) -> Void) {
        if notificationChannel != nil { return }

        let channel = supabase.channel("notifications_channel_\(recipientId.uuidString.prefix(8))")
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications"
        ) { action in
            // Decode off main-actor by encoding action.record to JSON bytes first,
            // then decoding SierraNotification in a detached Task to avoid
            // main-actor conformance being used from nonisolated context.
            let rawRecord = action.record
            Task.detached {
                if let data = try? JSONEncoder().encode(rawRecord),
                   let notification = try? JSONDecoder().decode(SierraNotification.self, from: data),
                   notification.recipientId == recipientId {
                    await MainActor.run { onNew(notification) }
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[NotificationService] Channel error: \(error)") }
            self.notificationChannel = channel
        }
    }

    func unsubscribeFromNotifications() {
        guard let channel = notificationChannel else { return }
        Task { await channel.unsubscribe() }
        notificationChannel = nil
    }
}
