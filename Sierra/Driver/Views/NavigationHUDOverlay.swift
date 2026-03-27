import SwiftUI
import Supabase
import CoreLocation

/// HUD overlay on top of TripNavigationView.
/// Shows instruction banner, stats, speed badge, off-route warning, and action bar.
struct NavigationHUDOverlay: View {

    let coordinator: TripNavigationCoordinator
    var onEndTrip: () -> Void

    @State private var showEndTripConfirm = false
    @State private var showSOSAlert = false
    @State private var showIncidentReport = false
    @State private var showFuelLog = false
    @State private var isVoiceMuted = false
    @State private var issueText = ""
    @State private var showIssueSentToast = false
    @State private var showIncidentBanner = true
    @State private var isEndingTrip = false
    @State private var endTripError: String?
    @State private var showFuelUnavailableAlert = false
    @State private var fuelUnavailableMessage = ""
    @State private var showAllDirections = false
    #if DEBUG
    // Debug simulation state kept for developer builds, but no in-UI trigger.
    @State private var showSimPanel = false
    @State private var simScrubValue: Double = 0
    #endif

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if !coordinator.currentStepInstruction.isEmpty {
                    instructionBanner
                }

                directionsPanel

                Spacer()

                // Off-route warning banner
                if coordinator.hasDeviated {
                    deviationBanner
                }

