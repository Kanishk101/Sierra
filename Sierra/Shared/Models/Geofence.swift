import Foundation

// MARK: - Geofence

struct Geofence: Identifiable, Codable {
    let id: UUID                  // SQL: geofence_id
    var name: String              // SQL: name
    var latitude: Double          // SQL: latitude
    var longitude: Double         // SQL: longitude
    var radius: Int               // SQL: radius (metres)
    var description: String       // SQL: description
    var createdAt: Date           // SQL: created_at

    // MARK: - Mock Data

    static let mockData: [Geofence] = [
        Geofence(
            id: UUID(),
            name: "Mumbai Warehouse",
            latitude: 19.0760,
            longitude: 72.8777,
            radius: 500,
            description: "Main dispatch warehouse, Mumbai",
            createdAt: Date().addingTimeInterval(-86400 * 30)
        ),
        Geofence(
            id: UUID(),
            name: "Pune Distribution Center",
            latitude: 18.5204,
            longitude: 73.8567,
            radius: 300,
            description: "Delivery hub, Pune",
            createdAt: Date().addingTimeInterval(-86400 * 20)
        ),
        Geofence(
            id: UUID(),
            name: "Delhi Hub",
            latitude: 28.6139,
            longitude: 77.2090,
            radius: 750,
            description: "Northern region dispatch point",
            createdAt: Date().addingTimeInterval(-86400 * 10)
        ),
    ]
}
