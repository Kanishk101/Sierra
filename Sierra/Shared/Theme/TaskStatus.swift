import SwiftUI

// MARK: - Task Status

enum TaskStatus: String, SierraStatus, CaseIterable, Codable {
    case active      = "Active"
    case scheduled   = "Scheduled"
    case inProgress  = "In Progress"
    case completed   = "Completed"
    case cancelled   = "Cancelled"
    case delayed     = "Delayed"
    case unassigned  = "Unassigned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:      SierraTheme.Colors.alpineMint
        case .scheduled:   SierraTheme.Colors.info
        case .inProgress:  SierraTheme.Colors.ember
        case .completed:   SierraTheme.Colors.granite
        case .cancelled:   SierraTheme.Colors.danger
        case .delayed:     SierraTheme.Colors.warning
        case .unassigned:  SierraTheme.Colors.mist
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .active:      SierraTheme.Colors.alpineDark
        case .scheduled:   SierraTheme.Colors.info
        case .inProgress:  SierraTheme.Colors.emberDark
        case .completed:   SierraTheme.Colors.granite
        case .cancelled:   SierraTheme.Colors.danger
        case .delayed:     SierraTheme.Colors.warning
        case .unassigned:  SierraTheme.Colors.granite
        }
    }
}

// MARK: - Priority Level

enum PriorityLevel: String, CaseIterable, Codable {
    case critical = "Critical"
    case high     = "High"
    case medium   = "Medium"
    case low      = "Low"

    var label: String { rawValue }

    var color: Color {
        switch self {
        case .critical: SierraTheme.Colors.danger
        case .high:     SierraTheme.Colors.warning
        case .medium:   SierraTheme.Colors.ember
        case .low:      SierraTheme.Colors.granite
        }
    }

    var icon: String {
        switch self {
        case .critical: "exclamationmark.3"
        case .high:     "exclamationmark.2"
        case .medium:   "exclamationmark"
        case .low:      "minus"
        }
    }
}
