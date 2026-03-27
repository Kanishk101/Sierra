import XCTest
import CoreLocation
import MapKit
@testable import Sierra

@MainActor
final class FleetLiveMapViewModelTests: XCTestCase {

    // MARK: - Filter Logic

    func test_filteredVehicles_activeFilter() {
        let vm = FleetLiveMapViewModel()
        vm.selectedFilter = .active

        let activeVehicle = makeVehicle(status: .active)
        let busyVehicle = makeVehicle(status: .busy)
        let idleVehicle = makeVehicle(status: .idle)
        let maintenanceVehicle = makeVehicle(status: .inMaintenance)

        let activeTrip = makeTrip(vehicleId: activeVehicle.id, status: "active")
        let busyTrip = makeTrip(vehicleId: busyVehicle.id, status: "active")

        let all = [activeVehicle, busyVehicle, idleVehicle, maintenanceVehicle]
        let result = vm.filteredVehicles(from: all, trips: [activeTrip, busyTrip])

        // Active filter should include vehicles that are active/busy
        XCTAssertTrue(result.contains(where: { $0.id == activeVehicle.id }))
        XCTAssertFalse(result.contains(where: { $0.id == idleVehicle.id }))
        XCTAssertFalse(result.contains(where: { $0.id == maintenanceVehicle.id }))
    }

    func test_filteredVehicles_allFilter() {
        let vm = FleetLiveMapViewModel()
        vm.selectedFilter = .all

        let vehicles = [
            makeVehicle(status: .active),
            makeVehicle(status: .idle),
            makeVehicle(status: .inMaintenance)
        ]
        let result = vm.filteredVehicles(from: vehicles)
        XCTAssertEqual(result.count, vehicles.count, "All filter should return all vehicles")
    }

    func test_filteredVehicles_idleFilter() {
        let vm = FleetLiveMapViewModel()
        vm.selectedFilter = .idle

        let idleVehicle = makeVehicle(status: .idle)
        let activeVehicle = makeVehicle(status: .active)

        let result = vm.filteredVehicles(from: [idleVehicle, activeVehicle])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, idleVehicle.id)
    }

    func test_filteredVehicles_maintenanceFilter() {
        let vm = FleetLiveMapViewModel()
        vm.selectedFilter = .inMaintenance

        let maintVehicle = makeVehicle(status: .inMaintenance)
        let idleVehicle = makeVehicle(status: .idle)

        let result = vm.filteredVehicles(from: [maintVehicle, idleVehicle])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, maintVehicle.id)
    }

    // MARK: - Coordinate Validation

    func test_coordinate_validVehicleReturnsCoordinate() {
        let vm = FleetLiveMapViewModel()
        var vehicle = makeVehicle(status: .active)
        vehicle.currentLatitude = 28.6139
        vehicle.currentLongitude = 77.2090

        let coord = vm.coordinate(for: vehicle)
        XCTAssertNotNil(coord)
        XCTAssertEqual(coord?.latitude ?? 0, 28.6139, accuracy: 0.0001)
        XCTAssertEqual(coord?.longitude ?? 0, 77.2090, accuracy: 0.0001)
    }

    func test_coordinate_nilLatLngReturnsNil() {
        let vm = FleetLiveMapViewModel()
        let vehicle = makeVehicle(status: .idle) // no lat/lng
        let coord = vm.coordinate(for: vehicle)
        XCTAssertNil(coord, "Vehicle without coordinates should return nil")
    }

    func test_coordinate_fallbackUsedWhenNoDirectCoords() {
        let vm = FleetLiveMapViewModel()
        let vehicle = makeVehicle(status: .active)

        // Set a fallback coordinate
        vm.fallbackCoordinates[vehicle.id] = FleetLiveMapViewModel.FallbackLocation(
            coordinate: CLLocationCoordinate2D(latitude: 28.5, longitude: 77.1),
            recordedAt: Date()
        )

        let coord = vm.coordinate(for: vehicle)
        XCTAssertNotNil(coord, "Should use fallback when vehicle has no direct coordinates")
    }

    // MARK: - Speed Segments

    func test_speedSegments_emptyForSinglePoint() {
        let vm = FleetLiveMapViewModel()
        vm.breadcrumbHistory = [
            makeLocationHistory(lat: 28.0, lng: 77.0, speed: 30)
        ]
        XCTAssertTrue(vm.speedSegments.isEmpty, "Need at least 2 points for segments")
    }

    func test_speedSegments_singleBucketProducesOneSegment() {
        let vm = FleetLiveMapViewModel()
        vm.breadcrumbHistory = [
            makeLocationHistory(lat: 28.0, lng: 77.0, speed: 30),
            makeLocationHistory(lat: 28.001, lng: 77.001, speed: 35),
            makeLocationHistory(lat: 28.002, lng: 77.002, speed: 40)
        ]
        // All speeds in same bucket (20-60), should produce 1 segment
        XCTAssertEqual(vm.speedSegments.count, 1)
    }

    // MARK: - Helpers

    private func makeVehicle(status: VehicleStatus) -> Vehicle {
        Vehicle(
            id: UUID(),
            organizationId: UUID(),
            name: "Test Vehicle",
            licensePlate: "TEST-001",
            make: "Toyota",
            model: "Hilux",
            year: 2024,
            vin: "TEST123456789",
            status: status,
            fuelType: .diesel,
            currentLatitude: nil,
            currentLongitude: nil,
            assignedDriverId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeTrip(vehicleId: UUID, status: String) -> Trip {
        Trip(
            id: UUID(),
            organizationId: UUID(),
            vehicleId: vehicleId.uuidString,
            driverId: UUID().uuidString,
            originName: "Origin",
            originLatitude: 28.0,
            originLongitude: 77.0,
            destinationName: "Destination",
            destinationLatitude: 29.0,
            destinationLongitude: 78.0,
            scheduledDate: Date(),
            status: TripStatus(rawValue: status) ?? .active,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeLocationHistory(lat: Double, lng: Double, speed: Double) -> VehicleLocationHistory {
        VehicleLocationHistory(
            id: UUID(),
            vehicleId: UUID(),
            tripId: nil,
            driverId: nil,
            latitude: lat,
            longitude: lng,
            speedKmh: speed,
            recordedAt: Date()
        )
    }
}
