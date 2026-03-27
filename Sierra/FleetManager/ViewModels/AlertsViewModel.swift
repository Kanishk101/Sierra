import Foundation
import Supabase

/// ViewModel for the Fleet Manager alerts inbox.
/// Unifies emergency alerts, route deviations, and overdue maintenance into a single model.
/// Replaces direct `@State` fetches in `AlertsInboxView`.
@Observable
final class AlertsViewModel {

    // MARK: - Data

    var emergencyAlerts: [EmergencyAlert] = []
    var routeDeviations: [RouteDeviationEvent] = []
    var isLoading = false
    var error: String? = nil

    // MARK: - Filter

    var selectedFilter: AlertFilter = .all

    enum AlertFilter: String, CaseIterable {
        case all = "All"
        case sos = "SOS"
        case deviation = "Route Deviation"
        case maintenance = "Overdue Maintenance"
    }

    // MARK: - Computed

    var activeAlerts: [EmergencyAlert] {
        let base = emergencyAlerts.filter { $0.status == .active }
        switch selectedFilter {
        case .all: return base
        case .sos: return base.filter { $0.alertType == .sos }
        case .deviation, .maintenance: return []
        }
    }

    var unacknowledgedDeviations: [RouteDeviationEvent] {
        let base = routeDeviations.filter { !$0.isAcknowledged }
        switch selectedFilter {
        case .all: return base
        case .deviation: return base
        case .sos, .maintenance: return []
        }
    }

    var unreadCount: Int {
        let unreadEmergency = emergencyAlerts.filter { $0.status == .active }.count
        let unreadDeviations = routeDeviations.filter { !$0.isAcknowledged }.count
        return unreadEmergency + unreadDeviations
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            emergencyAlerts = try await EmergencyAlertService.fetchAllEmergencyAlerts()
        } catch {
            print("[AlertsVM] Emergency alerts error: \(error)")
        }
        do {
            let deviations: [RouteDeviationEvent] = try await supabase
                .from("route_deviation_events")
                .select()
                .eq("is_acknowledged", value: false)
                .order("detected_at", ascending: false)
                .limit(50)
                .execute()
                .value
            routeDeviations = deviations
        } catch {
            print("[AlertsVM] Deviations error: \(error)")
        }
    }

    // MARK: - Actions

    func acknowledgeEmergency(id: UUID, by userId: UUID) async {
        do {
            try await EmergencyAlertService.acknowledgeAlert(id: id, acknowledgedBy: userId)
            if let idx = emergencyAlerts.firstIndex(where: { $0.id == id }) {
                emergencyAlerts[idx].status = .acknowledged
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
