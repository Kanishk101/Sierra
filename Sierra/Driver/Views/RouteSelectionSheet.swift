import SwiftUI
import MapboxDirections

/// Route picker shown after route build and before active navigation starts.
/// Presents up to 3 route options and a large GO action similar to native maps UX.
struct RouteSelectionSheet: View {

    let coordinator: TripNavigationCoordinator
    var onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int = 0
    @State private var isRebuildingRoutes = false

    private var choices: [RouteEngine.RouteChoice] {
        coordinator.routeChoices
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        routePreferenceToggles

                        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                            routeCard(
                                choice: choice,
                                index: index,
                                isSelected: selectedIndex == index
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                goButton
            }
            .padding(.top, 10)
            .navigationBarHidden(true)
        }
        .presentationDetents([.fraction(0.60), .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .onAppear {
            selectedIndex = min(max(0, coordinator.selectedRouteChoiceIndex), max(0, choices.count - 1))
        }
        .onChange(of: coordinator.routeChoices.count) { _, _ in
            selectedIndex = min(max(0, selectedIndex), max(0, choices.count - 1))
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Choose a Route")
                .font(.title3.weight(.bold))
            Text("Pick one option and tap GO")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var goButton: some View {
        Button {
            coordinator.selectRouteChoice(at: selectedIndex)
            coordinator.confirmRouteSelection()
            dismiss()
            onStart()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.green)
                    .frame(height: 88)

                Text("GO")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .disabled(choices.isEmpty || isRebuildingRoutes)
        .opacity((choices.isEmpty || isRebuildingRoutes) ? 0.5 : 1)
    }

    private var routePreferenceToggles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
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

            if isRebuildingRoutes {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Updating route options...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onChange(of: coordinator.avoidTolls) { _, _ in
            Task { await rebuildRouteChoicesForPreferences() }
        }
        .onChange(of: coordinator.avoidHighways) { _, _ in
            Task { await rebuildRouteChoicesForPreferences() }
        }
    }

    private func rebuildRouteChoicesForPreferences() async {
        guard !isRebuildingRoutes else { return }
        isRebuildingRoutes = true
        await coordinator.rebuildRoutes()
        selectedIndex = min(max(0, selectedIndex), max(0, choices.count - 1))
        isRebuildingRoutes = false
    }

    private func routeCard(
        choice: RouteEngine.RouteChoice,
        index: Int,
        isSelected: Bool
    ) -> some View {
        let route = choice.route
        let eta = Date().addingTimeInterval(route.expectedTravelTime)
        let baselineDistance = choices.first?.route.distance ?? route.distance
        let deltaKm = (baselineDistance - route.distance) / 1000

        return HStack(spacing: 12) {
            Image(systemName: icon(for: choice, index: index))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor(for: choice, index: index))
                .frame(width: 34, height: 34)
                .background(iconColor(for: choice, index: index).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title(for: choice, index: index))
                        .font(.subheadline.weight(.semibold))
                    if choice.isGreen {
                        Text("ECO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                }

                HStack(spacing: 10) {
                    Text(String(format: "%.1f km", route.distance / 1000))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(route.expectedTravelTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("ETA \(eta.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if choice.isGreen && deltaKm > 0.2 {
                    Text(String(format: "\u{2212}%.1f km vs fastest", deltaKm))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .secondary.opacity(0.45))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.green.opacity(0.10) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
    }

    private func title(for choice: RouteEngine.RouteChoice, index: Int) -> String {
        if choice.isFastest { return "Fastest" }
        if choice.isGreen { return "Green Route" }
        return "Route \(index + 1)"
    }

    private func icon(for choice: RouteEngine.RouteChoice, index: Int) -> String {
        if choice.isFastest { return "bolt.fill" }
        if choice.isGreen { return "leaf.fill" }
        return "point.topleft.down.curvedto.point.bottomright.up"
    }

    private func iconColor(for choice: RouteEngine.RouteChoice, index: Int) -> Color {
        if choice.isFastest { return .blue }
        if choice.isGreen { return .green }
        return .orange
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        if mins < 60 { return "\(mins) min" }
        let hrs = mins / 60
        let rem = mins % 60
        return rem == 0 ? "\(hrs) hr" : "\(hrs)h \(rem)m"
    }
}
