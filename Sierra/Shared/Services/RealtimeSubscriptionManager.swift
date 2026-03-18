import Foundation
import Supabase

/// Centralised realtime subscription manager — consolidates all Postgres channels
/// into a single lifecycle (startAll / stopAll).
///
/// Call `startAll(store:)` after successful auth, `stopAll()` on logout.
@MainActor
@Observable
final class RealtimeSubscriptionManager {

    static let shared = RealtimeSubscriptionManager()
    private var channels: [RealtimeChannelV2] = []
    private init() {}

    // MARK: - Start All

    func startAll(store: AppDataStore) {
        stopAll()  // clean up before restarting

        // 1. vehicle_location_history — live map feed
        subscribeToLocationHistory(store: store)

        // 2. route_deviation_events
        subscribeToRouteDeviations(store: store)

        // 3. geofence_events
        subscribeToGeofenceEvents(store: store)

        // 4. vehicles — live coordinate updates for FleetLiveMapView
        subscribeToVehicleUpdates(store: store)

        // 5. maintenance_tasks — update events
        subscribeToMaintenanceTasks(store: store)

        // 6. notifications
        subscribeToNotifications(store: store)
    }

    // MARK: - Stop All

    func stopAll() {
        for channel in channels {
            Task { await channel.unsubscribe() }
        }
        channels.removeAll()
    }

    // MARK: - Individual Channel Subscriptions

    private func subscribeToLocationHistory(store: AppDataStore) {
        let channel = supabase.channel("rt_vehicle_locations")
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "vehicle_location_history") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let loc = try? JSONDecoder().decode(VehicleLocationHistory.self, from: data) {
                    // Update the latest location for this vehicle
                    store.vehicleLocations[loc.vehicleId.uuidString] = loc
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] vehicle_locations error: \(error)") }
        }
        channels.append(channel)
    }

    private func subscribeToRouteDeviations(store: AppDataStore) {
        let channel = supabase.channel("rt_route_deviations")
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "route_deviation_events") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let dev = try? JSONDecoder().decode(RouteDeviationEvent.self, from: data) {
                    store.routeDeviationEvents.insert(dev, at: 0)
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] route_deviations error: \(error)") }
        }
        channels.append(channel)
    }

    private func subscribeToGeofenceEvents(store: AppDataStore) {
        let channel = supabase.channel("rt_geofence_events")
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "geofence_events") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let event = try? JSONDecoder().decode(GeofenceEvent.self, from: data) {
                    store.geofenceEvents.insert(event, at: 0)
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] geofence_events error: \(error)") }
        }
        channels.append(channel)
    }

    private func subscribeToVehicleUpdates(store: AppDataStore) {
        let channel = supabase.channel("rt_vehicles")
        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "vehicles") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                guard
                    let idValue = action.record["id"],
                    case let .string(idString) = idValue,
                    let vehicleId = UUID(uuidString: idString),
                    let idx = store.vehicles.firstIndex(where: { $0.id == vehicleId })
                else { return }

                if let lat = Self.doubleFromJSON(action.record["current_latitude"]) {
                    store.vehicles[idx].currentLatitude = lat
                }
                if let lng = Self.doubleFromJSON(action.record["current_longitude"]) {
                    store.vehicles[idx].currentLongitude = lng
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] vehicles error: \(error)") }
        }
        channels.append(channel)
    }

    private func subscribeToMaintenanceTasks(store: AppDataStore) {
        let channel = supabase.channel("rt_maintenance_tasks")
        _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "maintenance_tasks") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let updated = try? JSONDecoder().decode(MaintenanceTask.self, from: data) {
                    if let idx = store.maintenanceTasks.firstIndex(where: { $0.id == updated.id }) {
                        store.maintenanceTasks[idx] = updated
                    } else {
                        store.maintenanceTasks.insert(updated, at: 0)
                    }
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] maintenance_tasks error: \(error)") }
        }
        channels.append(channel)
    }

    private func subscribeToNotifications(store: AppDataStore) {
        let channel = supabase.channel("rt_notifications")
        _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "notifications") { [weak store] action in
            guard let store else { return }
            Task { @MainActor in
                if let data = try? JSONEncoder().encode(action.record),
                   let notif = try? JSONDecoder().decode(SierraNotification.self, from: data) {
                    store.notifications.insert(notif, at: 0)
                }
            }
        }
        Task {
            do { try await channel.subscribeWithError() } catch { print("[RealtimeManager] notifications error: \(error)") }
        }
        channels.append(channel)
    }

    private static func doubleFromJSON(_ value: AnyJSON?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .double(let d):
            return d
        case .integer(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }
}
