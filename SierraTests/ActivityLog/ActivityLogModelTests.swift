import XCTest
@testable import Sierra

final class ActivityLogModelTests: XCTestCase {

    private func makeLog(timestamp: Date) -> ActivityLog {
        ActivityLog(
            id: UUID(),
            type: .tripStarted,
            title: "Test",
            description: "Test log",
            actorId: nil,
            entityType: "trip",
            entityId: nil,
            severity: .info,
            isRead: false,
            timestamp: timestamp,
            createdAt: timestamp
        )
    }

    // MARK: - TC-LOG-004

    // TC-LOG-004
    func test_timeAgo_30SecondsAgo_returnsJustNow() {
        let log = makeLog(timestamp: Date().addingTimeInterval(-30))
        XCTAssertEqual(log.timeAgo, "Just now")
    }

    // TC-LOG-004
    func test_timeAgo_45MinutesAgo_returns45mAgo() {
        let log = makeLog(timestamp: Date().addingTimeInterval(-45 * 60))
        XCTAssertEqual(log.timeAgo, "45m ago")
    }

    // TC-LOG-004
    func test_timeAgo_3HoursAgo_returns3hAgo() {
        let log = makeLog(timestamp: Date().addingTimeInterval(-3 * 3600))
        XCTAssertEqual(log.timeAgo, "3h ago")
    }

    // TC-LOG-004
    func test_timeAgo_2DaysAgo_returns2dAgo() {
        let log = makeLog(timestamp: Date().addingTimeInterval(-2 * 86400))
        XCTAssertEqual(log.timeAgo, "2d ago")
    }

    // TC-LOG-004
    func test_activityType_tripStarted_rawValue() {
        XCTAssertEqual(ActivityType.tripStarted.rawValue, "Trip Started")
    }

    // TC-LOG-004
    func test_activityType_emergencyAlert_rawValue() {
        XCTAssertEqual(ActivityType.emergencyAlert.rawValue, "Emergency Alert")
    }

    // TC-LOG-004
    func test_activitySeverity_critical_rawValue() {
        XCTAssertEqual(ActivitySeverity.critical.rawValue, "Critical")
    }
}
