import Foundation

// MARK: - RouteStop
// Represents an intermediate waypoint within a trip.
// Stored as a JSONB array in trips.route_stops.
// Format: [{"name":"Stop Name","latitude":12.34,"longitude":56.78,"order":1}]

struct RouteStop: Codable, Equatable, Identifiable {
    var id: UUID = UUID()   // local only — not persisted to DB
    var name: String
    var latitude: Double
    var longitude: Double
    var order: Int

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, order
        // id is NOT encoded — it's a local rendering key only
    }

    init(name: String, latitude: Double, longitude: Double, order: Int) {
        self.name      = name
        self.latitude  = latitude
        self.longitude = longitude
        self.order     = order
    }

    // Custom decoder so we can assign a fresh UUID without it being in the JSON
    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        name      = try c.decode(String.self,  forKey: .name)
        latitude  = try c.decode(Double.self,  forKey: .latitude)
        longitude = try c.decode(Double.self,  forKey: .longitude)
        order     = try c.decode(Int.self,     forKey: .order)
        id        = UUID()
    }
}
