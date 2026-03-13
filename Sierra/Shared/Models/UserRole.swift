import Foundation

// MARK: - UserRole
// Maps to PostgreSQL enum: user_role
// Values: fleetManager | driver | maintenancePersonnel

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case fleetManager          = "fleetManager"
    case driver                = "driver"
    case maintenancePersonnel  = "maintenancePersonnel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fleetManager:         "Fleet Manager"
        case .driver:               "Driver"
        case .maintenancePersonnel: "Maintenance Personnel"
        }
    }
}
