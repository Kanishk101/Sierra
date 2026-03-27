import Foundation
import CoreLocation

/// ViewModel extracted from SOSAlertSheet — manages SOS alert submission.
/// Safeguard 1: `sentSuccessfully` prevents duplicate submissions.
/// Safeguard 2: GPS validated before submission — blocks if unavailable (BUG-03 fix).
@Observable
final class SOSAlertViewModel {

    var alertType: EmergencyAlertType = .sos
    var descriptionText = ""
    var isSending = false
    var sentSuccessfully = false
    var error: String? = nil
    var gpsRetryCount = 0

    /// BUG-03 / BUG-10 FIX: Never generate a random UUID as a driver ID.
    /// Returns nil if auth session has expired.
    var currentUserId: UUID? { AuthManager.shared.currentUser?.id }

    /// BUG-03 FIX: Accept an external CLLocation (from the active TripNavigationCoordinator)
    /// instead of creating a standalone CLLocationManager that has no delegate or auth.
    func triggerSOS(vehicleId: UUID?, tripId: UUID?, store: AppDataStore, currentLocation: CLLocation?) async {
        guard !sentSuccessfully && !isSending else { return }

        // BUG-10 FIX: Block submission if auth user is nil
        guard let driverId = currentUserId else {
            error = "Session expired. Please log in again."
            return
        }

        isSending = true

        // BUG-03 FIX: Use externally-provided location from TripNavigationCoordinator
        let latitude: Double
        let longitude: Double

        if let loc = currentLocation,
           loc.coordinate.latitude != 0 || loc.coordinate.longitude != 0 {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
        } else if gpsRetryCount < 5 {
            gpsRetryCount += 1
            isSending = false
            error = "Acquiring GPS location... Please wait and try again."
            return
        } else {
            // BUG-03 FIX: Block submission entirely instead of allowing (0,0)
            isSending = false
            error = "Unable to determine your location after multiple attempts. Please ensure Location Services are enabled and try again."
            return
        }

        do {
            let alert = EmergencyAlert(
                id: UUID(),
                driverId: driverId,
                tripId: tripId,
                vehicleId: vehicleId,
                latitude: latitude,
                longitude: longitude,
                alertType: alertType,
                status: .active,
                description: descriptionText.isEmpty ? nil : descriptionText,
                acknowledgedBy: nil,
                acknowledgedAt: nil,
                resolvedAt: nil,
                triggeredAt: Date(),
                createdAt: Date()
            )

            try await EmergencyAlertService.addEmergencyAlert(alert)
            await MainActor.run {
                if !store.emergencyAlerts.contains(where: { $0.id == alert.id }) {
                    store.emergencyAlerts.insert(alert, at: 0)
                }
            }

            let notifType: NotificationType = (alertType == .defect) ? .defectAlert : .sosAlert
            await NotificationService.sendToAdmins(
                type: notifType,
                title: "\(alertType.rawValue) Alert",
                body: "Driver emergency: \(alertType.rawValue)\(descriptionText.isEmpty ? "" : " — \(descriptionText)")",
                entityType: "emergency_alert",
                entityId: alert.id
            )

            sentSuccessfully = true
        } catch {
            isSending = false
            self.error = "Failed to send alert. Tap again to retry."
        }
    }
}
