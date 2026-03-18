import Foundation
import CoreLocation
import SwiftUI

// MARK: - TripViewModel
//
// Single source of truth for the driver's entire trip lifecycle.
//
// Responsibilities:
//   • Hold the current active trip
//   • Start / end / cancel a trip via TripService
//   • Publish GPS locations via VehicleLocationService (throttle is in the service)
//   • Load assigned trips from Supabase
//   • Keep AppDataStore in sync after every mutation
//
// Rules enforced:
//   • NEVER manually update vehicle status — DB triggers handle it
//   • NEVER manually update driver availability — DB triggers handle it
//   • Location publishing delegates entirely to VehicleLocationService.shared

@MainActor
@Observable
final class TripViewModel {

    // MARK: - State

    /// The trip currently being driven. Nil when no trip is active.
    var activeTrip: Trip? = nil

    /// All trips assigned to the current driver (scheduled + active + history).
    var assignedTrips: [Trip] = []

    var isLoading: Bool = false
    var errorMessage: String? = nil

    /// Set to true after endTrip succeeds — view should navigate to trip history.
    var tripJustCompleted: Bool = false

    // MARK: - Private

    private let store = AppDataStore.shared

    // MARK: - Load Assigned Trips

    /// Fetches all trips for this driver from Supabase and syncs into AppDataStore.
    func loadAssignedTrips(driverId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let trips = try await TripService.fetchTrips(driverId: driverId)
            assignedTrips = trips
            // Sync into store so other views (DriverHomeView) reflect live data
            for trip in trips {
                store.updateTrip(trip)
            }
            // Restore activeTrip from loaded data if one is currently active
            if let active = trips.first(where: { $0.status == .active }) {
                activeTrip = active
            }
        } catch {
            errorMessage = "Failed to load trips: \(error.localizedDescription)"
            #if DEBUG
            print("🚗 [TripViewModel.loadAssignedTrips] Error: \(error)")
            #endif
        }
    }

    // MARK: - Start Trip

    /// Transitions a scheduled trip to active.
    /// - Parameters:
    ///   - trip: The trip to start (must be .scheduled)
    ///   - startMileage: Odometer reading recorded by the driver before departure
    /// - Note: Do NOT manually set vehicle/driver status here. DB trigger handles it.
    func startTrip(_ trip: Trip, startMileage: Double) async throws {
        guard trip.status == .scheduled else {
            throw TripError.invalidStatus("Trip must be Scheduled to start. Current: \(trip.status.rawValue)")
        }
        isLoading = true
        defer { isLoading = false }

        try await TripService.startTrip(tripId: trip.id, startMileage: startMileage)

        // Build updated local copy
        var updated = trip
        updated.status = .active
        updated.actualStartDate = Date()
        updated.startMileage = startMileage

        activeTrip = updated
        store.updateTrip(updated)

        // Refresh assigned list
        if let idx = assignedTrips.firstIndex(where: { $0.id == trip.id }) {
            assignedTrips[idx] = updated
        }

        #if DEBUG
        print("🚗 [TripViewModel.startTrip] Started trip \(trip.taskId)")
        #endif
    }

    // MARK: - End Trip (Complete)

    /// Completes the currently active trip.
    /// - Parameter endMileage: Odometer reading recorded by the driver on arrival
    /// - Note: Do NOT manually set vehicle/driver status here. DB trigger handles it.
    func endTrip(endMileage: Double) async throws {
        guard let trip = activeTrip else {
            throw TripError.noActiveTrip
        }
        guard trip.status == .active else {
            throw TripError.invalidStatus("Trip must be Active to end. Current: \(trip.status.rawValue)")
        }
        isLoading = true
        defer { isLoading = false }

        try await TripService.completeTrip(tripId: trip.id, endMileage: endMileage)

        var completed = trip
        completed.status = .completed
        completed.actualEndDate = Date()
        completed.endMileage = endMileage

        activeTrip = nil
        store.updateTrip(completed)

        if let idx = assignedTrips.firstIndex(where: { $0.id == trip.id }) {
            assignedTrips[idx] = completed
        }

        tripJustCompleted = true

        #if DEBUG
        print("🚗 [TripViewModel.endTrip] Completed trip \(trip.taskId)")
        #endif
    }

    // MARK: - Cancel Trip

    func cancelTrip() async throws {
        guard let trip = activeTrip ?? assignedTrips.first(where: { $0.status == .scheduled }) else {
            throw TripError.noActiveTrip
        }
        isLoading = true
        defer { isLoading = false }

        try await TripService.cancelTrip(tripId: trip.id)

        var cancelled = trip
        cancelled.status = .cancelled

        if activeTrip?.id == trip.id { activeTrip = nil }
        store.updateTrip(cancelled)

        if let idx = assignedTrips.firstIndex(where: { $0.id == trip.id }) {
            assignedTrips[idx] = cancelled
        }

        #if DEBUG
        print("🚗 [TripViewModel.cancelTrip] Cancelled trip \(trip.taskId)")
        #endif
    }

    // MARK: - Publish Location

    /// Publishes the driver's current GPS position to Supabase.
    /// Throttling (5s minimum interval) is enforced inside VehicleLocationService — no
    /// need to gate here. Call this freely from the navigation coordinator on every
    /// CLLocationManager update.
    func publishLocation(
        latitude: Double,
        longitude: Double,
        speedKmh: Double? = nil
    ) async {
        guard let trip = activeTrip,
              let vehicleUUID = trip.vehicleUUID,
              let driverUUID  = trip.driverUUID else { return }

        do {
            try await VehicleLocationService.shared.publishLocation(
                vehicleId: vehicleUUID,
                tripId: trip.id,
                driverId: driverUUID,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh
            )
        } catch {
            // Non-fatal — GPS publish failure should not interrupt the driver
            #if DEBUG
            print("📍 [TripViewModel.publishLocation] Publish failed (non-fatal): \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// The scheduled or active trip assigned to this driver (for DriverHomeView).
    var currentAssignment: Trip? {
        activeTrip ?? assignedTrips.first(where: { $0.status == .scheduled })
    }

    var hasActiveTrip: Bool {
        activeTrip != nil
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - TripError

enum TripError: LocalizedError {
    case noActiveTrip
    case invalidStatus(String)

    var errorDescription: String? {
        switch self {
        case .noActiveTrip:
            return "No active trip found."
        case .invalidStatus(let msg):
            return msg
        }
    }
}
