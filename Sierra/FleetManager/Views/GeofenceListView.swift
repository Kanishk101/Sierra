import SwiftUI

/// Geofence list — view, toggle, delete only.
/// Create geofence is available ONLY within the trip creation flow, not from here.
struct GeofenceListView: View {

    @State private var vm = GeofenceViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if vm.isLoading && vm.geofences.isEmpty {
                Section {
                    HStack { Spacer(); ProgressView("Loading geofences\u{2026}"); Spacer() }.padding(.vertical, 20)
                }
            }
            if !vm.geofences.isEmpty {
                ForEach(vm.geofences) { geofence in
                    geofenceRow(geofence)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { vm.deleteConfirmationTarget = geofence } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            if !vm.isLoading && vm.geofences.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash").font(SierraFont.scaled(40, weight: .light)).foregroundStyle(.secondary.opacity(0.5))
                        Text("No geofences configured").font(.subheadline).foregroundStyle(.secondary)
                        Text("Geofences are created within the trip creation flow.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Geofences")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        // No + button — create geofence is only in trip creation flow
        .task { await vm.loadGeofences() }
        .refreshable { await vm.loadGeofences() }
        .confirmationDialog("Delete Geofence?", isPresented: .init(get: { vm.deleteConfirmationTarget != nil }, set: { if !$0 { vm.deleteConfirmationTarget = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let g = vm.deleteConfirmationTarget { Task { await vm.delete(g) } } }
            Button("Cancel", role: .cancel) { vm.deleteConfirmationTarget = nil }
        } message: { Text("This will permanently remove the geofence and all its event history.") }
        .alert("Error", isPresented: .constant(vm.error != nil)) { Button("OK") { vm.error = nil } } message: { Text(vm.error ?? "") }
    }

    private func geofenceRow(_ geofence: Geofence) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(geofence.isActive ? SierraTheme.Colors.alpineMint.opacity(0.15) : Color.gray.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: geofenceIcon(geofence.geofenceType)).font(SierraFont.scaled(16, weight: .semibold)).foregroundStyle(geofence.isActive ? SierraTheme.Colors.alpineMint : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(geofence.name).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(geofence.geofenceType.rawValue); Text("\u{00B7}"); Text(formatRadius(geofence.radiusMeters))
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: .init(get: { geofence.isActive }, set: { _ in Task { await vm.toggleActive(geofence) } }))
                .labelsHidden().tint(SierraTheme.Colors.alpineMint)
                .accessibilityLabel("\(geofence.name) geofence status")
                .accessibilityHint("Enables or disables this geofence")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func geofenceIcon(_ type: GeofenceType) -> String {
        switch type { case .warehouse: return "building.2.fill"; case .deliveryPoint: return "shippingbox.fill"; case .restrictedZone: return "exclamationmark.shield.fill"; case .custom: return "mappin.circle.fill" }
    }
    private func formatRadius(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters))m radius"
    }
}
