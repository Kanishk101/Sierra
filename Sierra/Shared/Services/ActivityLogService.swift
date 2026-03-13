import Foundation
import Supabase

// MARK: - ActivityLogService
// Activity logs are created by Supabase triggers / Edge Functions.
// The iOS app ONLY reads and marks-as-read. No insert method.

// Uses global `supabase` constant from SupabaseManager.swift

struct ActivityLogService {

    static func fetchRecentLogs(limit: Int = 50) async throws -> [ActivityLog] {
        try await supabase
            .from("activity_logs")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchLogs(entityId: UUID) async throws -> [ActivityLog] {
        try await supabase
            .from("activity_logs")
            .select()
            .eq("entity_id", value: entityId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchUnreadLogs() async throws -> [ActivityLog] {
        try await supabase
            .from("activity_logs")
            .select()
            .eq("is_read", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func markAsRead(id: UUID) async throws {
        struct Payload: Encodable { let is_read: Bool }
        try await supabase
            .from("activity_logs")
            .update(Payload(is_read: true))
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func markAllAsRead() async throws {
        struct Payload: Encodable { let is_read: Bool }
        try await supabase
            .from("activity_logs")
            .update(Payload(is_read: true))
            .eq("is_read", value: false)
            .execute()
    }
}
