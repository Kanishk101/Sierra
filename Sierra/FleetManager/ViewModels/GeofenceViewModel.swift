import Foundation

/// ViewModel for the Fleet Manager geofence list — CRUD operations.
/// Uses `GeofenceService` (static methods) for all Supabase interactions.
@Observable
final class GeofenceViewModel {

    var geofences: [Geofence] = []
    var isLoading = false
    var error: String? = nil
    var showCreateSheet = false
    var deleteConfirmationTarget: Geofence? = nil

    // MARK: - Load

    func loadGeofences() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            geofences = try await GeofenceService.fetchAllGeofences()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Toggle Active

    func toggleActive(_ geofence: Geofence) async {
        do {
            try await GeofenceService.toggleGeofence(id: geofence.id, isActive: !geofence.isActive)
            await loadGeofences()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(_ geofence: Geofence) async {
        do {
            try await GeofenceService.deleteGeofence(id: geofence.id)
            geofences.removeAll { $0.id == geofence.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
