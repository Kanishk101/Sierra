import SwiftUI

// MARK: - Maintenance Status

enum MaintenanceStatus: String, SierraStatus, CaseIterable, Codable {
    case scheduled     = "Scheduled"
    case inProgress    = "In Progress"
    case completed     = "Completed"
    case cancelled     = "Cancelled"
    case awaitingParts = "Awaiting Parts"
    case breakdown     = "Breakdown"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .scheduled:     SierraTheme.Colors.info
        case .inProgress:    SierraTheme.Colors.warning
        case .completed:     SierraTheme.Colors.alpineMint
        case .cancelled:     SierraTheme.Colors.danger
        case .awaitingParts: SierraTheme.Colors.warning
        case .breakdown:     SierraTheme.Colors.danger
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .scheduled:     SierraTheme.Colors.info
        case .inProgress:    SierraTheme.Colors.warning
        case .completed:     SierraTheme.Colors.alpineDark
        case .cancelled:     SierraTheme.Colors.danger
        case .awaitingParts: SierraTheme.Colors.warning
        case .breakdown:     SierraTheme.Colors.danger
        }
    }

    var icon: String? {
        switch self {
        case .breakdown: "exclamationmark.triangle.fill"
        default: nil
        }
    }
}

// MARK: - Document Status

enum DocumentStatus: String, SierraStatus, CaseIterable, Codable {
    case valid        = "Valid"
    case expiringSoon = "Expiring Soon"
    case expired      = "Expired"
    case missing      = "Missing"

    // MARK: - SierraStatus

    var label: String { rawValue }

    /// Alias for domain clarity.
    var urgencyLabel: String { label }

    var dotColor: Color {
        switch self {
        case .valid:        SierraTheme.Colors.alpineMint
        case .expiringSoon: SierraTheme.Colors.warning
        case .expired:      SierraTheme.Colors.danger
        case .missing:      SierraTheme.Colors.danger
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .valid:        SierraTheme.Colors.alpineDark
        case .expiringSoon: SierraTheme.Colors.warning
        case .expired:      SierraTheme.Colors.danger
        case .missing:      SierraTheme.Colors.danger
        }
    }
}
