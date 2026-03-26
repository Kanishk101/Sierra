import XCTest
@testable import Sierra

final class TripModelTests: XCTestCase {

    // MARK: - TC-TRIP-008

    // TC-TRIP-008
    func test_isOverdue_whenScheduledAndPastDate_returnsTrue() {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let trip = Trip.makeTest(scheduledDate: pastDate, status: .scheduled)
        XCTAssertTrue(trip.isOverdue)
    }

    // TC-TRIP-008
    func test_isOverdue_whenActive_returnsFalse() {
        let pastDate = Date().addingTimeInterval(-3600)
        let trip = Trip.makeTest(scheduledDate: pastDate, status: .active)
        XCTAssertFalse(trip.isOverdue)
    }

    // MARK: - TC-TRIP-009

    // TC-TRIP-009
    func test_durationString_90minutes_returns1h30m() {
        let start = Date()
        let end = start.addingTimeInterval(90 * 60) // 90 minutes
        let trip = Trip.makeTest(actualStartDate: start, actualEndDate: end)
        XCTAssertEqual(trip.durationString, "1h 30m")
    }

    // TC-TRIP-009
    func test_durationString_45minutes_returnsNoHoursSegment() {
        let start = Date()
        let end = start.addingTimeInterval(45 * 60) // 45 minutes
        let trip = Trip.makeTest(actualStartDate: start, actualEndDate: end)
        XCTAssertEqual(trip.durationString, "45m")
    }

    // TC-TRIP-009
    func test_durationString_nilWhenNoDates() {
        let trip = Trip.makeTest(actualStartDate: nil, actualEndDate: nil)
        XCTAssertNil(trip.durationString)
    }

    // MARK: - TC-DATA-003

    // TC-DATA-003
    func test_distanceKm_returnsCorrectValue() {
        let trip = Trip.makeTest(startMileage: 100.0, endMileage: 250.0)
        XCTAssertEqual(trip.distanceKm, 150.0)
    }

    // TC-DATA-003
    func test_distanceKm_returnsNilWhenMileageMissing() {
        let trip = Trip.makeTest(startMileage: nil, endMileage: nil)
        XCTAssertNil(trip.distanceKm)
    }

    // MARK: - TC-EDGE-005

    // TC-EDGE-005
    func test_driverUUID_invalidString_returnsNil() {
        let trip = Trip.makeTest(driverId: "not-a-uuid")
        XCTAssertNil(trip.driverUUID)
    }

    // TC-EDGE-005
    func test_driverUUID_validString_returnsUUID() {
        let uuidString = "D0000000-0000-0000-0000-000000000001"
        let trip = Trip.makeTest(driverId: uuidString)
        XCTAssertEqual(trip.driverUUID, UUID(uuidString: uuidString))
    }

    // MARK: - TC-TRIP-001

    // TC-TRIP-001
    func test_generateTaskId_matchesExpectedFormat() {
        let taskId = Trip.generateTaskId()
        // Format: TRP-yyyyMMdd-####
        let pattern = #"^TRP-\d{8}-\d{4}$"#
        XCTAssertNotNil(taskId.range(of: pattern, options: .regularExpression),
                        "taskId '\(taskId)' should match TRP-yyyyMMdd-####")
    }

    // MARK: - TC-TRIP-006 (status logic)

    // TC-TRIP-006
    func test_tripStatus_active_isActionable() {
        XCTAssertTrue(TripStatus.active.isActionable)
    }

    // TC-TRIP-006
    func test_tripStatus_completed_notActionable() {
        XCTAssertFalse(TripStatus.completed.isActionable)
    }

    // TC-TRIP-006
    func test_tripStatus_scheduled_colorIsBlue() {
        XCTAssertEqual(TripStatus.scheduled.color, "blue")
    }

    // TC-TRIP-006
    func test_tripStatus_active_colorIsGreen() {
        XCTAssertEqual(TripStatus.active.color, "green")
    }

    // TC-TRIP-006
    func test_tripStatus_cancelled_colorIsRed() {
        XCTAssertEqual(TripStatus.cancelled.color, "red")
    }
}
