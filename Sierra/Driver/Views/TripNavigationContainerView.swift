import SwiftUI
import AVFoundation

/// Full-screen container composing TripNavigationView + NavigationHUDOverlay.
/// Safeguard 9: .ignoresSafeArea() + tab bar hidden.
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showProofOfDelivery = false
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
                // End Trip tapped — stop navigation, show proof of delivery
                coordinator.stopLocationPublishing()
                coordinator.isNavigating = false
                showProofOfDelivery = true
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await coordinator.buildRoutes()
        }
        .onAppear {
            guard let vehicleIdStr = coordinator.trip.vehicleId,
                  let vehicleId = UUID(uuidString: vehicleIdStr),
                  let driverId = user?.id else { return }
            coordinator.startLocationPublishing(vehicleId: vehicleId, driverId: driverId)
        }
        .onDisappear {
            coordinator.stopLocationPublishing()
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        .onChange(of: coordinator.currentStepInstruction) { _, newInstruction in
            guard !newInstruction.isEmpty, newInstruction != lastSpokenInstruction else { return }
            lastSpokenInstruction = newInstruction
            let utterance = AVSpeechUtterance(string: newInstruction)
            utterance.rate = 0.52
            utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            speechSynthesizer.speak(utterance)
        }
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
}
