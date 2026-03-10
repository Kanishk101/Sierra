import Foundation

enum ActivityType: String {
    case trip = "Trip"
    case maintenance = "Maintenance"
    case fuel = "Fuel"
    case staff = "Staff"
    case alert = "Alert"
}

struct ActivityLog: Identifiable {
    let id: UUID
    let type: ActivityType
    let description: String
    let timestamp: Date

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    static let samples: [ActivityLog] = [
        ActivityLog(id: UUID(), type: .trip, description: "Hauler Alpha completed delivery to Dock 7", timestamp: Date().addingTimeInterval(-300)),
        ActivityLog(id: UUID(), type: .maintenance, description: "Cargo One scheduled for brake inspection", timestamp: Date().addingTimeInterval(-1800)),
        ActivityLog(id: UUID(), type: .fuel, description: "City Runner refuelled — 62L diesel", timestamp: Date().addingTimeInterval(-3600)),
        ActivityLog(id: UUID(), type: .staff, description: "David Park submitted driver application", timestamp: Date().addingTimeInterval(-7200)),
        ActivityLog(id: UUID(), type: .alert, description: "Express Van insurance expires in 5 days", timestamp: Date().addingTimeInterval(-10800)),
    ]
}