                // Speed + realtime issue + route progress (same row)
                HStack(alignment: .center, spacing: 10) {
                    speedBadge
                    if let incident = coordinator.trafficService.nearestIncident {
                        compactRealtimeIssueBadge(incident)
                    }
                    Spacer(minLength: 0)
                    if coordinator.hasRenderableRoute {
                        routeProgressBadge
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Stats row (below speed, above actions)
                statsRow

                // Action bar
                actionBar
            }
            .sheet(isPresented: $showSOSAlert) {
                SOSAlertSheet(
                    tripId: coordinator.trip.id,
                    vehicleId: UUID(uuidString: coordinator.trip.vehicleId ?? ""),
                    currentLocation: coordinator.currentLocation  // BUG-03 FIX
                )
            }
            .sheet(isPresented: $showFuelLog) {
                if let vehicleIdStr = coordinator.trip.vehicleId,
                   let vehicleId = UUID(uuidString: vehicleIdStr),
                   let driverId = AuthManager.shared.currentUser?.id {
                    FuelLogView(vehicleId: vehicleId, driverId: driverId, tripId: coordinator.trip.id)
                }
            }
            .alert("Fuel Log Unavailable", isPresented: $showFuelUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(fuelUnavailableMessage)
            }

            // Dark overlay modals
            if showEndTripConfirm {
                endTripModal
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(200)
            }

            if showIncidentReport {
                reportIssueModal
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(210)
            }

            if showIssueSentToast {
                issueSentToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(220)
            }

        }
    }

    // MARK: - Instruction Banner

    private var turnIndicatorPill: some View {
        HStack(spacing: 8) {
            Image(systemName: maneuverIcon(for: coordinator.currentStepManeuver.isEmpty
                                           ? coordinator.currentStepInstruction
                                           : coordinator.currentStepManeuver))
                .font(SierraFont.scaled(16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.appOrange, in: Circle())

            Text(shortTurnInstruction(coordinator.currentStepInstruction))
                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.98))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var instructionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: maneuverIcon(for: coordinator.currentStepManeuver.isEmpty
                                           ? coordinator.currentStepInstruction
                                           : coordinator.currentStepManeuver))
                .font(SierraFont.scaled(24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appOrange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(formatDistance(coordinator.distanceRemainingMetres))
                    .font(SierraFont.scaled(28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(coordinator.currentStepInstruction)
                    .font(SierraFont.scaled(15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                if !coordinator.nextStepInstruction.isEmpty {
                    Text("Then: \(coordinator.nextStepInstruction)")
                        .font(SierraFont.scaled(12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer()

            // Expand/collapse chevron
            Image(systemName: showAllDirections ? "chevron.up" : "chevron.down")
                .font(SierraFont.scaled(14, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 28, height: 28)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // Leave room for close button (left) and overview/compass stack (right).
        .padding(.leading, 64)
        .padding(.trailing, 64)
        .padding(.top, 44)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showAllDirections.toggle()
            }
        }
    }

    // MARK: - Expanded Directions Panel

    @ViewBuilder
    private var directionsPanel: some View {
        let steps = coordinator.allSteps
        let currentIdx = coordinator.currentStepIndex
        if showAllDirections, !steps.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("All Directions")
                        .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(steps.count) steps")
                        .font(SierraFont.scaled(12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Button {
                        withAnimation(.spring(response: 0.3)) { showAllDirections = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(SierraFont.scaled(20))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(steps) { step in
                                directionRow(step: step, isCurrent: step.id == currentIdx)
                                    .id(step.id)
                                if step.id != steps.last?.id {
                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onAppear {
                        proxy.scrollTo(currentIdx, anchor: .center)
                    }
                    .onChange(of: currentIdx) { _, newIdx in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIdx, anchor: .center)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.97))
                    .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func directionRow(step: RouteEngine.NavigationStepInfo, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: maneuverIcon(for: step.maneuverType))
                .font(SierraFont.scaled(16, weight: .bold))
                .foregroundColor(isCurrent ? .appOrange : .white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isCurrent ? Color.appOrange.opacity(0.2) : Color.white.opacity(0.06))
                )

            Text(step.instruction)
                .font(SierraFont.scaled(14, weight: isCurrent ? .bold : .medium, design: .rounded))
                .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
                .lineLimit(2)
            Spacer()

            Text(formatDistance(step.distance))
                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                .foregroundColor(isCurrent ? .appOrange : .white.opacity(0.45))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.appOrange.opacity(0.08) : Color.clear)
    }

    private func maneuverIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("left")    { return "arrow.turn.up.left" }
        if lower.contains("right")   { return "arrow.turn.up.right" }
        if lower.contains("u-turn")  { return "arrow.uturn.left" }
        if lower.contains("merge")   { return "arrow.merge" }
        if lower.contains("flyover") || lower.contains("overpass") { return "arrow.up.forward" }
        if lower.contains("roundabout") { return "arrow.triangle.2.circlepath" }
        if lower.contains("exit")    { return "arrow.triangle.turn.up.right.circle" }
        if lower.contains("arrive")  { return "mappin.circle.fill" }
        if lower.contains("depart")  { return "arrow.up.circle.fill" }
        return "arrow.up"
    }

    private func shortTurnInstruction(_ full: String) -> String {
        let text = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "Continue on route" }
        if text.count <= 46 { return text }
        let idx = text.index(text.startIndex, offsetBy: 46)
        return "\(text[..<idx])…"
    }

    private func formatDistance(_ metres: Double) -> String {
        if metres >= 1000 {
            return String(format: "%.1f km", metres / 1000)
        } else {
            return String(format: "%.0f m", metres)
        }
    }

    // MARK: - Incident Banner (GAP-1)

    private func incidentBanner(_ incident: TrafficIncident) -> some View {
        HStack(spacing: 10) {
            Image(systemName: incidentIcon(incident.severity))
                .font(SierraFont.scaled(18, weight: .bold))
                .foregroundStyle(incidentColor(incident.severity))
                .frame(width: 36, height: 36)
                .background(incidentColor(incident.severity).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.description)
                    .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let road = incident.roadName {
                        Text(road).font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                    if let dist = incident.distanceAheadMetres {
                        Text(formatDistance(dist))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(incidentColor(incident.severity))
                    }
                }
            }

            Spacer()

            Button {
                Task { await coordinator.rebuildRoutes() }
            } label: {
                Text("Reroute")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(incidentColor(incident.severity), in: Capsule())
            }

            Button {
                withAnimation(.spring(response: 0.3)) { showIncidentBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.14, green: 0.14, blue: 0.18))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(incidentColor(incident.severity).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func incidentIcon(_ severity: TrafficIncident.IncidentSeverity) -> String {
        switch severity {
        case .minor:    return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .major:    return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func incidentColor(_ severity: TrafficIncident.IncidentSeverity) -> Color {
        switch severity {
        case .minor:    return .yellow
        case .moderate: return .orange
        case .major:    return Color(red: 1.0, green: 0.3, blue: 0.2)
        case .critical: return .red
        }
    }

    // MARK: - Deviation Banner

    private var deviationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.black)
            Text("Off Route — Recalculating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
            Spacer()
            // ISSUE-25 FIX: Show spinner during reroute
            ProgressView()
                .tint(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.yellow)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statItem(
                value: String(format: "%.1f km", coordinator.distanceRemainingMetres / 1000),
                label: "Distance"
            )
            statItem(
                value: coordinator.estimatedArrivalTime?.formatted(.dateTime.hour().minute()) ?? "--:--",
                label: "ETA"
            )
            statItem(
                value: formatRemainingTime(coordinator.estimatedArrivalTime),
                label: "Remaining"
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func formatRemainingTime(_ eta: Date?) -> String {
        guard let eta else { return "0m" }
        let totalMinutes = max(0, Int(eta.timeIntervalSinceNow / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Speed Badge
    // Triple-tap opens the #if DEBUG simulator panel.
    private var speedBadge: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                .frame(width: 68, height: 68)
            VStack(spacing: 1) {
                Text(String(format: "%.0f", max(0, coordinator.currentSpeedKmh)))
                    .font(SierraFont.scaled(26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("km/h")
                    .font(SierraFont.scaled(10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("SOS", icon: "sos", color: SierraTheme.Colors.danger) {
                showSOSAlert = true
            }
            actionButton("Fuel", icon: "fuelpump.fill", color: .appOrange) {
                guard let vehicleIdStr = coordinator.trip.vehicleId,
                      UUID(uuidString: vehicleIdStr) != nil else {
                    fuelUnavailableMessage = "This trip is missing a valid vehicle assignment."
                    showFuelUnavailableAlert = true
                    return
                }
                guard AuthManager.shared.currentUser?.id != nil else {
                    fuelUnavailableMessage = "Your session is unavailable. Please sign in again."
                    showFuelUnavailableAlert = true
                    return
                }
                showFuelLog = true
            }
            actionButton("Incident", icon: "exclamationmark.triangle.fill", color: .appOrange) {
                showIncidentReport = true
            }
            actionButton("End Trip", icon: "xmark.circle", color: .red) {
                showEndTripConfirm = true
            }
            // Phase 10: Voice mute toggle
            actionButton(
                isVoiceMuted ? "Unmute" : "Mute",
                icon: isVoiceMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: isVoiceMuted ? Color.secondary : .blue
            ) {
                VoiceNavigationService.shared.toggleMute()
                isVoiceMuted = VoiceNavigationService.shared.isMutedState
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Route Progress

    private var routeProgressBadge: some View {
        let progress = coordinator.routeProgressFraction
        let pct = Int(progress * 100)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(pct)%")
                    .font(SierraFont.scaled(18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Route")
                    .font(SierraFont.scaled(10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                    .textCase(.uppercase)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.85, blue: 0.55), .appOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 132)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func compactRealtimeIssueBadge(_ incident: TrafficIncident) -> some View {
        HStack(spacing: 8) {
            Image(systemName: incidentIcon(for: incident))
                .font(SierraFont.scaled(13, weight: .bold))
                .foregroundStyle(incidentColor(incident.severity))
                .frame(width: 24, height: 24)
                .background(incidentColor(incident.severity).opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(shortIssueTitle(incident.description))
                    .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let dist = incident.distanceAheadMetres {
                    Text("\(formatDistance(dist)) ahead")
                        .font(SierraFont.scaled(10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                } else {
                    Text("Live incident")
                        .font(SierraFont.scaled(10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(incidentColor(incident.severity).opacity(0.30), lineWidth: 1)
        )
    }

    private func incidentIcon(for incident: TrafficIncident) -> String {
        let text = incident.description.lowercased()
        if text.contains("accident") || text.contains("collision") {
            return "car.rear.and.collision.road.lane"
        }
        if text.contains("crowd") || text.contains("congestion") || text.contains("traffic jam") {
            return "person.3.fill"
        }
        if text.contains("pothole") || text.contains("road damage") {
            return "triangle.fill"
        }
        return incidentIcon(incident.severity)
    }

    private func shortIssueTitle(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Road issue" }
        if cleaned.count <= 26 { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: 26)
        return "\(cleaned[..<idx])…"
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(SierraFont.scaled(16, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(SierraFont.scaled(10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    // MARK: - End Trip Modal

    private var endTripModal: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isEndingTrip {
                        withAnimation(.spring(response: 0.3)) { showEndTripConfirm = false }
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "flag.checkered")
                                .font(SierraFont.scaled(18, weight: .bold))
                                .foregroundColor(Color.red.opacity(0.95))
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("End Navigation")
                            .font(SierraFont.scaled(22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Delivery options will open next.")
                            .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                // Error
                if let err = endTripError {
                    Text(err)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.35))
                }

                // Buttons
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { showEndTripConfirm = false }
                        endTripError = nil
                    } label: {
                        Text("Cancel")
                            .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.17, green: 0.17, blue: 0.18)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isEndingTrip)

                    Button {
                        Task { await confirmEndTrip() }
                    } label: {
                        Group {
                            if isEndingTrip {
                                ProgressView().tint(.white)
                            } else {
                                Text("End Navigation")
                                    .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.95, green: 0.23, blue: 0.20))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isEndingTrip)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.98))
            )
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 108)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private func confirmEndTrip() async {
        isEndingTrip = true
        endTripError = nil
        withAnimation(.spring(response: 0.3)) { showEndTripConfirm = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onEndTrip()
        }
        isEndingTrip = false
    }

    // MARK: - Report Issue Modal

    private var reportIssueModal: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showIncidentReport = false
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appOrange.opacity(0.2))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(SierraFont.scaled(18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Report Issue")
                            .font(SierraFont.scaled(22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("This will be sent to admin while route continues.")
                            .font(SierraFont.scaled(12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                Text("Describe the issue")
                    .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $issueText)
                        .font(SierraFont.scaled(15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(height: 108)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.17))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    if issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Example: Road blocked due to accident near next turn")
                            .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showIncidentReport = false
                            issueText = ""
                        }
                    }) {
                        Text("Cancel")
                            .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: submitIssue) {
                        Text("Send")
                            .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.appOrange)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    // MARK: - Issue Sent Toast

    private var issueSentToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.circle.fill")
                    .font(SierraFont.scaled(16, weight: .bold))
                Text("Issue sent to admin. Continuing route.")
                    .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.appOrange))
            .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - Submit Issue

    private func submitIssue() {
        let text = issueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        issueText = ""
        withAnimation(.spring(response: 0.3)) { showIncidentReport = false }

        Task {
            guard let driverId = AuthManager.shared.currentUser?.id else { return }
            do {
                struct ActivityPayload: Encodable {
                    let type: String
                    let title: String
                    let description: String
                    let actor_id: String
                    let entity_type: String
                    let entity_id: String
                    let severity: String
                    let is_read: Bool
                    let timestamp: String
                }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                try await supabase
                    .from("activity_logs")
                    .insert(ActivityPayload(
                        type: "incident_report",
                        title: "Driver Incident Report",
                        description: text,
                        actor_id: driverId.uuidString,
                        entity_type: "trip",
                        entity_id: coordinator.trip.id.uuidString,
                        severity: "warning",
                        is_read: false,
                        timestamp: iso.string(from: Date())
                    ))
                    .execute()
                struct FMIdRow: Decodable { let id: UUID }
                let fmRows: [FMIdRow] = try await supabase
                    .from("staff_members")
                    .select("id")
                    .eq("role", value: "fleetManager")
                    .eq("status", value: "Active")
                    .execute()
                    .value
                for fm in fmRows {
                    try? await NotificationService.insertNotification(
                        recipientId: fm.id,
                        type: .defectAlert,
                        title: "Driver Incident Report",
                        body: "Trip \(coordinator.trip.taskId): \(text.prefix(100))",
                        entityType: "trip",
                        entityId: coordinator.trip.id
                    )
                }
                // Inject locally so the badge appears immediately
                if let loc = coordinator.currentLocation?.coordinate {
                    coordinator.trafficService.addLocalIncident(
                        description: text,
                        coordinate: loc
                    )
                }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) { showIssueSentToast = true }
                }
            } catch {
                print("[HUD] Incident report failed: \(error)")
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) { showIssueSentToast = true }
                }
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { showIssueSentToast = false }
            }
        }
    }

    // MARK: - #if DEBUG Simulator Panel
    #if DEBUG
    private var debugSimPanel: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { withAnimation { showSimPanel = false } }
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                // Title
                HStack {
                    Label("Route Simulator", systemImage: "ladybug.fill")
                        .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("DEBUG ONLY")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.yellow.opacity(0.6))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.12), in: Capsule())
                }

                // Progress label
                HStack {
                    Text(String(format: "Progress: %.0f%%", coordinator.simulationProgress * 100))
                        .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(coordinator.simulated ? "▶ Running" : "⏸ Paused")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(coordinator.simulated ? .green : .orange)
                }

                // Scrubber
                Slider(
                    value: Binding(
                        get: { simScrubValue },
                        set: { newVal in
                            simScrubValue = newVal
                            coordinator.scrubSimulation(to: newVal)
                        }
                    ),
                    in: 0...1
                )
                .tint(.yellow)

                // Controls
                HStack(spacing: 12) {
                    Button {
                        coordinator.resetSimulation()
                    } label: {
                        Label("Reset", systemImage: "backward.end.fill")
                            .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if coordinator.simulated { coordinator.stopSimulation() }
                        else { coordinator.startSimulation() }
                        simScrubValue = coordinator.simulationProgress
                    } label: {
                        Label(coordinator.simulated ? "Stop" : "Play",
                              systemImage: coordinator.simulated ? "stop.fill" : "play.fill")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(coordinator.simulated ? Color.red : Color.yellow,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation { showSimPanel = false }
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.98))
            )
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 108)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
        .onAppear { simScrubValue = coordinator.simulationProgress }
        .onChange(of: coordinator.simulationProgress) { _, newVal in
            guard !coordinator.simulated else { return }
            simScrubValue = newVal
        }
    }
    #endif
}
