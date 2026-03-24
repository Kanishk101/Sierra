import SwiftUI
import MapKit

/// Driver-side trip detail view with full acceptance + lifecycle actions.
///
/// Status → action mapping:
///   .scheduled         → Awaiting Assignment message
///   .pendingAcceptance → Accept button (driver can also dismiss sheet)
///   .accepted          → Begin Pre-Trip Inspection (if none) or Start Trip
///   .active            → Navigate (primary) + Complete Delivery (secondary)
///   .completed         → Completion summary
///   .rejected          → Rejected banner with reason
///   .cancelled         → Cancelled banner
///
/// Flow card: Accept Trip step is ONLY shown when the trip used the acceptance flow
/// (detected via acceptedAt, rejectedReason, or acceptance-related status).
struct TripDetailDriverView: View {

    let tripId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // MARK: - Presentation State

    @State private var showPreInspection        = false
    @State private var showStartTrip            = false
    @State private var showNavigation           = false
    @State private var showProofOfDelivery      = false
    @State private var showPostInspection       = false

    // Accept
    @State private var isAccepting              = false
    @State private var showAcceptSuccess        = false

    // End Trip
    @State private var isEndingTrip             = false

    // Pulse animation for Navigate button
    @State private var navigatePulse            = false

    // Error alert
    @State private var errorMessage: String?
    @State private var showError                = false

    // MARK: - Convenience

    private var trip: Trip?  { store.trips.first { $0.id == tripId } }
    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var vehicle: Vehicle? {
        guard let vId = trip?.vehicleId, let uuid = UUID(uuidString: vId) else { return nil }
        return store.vehicle(for: uuid)
    }

    /// True when this trip was (or is being) routed through the driver-acceptance flow.
    private func usedAcceptanceFlow(_ trip: Trip) -> Bool {
        trip.acceptedAt != nil
            || trip.rejectedReason != nil
            || trip.status == .pendingAcceptance
            || trip.status == .scheduled   // post-acceptance
            || trip.status == .accepted    // legacy accepted state
            || trip.status == .rejected
    }

