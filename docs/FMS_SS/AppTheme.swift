import SwiftUI

// MARK: - App Color Theme
extension Color {
    static let appOrange      = Color(red: 0.95, green: 0.55, blue: 0.10)
    static let appAmber       = Color(red: 1.0, green: 0.75, blue: 0.20)
    static let appDeepOrange  = Color(red: 0.90, green: 0.35, blue: 0.08)
    static let appSurface     = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let appCardBg      = Color.white
    static let appTextPrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let appTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.48)
    static let appDivider     = Color(red: 0.92, green: 0.92, blue: 0.93)
}

// MARK: - Trip Priority
enum TripPriority: String, CaseIterable {
    case urgent  = "Urgent"
    case high    = "High"
    case medium  = "Medium"
    case normal  = "Normal"

    var color: Color {
        switch self {
        case .urgent:  return Color(red: 0.85, green: 0.18, blue: 0.15)
        case .high:    return Color(red: 0.95, green: 0.55, blue: 0.10)
        case .medium:  return Color(red: 0.95, green: 0.75, blue: 0.10)
        case .normal:  return Color(red: 0.20, green: 0.65, blue: 0.32)
        }
    }

    var bgColor: Color {
        color.opacity(0.10)
    }

    var borderColor: Color {
        color.opacity(0.35)
    }

    var icon: String {
        switch self {
        case .urgent:  return "flame.fill"
        case .high:    return "arrow.up.circle.fill"
        case .medium:  return "minus.circle.fill"
        case .normal:  return "checkmark.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent:  return 0
        case .high:    return 1
        case .medium:  return 2
        case .normal:  return 3
        }
    }
}

enum VehicleAssignmentStatus: String {
    case assigned
    case waitingReallocation
}

// MARK: - Data Models
struct Trip: Identifiable {
    let id: String
    let tripCode: String
    let origin: String
    let destination: String
    let fleetNumber: String
    let vehicleType: String
    let dateTime: String
    var priority: TripPriority = .normal
    var isAccepted: Bool = false
    var isInspectionCompleted: Bool = false
    var isTripEnded: Bool = false
    var isPostTripInspectionCompleted: Bool = false
    var vehicleStatus: VehicleAssignmentStatus = .assigned
    var distanceKm: Int = 101
    var scheduledDate: String = "13 March 2027"
    var scheduledTime: String = "10:30 AM"
}
