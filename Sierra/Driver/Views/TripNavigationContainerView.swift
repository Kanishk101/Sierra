import SwiftUI
import CoreLocation

/// Full-screen navigation container.
/// X button top-left to exit. Confirmation alert when navigation is active.
/// Better error messages based on RouteEngine.lastBuildError.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showEndTripModal  = false
    @State private var isBuildingRoutes  = false
    @State private var routeBuildFailed  = false
    @State private var buildErrorMessage = "Could not calculate route. Check your connection and try again."
    @State private var isWaitingForGPS = false
    @State private var gpsWaitMessage = "Waiting for GPS fix…"
    @State private var showDismissAlert  = false
    @State private var showProofOfDelivery = false
    @State private var showRouteSelection = false
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

            // Top-left close button
            VStack {
                HStack {
                    Button {
                        if coordinator.isNavigating { showDismissAlert = true } else { dismissView() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(SierraFont.scaled(14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 60)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(20)

            // Right-side camera controls (overview above, compass below)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Button {
                            coordinator.toggleCameraMode()
                        } label: {
                            Image(systemName: coordinator.isOverviewMode ? "location.north.line.fill" : "map.fill")
                                .font(SierraFont.scaled(14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                        }

                        Button {
                            coordinator.switchToFollowMode()
                        } label: {
                            Image(systemName: "location.north.circle.fill")
                                .font(SierraFont.scaled(14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 132)
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(20)

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

            if isWaitingForGPS {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2).tint(.white)
                        Text("Acquiring GPS")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(gpsWaitMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
                .zIndex(15)
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
            coordinator.startEarlyLocationUpdates()
            await buildAndShowRoutes()
        }
        .task {
            while !Task.isCancelled {
                if canStartLiveNavigation, coordinator.hasRenderableRoute, coordinator.hasConfirmedRouteSelection {
                    print("[NAV-DEBUG] Auto-start: canStartLiveNavigation=true, hasRoute=true, confirmed=true → starting tracking")
                    startTracking()
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s poll, was 30s
            }
        }
        .onDisappear { coordinator.stopLocationPublishing(); VoiceNavigationService.shared.stop() }
        .alert("Exit Navigation?", isPresented: $showDismissAlert) {
            Button("Exit", role: .destructive) { dismissView() }
            Button("Keep Navigating", role: .cancel) {}
        } message: { Text("Your trip is still active. You can return to navigation from the trip card.") }
        .sheet(isPresented: $showProofOfDelivery) {
            if let driverId {
                NavigationStack {
                    ProofOfDeliveryView(tripId: coordinator.trip.id, driverId: driverId) {
                        showProofOfDelivery = false
                        coordinator.stopLocationPublishing()
                        coordinator.isNavigating = false

                        Task {
                            do {
                                try await store.endTrip(tripId: coordinator.trip.id)
                            } catch {
                                print("❌ Failed to complete trip after POD: \(error)")
                            }
                            await store.refreshDriverData(driverId: driverId, force: true)
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
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) {
                startTracking()
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
        return coordinator.trip.scheduledDate <= Date()
    }

    private var isPreStartScheduledTrip: Bool {
        let status = coordinator.trip.status.normalized
        return status == .scheduled
            && coordinator.trip.acceptedAt != nil
            && coordinator.trip.preInspectionId != nil
            && !canStartLiveNavigation
    }

    private func buildAndShowRoutes() async {
        guard canNavigateTrip, !coordinator.trip.hasEndedNavigationPhase else {
            dismissView()
            return
        }

        if coordinator.hasRenderableRoute, coordinator.hasConfirmedRouteSelection {
            startTracking()
            return
        }

        guard await waitForReliableGPSFix() else { return }

        isBuildingRoutes = true
        routeBuildFailed = false
        await coordinator.buildRoutes()
        isBuildingRoutes = false

        if coordinator.hasRenderableRoute {
            if coordinator.routeChoices.isEmpty {
                coordinator.confirmRouteSelection()
                startTracking()
            } else if !coordinator.hasConfirmedRouteSelection {
                showRouteSelection = true
            } else {
                startTracking()
            }
        } else {
            buildErrorMessage = coordinator.routeEngineError ?? "Could not calculate route. Check your network and try again."
            routeBuildFailed = true
        }
    }

    private func waitForReliableGPSFix() async -> Bool {
        if coordinator.hasReliableLocationFix {
            isWaitingForGPS = false
            return true
        }

        isWaitingForGPS = true
        routeBuildFailed = false
        let timeout = Date().addingTimeInterval(30)

        while Date() < timeout {
            if coordinator.hasReliableLocationFix {
                isWaitingForGPS = false
                return true
            }

            if let issue = coordinator.locationReadinessIssue {
                gpsWaitMessage = issue
            }

            if coordinator.locationAuthorizationStatus == .denied
                || coordinator.locationAuthorizationStatus == .restricted {
                break
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        isWaitingForGPS = false
        buildErrorMessage = coordinator.locationReadinessIssue ?? "Unable to get a reliable GPS fix. Please retry."
        routeBuildFailed = true
        return false
    }

    private func startTracking() {
        guard canNavigateTrip, !coordinator.trip.hasEndedNavigationPhase else { return }
        guard canStartLiveNavigation else { return }
        guard coordinator.hasConfirmedRouteSelection else { return }
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