    /// True when the trip is within 30 minutes of its scheduled start.
    private func isInTimeWindow(_ trip: Trip) -> Bool {
        let secsUntilStart = trip.scheduledDate.timeIntervalSinceNow
        return secsUntilStart <= TripConstants.driverBlockWindowSeconds
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    VStack(spacing: 16) {
                        statusBanner(trip)
                        tripInfoCard(trip)
                        routeMapCard(trip)
                        if let vehicle { vehicleCard(vehicle) }
                        tripProgressBar(trip)
                        actionButtons(trip)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                ContentUnavailableView("Trip Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .overlay {
            if showAcceptSuccess {
                AcceptSuccessOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(200)
            }
        }
        .navigationTitle("Trip Overview")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showPreInspection) {
            if let trip, let vehicle, let userId = user?.id {
                NavigationStack {
                    PreTripInspectionView(
                        tripId: trip.id,
                        vehicleId: vehicle.id,
                        driverId: userId,  // ISSUE-21 FIX
                        inspectionType: .preTripInspection,
                        onComplete: { showPreInspection = false }
                    )
                }
            }
        }
        .sheet(isPresented: $showStartTrip) {
            if let trip {
                NavigationStack {
                    StartTripSheet(tripId: trip.id) {
                        showStartTrip = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            showNavigation = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showProofOfDelivery) {
            if let trip, let userId = user?.id {
                NavigationStack {
                    ProofOfDeliveryView(tripId: trip.id, driverId: userId) {  // ISSUE-21 FIX
                        showProofOfDelivery = false
                    }
                }
            }
        }
        .sheet(isPresented: $showPostInspection) {
            if let trip, let vehicle, let userId = user?.id {
                NavigationStack {
                    PostTripInspectionView(
                        tripId: trip.id,
                        vehicleId: vehicle.id,
                        driverId: userId  // ISSUE-21 FIX
                    )
                    .environment(store)
                }
            }
        }
        .fullScreenCover(isPresented: $showNavigation) {
            if let trip {
                TripNavigationContainerView(trip: trip)
                    .environment(AppDataStore.shared)
            }
        }
        .onAppear {
            if trip?.status == .active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    navigatePulse = true
                }
            }
        }
    }

    // MARK: - Route Map Card (FMS_SS heroMapSection style)

    @ViewBuilder
    private func routeMapCard(_ trip: Trip) -> some View {
        let hasCoords = trip.originLatitude != nil && trip.originLongitude != nil
                     && trip.destinationLatitude != nil && trip.destinationLongitude != nil

        if hasCoords,
           let oLat = trip.originLatitude, let oLng = trip.originLongitude,
           let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {

            // Real map when GPS coords exist
            let originCoord = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
            let destCoord   = CLLocationCoordinate2D(latitude: dLat, longitude: dLng)
            let minLat = min(oLat, dLat), maxLat = max(oLat, dLat)
            let minLng = min(oLng, dLng), maxLng = max(oLng, dLng)
            let spanLat = max((maxLat - minLat) * 1.5, 0.05)
            let spanLng = max((maxLng - minLng) * 1.5, 0.05)
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            )

            ZStack(alignment: .bottom) {
                Map(initialPosition: .region(region)) {
                    Annotation(trip.origin, coordinate: originCoord) {
                        ZStack {
                            Circle().fill(Color.green).frame(width: 28, height: 28)
                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }.shadow(radius: 3)
                    }
                    Annotation(trip.destination, coordinate: destCoord) {
                        ZStack {
                            Circle().fill(Color.appOrange).frame(width: 28, height: 28)
                            Image(systemName: "mappin")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }.shadow(radius: 3)
                    }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .disabled(true)

                // "Live Tracking" chip top-left
                VStack {
                    HStack {
                        mapChip(text: trip.status == .active ? "Live Tracking" : "Route Preview",
                                icon: "circle.fill",
                                iconColor: trip.status == .active ? .green : .orange)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    Spacer()
                }
                .frame(height: 240)

                // Tap to navigate overlay for active trips
                if trip.status == .active {
                    Button { showNavigation = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill").font(.system(size: 14, weight: .bold))
                            Text("Open Navigation").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                    .padding(.bottom, 14)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)

        } else {
            // FMS_SS-style hero map (no GPS coords) — grid + bezier route art + floating summary
            heroMapArt(trip)
        }
    }

    /// FMS_SS-style illustrated hero map — shown when no GPS coords are stored.
    private func heroMapArt(_ trip: Trip) -> some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.95, blue: 0.92),
                            Color(red: 0.92, green: 0.93, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 320)
                .overlay(mapGridOverlay)
                .overlay(mapRoutePathOverlay)

            VStack(spacing: 0) {
                // Top — Live Tracking / Status chip
                HStack {
                    mapChip(
                        text: trip.status == .active ? "Live Tracking" : "Scheduled Route",
                        icon: "circle.fill",
                        iconColor: trip.status == .active ? .green : .orange
                    )
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Spacer()

                // Floating summary card at bottom
                heroFloatingSummary(trip)
                    .padding(12)
            }
            .frame(height: 320)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var mapGridOverlay: some View {
        GeometryReader { geo in
            Path { path in
                stride(from: 0.0, through: geo.size.width, by: 44).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                stride(from: 0.0, through: geo.size.height, by: 44).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.03), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private var mapRoutePathOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Dashed bezier route
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width * 0.16, y: geo.size.height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: geo.size.width * 0.82, y: geo.size.height * 0.18),
                        control1: CGPoint(x: geo.size.width * 0.45, y: geo.size.height * 0.62),
                        control2: CGPoint(x: geo.size.width * 0.57, y: geo.size.height * 0.20)
                    )
                }
                .stroke(Color.blue.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6]))

                // Origin pin
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().fill(Color.white).frame(width: 6, height: 6))
                    .shadow(radius: 3)
                    .position(x: geo.size.width * 0.16, y: geo.size.height * 0.72)

