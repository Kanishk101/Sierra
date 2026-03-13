import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - ActivityLogPayload
// activity_log is an append-only audit trail; rows are never updated or deleted.

struct ActivityLogPayload: Encodable {
    let type: String
    let title: String
    let description: String
    let actorId: String?
    let entityType: String
    let entityId: String?
    let severity: String
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case description
        case actorId     = "actor_id"
        case entityType  = "entity_type"
        case entityId    = "entity_id"
        case severity
        case isRead      = "is_read"
    }

    init(from log: ActivityLog) {
        self.type        = log.type.rawValue
        self.title       = log.title
        self.description = log.description
        self.actorId     = log.actorId?.uuidString
        self.entityType  = log.entityType
        self.entityId    = log.entityId?.uuidString   // UUID? → String?
        self.severity    = log.severity.rawValue
        self.isRead      = log.isRead
    }
}

// MARK: - ActivityLogService

struct ActivityLogService {

    static func fetchAllLogs() async throws -> [ActivityLog] {
        return try await supabase
            .from("activity_log")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchRecent(limit: Int) async throws -> [ActivityLog] {
        return try await supabase
            .from("activity_log")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchUnread() async throws -> [ActivityLog] {
        return try await supabase
            .from("activity_log")
            .select()
            .eq("is_read", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func addLog(_ log: ActivityLog) async throws {
        let payload = ActivityLogPayload(from: log)
        try await supabase
            .from("activity_log")
            .insert(payload)
            .execute()
    }

    /// Marks a single activity log entry as read.
    static func markAsRead(id: UUID) async throws {
        try await supabase
            .from("activity_log")
            .update(["is_read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Marks all unread activity logs as read (bulk operation).
    static func markAllAsRead() async throws {
        try await supabase
            .from("activity_log")
            .update(["is_read": true])
            .eq("is_read", value: false)
            .execute()
    }
}
