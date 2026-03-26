import XCTest
@testable import Sierra

final class AuthManagerTests: XCTestCase {

    // MARK: - TC-AUTH-003, TC-AUTH-004, TC-AUTH-005
    //
    // AuthManager (AuthManager.swift) declares these private constants:
    //   Line 43: private let otpValidSeconds: TimeInterval = 600
    //   Line 52: private let otpCooldownSeconds: TimeInterval = 30
    //   Line 49: private let autoLockSeconds: TimeInterval = 300
    //
    // AuthManager is @MainActor, so we verify the constant values via
    // MainActor.assumeIsolated to satisfy synchronous XCTestCase execution.

    // TC-AUTH-003
    func test_otpValidSeconds_is600() {
        MainActor.assumeIsolated {
            let mirror = Mirror(reflecting: AuthManager.shared)
            let value = mirror.children.first { $0.label == "otpValidSeconds" }?.value as? TimeInterval
            XCTAssertEqual(value, 600, "otpValidSeconds should be 600")
        }
    }

    // TC-AUTH-004
    func test_otpCooldownSeconds_is30() {
        MainActor.assumeIsolated {
            let mirror = Mirror(reflecting: AuthManager.shared)
            let value = mirror.children.first { $0.label == "otpCooldownSeconds" }?.value as? TimeInterval
            XCTAssertEqual(value, 30, "otpCooldownSeconds should be 30")
        }
    }

    // TC-AUTH-005
    func test_autoLockSeconds_is300() {
        MainActor.assumeIsolated {
            let mirror = Mirror(reflecting: AuthManager.shared)
            let value = mirror.children.first { $0.label == "autoLockSeconds" }?.value as? TimeInterval
            XCTAssertEqual(value, 300, "autoLockSeconds should be 300")
        }
    }
}
