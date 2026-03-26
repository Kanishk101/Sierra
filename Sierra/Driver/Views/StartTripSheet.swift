import SwiftUI

/// Bottom sheet for entering odometer + selecting route before starting navigation.
struct StartTripSheet: View {

    let tripId: UUID
    var onStarted: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var odometerText = ""
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var trip: Trip? { store.trips.first { $0.id == tripId } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Odometer
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Odometer Reading (km)")
                        .font(.subheadline.weight(.medium))
                    TextField("e.g. 45230", text: $odometerText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                Text("Route is preset by Fleet Manager and locked for this trip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 20)

                Button {
                    Task { await startNavigation() }
                } label: {
                    HStack {
                        if isStarting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                        }
                        Text("Start Navigation")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canStart ? SierraTheme.Colors.alpineMint : Color.gray,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canStart || isStarting)
            }
            .padding(16)
        }
        .navigationTitle("Start Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Logic

    private var canStart: Bool {
        guard let mileage = Double(odometerText), mileage > 0 else { return false }
        return true
    }

    private func startNavigation() async {
        guard let mileage = Double(odometerText) else {
            errorMessage = "Please enter a valid odometer reading"
            showError = true
            return
        }

        isStarting = true
        guard let trip,
              let lockedRoutePolyline = trip.routePolyline?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lockedRoutePolyline.isEmpty else {
            errorMessage = "Route is missing on this trip. Ask fleet manager to set route and retry."
            showError = true
            isStarting = false
            return
        }

        do {
            try await store.startActiveTrip(tripId: tripId, startMileage: mileage)

            if let originLat = trip.originLatitude,
               let originLng = trip.originLongitude,
               let destLat = trip.destinationLatitude,
               let destLng = trip.destinationLongitude {
                try await TripService.updateTripCoordinates(
                    tripId: tripId,
                    originLat: originLat,
                    originLng: originLng,
                    destLat: destLat,
                    destLng: destLng,
                    routePolyline: lockedRoutePolyline
                )

                if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                    store.trips[idx].originLatitude = originLat
                    store.trips[idx].originLongitude = originLng
                    store.trips[idx].destinationLatitude = destLat
                    store.trips[idx].destinationLongitude = destLng
                    store.trips[idx].routePolyline = lockedRoutePolyline
                }
            }

            onStarted()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isStarting = false
    }
}
