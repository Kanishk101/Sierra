import SwiftUI
import AVFoundation

/// Full-screen container composing TripNavigationView + NavigationHUDOverlay.
/// Flow:
///   1. .task fires buildRoutes() and shows a spinner while the Mapbox API call is in-flight.
///   2. On success, RouteSelectionSheet is presented so the driver can choose Fastest or Green.
///   3. After the driver confirms, startLocationTracking() + startLocationPublishing() begin.
///   4. Navigation runs; End Trip triggers ProofOfDeliveryView.
///
/// Safeguard: location tracking is NOT started in .onAppear — it starts only after the driver
/// has confirmed a route in RouteSelectionSheet. This prevents battery drain when the sheet
/// is dismissed or the build fails.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showProofOfDelivery = false
    @State private var showRouteSelection  = false
    @State private var isBuildingRoutes    = false
    @State private var routeBuildFailed    = false
    @State private var lastSpokenInstruction = ""
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
                // End Trip tapped
                coordinator.stopLocationPublishing()
                coordinator.isNavigating = false
                showProofOfDelivery = true
            }

            // Spinner while Mapbox API call is in-flight
            if isBuildingRoutes {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Calculating routes\u{2026}")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
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
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Could not calculate routes")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Check your connection and try again")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Button("Retry") {
                            routeBuildFailed = false
                            Task { await buildAndShowRoutes() }
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    }
                    .padding(16)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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
        // Route selection — shown once routes are ready, before navigation starts
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) {
                // Driver confirmed a route — now start location tracking
                startTracking()
            }
        }
        // Proof of delivery — shown when driver ends the trip
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
            // Routes ready — show selection sheet
            showRouteSelection = true
        } else {
            // API call failed — show retry banner
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
}
