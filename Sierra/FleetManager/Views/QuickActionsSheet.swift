import SwiftUI

// MARK: - QuickActionDestination
// Used to signal non-creation navigations to AdminDashboardView so we avoid modal-over-modal.
enum QuickActionDestination {
    case alerts
    case reports
    case geofences
    case notifications
}

struct QuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    /// Called when the user selects a navigation-only action (Alerts, Reports, Geofences, Notifications).
    var onNavigate: (QuickActionDestination) -> Void

    @State private var showCreateTrip        = false
    @State private var showAddVehicle        = false
    @State private var showCreateStaff       = false
    @State private var showCreateMaintenance = false

    private struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
        let tag: String
    }

    private let actions: [QuickAction] = [
        QuickAction(icon: "arrow.triangle.swap",          label: "Create Trip",         color: .blue,   tag: "trip"),
        QuickAction(icon: "car.badge.gearshape",          label: "Add Vehicle",         color: .green,  tag: "vehicle"),
        QuickAction(icon: "person.badge.plus",            label: "Add Staff",           color: .indigo, tag: "staff"),
        QuickAction(icon: "wrench.and.screwdriver.fill",  label: "Maint. Request",      color: .orange, tag: "maintenance"),
        QuickAction(icon: "chart.bar.fill",               label: "View Reports",        color: .purple, tag: "reports"),
        QuickAction(icon: "bell.badge.fill",              label: "View Alerts",         color: .red,    tag: "alerts"),
        QuickAction(icon: "mappin.and.ellipse",           label: "View Geofences",      color: .teal,   tag: "geofences"),
        QuickAction(icon: "tray.full.fill",               label: "Notifications",       color: .gray,   tag: "notifications"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color(.separator))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Quick Actions")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                ForEach(actions) { action in
                    Button { handle(action.tag) } label: {
                        VStack(spacing: 16) {
                            Image(systemName: action.icon)
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(action.color)
                                .frame(width: 52, height: 52)
                                .background(action.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text(action.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // Creation sheets — shown after dismiss delay to avoid double-sheet jitter
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateStaff) {
            CreateStaffView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateMaintenance) {
            NavigationStack {
                MaintenanceRequestsView()
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Action Handler

    private func handle(_ tag: String) {
        switch tag {
        // Navigation-only actions — dismiss first, then let parent navigate
        case "alerts":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                onNavigate(.alerts)
            }
        case "reports":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                onNavigate(.reports)
            }
        case "geofences":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                onNavigate(.geofences)
            }
        case "notifications":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                onNavigate(.notifications)
            }

        // Creation actions — dismiss self, then present the creation sheet after a brief delay
        case "trip":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showCreateTrip = true
            }
        case "vehicle":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showAddVehicle = true
            }
        case "staff":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showCreateStaff = true
            }
        case "maintenance":
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showCreateMaintenance = true
            }
        default:
            dismiss()
        }
    }
}

#Preview {
    QuickActionsSheet(onNavigate: { _ in })
        .environment(AppDataStore.shared)
}
