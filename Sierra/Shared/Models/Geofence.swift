import Foundation

// MARK: - Geofence Type
// Maps to PostgreSQL enum: geofence_type

enum GeofenceType: String, Codable, CaseIterable {
    case warehouse      = "Warehouse"
    case deliveryPoint  = "Delivery Point"
    case restrictedZone = "Restricted Zone"
    case custom         = "Custom"
}

// MARK: - Geofence
// Maps to table: geofences

struct Geofence: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var name: String                     // name
    var description: String              // description (default '')
    var latitude: Double                 // latitude
    var longitude: Double                // longitude
    var radiusMeters: Double             // radius_meters

    // MARK: Settings
    var isActive: Bool                   // is_active
    var createdByAdminId: UUID           // created_by_admin_id (FK → staff_members.id)
    var alertOnEntry: Bool               // alert_on_entry
    var alertOnExit: Bool                // alert_on_exit

    // MARK: Type
    var geofenceType: GeofenceType = .custom  // geofence_type (default 'Custom')

    // MARK: Timestamps
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case latitude
        case longitude
        case radiusMeters        = "radius_meters"
        case isActive            = "is_active"
        case createdByAdminId    = "created_by_admin_id"
        case alertOnEntry        = "alert_on_entry"
        case alertOnExit         = "alert_on_exit"
        case geofenceType        = "geofence_type"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }

    // MARK: - Mock Data

    static let mockData: [Geofence] = [
        Geofence(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!,
            name: "Mumbai Warehouse",
            description: "Main dispatch warehouse, Mumbai",
            latitude: 19.0760,
            longitude: 72.8777,
            radiusMeters: 500.0,
            isActive: true,
            createdByAdminId: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!,
            alertOnEntry: true,
            alertOnExit: true,
            geofenceType: .warehouse,
            createdAt: Date().addingTimeInterval(-86400 * 30),
            updatedAt: Date().addingTimeInterval(-86400 * 30)
        ),
        Geofence(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!,
            name: "Pune Distribution Center",
            description: "Delivery hub, Pune",
            latitude: 18.5204,
            longitude: 73.8567,
            radiusMeters: 300.0,
            isActive: true,
            createdByAdminId: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!,
            alertOnEntry: true,
            alertOnExit: true,
            geofenceType: .deliveryPoint,
            createdAt: Date().addingTimeInterval(-86400 * 20),
            updatedAt: Date().addingTimeInterval(-86400 * 20)
        ),
        Geofence(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000003")!,
            name: "Delhi Hub",
            description: "Northern region dispatch point",
            latitude: 28.6139,
            longitude: 77.2090,
            radiusMeters: 750.0,
            isActive: true,
            createdByAdminId: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!,
            alertOnEntry: true,
            alertOnExit: false,
            geofenceType: .custom,
            createdAt: Date().addingTimeInterval(-86400 * 10),
            updatedAt: Date().addingTimeInterval(-86400 * 10)
        ),
    ]
}
