import Foundation

/// Centralized constants for trip-related thresholds.
/// BUG-12 FIX: Eliminates hardcoded duplicate values across files.
enum TripConstants {
    /// How long a driver has to accept/reject a dispatched trip (24 hours).
    static let acceptanceDeadlineSeconds: TimeInterval = 24 * 3600

    /// Window before scheduled departure during which the driver's availability toggle is blocked (30 minutes).
    static let driverBlockWindowSeconds: TimeInterval = 30 * 60

    /// Minimum distance (metres) the driver must travel along the polyline before step detection fires again.
    /// ISSUE-13 FIX: Prevents rapid step-change oscillation near roundabouts.
    static let stepChangeHysteresisMetres: Double = 30

    /// OTP validity window in seconds (10 minutes).
    static let otpExpirySeconds: TimeInterval = 600
}
