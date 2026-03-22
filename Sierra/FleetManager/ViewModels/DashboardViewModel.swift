import SwiftUI
import Foundation

// MARK: - DashboardViewModel
// Extracted from DashboardHomeView — Phase 8 MVVM refactor.
// All computed properties delegate to AppDataStore so the view stays declarative.

@MainActor
@Observable
final class DashboardViewModel {

    private let store: AppDataStore

    init(store: AppDataStore) {
        self.store = store
    }

    // MARK: - KPI Values

    var vehicleCount: Int { store.vehicles.count }
    var activeTripsCount: Int { store.activeTripsCount }
    var pendingApplicationsCount: Int { store.pendingApplicationsCount }
    var activeAlertsCount: Int { store.activeEmergencyAlerts().count }
    var inMaintenanceCount: Int { store.vehicles.filter { $0.status == .inMaintenance }.count }
    var availableDriversCount: Int {
        store.staff.filter { $0.role == .driver && $0.status == .active && $0.availability == .available }.count
    }

    // MARK: - Loading

    var isLoading: Bool { store.isLoading }

    // MARK: - Donut Slices

    var fleetSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.vehicles.filter { $0.status == .active }.count),        .green),
            (Double(store.vehicles.filter { $0.status == .idle }.count),          .blue),
            (Double(store.vehicles.filter { $0.status == .inMaintenance }.count), .orange),
            (Double(store.vehicles.filter { $0.status == .outOfService }.count),  .red)
        ]
        return s.filter { $0.0 > 0 }
    }

    var tripSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.trips.filter { $0.status == .active }.count),    .green),
            (Double(store.trips.filter { $0.status == .scheduled }.count), .blue),
            (Double(store.trips.filter { $0.status == .completed }.count), Color.secondary),
            (Double(store.trips.filter { $0.status == .cancelled }.count), .red)
        ]
        return s.filter { $0.0 > 0 }
    }

    var staffSlices: [(Double, Color)] {
        let s: [(Double, Color)] = [
            (Double(store.staff.filter { $0.role == .driver && $0.status == .active }.count),              .blue),
            (Double(store.staff.filter { $0.role == .maintenancePersonnel && $0.status == .active }.count),.orange),
            (Double(store.staff.filter { $0.status == .pendingApproval }.count),                           .yellow)
        ]
        return s.filter { $0.0 > 0 }
    }

    // MARK: - Monthly Sparkline Data

    var monthlyData: [MonthlyTripData] {
        let calendar  = Calendar.current
        let now       = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().compactMap { offset -> MonthlyTripData? in
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: now),
                  let range      = calendar.dateInterval(of: .month, for: monthStart) else { return nil }
            let count = store.trips.filter { range.contains($0.scheduledDate) }.count
            return MonthlyTripData(month: formatter.string(from: monthStart),
                                   year:  calendar.component(.year, from: monthStart),
                                   count: count,
                                   date:  range.start)
        }
    }

    // MARK: - Document Health

    var validDocCount:    Int { store.vehicleDocuments.filter { !$0.isExpiringSoon && !$0.isExpired }.count }
    var expiringDocCount: Int { store.vehicleDocuments.filter { $0.isExpiringSoon && !$0.isExpired }.count }
    var expiredDocCount:  Int { store.vehicleDocuments.filter { $0.isExpired }.count }
    var activeStaffCount: Int { store.staff.filter { $0.status == .active }.count }

    // MARK: - Lists

    var recentTrips: [Trip] {
        Array(store.trips.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var expiringDocs: [VehicleDocument] {
        store.documentsExpiringSoon()
    }

    // MARK: - Fleet Management Counts

    var pendingMaintenanceCount: Int { store.maintenanceTasks.filter { $0.status == .pending }.count }
    var activeGeofenceCount: Int { store.geofences.filter { $0.isActive }.count }
}
