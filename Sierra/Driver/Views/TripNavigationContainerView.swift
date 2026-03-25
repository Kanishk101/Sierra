import SwiftUI

/// Full-screen navigation container.
/// X button top-left to exit. Confirmation alert when navigation is active.
/// Better error messages based on RouteEngine.lastBuildError.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showEndTripModal  = false
    @State private var isBuildingRoutes  = false
    @State private var routeBuildFailed  = false
    @State private var buildErrorMessage = "Could not calculate route. Check your connection and try again."
    @State private var showDismissAlert  = false
    @State private var showProofOfDelivery = false
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip) {
        _coordinator = State(initialValue: TripNavigationCoordinator.session(for: trip))
    }

    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            if MapService.hasValidToken {
                TripNavigationView(coordinator: coordinator, simulate: false)
            } else {
                TripNavigationFallbackMapView(coordinator: coordinator)
            }

            NavigationHUDOverlay(coordinator: coordinator) {
                // End trip flow: after confirmation in HUD, open same delivery proof sheet
                // (photo/signature/OTP) used by Trip Detail -> Complete Delivery.
                showProofOfDelivery = true
            }

            if isPreStartScheduledTrip {
                preStartBanner
                    .zIndex(9)
            }

            // Close button — top left
            VStack {
                HStack {
                    Button {
                        if coordinator.isNavigating { showDismissAlert = true } else { dismissView() }
                    } label: {
                        ZStack {
                            Circle().fill(.black.opacity(0.55)).frame(width: 40, height: 40)
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    .padding(.leading, 18)
                    .padding(.top, 56)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(10)

            // Route building spinner
            if isBuildingRoutes {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.4).tint(.white)
                        Text("Calculating route…").font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }

            // Route build failure — informative, with retry
            if routeBuildFailed {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            Text("Route unavailable").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }
                        Text(buildErrorMessage).font(.caption).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button("Retry") {
                                routeBuildFailed = false
                                Task { await buildAndShowRoutes() }
                            }
                            .font(.caption.weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.orange, in: Capsule())

                            Button("Exit") { dismissView() }
                                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await buildAndShowRoutes()
        }
        .task {
            while !Task.isCancelled {
                if canStartLiveNavigation, coordinator.hasRenderableRoute {
                    startTracking()
                    break
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .onDisappear { coordinator.stopLocationPublishing(); VoiceNavigationService.shared.stop() }
        .alert("Exit Navigation?", isPresented: $showDismissAlert) {
            Button("Exit", role: .destructive) { dismissView() }
            Button("Keep Navigating", role: .cancel) {}
        } message: { Text("Your trip is still active. You can return to navigation from the trip card.") }
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) { startTracking() }
        }
        .sheet(isPresented: $showProofOfDelivery) {
            if let driverId {
                NavigationStack {
                    ProofOfDeliveryView(tripId: coordinator.trip.id, driverId: driverId) {
                        showProofOfDelivery = false
                        coordinator.stopLocationPublishing()
                        coordinator.isNavigating = false
                        Task {
                            await store.loadDriverData(driverId: driverId)
                        }
                        dismiss()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("Delivery options unavailable")
                        .font(.headline)
                    Text("Could not identify the current driver session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Close") { showProofOfDelivery = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
        }
    }

    // MARK: - Private helpers

    private var driverId: UUID? { user?.id }
    private var canNavigateTrip: Bool {
        let status = coordinator.trip.status.normalized
        if status == .active { return true }
        if status == .scheduled,
           coordinator.trip.acceptedAt != nil,
           coordinator.trip.preInspectionId != nil {
            return true
        }
        return false
    }

    private var canStartLiveNavigation: Bool {
        let status = coordinator.trip.status.normalized
        if status == .active { return true }
        guard status == .scheduled,
              coordinator.trip.acceptedAt != nil,
              coordinator.trip.preInspectionId != nil else {
            return false
        }
        return coordinator.trip.scheduledDate.timeIntervalSinceNow <= TripConstants.driverBlockWindowSeconds
    }

    private var isPreStartScheduledTrip: Bool {
        let status = coordinator.trip.status.normalized
        return status == .scheduled
            && coordinator.trip.acceptedAt != nil
            && coordinator.trip.preInspectionId != nil
            && !canStartLiveNavigation
    }

    @State private var showRouteSelection = false

    private func buildAndShowRoutes() async {
        guard canNavigateTrip, !coordinator.trip.hasEndedNavigationPhase else {
            dismissView()
            return
        }

        if coordinator.hasRenderableRoute, coordinator.hasConfirmedRouteSelection {
            startTracking()
            return
        }

        isBuildingRoutes = true
        routeBuildFailed = false
        await coordinator.buildRoutes()
        isBuildingRoutes = false

        if coordinator.hasRenderableRoute {
            if coordinator.alternativeRoute != nil, !coordinator.hasConfirmedRouteSelection {
                showRouteSelection = true
            } else {
                startTracking()
            }
        } else {
            buildErrorMessage = coordinator.routeEngineError ?? "Could not calculate route. Check your network and try again."
            routeBuildFailed = true
        }
    }

    private func startTracking() {
        guard canNavigateTrip, !coordinator.trip.hasEndedNavigationPhase else { return }
        guard canStartLiveNavigation else { return }
        guard !coordinator.isNavigating else { return }
        guard let vehicleIdStr = coordinator.trip.vehicleId,
              let vehicleId = UUID(uuidString: vehicleIdStr),
              let driverId = user?.id else { return }
        coordinator.startLocationTracking()
        coordinator.startLocationPublishing(vehicleId: vehicleId, driverId: driverId)
    }

    private var preStartBanner: some View {
        VStack {
            HStack {
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip Scheduled")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text(preStartMessage)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 280)
                .padding(.top, 56)
                .padding(.trailing, 16)
            }
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var preStartMessage: String {
        let interval = max(0, coordinator.trip.scheduledDate.timeIntervalSinceNow)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let timeText = coordinator.trip.scheduledDate.formatted(.dateTime.hour().minute())
        if hours > 0 {
            return "Starts in \(hours)h \(minutes)m (\(timeText))."
        }
        return "Starts in \(minutes)m (\(timeText))."
    }

    private func dismissView() {
        coordinator.stopLocationPublishing()
        VoiceNavigationService.shared.stop()
        dismiss()
    }
}
