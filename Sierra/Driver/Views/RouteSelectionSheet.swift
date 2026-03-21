import SwiftUI
import MapboxDirections

/// Presented after buildRoutes() completes, before navigation starts.
/// Driver picks Fastest or Green (lowest distance / most fuel-efficient) route,
/// then taps Start Navigation. Location tracking only begins after confirmation.
struct RouteSelectionSheet: View {

    let coordinator: TripNavigationCoordinator
    /// Called when the driver confirms a route. Parent starts location tracking here.
    var onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIsGreen = false

    private var fastest: Route? { coordinator.currentRoute }
    private var green:   Route? { coordinator.alternativeRoute }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Choose Your Route")
                        .font(.title3.weight(.bold))
                    Text("Select the route that works best for your trip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if let f = fastest {
                        routeCard(
                            label: "Fastest",
                            badge: nil,
                            icon: "bolt.fill",
                            color: .blue,
                            distanceKm: f.distance / 1000,
                            durationSec: f.expectedTravelTime,
                            eta: Date().addingTimeInterval(f.expectedTravelTime),
                            savings: nil,
                            isSelected: !selectedIsGreen
                        ) {
                            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                                selectedIsGreen = false
                            }
                        }
                    }

                    if let g = green, let f = fastest {
                        let savedKm = (f.distance - g.distance) / 1000
                        routeCard(
                            label: "Green Route",
                            badge: "ECO",
                            icon: "leaf.fill",
                            color: .green,
                            distanceKm: g.distance / 1000,
                            durationSec: g.expectedTravelTime,
                            eta: Date().addingTimeInterval(g.expectedTravelTime),
                            savings: savedKm > 0.2 ? savedKm : nil,
                            isSelected: selectedIsGreen
                        ) {
                            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                                selectedIsGreen = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Toll / Highway toggles
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 24) {
                        Toggle(isOn: Binding(
                            get: { coordinator.avoidTolls },
                            set: { coordinator.avoidTolls = $0 }
                        )) {
                            Label("Avoid Tolls", systemImage: "indianrupeesign.square")
                                .font(.subheadline)
                        }
                        Toggle(isOn: Binding(
                            get: { coordinator.avoidHighways },
                            set: { coordinator.avoidHighways = $0 }
                        )) {
                            Label("Avoid Highways", systemImage: "road.lanes")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .onChange(of: coordinator.avoidTolls)    { _, _ in Task { await coordinator.rebuildRoutes() } }
                    .onChange(of: coordinator.avoidHighways) { _, _ in Task { await coordinator.rebuildRoutes() } }
                }

                // CTA
                Button {
                    if selectedIsGreen { coordinator.selectGreenRoute() }
                    dismiss()
                    onStart()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Start Navigation")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .disabled(coordinator.currentRoute == nil)
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // Prevent accidental swipe-down before the driver has confirmed a route
        .interactiveDismissDisabled()
    }

    // MARK: - Route Card

    private func routeCard(
        label: String,
        badge: String?,
        icon: String,
        color: Color,
        distanceKm: Double,
        durationSec: Double,
        eta: Date,
        savings: Double?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(color, in: Capsule())
                        }
                    }
                    HStack(spacing: 10) {
                        Text(String(format: "%.1f km", distanceKm))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(formatDuration(durationSec))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("ETA \(eta.formatted(.dateTime.hour().minute()))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let saved = savings {
                        Text(String(format: "\u{2212}%.1f km vs fastest \u{2022} Saves fuel", saved))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? color : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(
                isSelected ? color.opacity(0.07) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .animation(.spring(duration: 0.25, bounce: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        if mins < 60 { return "\(mins) min" }
        let hrs  = mins / 60
        let rem  = mins % 60
        return rem == 0 ? "\(hrs) hr" : "\(hrs)h \(rem)m"
    }
}
