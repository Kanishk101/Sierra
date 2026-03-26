import Foundation
import Supabase

// MARK: - WorkOrderPhaseService
/// Manages CRUD operations for work order completion phases.
/// All methods throw on network/auth errors; callers should handle accordingly.

final class WorkOrderPhaseService {

    private let client = SupabaseManager.shared.client
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Fetch

    func fetchPhases(workOrderId: UUID) async throws -> [WorkOrderPhase] {
        try await client
            .from("work_order_phases")
            .select()
            .eq("work_order_id", value: workOrderId.uuidString)
            .order("phase_number", ascending: true)
            .execute()
            .value
    }

    // MARK: - Create

    func createPhase(
        workOrderId: UUID,
        phaseNumber: Int,
        title: String,
        description: String? = nil,
        estimatedMinutes: Int? = nil,
        plannedCompletionAt: Date? = nil,
        isLocked: Bool = false
    ) async throws -> WorkOrderPhase {
        let now = iso.string(from: Date())
        let payload: [String: AnyJSON] = [
            "work_order_id": .string(workOrderId.uuidString),
            "phase_number":  .double(Double(phaseNumber)),
            "title":         .string(title),
            "description":   description.map { .string($0) } ?? .null,
            "estimated_minutes": estimatedMinutes.map { .double(Double($0)) } ?? .null,
            "planned_completion_at": plannedCompletionAt.map { .string(iso.string(from: $0)) } ?? .null,
            "is_locked": .bool(isLocked),
            "locked_at": isLocked ? .string(now) : .null,
            "is_completed":  .bool(false)
        ]
        return try await client
            .from("work_order_phases")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Update Phase Plan

    func updatePhase(
        phaseId: UUID,
        phaseNumber: Int,
        title: String,
        description: String?,
        estimatedMinutes: Int?,
        plannedCompletionAt: Date?,
        isLocked: Bool
    ) async throws {
        let now = iso.string(from: Date())
        let payload: [String: AnyJSON] = [
            "phase_number": .double(Double(phaseNumber)),
            "title": .string(title),
            "description": description.map { .string($0) } ?? .null,
            "estimated_minutes": estimatedMinutes.map { .double(Double($0)) } ?? .null,
            "planned_completion_at": plannedCompletionAt.map { .string(iso.string(from: $0)) } ?? .null,
            "is_locked": .bool(isLocked),
            "locked_at": isLocked ? .string(now) : .null
        ]
        try await client
            .from("work_order_phases")
            .update(payload)
            .eq("id", value: phaseId.uuidString)
            .execute()
    }

    // MARK: - Complete Phase

    func completePhase(phaseId: UUID, completedById: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let payload: [String: AnyJSON] = [
            "is_completed":    .bool(true),
            "completed_at":    .string(now),
            "completed_by_id": .string(completedById.uuidString)
        ]
        try await client
            .from("work_order_phases")
            .update(payload)
            .eq("id", value: phaseId.uuidString)
            .execute()
    }

    // MARK: - Check All Complete

    /// Returns true if every phase for the given work order is marked complete.
    func allPhasesComplete(workOrderId: UUID) async throws -> Bool {
        let phases: [WorkOrderPhase] = try await fetchPhases(workOrderId: workOrderId)
        guard !phases.isEmpty else { return false }
        return phases.allSatisfy { $0.isCompleted }
    }

    // MARK: - Delete Phase

    func deletePhase(phaseId: UUID) async throws {
        try await client
            .from("work_order_phases")
            .delete()
            .eq("id", value: phaseId.uuidString)
            .execute()
    }
}
