import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case fleetManager
    case driver
    case maintenancePersonnel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fleetManager: "Fleet Manager"
        case .driver: "Driver"
        case .maintenancePersonnel: "Maintenance Personnel"
        }
    }
}
