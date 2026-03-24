import Foundation
import CoreLocation

// MARK: - TrafficIncident
// GAP-1: Live traffic incident model for display in HUD and map overlay.

struct TrafficIncident: Identifiable, Codable, Equatable {
    let id: String
    let description: String
    let severity: IncidentSeverity
    let coordinate: IncidentCoordinate
    let roadName: String?
    let startTime: Date?
    let endTime: Date?

    /// Distance from the driver's current position along the route (metres).
    /// Computed at poll time, not stored from API.
    var distanceAheadMetres: Double?

    enum IncidentSeverity: String, Codable, Comparable {
        case minor, moderate, major, critical

        private var rank: Int {
            switch self {
            case .minor:    return 0
            case .moderate: return 1
            case .major:    return 2
            case .critical: return 3
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
    }

    struct IncidentCoordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}
