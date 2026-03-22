import Foundation

// MARK: - CreateTripViewModel
// @MainActor @Observable — extracted from CreateTripView (Phase 13 MVVM refactor).
// Contains all form state, validation logic, conflict checking, geocoding, and submission logic.
// Store is injected via method parameters, not init.

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

    // MARK: - Busy-Resource Validation

    private func busyResourceValidationError(resourceLabel: String, trips: [Trip], newTripStart: Date) -> String? {
        let blockingTrips = trips.filter { $0.status == .active || $0.status == .scheduled }
        guard !blockingTrips.isEmpty else {
            return "Selected \(resourceLabel) is marked Busy. Please resolve the current assignment first."
        }
        let explicitEndTimes = blockingTrips.compactMap { $0.actualEndDate ?? $0.scheduledEndDate }
        guard let latestEnd = explicitEndTimes.max() else {
            return "Selected \(resourceLabel) is Busy and has no explicit trip end time."
        }
        if latestEnd > newTripStart {
            let endText = latestEnd.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
            return "Selected \(resourceLabel) is Busy until \(endText). Choose another or a later departure."
        }
        return nil
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

        do {
            guard let latestDriver = try await StaffMemberService.fetchStaffMember(id: driverId) else {
                errorMessage = "Selected driver no longer exists."; showError = true; isCreating = false; return
            }
            guard latestDriver.status == .active else {
                errorMessage = "Selected driver is not active."; showError = true; isCreating = false; return
            }
            if latestDriver.availability != .available && latestDriver.availability != .busy {
                errorMessage = "Selected driver is unavailable."; showError = true; isCreating = false; return
            }
            if latestDriver.availability == .busy {
                let driverTrips = try await TripService.fetchTrips(driverId: driverId)
                if let err = busyResourceValidationError(resourceLabel: "driver", trips: driverTrips, newTripStart: scheduledDate) {
                    errorMessage = err; showError = true; isCreating = false; return
                }
            }

            guard let latestVehicle = try await VehicleService.fetchVehicle(id: vehicleId) else {
                errorMessage = "Selected vehicle no longer exists."; showError = true; isCreating = false; return
            }
            if latestVehicle.status == .busy {
                let vehicleTrips = try await TripService.fetchTrips(vehicleId: vehicleId)
                if let err = busyResourceValidationError(resourceLabel: "vehicle", trips: vehicleTrips, newTripStart: scheduledDate) {
                    errorMessage = err; showError = true; isCreating = false; return
                }
            }

            let conflict = try await TripService.checkOverlap(
                driverId: driverId, vehicleId: vehicleId,
                start: scheduledDate, end: scheduledEndDate
            )
            if conflict.driverConflict {
                errorMessage = "This driver already has a trip in that time slot."; showError = true; isCreating = false; return
            }
            if conflict.vehicleConflict {
                errorMessage = "This vehicle is already assigned in that time slot."; showError = true; isCreating = false; return
            }

            let adminId = AuthManager.shared.currentUser?.id ?? UUID()
            let now = Date()

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
                routePolyline: nil, routeStops: routeStops.isEmpty ? nil : routeStops,
                deliveryInstructions: "",
                scheduledDate: scheduledDate, scheduledEndDate: scheduledEndDate,
                actualStartDate: nil, actualEndDate: nil,
                startMileage: nil, endMileage: nil,
                notes: notes, status: .scheduled, priority: priority,
                proofOfDeliveryId: nil, preInspectionId: nil, postInspectionId: nil,
                driverRating: nil, driverRatingNote: nil, ratedById: nil, ratedAt: nil,
                createdAt: now, updatedAt: now
            )

            try await store.addTrip(trip)

            if scheduledDate <= now {
                try await TripService.markResourcesBusy(driverId: driverId, vehicleId: vehicleId)
                if var v = store.vehicle(for: vehicleId) { v.status = .busy; v.assignedDriverId = driverId.uuidString; try? await store.updateVehicle(v) }
                if var d = store.staffMember(for: driverId) { d.availability = .busy; try? await store.updateStaffMember(d) }
            }

            createdTrip = trip

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
