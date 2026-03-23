import Foundation
import CoreLocation

// MARK: - GeofenceMonitor
// Extracted from TripNavigationCoordinator. Handles CLCircularRegion
// registration & geofence-event insert + fleet-manager notification fan-out.

@MainActor
final class GeofenceMonitor {

    // MARK: - Register

    /// Registers the nearest 20 active geofences for monitoring.
    func register(
        _ geofences: [Geofence],
        locationManager: CLLocationManager,
        currentLocation: CLLocation?
    ) {
        // Clear previous regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        let driverCoord = currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629)
        let driverLoc = CLLocation(latitude: driverCoord.latitude, longitude: driverCoord.longitude)

        let active = geofences
            .filter { $0.isActive }
            .sorted {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: driverLoc)
                < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: driverLoc)
            }

        for geofence in active.prefix(20) {
            let center = CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            )
            let region = CLCircularRegion(
                center: center,
                radius: geofence.radiusMeters,
                identifier: geofence.id.uuidString
            )
            region.notifyOnEntry = geofence.alertOnEntry
            region.notifyOnExit  = geofence.alertOnExit
            locationManager.startMonitoring(for: region)
        }
    }

    // MARK: - Stop Monitoring

    func stopMonitoring(locationManager: CLLocationManager) {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    // MARK: - Handle Event

    func handleGeofenceEvent(
        geofenceId: UUID,
        eventType: String,
        vehicleIdStr: String,
        tripId: UUID,
        currentLocation: CLLocation?
    ) async {
        guard let vehicleId = UUID(uuidString: vehicleIdStr) else { return }

        // BUG-10 FIX: Never generate a random UUID for a driver ID
        guard let driverId = AuthManager.shared.currentUser?.id else {
            print("[GeofenceMonitor] No auth user — skipping event record")
            return
        }

        // BUG-07 FIX: Guard against nil location — don't write (0,0) to DB
        guard let location = currentLocation,
              (location.coordinate.latitude != 0 || location.coordinate.longitude != 0) else {
            print("[GeofenceMonitor] GPS unavailable — deferring event record")
            return
        }

        do {
            try await GeofenceEventService.addGeofenceEvent(GeofenceEvent(
                id: UUID(),
                geofenceId: geofenceId,
                vehicleId: vehicleId,
                tripId: tripId,
                driverId: driverId,
                eventType: eventType == "Entry" ? .entry : .exit,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                triggeredAt: Date(),
                createdAt: Date()
            ))
        } catch {
            print("[GeofenceMonitor] Event insert failed: \(error)")
        }

        // Notify all fleet managers
        let fmIds = AppDataStore.shared.staff
            .filter { $0.role == .fleetManager && $0.status == .active }
            .map { $0.id }
        for fmId in fmIds {
            try? await NotificationService.insertNotification(
                recipientId: fmId,
                type: .geofenceAlert,
                title: "Geofence \(eventType)",
                body: "Vehicle \(vehicleIdStr) \(eventType == "Entry" ? "entered" : "exited") a monitored zone",
                entityType: "geofence",
                entityId: geofenceId
            )
        }
    }
}
