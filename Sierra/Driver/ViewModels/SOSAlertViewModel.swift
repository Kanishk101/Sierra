import Foundation
import CoreLocation

/// ViewModel extracted from SOSAlertSheet — manages SOS alert submission.
/// Safeguard 1: `sentSuccessfully` prevents duplicate submissions.
/// Safeguard 2: GPS validated before submission.
@Observable
final class SOSAlertViewModel {

    var alertType: EmergencyAlertType = .sos
    var descriptionText = ""
    var isSending = false
    var sentSuccessfully = false
    var error: String? = nil
    var gpsRetryCount = 0

    private let locationManager = CLLocationManager()

    var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    func triggerSOS(vehicleId: UUID?, tripId: UUID?, store: AppDataStore) async {
        guard !sentSuccessfully && !isSending else { return }
        isSending = true

        // Safeguard 2: GPS validation
        var latitude: Double = 0
        var longitude: Double = 0

        if let loc = locationManager.location,
           loc.coordinate.latitude != 0 || loc.coordinate.longitude != 0 {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
        } else if gpsRetryCount < 5 {
            gpsRetryCount += 1
            isSending = false
            error = "Acquiring GPS location... Please wait and try again."
            return
        }
        // After 5 retries, allow submission with (0,0) but warn

        do {
            let alert = EmergencyAlert(
                id: UUID(),
                driverId: currentUserId,
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

            // Notify all fleet managers
            let fms = store.staff.filter { $0.role == .fleetManager }
            let notifType: NotificationType = (alertType == .defect) ? .defectAlert : .sosAlert
            for fm in fms {
                do {
                    try await NotificationService.insertNotification(
                        recipientId: fm.id,
                        type: notifType,
                        title: "\(alertType.rawValue) Alert",
                        body: "Driver emergency: \(alertType.rawValue)\(descriptionText.isEmpty ? "" : " — \(descriptionText)")",
                        entityType: "emergency_alert",
                        entityId: alert.id
                    )
                } catch {
                    print("[SOS] Non-fatal: notification to FM \(fm.id) failed")
                }
            }

            sentSuccessfully = true
        } catch {
            isSending = false
            self.error = "Failed to send alert. Tap again to retry."
        }
    }
}
