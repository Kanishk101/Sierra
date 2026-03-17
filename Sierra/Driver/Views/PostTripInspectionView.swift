import SwiftUI

/// Post-trip inspection + trip completion.
/// Same structure as PreTripInspectionView but completes the trip on submit.
struct PostTripInspectionView: View {

    let tripId: UUID
    let vehicleId: UUID
    let driverId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PreTripInspectionViewModel
    @State private var endOdometerText = ""
    @State private var showCompletedAlert = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(tripId: UUID, vehicleId: UUID, driverId: UUID) {
        self.tripId = tripId
        self.vehicleId = vehicleId
        self.driverId = driverId
        _viewModel = State(initialValue: PreTripInspectionViewModel(
            tripId: tripId, vehicleId: vehicleId, driverId: driverId, inspectionType: .postTripInspection
        ))
    }

    private var trip: Trip? { store.trips.first { $0.id == tripId } }

    var body: some View {
        VStack(spacing: 0) {
            if showCompletedAlert {
                completedView
            } else if viewModel.currentStep <= 3 {
                // Reuse the PreTripInspectionView for the inspection part
                PreTripInspectionView(
                    tripId: tripId,
                    vehicleId: vehicleId,
                    driverId: driverId,
                    inspectionType: .postTripInspection,
                    onComplete: {
                        viewModel.didSubmitSuccessfully = true
                    }
                )
            }

            if viewModel.didSubmitSuccessfully && !showCompletedAlert {
                odometerAndComplete
            }
        }
        .navigationTitle("Post-Trip Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !showCompletedAlert {
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
        VStack(spacing: 16) {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("End Odometer Reading (km)")
                    .font(.subheadline.weight(.medium))
                TextField("e.g. 45380", text: $endOdometerText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 16)

            // Safeguard 6: completeTrip gated behind proof_of_delivery_id
            // Safeguard 7: Task { } not .task { }
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
        // Safeguard 6: check proof of delivery exists
        guard let trip = trip, trip.proofOfDeliveryId != nil else {
            errorMessage = "Please submit proof of delivery before completing the trip."
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
            showCompletedAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
