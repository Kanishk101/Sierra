import Foundation
import Supabase

/// ViewModel for Maintenance Dashboard.
/// Safeguard 5: 60-second freshness guard on loadTasks.
@MainActor
@Observable
final class MaintenanceDashboardViewModel {

    // MARK: - Filter

    enum TaskFilter: String, CaseIterable {
        case all        = "All"
        case pending    = "Pending"
        case inProgress = "In Progress"
        case completed  = "Completed"
    }

    // MARK: - State

    var assignedTasks: [MaintenanceTask] = []
    var selectedFilter: TaskFilter = .all
    var selectedVehicleFilter: UUID?
    var isLoading = false
    var errorMessage: String?
    private var lastFetchedAt: Date?  // Safeguard 5

    // MARK: - Computed

    var filteredTasks: [MaintenanceTask] {
        var tasks = assignedTasks

        switch selectedFilter {
        case .all: break
        case .pending: tasks = tasks.filter { $0.status == .pending || $0.status == .assigned }
        case .inProgress: tasks = tasks.filter { $0.status == .inProgress }
        case .completed: tasks = tasks.filter { $0.status == .completed }
        }

        if let vehicleId = selectedVehicleFilter {
            tasks = tasks.filter { $0.vehicleId == vehicleId }
        }

        return tasks
    }

    var uniqueVehicleIds: [UUID] {
        Array(Set(assignedTasks.map(\.vehicleId)))
    }

    // MARK: - Load (Safeguard 5: freshness guard)

    func loadTasks(for staffId: UUID, force: Bool = false) async {
        if !force, let last = lastFetchedAt, Date().timeIntervalSince(last) < 60 {
            return  // data is fresh
        }
        isLoading = true
        errorMessage = nil
        do {
            assignedTasks = try await MaintenanceTaskService.fetchMaintenanceTasks(assignedToId: staffId)
            lastFetchedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh(for staffId: UUID) async {
        lastFetchedAt = nil  // force refresh
        await loadTasks(for: staffId, force: true)
    }

    func filterByStatus(_ filter: TaskFilter) {
        selectedFilter = filter
    }

    func filterByVehicle(_ vehicleId: UUID?) {
        selectedVehicleFilter = vehicleId
    }
}
