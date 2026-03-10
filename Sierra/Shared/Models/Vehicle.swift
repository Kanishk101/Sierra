import Foundation

enum VehicleStatus: String, CaseIterable {
    case active = "Active"
    case inMaintenance = "In Maintenance"
    case idle = "Idle"
}

struct Vehicle: Identifiable {
    let id: UUID
    let name: String
    let model: String
    let licensePlate: String
    var status: VehicleStatus
    let year: Int
    var documentsExpiringSoon: Bool

    static let samples: [Vehicle] = [
        Vehicle(id: UUID(), name: "Hauler Alpha", model: "Volvo FH16", licensePlate: "FL-1024", status: .active, year: 2024, documentsExpiringSoon: true),
        Vehicle(id: UUID(), name: "City Runner", model: "Mercedes Sprinter", licensePlate: "FL-2048", status: .active, year: 2023, documentsExpiringSoon: false),
        Vehicle(id: UUID(), name: "Cargo One", model: "MAN TGX", licensePlate: "FL-3072", status: .inMaintenance, year: 2022, documentsExpiringSoon: false),
        Vehicle(id: UUID(), name: "Express Van", model: "Ford Transit", licensePlate: "FL-4096", status: .idle, year: 2025, documentsExpiringSoon: true),
        Vehicle(id: UUID(), name: "Tank Mover", model: "Scania R500", licensePlate: "FL-5120", status: .active, year: 2024, documentsExpiringSoon: false),
        Vehicle(id: UUID(), name: "Route Master", model: "DAF XF", licensePlate: "FL-6144", status: .active, year: 2023, documentsExpiringSoon: false),
        Vehicle(id: UUID(), name: "Cold Chain", model: "Isuzu NQR", licensePlate: "FL-7168", status: .inMaintenance, year: 2021, documentsExpiringSoon: true),
    ]
}
