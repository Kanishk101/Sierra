import SwiftUI

/// Canonical admin maintenance screen.
/// Uses the same UI/flow as VehicleListView's Maintenance segment.
struct MaintenanceRequestsView: View {
    var body: some View {
        MaintenanceHubView()
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.large)
    }
}
