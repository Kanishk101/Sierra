import XCTest
@testable import Sierra

final class VehicleModelTests: XCTestCase {

    // MARK: - TC-EDGE-002

    // TC-EDGE-002
    func test_fuelType_diesel_descriptionIsCorrect() {
        XCTAssertEqual(FuelType.diesel.description, "Diesel")
    }

    // TC-EDGE-002
    func test_fuelType_electric_descriptionIsCorrect() {
        XCTAssertEqual(FuelType.electric.description, "Electric")
    }

    // TC-EDGE-002
//    func test_assignedDriverUUID_invalidString_returnsNil() {
//        let vehicle = Vehicle.makeTest(assignedDriverId: "not-a-uuid")
//        XCTAssertNil(vehicle.assignedDriverUUID)
//    }
//
//    // TC-EDGE-002
//    func test_assignedDriverUUID_validString_returnsUUID() {
//        let uuidString = "D0000000-0000-0000-0000-000000000001"
//        let vehicle = Vehicle.makeTest(assignedDriverId: uuidString)
//        XCTAssertEqual(vehicle.assignedDriverUUID, UUID(uuidString: uuidString))
//    }

    // TC-EDGE-002
    func test_vehicleStatus_enumRawValues() {
        XCTAssertEqual(VehicleStatus.active.rawValue, "Active")
        XCTAssertEqual(VehicleStatus.idle.rawValue, "Idle")
        XCTAssertEqual(VehicleStatus.busy.rawValue, "Busy")
        XCTAssertEqual(VehicleStatus.inMaintenance.rawValue, "In Maintenance")
        XCTAssertEqual(VehicleStatus.outOfService.rawValue, "Out of Service")
        XCTAssertEqual(VehicleStatus.decommissioned.rawValue, "Decommissioned")
    }
}
