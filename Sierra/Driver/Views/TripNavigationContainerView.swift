import SwiftUI
import AVFoundation

/// Full-screen container composing TripNavigationView + NavigationHUDOverlay.
/// Added: X/close button in top-left so the driver can exit the map view.
/// When navigation is in progress, a confirmation alert prevents accidental exits.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showProofOfDelivery = false
    @State private var showRouteSelection  = false
    @State private var isBuildingRoutes    = false
    @State private var routeBuildFailed    = false
    @State private var lastSpokenInstruction = ""
    @State private var showDismissAlert    = false   // confirmation before exiting mid-navigation
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let speechSynthesizer = AVSpeechSynthesizer()

    init(trip: Trip) {
        _coordinator = State(initialValue: TripNavigationCoordinator(trip: trip))
    }

    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            TripNavigationView(coordinator: coordinator)

            NavigationHUDOverlay(coordinator: coordinator) {
                // End Trip tapped from HUD
                coordinator.stopLocationPublishing()
                coordinator.isNavigating = false
                showProofOfDelivery = true
            }

            // ── Close (X) button — top-left corner ──────────────────────────
            VStack {
                HStack {
                    Button {
                        if coordinator.isNavigating {
                            showDismissAlert = true
                        } else {
                            dismissView()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.55))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    .padding(.leading, 18)
                    .padding(.top, 56) // Below the safe-area notch
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(10)

            // Spinner while Mapbox API call is in-flight
            if isBuildingRoutes {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.4).tint(.white)
                        Text("Calculating routes\u{2026}")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }

            // Route build failure banner
            if routeBuildFailed {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Could not calculate routes")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("Check your connection and try again")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Button("Retry") {
                            routeBuildFailed = false
                            Task { await buildAndShowRoutes() }
                        }
                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                    .padding(16)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await buildAndShowRoutes()
        }
        .onChange(of: coordinator.currentStepInstruction) { _, newInstruction in
            guard !newInstruction.isEmpty, newInstruction != lastSpokenInstruction else { return }
            lastSpokenInstruction = newInstruction
            let utterance = AVSpeechUtterance(string: newInstruction)
            utterance.rate  = 0.52
            utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            speechSynthesizer.speak(utterance)
        }
        .onDisappear {
            coordinator.stopLocationPublishing()
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        // Dismiss confirmation (only shown when navigation is active)
        .alert("Exit Navigation?", isPresented: $showDismissAlert) {
            Button("Exit", role: .destructive) { dismissView() }
            Button("Keep Navigating", role: .cancel) {}
        } message: {
            Text("Your trip is still active. You can return to navigation from the trip detail screen.")
        }
        // Route selection — shown once routes are ready, before navigation starts
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) {
                startTracking()
            }
        }
        // Proof of delivery
        .sheet(isPresented: $showProofOfDelivery) {
            NavigationStack {
                ProofOfDeliveryView(
                    tripId: coordinator.trip.id,
                    driverId: user?.id ?? UUID()
                ) {
                    showProofOfDelivery = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Route Build

    private func buildAndShowRoutes() async {
        isBuildingRoutes = true
        routeBuildFailed = false
        await coordinator.buildRoutes()
        isBuildingRoutes = false

        if coordinator.currentRoute != nil {
            showRouteSelection = true
        } else {
            routeBuildFailed = true
        }
    }

    // MARK: - Start Tracking (called after driver confirms route)

    private func startTracking() {
        guard let vehicleIdStr = coordinator.trip.vehicleId,
              let vehicleId   = UUID(uuidString: vehicleIdStr),
              let driverId    = user?.id else { return }
        coordinator.startLocationTracking()
        coordinator.startLocationPublishing(vehicleId: vehicleId, driverId: driverId)
    }

    // MARK: - Dismiss Helper

    private func dismissView() {
        coordinator.stopLocationPublishing()
        speechSynthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
}
