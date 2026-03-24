import Foundation

// MARK: - CreateTripViewModel
// @MainActor @Observable — extracted from CreateTripView (Phase 13 MVVM refactor).
//
// STATUS LOGIC (FIXED):
// Trips are ALWAYS created as .pendingAcceptance with a 24-hour acceptance deadline.
// Previously they were created as .scheduled, meaning the FM had to manually tap
// "Dispatch to Driver" in TripDetailView, and drivers never saw a PendingAcceptance
// trip to accept.
//
// Now the create-trip wizard IS the dispatch action:
//   Step 1: route details  →  Step 2: driver  →  Step 3: vehicle  →  Step 4: geofences
//   → INSERT as PendingAcceptance + acceptance_deadline = now + 24h
//   → Driver sees it immediately in DriverTripsListView with Accept/Decline CTA
//
// The "Dispatch to Driver" button in TripDetailView still works for any Scheduled
// trips that exist (legacy data, or trips created without a driver).
//
// RESOURCE LOCKING:
// Resources are NOT marked Busy at creation time. The DB trigger fn_trip_status_change
// fires on status → Active and handles Busy/Idle atomically. PendingAcceptance and
// Accepted do not lock resources — the driver might still reject the trip.

@MainActor
@Observable
final class CreateTripViewModel {

    // MARK: - Step Navigation

    var currentStep = 1

    // MARK: - Step 1: Trip Details

    var origin = ""
    var destination = ""
    var scheduledDate = Date()
    var scheduledEndDate: Date = Date().addingTimeInterval(3600 * 8)
    var priority: TripPriority = .normal
    var notes = ""
    var selectedOrigin: GeocodedAddress?
    var selectedDestination: GeocodedAddress?
    var stops: [GeocodedAddress] = []
    var showOriginSearch = false
    var showDestinationSearch = false
    var showStopSearch = false

    // MARK: - Step 2: Driver

    var selectedDriverId: UUID?

    // MARK: - Step 3: Vehicle

    var selectedVehicleId: UUID?

    // MARK: - Step 4: Geofences

    var tripGeofences: [GeofenceCandidate] = []
    var editingGeofenceId: UUID?

    // MARK: - Submission State

    var createdTrip: Trip?
    var showSuccess = false
    var isCreating = false
    var errorMessage: String?
    var showError = false

    // MARK: - Validation

