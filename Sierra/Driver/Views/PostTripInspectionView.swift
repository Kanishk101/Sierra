import SwiftUI

/// Post-trip inspection wrapper.
/// Odometer capture is handled in OCR flow inside PreTripInspectionView (step 2),
/// with manual entry as fallback in that same step.
/// There is no extra "enter odometer again" page here.
struct PostTripInspectionView: View {

    let tripId: UUID
    let vehicleId: UUID
    let driverId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Phase { case inspecting, completed }
    @State private var phase: Phase = .inspecting

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .inspecting:
                PreTripInspectionView(
                    tripId: tripId,
                    vehicleId: vehicleId,
                    driverId: driverId,
                    inspectionType: .postTripInspection,
                    onComplete: {
                        finalizeAfterInspection()
                    }
                )

            case .completed:
                completedView
            }
        }
        .navigationTitle("Post-Trip Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if phase != .completed {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(SierraTheme.Colors.alpineMint)

            Text("Inspection Submitted!")
                .font(.title2.weight(.bold))

            Text("Post-trip inspection recorded successfully.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func finalizeAfterInspection() {
        TripNavigationCoordinator.clearSession(for: tripId)
        if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
            // Mirror expected final state locally once post inspection is done.
            if store.trips[idx].proofOfDeliveryId != nil, store.trips[idx].endMileage != nil {
                store.trips[idx].status = .completed
                if store.trips[idx].actualEndDate == nil {
                    store.trips[idx].actualEndDate = Date()
                }
            }
        }
        withAnimation { phase = .completed }
        Task { await store.refreshDriverData(driverId: driverId, force: true) }
    }
}
