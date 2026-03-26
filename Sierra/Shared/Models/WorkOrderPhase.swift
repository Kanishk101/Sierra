import Foundation

// MARK: - WorkOrderPhase
// Maps to table: work_order_phases

struct WorkOrderPhase: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var workOrderId: UUID               // work_order_id (FK → work_orders.id)
    var completedById: UUID?            // completed_by_id (FK → staff_members.id)

    // MARK: Phase details
    var phaseNumber: Int                // phase_number — ordering within WO
    var title: String                   // title — e.g. "Replace headlights"
    var description: String?            // description — optional detail
    var estimatedMinutes: Int?          // estimated_minutes — planned ETA for phase
    var plannedCompletionAt: Date?      // planned_completion_at — target date/time picked by technician
    var isLocked: Bool                  // is_locked — phase plan frozen by technician submit
    var lockedAt: Date?                 // locked_at — when phase was submitted/locked

    // MARK: Completion
    var isCompleted: Bool               // is_completed (default false)
    var completedAt: Date?              // completed_at

    // MARK: Timestamps
    var createdAt: Date                 // created_at
    var updatedAt: Date                 // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId    = "work_order_id"
        case completedById  = "completed_by_id"
        case phaseNumber    = "phase_number"
        case title
        case description
        case estimatedMinutes = "estimated_minutes"
        case plannedCompletionAt = "planned_completion_at"
        case isLocked = "is_locked"
        case lockedAt = "locked_at"
        case isCompleted    = "is_completed"
        case completedAt    = "completed_at"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }
}
