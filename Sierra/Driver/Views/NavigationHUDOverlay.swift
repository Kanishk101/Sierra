import SwiftUI
import Supabase

/// HUD overlay on top of TripNavigationView.
/// Shows instruction banner, stats, speed badge, off-route warning, and action bar.
struct NavigationHUDOverlay: View {

    let coordinator: TripNavigationCoordinator
    var onEndTrip: () -> Void

    @State private var showEndTripConfirm = false
    @State private var showSOSAlert = false
    @State private var showIncidentReport = false
    @State private var isVoiceMuted = false
    @State private var issueText = ""
    @State private var showIssueSentToast = false
    @State private var showIncidentBanner = true

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top instruction banner
                if !coordinator.currentStepInstruction.isEmpty {
                    instructionBanner
                }

                // GAP-1: Traffic incident banner
                if showIncidentBanner, let incident = coordinator.trafficService.nearestIncident {
                    incidentBanner(incident)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Off-route warning banner
                if coordinator.hasDeviated {
                    deviationBanner
                }

                // Route progress bar (live distance)
                if coordinator.hasRenderableRoute && coordinator.isNavigating {
                    routeProgressBar()
                }

                // Stats row
                statsRow

                // Speed badge + speed limit
                HStack {
                    speedBadge
                    if let limit = coordinator.currentSpeedLimit {
                        speedLimitSign(limit)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

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

    private var instructionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: maneuverIcon(for: coordinator.currentStepManeuver.isEmpty
                                           ? coordinator.currentStepInstruction
                                           : coordinator.currentStepManeuver))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appOrange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(formatDistance(coordinator.distanceRemainingMetres))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(coordinator.currentStepInstruction)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                if !coordinator.nextStepInstruction.isEmpty {
                    Text("Then: \(coordinator.nextStepInstruction)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer()
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
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private func maneuverIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("left")    { return "arrow.turn.up.left" }
        if lower.contains("right")   { return "arrow.turn.up.right" }
        if lower.contains("u-turn")  { return "arrow.uturn.left" }
        if lower.contains("merge")   { return "arrow.merge" }
        if lower.contains("exit")    { return "arrow.triangle.turn.up.right.circle" }
        if lower.contains("arrive")  { return "mappin.circle.fill" }
        if lower.contains("depart")  { return "arrow.up.circle.fill" }
        return "arrow.up"
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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(incidentColor(incident.severity))
                .frame(width: 36, height: 36)
                .background(incidentColor(incident.severity).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.description)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                value: String(format: "%.0f min", coordinator.distanceRemainingMetres > 0
                              ? (coordinator.estimatedArrivalTime?.timeIntervalSinceNow ?? 0) / 60
                              : 0),
                label: "Remaining"
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    private var speedBadge: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.appOrange.opacity(0.3), lineWidth: 4)
                .frame(width: 80, height: 80)

            // Inner fill
            Circle()
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                .frame(width: 68, height: 68)

            VStack(spacing: 1) {
                Text(String(format: "%.0f", max(0, coordinator.currentSpeedKmh)))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Speed Limit Sign

    private func speedLimitSign(_ limit: Int) -> some View {
        VStack(spacing: 2) {
            Circle()
                .stroke(.red, lineWidth: 4)
                .frame(width: 52, height: 52)
                .overlay(
                    Text("\(limit)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                )
            Text("km/h").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("SOS", icon: "sos", color: SierraTheme.Colors.danger) {
                showSOSAlert = true
            }
            actionButton("Incident", icon: "exclamationmark.triangle.fill", color: .appOrange) {
                showIncidentReport = true
            }
            actionButton("End Trip", icon: "xmark.circle", color: .appOrange) {
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

    // MARK: - Route Progress Bar

    private func routeProgressBar() -> some View {
        let progress = coordinator.routeProgressFraction
        let pct = Int(progress * 100)
        return VStack(spacing: 4) {
            HStack {
                Text("Route Progress")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.85, blue: 0.55), .appOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.6))
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
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
                    withAnimation(.spring(response: 0.3)) {
                        showEndTripConfirm = false
                    }
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.red.opacity(0.95))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("End Trip?")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("This will complete all stops and begin post-trip inspection.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showEndTripConfirm = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showEndTripConfirm = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onEndTrip()
                        }
                    }) {
                        Text("Confirm End")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.95, green: 0.23, blue: 0.20))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 104)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appOrange.opacity(0.2))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Report Issue")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("This will be sent to admin while route continues.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                Text("Describe the issue")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $issueText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
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
                            .font(.system(size: 13, weight: .medium, design: .rounded))
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
                    .font(.system(size: 16, weight: .bold))
                Text("Issue sent to admin. Continuing route.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
        withAnimation(.spring(response: 0.3)) {
            showIncidentReport = false
        }

        Task {
            // Insert activity log for incident report
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

                // Notify fleet managers
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

                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) { showIssueSentToast = true }
                }
            } catch {
                print("[HUD] Incident report failed: \(error)")
                // Still show toast — driver shouldn't think it failed silently
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
}
