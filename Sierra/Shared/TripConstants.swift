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

    // MARK: - Navigation Constants (Phase 7)

    /// Minimum seconds between reroute attempts to prevent rapid-fire requests.
    static let rerouteCooldownSeconds: TimeInterval = 30

    /// Seconds between traffic incident API polls.
    static let incidentPollIntervalSeconds: TimeInterval = 90

    /// Buffer around the route bounding box for incident queries (km).
    static let incidentBufferKm: Double = 2.0

    /// Distance ahead (metres) at which a severe incident triggers auto-reroute.
    static let autoRerouteProximityMetres: Double = 1000
}