    var step1Valid: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && routeFieldValidationError(for: origin) == nil
            && routeFieldValidationError(for: destination) == nil
    }
    var step2Valid: Bool { selectedDriverId != nil }
    var step3Valid: Bool { selectedVehicleId != nil }
    var step4Valid: Bool { !tripGeofences.isEmpty }

    func routeFieldValidationError(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "This field is required." }
        if trimmed.count < 3 { return "Address is too short." }
        return nil
    }

    // MARK: - Suggestions

    func buildSuggestions() -> [(String, Double, Double)] {
        var list: [(String, Double, Double)] = []
        if let o = selectedOrigin  { list.append(("Origin: \(o.shortName)", o.latitude, o.longitude)) }
        for (i, stop) in stops.enumerated() { list.append(("Stop \(i+1): \(stop.shortName)", stop.latitude, stop.longitude)) }
        if let d = selectedDestination { list.append(("Destination: \(d.shortName)", d.latitude, d.longitude)) }
        return list
    }

    // MARK: - Geofence Helpers

    func hasGeofence(latitude: Double, longitude: Double) -> Bool {
        tripGeofences.contains { $0.latitude == latitude && $0.longitude == longitude }
    }

    func addGeofence(name: String, latitude: Double, longitude: Double) {
        guard !hasGeofence(latitude: latitude, longitude: longitude) else { return }
        tripGeofences.append(
            GeofenceCandidate(name: name, latitude: latitude, longitude: longitude)
        )
    }

    func removeGeofence(id: UUID) {
        guard let index = tripGeofences.firstIndex(where: { $0.id == id }) else { return }
        tripGeofences.remove(at: index)
    }

    // MARK: - Geocoding

    func geocodeAddress(_ address: String) async -> (Double, Double)? {
        guard !address.isEmpty,
              let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
              !token.isEmpty else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json?access_token=\(token)&limit=1&country=IN"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]]
            let geometry = features?.first?["geometry"] as? [String: Any]
            let coords = geometry?["coordinates"] as? [Double]
            if let lng = coords?[0], let lat = coords?[1] { return (lat, lng) }
        } catch {
            print("[CreateTrip] Geocoding failed: \(error)")
        }
        return nil
    }

    // MARK: - Create Trip

    func createTrip(store: AppDataStore) async {
        guard let driverId = selectedDriverId, let vehicleId = selectedVehicleId else { return }
        isCreating = true

        let originCoords: (Double, Double)?
        if let o = selectedOrigin { originCoords = (o.latitude, o.longitude) }
        else { originCoords = await geocodeAddress(origin.trimmingCharacters(in: .whitespaces)) }

        let destCoords: (Double, Double)?
        if let d = selectedDestination { destCoords = (d.latitude, d.longitude) }
        else { destCoords = await geocodeAddress(destination.trimmingCharacters(in: .whitespaces)) }

        // Missing C FIX: Fetch and store route polyline at creation time.
        // This ensures the stored-polyline fallback works for offline/token-less nav.
        var routePolyline: String? = nil
        if let origin = originCoords, let dest = destCoords {
            do {
                let routes = try await MapService.fetchRoutes(
                    originLat: origin.0, originLng: origin.1,
                    destLat: dest.0, destLng: dest.1
                )
                routePolyline = routes.first?.geometry
            } catch {
                print("[CreateTrip] Route polyline fetch failed (non-fatal): \(error)")
            }
        }

        do {
            // Validate driver
            guard let latestDriver = try await StaffMemberService.fetchStaffMember(id: driverId) else {
                errorMessage = "Selected driver no longer exists."; showError = true; isCreating = false; return
            }
            guard latestDriver.status == .active else {
                errorMessage = "Selected driver is not active."; showError = true; isCreating = false; return
            }
            if latestDriver.availability == .unavailable {
                errorMessage = "Selected driver is currently offline. Ask them to mark themselves Available first."
                showError = true; isCreating = false; return
            }

            // Validate vehicle
            guard let latestVehicle = try await VehicleService.fetchVehicle(id: vehicleId) else {
                errorMessage = "Selected vehicle no longer exists."; showError = true; isCreating = false; return
            }
            if latestVehicle.status == .inMaintenance {
                errorMessage = "Selected vehicle is currently in maintenance."; showError = true; isCreating = false; return
            }

            // Authoritative time-based overlap check
            // (now includes PendingAcceptance + Accepted — migration 20260323000001)
            let conflict = try await TripService.checkOverlap(
                driverId: driverId, vehicleId: vehicleId,
                start: scheduledDate, end: scheduledEndDate
            )
            if conflict.driverConflict {
                errorMessage = "This driver already has a trip in that time window."
                showError = true; isCreating = false; return
            }
            if conflict.vehicleConflict {
                errorMessage = "This vehicle is already assigned in that time window."
                showError = true; isCreating = false; return
            }

            // Hard guard — never fall back to random UUID
            guard let adminId = AuthManager.shared.currentUser?.id else {
                errorMessage = "No authenticated session. Please sign in again."
                showError = true; isCreating = false; return
            }

            let now = Date()
            let acceptanceDeadline = now.addingTimeInterval(24 * 3600)

            let routeStops: [RouteStop] = stops.enumerated().map { index, addr in
                RouteStop(name: addr.shortName, latitude: addr.latitude, longitude: addr.longitude, order: index + 1)
            }

            let trip = Trip(
                id: UUID(), taskId: TripService.newTaskId(),
                driverId: driverId.uuidString, vehicleId: vehicleId.uuidString,
                createdByAdminId: adminId.uuidString,
                origin: origin.trimmingCharacters(in: .whitespaces),
                destination: destination.trimmingCharacters(in: .whitespaces),
                originLatitude: originCoords?.0, originLongitude: originCoords?.1,
                destinationLatitude: destCoords?.0, destinationLongitude: destCoords?.1,
                routePolyline: routePolyline, routeStops: routeStops.isEmpty ? nil : routeStops,
                deliveryInstructions: "",
                scheduledDate: scheduledDate, scheduledEndDate: scheduledEndDate,
                actualStartDate: nil, actualEndDate: nil,
                startMileage: nil, endMileage: nil,
                notes: notes,
                // FIXED: always PendingAcceptance — driver selects accept/reject next
                status: .pendingAcceptance,
                priority: priority,
                proofOfDeliveryId: nil, preInspectionId: nil, postInspectionId: nil,
                acceptanceDeadline: acceptanceDeadline,
                driverRating: nil, driverRatingNote: nil, ratedById: nil, ratedAt: nil,
                createdAt: now, updatedAt: now
            )

            try await store.addTrip(trip)
            // NOTE: do NOT manually mark resources Busy here.
            // The DB trigger fn_trip_status_change fires on status → Active.
            // PendingAcceptance does not lock resources (driver might reject).

            createdTrip = trip

            // Create associated geofences
            for gf in tripGeofences {
                let geofence = Geofence(
                    id: UUID(), name: gf.name,
                    description: "Trip \(trip.taskId) — \(gf.geofenceType.rawValue) zone",
                    latitude: gf.latitude, longitude: gf.longitude,
                    radiusMeters: gf.radiusMeters, isActive: true,
                    createdByAdminId: adminId,
                    alertOnEntry: gf.alertOnEntry, alertOnExit: gf.alertOnExit,
                    geofenceType: gf.geofenceType, createdAt: Date(), updatedAt: Date()
                )
                try? await store.addGeofence(geofence)
            }

            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isCreating = false
    }
}
