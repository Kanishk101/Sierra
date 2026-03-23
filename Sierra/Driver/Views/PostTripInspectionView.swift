import SwiftUI

/// Post-trip inspection + trip completion.
/// BUG-05 FIX: Uses a clean phase-based state machine instead of a dual-ViewModel pattern.
/// Phase 1: .inspecting — embeds PreTripInspectionView
/// Phase 2: .enteringOdometer — shows end-odometer + Complete Trip form
/// Phase 3: .completed — shows success screen
struct PostTripInspectionView: View {

    let tripId: UUID
    let vehicleId: UUID
    let driverId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // BUG-05 FIX: Single phase enum drives the entire UI
    enum Phase { case inspecting, enteringOdometer, completed }
    @State private var phase: Phase = .inspecting
    @State private var endOdometerText = ""
    @State private var errorMessage: String?
    @State private var showError = false

    private var trip: Trip? { store.trips.first { $0.id == tripId } }

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
                        withAnimation { phase = .enteringOdometer }
                    }
                )

            case .enteringOdometer:
                odometerAndComplete

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
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Odometer + Complete

    private var odometerAndComplete: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SierraTheme.Colors.alpineMint)

            Text("Post-Trip Inspection Complete")
                .font(.headline)

            Text("Enter the final odometer reading to complete the trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("End Odometer Reading (km)")
                    .font(.subheadline.weight(.medium))
                TextField("e.g. 45380", text: $endOdometerText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 16)

            Spacer()

            Button {
                Task { await completeTrip() }
            } label: {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("Complete Trip")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(endOdometerValid ? SierraTheme.Colors.alpineMint : Color.gray,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!endOdometerValid)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(SierraTheme.Colors.alpineMint)

            Text("Trip Completed!")
                .font(.title2.weight(.bold))

            Text("Your trip has been recorded successfully.\nThank you for driving safely.")
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

    // MARK: - Logic

    private var endOdometerValid: Bool {
        guard let value = Double(endOdometerText), value > 0 else { return false }
        return true
    }

    private func completeTrip() async {
        guard let _ = trip else {
            errorMessage = "Trip not found."
            showError = true
            return
        }

        guard let endMileage = Double(endOdometerText) else {
            errorMessage = "Please enter a valid odometer reading"
            showError = true
            return
        }

        do {
            try await store.endTrip(tripId: tripId, endMileage: endMileage)
            withAnimation { phase = .completed }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
