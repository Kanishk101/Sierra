import XCTest
import CoreLocation
@testable import Sierra

final class DeviationDetectorTests: XCTestCase {

    // MARK: - Transition logic

    func test_transition_entersDeviationAboveThreshold() {
        let detector = DeviationDetector()
        XCTAssertFalse(detector.isDeviationActive)

        let result = detector.transition(for: 150) // > 120m threshold
        XCTAssertEqual(result, .enteredDeviation)
        XCTAssertTrue(detector.isDeviationActive)
    }

    func test_transition_staysOnRouteAtThreshold() {
        let detector = DeviationDetector()
        let result = detector.transition(for: 120) // exactly at threshold, not above
        XCTAssertEqual(result, .stayingOnRoute)
        XCTAssertFalse(detector.isDeviationActive)
    }

    func test_transition_staysOnRouteBelowThreshold() {
        let detector = DeviationDetector()
        let result = detector.transition(for: 50) // well below 120m
        XCTAssertEqual(result, .stayingOnRoute)
        XCTAssertFalse(detector.isDeviationActive)
    }

    func test_transition_exitsDeviationBelowRecovery() {
        let detector = DeviationDetector()
        // First enter deviation
        _ = detector.transition(for: 150)
        XCTAssertTrue(detector.isDeviationActive)

        // Then recover (< 80m)
        let result = detector.transition(for: 70)
        XCTAssertEqual(result, .exitedDeviation)
        XCTAssertFalse(detector.isDeviationActive)
    }

    func test_transition_staysOffRouteAboveRecovery() {
        let detector = DeviationDetector()
        // Enter deviation
        _ = detector.transition(for: 150)
        XCTAssertTrue(detector.isDeviationActive)

        // Still off route (> 80m, even if < 120m)
        let result = detector.transition(for: 100)
        XCTAssertEqual(result, .stayingOffRoute)
        XCTAssertTrue(detector.isDeviationActive)
    }

    // MARK: - Followup record cooldown

    func test_shouldRecordFollowup_respectsCooldown() {
        let detector = DeviationDetector()
        _ = detector.transition(for: 200)

        let coord = CLLocationCoordinate2D(latitude: 28.0, longitude: 77.0)
        let now = Date()
        detector.markDeviationRecorded(at: coord, deviationMetres: 200, now: now)

        // Too soon: only 10s later (< 20s interval)
        let farCoord = CLLocationCoordinate2D(latitude: 28.001, longitude: 77.001)
        let tooSoon = detector.shouldRecordFollowupSample(
            at: farCoord, deviationMetres: 250,
            now: now.addingTimeInterval(10)
        )
        XCTAssertFalse(tooSoon, "Should not record within 20s cooldown")

        // After cooldown: 25s later
        let afterCooldown = detector.shouldRecordFollowupSample(
            at: farCoord, deviationMetres: 250,
            now: now.addingTimeInterval(25)
        )
        XCTAssertTrue(afterCooldown, "Should record after cooldown expires")
    }

    func test_shouldRecordFollowup_requiresDeviationActive() {
        let detector = DeviationDetector()
        // Deviation is NOT active
        XCTAssertFalse(detector.isDeviationActive)

        let coord = CLLocationCoordinate2D(latitude: 28.0, longitude: 77.0)
        let result = detector.shouldRecordFollowupSample(at: coord, deviationMetres: 200)
        XCTAssertFalse(result, "Should not record when deviation is not active")
    }

    // MARK: - Distance from route

    func test_distanceFromRoute_onRouteReturnsSmallValue() {
        let detector = DeviationDetector()
        // A simple straight route from (0,0) to (0,0.001) — roughly 111m
        let routeCoords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.001)
        ]
        // Point right on the route midpoint
        let onRoute = CLLocationCoordinate2D(latitude: 0, longitude: 0.0005)
        let distance = detector.distanceFromRoute(location: onRoute, routeCoords: routeCoords)
        XCTAssertLessThan(distance, 5.0, "Point on route should have near-zero distance")
    }

    func test_distanceFromRoute_offRouteReturnsLargerValue() {
        let detector = DeviationDetector()
        let routeCoords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01) // ~1.1km
        ]
        // Point significantly off the route (0.002° latitude ≈ 222m)
        let offRoute = CLLocationCoordinate2D(latitude: 0.002, longitude: 0.005)
        let distance = detector.distanceFromRoute(location: offRoute, routeCoords: routeCoords)
        XCTAssertGreaterThan(distance, 100.0, "Point 200m off route should be detected")
    }

    func test_distanceFromRoute_insufficientCoordsReturnsMax() {
        let detector = DeviationDetector()
        let singleCoord = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        let distance = detector.distanceFromRoute(
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            routeCoords: singleCoord
        )
        XCTAssertEqual(distance, .greatestFiniteMagnitude)
    }
}

// MARK: - Equatable conformance for testing
extension DeviationDetector.Transition: Equatable {}
