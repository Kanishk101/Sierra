import SwiftUI

// MARK: - Vehicle Status

enum VehicleStatus: String, SierraStatus, CaseIterable, Codable {
    case active        = "Active"
    case idle          = "Idle"
    case inMaintenance = "In Maintenance"
    case outOfService  = "Out of Service"
    case assigned      = "Assigned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:        SierraTheme.Colors.alpineMint
        case .idle:          SierraTheme.Colors.granite
        case .inMaintenance: SierraTheme.Colors.warning
        case .outOfService:  SierraTheme.Colors.danger
        case .assigned:      SierraTheme.Colors.ember
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .active:        SierraTheme.Colors.alpineDark
        case .idle:          SierraTheme.Colors.granite
        case .inMaintenance: SierraTheme.Colors.warning
        case .outOfService:  SierraTheme.Colors.danger
        case .assigned:      SierraTheme.Colors.emberDark
        }
    }

    var icon: String? {
        switch self {
        case .active:        "truck.box.fill"
        case .idle:          "parkingsign.circle"
        case .inMaintenance: "wrench.fill"
        case .outOfService:  "xmark.octagon.fill"
        case .assigned:      "arrow.triangle.swap"
        }
    }

    var showsDot: Bool { true }

    /// Convenience: border accent color (used on VehicleCard left border).
    var accentBorderColor: Color { dotColor }
}
