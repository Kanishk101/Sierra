import SwiftUI
import AVFoundation

/// Full-screen navigation container.
/// X button top-left to exit. Confirmation alert when navigation is active.
/// Better error messages based on RouteEngine.lastBuildError.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showProofOfDelivery = false
    @State private var showRouteSelection  = false
    @State private var isBuildingRoutes    = false
    @State private var routeBuildFailed    = false
    @State private var buildErrorMessage   = "Could not calculate route. Check your connection and try again."
    @State private var lastSpokenInstruction = ""
    @State private var showDismissAlert    = false
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
                coordinator.stopLocationPublishing()
                coordinator.isNavigating = false
                showProofOfDelivery = true
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
                        Text("Calculating route\u{2026}").font(.subheadline.weight(.medium)).foregroundStyle(.white)
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
        .task { await buildAndShowRoutes() }
        .onChange(of: coordinator.currentStepInstruction) { _, newInstruction in
            guard !newInstruction.isEmpty, newInstruction != lastSpokenInstruction else { return }
            lastSpokenInstruction = newInstruction
            let utterance = AVSpeechUtterance(string: newInstruction)
            utterance.rate = 0.52
            utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            speechSynthesizer.speak(utterance)
        }
        .onDisappear { coordinator.stopLocationPublishing(); speechSynthesizer.stopSpeaking(at: .immediate) }
        .alert("Exit Navigation?", isPresented: $showDismissAlert) {
            Button("Exit", role: .destructive) { dismissView() }
            Button("Keep Navigating", role: .cancel) {}
        } message: { Text("Your trip is still active. You can return to navigation from the trip detail screen.") }
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) { startTracking() }
        }
        .sheet(isPresented: $showProofOfDelivery) {
            NavigationStack {
                ProofOfDeliveryView(tripId: coordinator.trip.id, driverId: user?.id ?? UUID()) {
                    showProofOfDelivery = false; dismiss()
                }
            }
        }
    }

    private func buildAndShowRoutes() async {
        isBuildingRoutes = true
        routeBuildFailed = false
        await coordinator.buildRoutes()
        isBuildingRoutes = false

        if coordinator.currentRoute != nil {
            showRouteSelection = true
        } else {
            // Surface the specific error from RouteEngine so the driver knows what's wrong
            buildErrorMessage = coordinator.routeEngineError ?? "Could not calculate route. Check your network and try again."
            routeBuildFailed = true
        }
    }

    private func startTracking() {
        guard let vehicleIdStr = coordinator.trip.vehicleId,
              let vehicleId = UUID(uuidString: vehicleIdStr),
              let driverId = user?.id else { return }
        coordinator.startLocationTracking()
        coordinator.startLocationPublishing(vehicleId: vehicleId, driverId: driverId)
    }

    private func dismissView() {
        coordinator.stopLocationPublishing()
        speechSynthesizer.stopSpeaking(at: .immediate)
        dismiss()
    }
}
