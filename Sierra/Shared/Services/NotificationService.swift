import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - NotificationService

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
            .limit(200)
            .execute()
            .value
    }

    // MARK: - Mark As Read
    // Label uses `id:` to match all call sites in AppDataStore / views.

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
    // Server-side filter: only INSERT events for this specific recipient are
    // delivered over the WebSocket. Prevents data leakage where all connected
    // users could see each other's notifications before the client-side check.

    func subscribeToNotifications(for recipientId: UUID, onNew: @escaping (SierraNotification) -> Void) {
        if notificationChannel != nil { return }

        let channel = supabase.channel("notifications_channel_\(recipientId.uuidString.prefix(8))")
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: "recipient_id=eq.\(recipientId.uuidString)"  // server-side filter
        ) { action in
            let rawRecord = action.record
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(rawRecord),
                   let notification = try? JSONDecoder().decode(SierraNotification.self, from: data) {
                    onNew(notification)
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