                // Destination pin
                Circle()
                    .fill(Color.appOrange)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().fill(Color.white).frame(width: 6, height: 6))
                    .shadow(radius: 3)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private func heroFloatingSummary(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Route")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text(trip.taskId)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.appOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appOrange.opacity(0.12)))
            }

            HStack(spacing: 12) {
                if let km = trip.distanceKm {
                    heroStat(icon: "arrow.up.right", label: "Distance", value: "\(Int(km)) km", tint: .blue)
                }
                heroStat(icon: "clock", label: "Scheduled", value: trip.scheduledDate.formatted(.dateTime.hour().minute()), tint: .green)
                heroStat(icon: "flag.checkered", label: "Priority", value: trip.priority.rawValue, tint: .appOrange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.97))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private func heroStat(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint.opacity(0.13))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(tint)
                    )
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapChip(text: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.96)))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Flow Steps Card
    // Accept Trip step is conditionally included — only for trips that went
    // through the driver-acceptance flow.

    private func flowStepsCard(_ trip: Trip) -> some View {
        var steps: [(icon: String, label: String, done: Bool)] = []

        // Only inject Accept Trip step if this trip used the acceptance flow
        if usedAcceptanceFlow(trip) {
            steps.append((
                "checkmark.shield.fill",
                "Accept Trip",
                trip.status != .pendingAcceptance
            ))
        }

        steps += [
            ("checklist",         "Pre-Trip Inspection",  trip.preInspectionId != nil),
            ("play.fill",         "Start Trip",           trip.status == .active || trip.status == .completed),
            ("location.fill",     "Navigate",             trip.status == .completed),
            ("shippingbox.fill",  "Complete Delivery",    trip.proofOfDeliveryId != nil),
            ("checklist.checked", "Post-Trip Inspection", trip.postInspectionId != nil),
            ("flag.checkered",    "End Trip",             trip.status == .completed),
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Text("TRIP FLOW")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .kerning(1)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(step.done
                                  ? Color.green.opacity(0.14)
                                  : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 36, height: 36)
                        Image(systemName: step.done ? "checkmark" : step.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(step.done ? .green : .appTextSecondary)
                    }
                    Text(step.label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(step.done ? .appTextPrimary : .appTextSecondary)
                    Spacer()
                    if step.label == "Navigate" && trip.status == .active {
                        Text("TAP BELOW")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.10)))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(Color.appDivider.opacity(0.5))
                        .frame(height: 1)
                        .padding(.leading, 66)
                }
            }
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    // MARK: - Status Banner

    private func statusBanner(_ trip: Trip) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(statusColor(trip.status)).frame(width: 10, height: 10)
                Text(statusLabel(trip.status))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor(trip.status))
            }
            Spacer()
            Text(trip.priority.rawValue)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(priorityColor(trip.priority)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Trip Info Card

    private func tripInfoCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "number.square.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appOrange)
                Text(trip.taskId)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.appOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            // Route plan nodes
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        )

                    Rectangle()
                        .fill(
                            LinearGradient(colors: [.green, .appOrange], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 3, height: 52)

                    Circle()
                        .fill(Color.appOrange.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Origin node
                    VStack(alignment: .leading, spacing: 4) {
                        Text("START")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.green.opacity(0.10)))
                        Text(trip.origin.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                        Label(
                            trip.scheduledDate.formatted(.dateTime.hour().minute()),
                            systemImage: "clock"
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                    }

                    // Destination node
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DESTINATION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.appOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.appOrange.opacity(0.10)))
                        Text(trip.destination.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                        if trip.status == .pendingAcceptance, let deadline = trip.acceptanceDeadline {
                            Label(
                                "Respond by \(deadline.formatted(.dateTime.hour().minute()))",
                                systemImage: "clock.badge.exclamationmark"
                            )
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                        }
                    }
                }
            }

            // Distance + scheduled time stat chips
            HStack(spacing: 10) {
                // Distance chip
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(trip.distanceKm.map { "\(Int($0)) km" } ?? "N/A")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.18), lineWidth: 1))

                // Scheduled time chip
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appOrange)
                    Text(trip.scheduledDate.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appOrange.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appOrange.opacity(0.18), lineWidth: 1))
            }
            .padding(.top, 4)

            if !trip.deliveryInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DELIVERY INSTRUCTIONS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .kerning(1)
                    Text(trip.deliveryInstructions)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appTextSecondary)

            Text(vehicle.licensePlate)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.appOrange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.appOrange.opacity(0.08)))

            Text("\(vehicle.name) \(vehicle.model)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons (status-driven)

    @ViewBuilder
    private func actionButtons(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            switch trip.status {

            // ── Pending Acceptance: driver must accept or reject ─────────────
            case .pendingAcceptance:
                acceptanceButtons(trip)

            // ── Scheduled (post-acceptance): pre-inspection → then Start Trip ─
            // Navigate is enabled only once scheduled start time has begun.
            case .scheduled, .accepted:
                if trip.status == .scheduled && trip.acceptedAt == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Awaiting Dispatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Your fleet manager will send this trip for your review shortly.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if trip.preInspectionId == nil {
                    // Step 1: Complete pre-trip inspection first
                    actionButton("Begin Pre-Trip Inspection", icon: "checklist", color: SierraTheme.Colors.ember) {
                        showPreInspection = true
                    }
                } else if trip.scheduledDate <= Date() {
                    // Time slot has started — allow navigation.
                    navigateButton()
                } else {
                    // Pre-inspection done but trip has not started yet.
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            Text("Navigate")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )

                        Text("Navigation unlocks when the scheduled start time begins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

            // ── Active: Navigate (primary) then delivery / inspection gate ───
            case .active:
                // Primary: Navigate is ALWAYS the main CTA while the trip is active
                navigateButton()

                // Secondary gate — only one of these shows at a time, smaller weight
                if trip.proofOfDeliveryId == nil {
                    secondaryActionButton(
                        "Complete Delivery",
                        icon: "shippingbox.fill",
                        color: SierraTheme.Colors.ember
                    ) {
                        showProofOfDelivery = true
                    }
                } else if trip.postInspectionId == nil {
                    actionButton(
                        "Post-Trip Inspection (Required)",
                        icon: "checklist",
                        color: SierraTheme.Colors.info
                    ) {
                        showPostInspection = true
                    }
                } else {
                    endTripButton(trip)
                }
                // NOTE: Log Fuel and Report Issue are accessed from within
                // Pre-Trip Inspection and Post-Trip Inspection views respectively.
                // They are NOT standalone actions in trip detail.

            // ── Completed ──────────────────────────────────────────────────
            case .completed:
                completionSummary(trip)

            // ── Rejected ───────────────────────────────────────────────────
            case .rejected:
                rejectedBanner(trip)

            // ── Cancelled ──────────────────────────────────────────────────
            case .cancelled:
                cancelledBanner()
            }
        }
    }

    // MARK: - Accept Button Block

    @ViewBuilder
    private func acceptanceButtons(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            Button {
                Task { await handleAccept(trip: trip) }
            } label: {
                Group {
                    if isAccepting {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").font(.body.weight(.bold))
                            Text("Accept Trip").font(.system(size: 18, weight: .bold))
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.green.opacity(0.35), radius: 10, y: 4)
            }
            .disabled(isAccepting)
        }
    }

    // MARK: - Navigate Button (pulsing, primary CTA for active trips)

    private func navigateButton() -> some View {
        Button { showNavigation = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Start Navigation")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color(red: 0.90, green: 0.22, blue: 0.18))
            )
            .shadow(color: Color.red.opacity(0.22), radius: 10, x: 0, y: 4)
            .scaleEffect(navigatePulse ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: navigatePulse)
    }

    // MARK: - End Trip Button

    private func endTripButton(_ trip: Trip) -> some View {
        Button {
            Task { await handleEndTrip(trip: trip) }
        } label: {
            Group {
                if isEndingTrip {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered").font(.body.weight(.bold))
                        Text("End Trip").font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.indigo, Color.purple.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color.indigo.opacity(0.35), radius: 10, y: 4)
        }
        .disabled(isEndingTrip)
    }

    // MARK: - Banners

    private func completionSummary(_ trip: Trip) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("Trip Completed")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            if let endDate = trip.actualEndDate {
                Text(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    private func rejectedBanner(_ trip: Trip) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text("Trip Rejected").font(.headline).foregroundStyle(.red)
            }
            if let reason = trip.rejectedReason, !reason.isEmpty {
                Text(reason).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    private func cancelledBanner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            Text("Trip Cancelled").font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Generic Action Buttons

    /// Full-height primary action button.
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// Smaller secondary action — used for Complete Delivery alongside Navigate.
    private func secondaryActionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Async Action Handlers

    private func handleAccept(trip: Trip) async {
        isAccepting = true
        defer { isAccepting = false }
        do {
            try await store.acceptTrip(tripId: trip.id)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showAcceptSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showAcceptSuccess = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleEndTrip(trip: Trip) async {
        isEndingTrip = true
        defer { isEndingTrip = false }
        do {
            try await store.endTrip(tripId: trip.id, endMileage: trip.endMileage ?? 0)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Trip Progress

    private func tripProgress(_ trip: Trip) -> Double {
        switch trip.status {
        case .scheduled:
            // Post-acceptance: accepted but awaiting time window
            if trip.acceptedAt != nil {
                return trip.preInspectionId != nil ? 0.30 : 0.20
            }
            return 0.0
        case .pendingAcceptance: return 0.10
        case .accepted:          return trip.preInspectionId != nil ? 0.30 : 0.20
        case .active:
            if trip.postInspectionId != nil { return 0.85 }
            if trip.proofOfDeliveryId != nil { return 0.70 }
            return 0.50
        case .completed:         return 1.0
        case .rejected, .cancelled: return 0.0
        }
    }

    private func tripProgressBar(_ trip: Trip) -> some View {
        let progress = tripProgress(trip)
        let pct = Int(progress * 100)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Trip Progress")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(pct)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SierraTheme.Colors.alpineMint, SierraTheme.Colors.ember],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Style Helpers

    private func statusLabel(_ status: TripStatus) -> String {
        switch status {
        case .scheduled:          return trip?.acceptedAt != nil ? "Accepted — Awaiting Time Window" : "Scheduled"
        case .pendingAcceptance:  return "Awaiting Your Acceptance"
        case .accepted:           return "Accepted — Ready to Start"
        case .rejected:           return "Trip Rejected"
        case .active:             return "Active — In Progress"
        case .completed:          return "Completed"
        case .cancelled:          return "Cancelled"
        }
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled:          return trip?.acceptedAt != nil ? .teal : SierraTheme.Colors.info
        case .pendingAcceptance:  return .orange
        case .accepted:           return .teal
        case .rejected:           return SierraTheme.Colors.danger
        case .active:             return SierraTheme.Colors.alpineMint
        case .completed:          return .gray
        case .cancelled:          return SierraTheme.Colors.danger
        }
    }

    private func priorityColor(_ priority: TripPriority) -> Color {
        switch priority {
        case .low:    return .gray
        case .normal: return SierraTheme.Colors.info
        case .high:   return SierraTheme.Colors.warning
        case .urgent: return SierraTheme.Colors.danger
        }
    }
}
