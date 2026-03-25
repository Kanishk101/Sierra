import Foundation

// MARK: - Dashboard ViewModel (Static Data)
@MainActor
@Observable
final class MaintenanceDashboardViewModel {

    enum TaskFilter: String, CaseIterable {
        case all        = "All"
        case pending    = "Pending"
        case inProgress = "In Progress"
        case completed  = "Completed"
    }

    var assignedTasks: [MMaintenanceTask] = StaticData.tasks
    var selectedFilter: TaskFilter = .all
    var selectedVehicleFilter: UUID? = nil

    var filteredTasks: [MMaintenanceTask] {
        var tasks = assignedTasks
        switch selectedFilter {
        case .all: break
        case .pending:    tasks = tasks.filter { $0.status == .pending || $0.status == .assigned }
        case .inProgress: tasks = tasks.filter { $0.status == .inProgress }
        case .completed:  tasks = tasks.filter { $0.status == .completed }
        }
        if let vehicleId = selectedVehicleFilter {
            tasks = tasks.filter { $0.vehicleId == vehicleId }
        }
        return tasks
    }

    var uniqueVehicleIds: [UUID] {
        Array(Set(assignedTasks.map(\.vehicleId)))
    }

    func filterByStatus(_ filter: TaskFilter) {
        selectedFilter = filter
    }

    func filterByVehicle(_ vehicleId: UUID?) {
        selectedVehicleFilter = vehicleId
    }
}
