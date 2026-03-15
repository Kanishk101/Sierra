import SwiftUI

// MARK: - Driver Status

enum DriverStatus: String, SierraStatus, CaseIterable, Codable {
    case available     = "Available"
    case busy          = "Busy"
    case unavailable   = "Unavailable"
    case offDuty       = "Off Duty"
    case pendingReview = "Pending Review"
    case rejected      = "Rejected"
    case inactive      = "Inactive"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineMint
        case .busy:          SierraTheme.Colors.ember
        case .unavailable:   SierraTheme.Colors.granite
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .available:     SierraTheme.Colors.alpineDark
        case .busy:          SierraTheme.Colors.emberDark
        case .unavailable:   SierraTheme.Colors.granite
        case .offDuty:       SierraTheme.Colors.granite
        case .pendingReview: SierraTheme.Colors.info
        case .rejected:      SierraTheme.Colors.danger
        case .inactive:      SierraTheme.Colors.granite
        }
    }

    var showsDot: Bool { true }

    var icon: String? { nil }
}

