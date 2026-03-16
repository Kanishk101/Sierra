import SwiftUI

// MARK: - Vehicle Status
// Maps to PostgreSQL enum: vehicle_status
// Values: Active | Idle | In Maintenance | Out of Service | Decommissioned

enum VehicleStatus: String, SierraStatus, CaseIterable, Codable {
    case active          = "Active"
    case busy            = "Busy"
    case idle            = "Idle"
    case inMaintenance   = "In Maintenance"
    case outOfService    = "Out of Service"
    case decommissioned  = "Decommissioned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineMint
        case .busy:           SierraTheme.Colors.warning
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var backgroundColor: Color {
        dotColor.opacity(0.12)
    }

    var foregroundColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineDark
        case .busy:           SierraTheme.Colors.warning
        case .idle:           SierraTheme.Colors.granite
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var icon: String? {
        switch self {
        case .active:         "truck.box.fill"
        case .busy:           "bolt.fill"
        case .idle:           "parkingsign.circle"
        case .inMaintenance:  "wrench.fill"
        case .outOfService:   "xmark.octagon.fill"
        case .decommissioned: "archivebox.fill"
        }
    }

    var showsDot: Bool { true }

    /// Convenience: border accent color (used on VehicleCard left border).
    var accentBorderColor: Color { dotColor }
}
