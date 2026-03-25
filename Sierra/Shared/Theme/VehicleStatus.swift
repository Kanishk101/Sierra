import SwiftUI

// MARK: - Vehicle Status
// Maps to PostgreSQL enum: vehicle_status
// Values: Active | Idle | Busy | In Maintenance | Out of Service | Decommissioned

enum VehicleStatus: String, SierraStatus, CaseIterable, Codable {
    case active          = "Active"
    case idle            = "Idle"
    case busy            = "Busy"
    case inMaintenance   = "In Maintenance"
    case outOfService    = "Out of Service"
    case decommissioned  = "Decommissioned"

    // MARK: - SierraStatus

    var label: String { rawValue }

    var dotColor: Color {
        switch self {
        case .active:         SierraTheme.Colors.alpineMint
        case .idle:           SierraTheme.Colors.granite
        case .busy:           SierraTheme.Colors.ember
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
        case .idle:           SierraTheme.Colors.granite
        case .busy:           SierraTheme.Colors.emberDark
        case .inMaintenance:  SierraTheme.Colors.warning
        case .outOfService:   SierraTheme.Colors.danger
        case .decommissioned: SierraTheme.Colors.danger
        }
    }

    var icon: String? {
        switch self {
        case .active:         "truck.box.fill"
        case .idle:           "parkingsign.circle"
        case .busy:           "road.lanes"
        case .inMaintenance:  "wrench.fill"
        case .outOfService:   "xmark.octagon.fill"
        case .decommissioned: "archivebox.fill"
        }
    }

    var showsDot: Bool { true }

    /// Convenience: border accent color (used on VehicleCard left border).
    var accentBorderColor: Color { dotColor }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let parsed = Self.parse(raw) {
            self = parsed
        } else {
            self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func parse(_ raw: String) -> VehicleStatus? {
        if let exact = VehicleStatus(rawValue: raw) { return exact }

        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "active": return .active
        case "idle": return .idle
        case "busy": return .busy
        case "in maintenance", "inmaintenance": return .inMaintenance
        case "out of service", "outofservice": return .outOfService
        case "decommissioned": return .decommissioned
        default: return nil
        }
    }
}
