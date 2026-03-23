import SwiftUI
import MapKit

/// Driver-side trip detail view with full acceptance + lifecycle actions.
///
/// Status → action mapping:
///   .scheduled         → Awaiting Assignment message
///   .pendingAcceptance → Accept + Reject buttons
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

    // Accept / Reject
    @State private var isAccepting              = false
    @State private var isRejecting              = false

    // Reject sheet
    @State private var showRejectSheet          = false
    @State private var rejectionReason          = ""
    @State private var rejectionError: String?  = nil

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
    /// Used to decide whether to show the "Accept Trip" step in the flow card.
    private func usedAcceptanceFlow(_ trip: Trip) -> Bool {
        trip.acceptedAt != nil
            || trip.rejectedReason != nil
            || trip.status == .pendingAcceptance
            || trip.status == .accepted
            || trip.status == .rejected
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
                        flowStepsCard(trip)
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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectSheet
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

    // MARK: - Route Map Card

    @ViewBuilder
    private func routeMapCard(_ trip: Trip) -> some View {
        let hasCoords = trip.originLatitude != nil && trip.originLongitude != nil
                     && trip.destinationLatitude != nil && trip.destinationLongitude != nil

        VStack(alignment: .leading, spacing: 0) {
            if hasCoords,
               let oLat = trip.originLatitude, let oLng = trip.originLongitude,
               let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {

                let originCoord = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
                let destCoord   = CLLocationCoordinate2D(latitude: dLat, longitude: dLng)
                let minLat = min(oLat, dLat), maxLat = max(oLat, dLat)
                let minLng = min(oLng, dLng), maxLng = max(oLng, dLng)
                let spanLat = max((maxLat - minLat) * 1.5, 0.05)
                let spanLng = max((maxLng - minLng) * 1.5, 0.05)
                let center  = CLLocationCoordinate2D(
                    latitude:  (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                )
                let region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
                )

                ZStack(alignment: .bottom) {
                    Map(initialPosition: .region(region)) {
                        Annotation(trip.origin, coordinate: originCoord) {
                            ZStack {
                                Circle().fill(SierraTheme.Colors.alpineMint).frame(width: 28, height: 28)
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            }.shadow(radius: 3)
                        }
                        Annotation(trip.destination, coordinate: destCoord) {
                            ZStack {
                                Circle().fill(SierraTheme.Colors.ember).frame(width: 28, height: 28)
                                Image(systemName: "mappin")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            }.shadow(radius: 3)
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(true)

                    if trip.status == .active {
                        Button { showNavigation = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill").font(.system(size: 14, weight: .bold))
                                Text("Tap to Open Navigation").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(.black.opacity(0.55), in: Capsule())
                        }
                        .padding(.bottom, 12)
                    }
                }

            } else {
                HStack(spacing: 12) {
                    Image(systemName: "map").font(.system(size: 28)).foregroundStyle(.secondary.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Route preview unavailable")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text("Ask your fleet manager to set GPS coordinates for this trip.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .kerning(1)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(step.done
                                  ? SierraTheme.Colors.alpineMint
                                  : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 32, height: 32)
                        Image(systemName: step.done ? "checkmark" : step.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(step.done ? .white : .secondary)
                    }
                    Text(step.label)
                        .font(.subheadline)
                        .foregroundStyle(step.done ? .primary : .secondary)
                    Spacer()
                    if step.label == "Navigate" && trip.status == .active {
                        Text("TAP BELOW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SierraTheme.Colors.alpineMint)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(SierraTheme.Colors.alpineMint.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.4))
                        .frame(height: 1)
                        .padding(.leading, 60)
                }
            }
            .padding(.bottom, 6)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Status Banner

    private func statusBanner(_ trip: Trip) -> some View {
        HStack {
            Circle().fill(statusColor(trip.status)).frame(width: 10, height: 10)
            Text(statusLabel(trip.status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor(trip.status))
            Spacer()
            Text(trip.priority.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(priorityColor(trip.priority), in: Capsule())
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Trip Info Card

    private func tripInfoCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.taskId)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gray.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 6) {
                Label(trip.origin, systemImage: "location.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SierraTheme.Colors.alpineMint)
                Rectangle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 1, height: 16)
                    .padding(.leading, 8)
                Label(trip.destination, systemImage: "mappin.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SierraTheme.Colors.ember)
            }

            Divider()

            Label(
                trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                systemImage: "calendar"
            )
            .font(.caption).foregroundStyle(.secondary)

            if trip.status == .pendingAcceptance, let deadline = trip.acceptanceDeadline {
                Divider()
                Label(
                    "Respond by \(deadline.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
                    systemImage: "clock.badge.exclamationmark"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
            }

            if !trip.deliveryInstructions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delivery Instructions")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(trip.deliveryInstructions)
                        .font(.caption).foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(SierraTheme.Colors.ember)
                .frame(width: 44, height: 44)
                .background(SierraTheme.Colors.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.name) \(vehicle.model)").font(.subheadline.weight(.semibold))
                Text(vehicle.licensePlate)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Action Buttons (status-driven)

    @ViewBuilder
    private func actionButtons(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            switch trip.status {

            // ── Scheduled: unassigned, no driver yet ────────────────────────
            case .scheduled:
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

            // ── Pending Acceptance: driver must accept or reject ─────────────
            case .pendingAcceptance:
                acceptanceButtons(trip)

            // ── Accepted: pre-inspection gate → then start trip ─────────────
            case .accepted:
                if trip.preInspectionId == nil {
                    actionButton("Begin Pre-Trip Inspection", icon: "checklist", color: SierraTheme.Colors.ember) {
                        showPreInspection = true
                    }
                } else {
                    actionButton("Start Trip", icon: "play.fill", color: SierraTheme.Colors.alpineMint) {
                        showStartTrip = true
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

    // MARK: - Accept / Reject Buttons Block

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
            .disabled(isAccepting || isRejecting)

            Button {
                showRejectSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").font(.body.weight(.semibold))
                    Text("Reject Trip").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isAccepting || isRejecting)
        }
    }

    // MARK: - Navigate Button (pulsing, primary CTA for active trips)

    private func navigateButton() -> some View {
        Button { showNavigation = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.fill").font(.body.weight(.bold))
                Text("Navigate").font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [SierraTheme.Colors.alpineMint, SierraTheme.Colors.alpineMint.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(
                color: SierraTheme.Colors.alpineMint.opacity(navigatePulse ? 0.6 : 0.2),
                radius: navigatePulse ? 14 : 6,
                y: 4
            )
            .scaleEffect(navigatePulse ? 1.01 : 1.0)
        }
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

    // MARK: - Reject Sheet

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Reason for rejection helps the admin reassign this trip quickly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextEditor(text: $rejectionReason)
                    .frame(height: 120)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .padding(.horizontal)

                if rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                    Text("Minimum 10 characters required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = rejectionError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task { await handleReject() }
                } label: {
                    Group {
                        if isRejecting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm Rejection")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
                            ? Color.red
                            : Color.red.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 || isRejecting)
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .navigationTitle("Reject Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRejectSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Banners

    private func completionSummary(_ trip: Trip) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(SierraTheme.Colors.alpineMint)
            Text("Trip Completed").font(.headline)
            if let endDate = trip.actualEndDate {
                Text(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
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
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleReject() async {
        isRejecting = true
        rejectionError = nil
        defer { isRejecting = false }
        do {
            try await store.rejectTrip(tripId: tripId, reason: rejectionReason)
            showRejectSheet = false
            rejectionReason = ""
        } catch {
            rejectionError = error.localizedDescription
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
        case .scheduled:         return 0.0
        case .pendingAcceptance: return 0.1
        case .accepted:          return trip.preInspectionId != nil ? 0.3 : 0.2
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
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Style Helpers

    private func statusLabel(_ status: TripStatus) -> String {
        switch status {
        case .scheduled:          return "Scheduled"
        case .pendingAcceptance:  return "Awaiting Your Acceptance"
        case .accepted:           return "Accepted — Ready to Start"
        case .rejected:           return "Trip Rejected"
        case .active:             return "Active"
        case .completed:          return "Completed"
        case .cancelled:          return "Cancelled"
        }
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled:          return SierraTheme.Colors.info
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
