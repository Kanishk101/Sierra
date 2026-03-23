import SwiftUI

/// Bottom sheet for entering odometer + selecting route before starting navigation.
struct StartTripSheet: View {

    let tripId: UUID
    var onStarted: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var odometerText = ""
    @State private var avoidTolls = false
    @State private var avoidHighways = false
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var showError = false

    @State private var routeOptions: [RouteOption] = []
    @State private var selectedRouteIndex = 0
    @State private var isFetchingRoutes = false

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

                // Avoidance toggles
                VStack(spacing: 0) {
                    Toggle(isOn: $avoidTolls) {
                        Label("Avoid Tolls", systemImage: "banknote")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    Toggle(isOn: $avoidHighways) {
                        Label("Avoid Highways", systemImage: "road.lanes")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                if isFetchingRoutes {
                    HStack {
                        ProgressView()
                        Text("Fetching routes...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }

                if !routeOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ROUTE OPTIONS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .kerning(1)

                        ForEach(routeOptions.indices, id: \.self) { idx in
                            routeCard(routeOptions[idx], isSelected: idx == selectedRouteIndex)
                                .onTapGesture { selectedRouteIndex = idx }
                        }
                    }
                }

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

    // MARK: - Route Card

    private func routeCard(_ route: RouteOption, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: route.isGreen ? "leaf.fill" : "bolt.fill")
                .foregroundStyle(route.isGreen ? .green : SierraTheme.Colors.ember)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.label)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    Text(String(format: "%.1f km", route.distanceKm))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.0f min", route.durationMinutes))
                        .font(.caption).foregroundStyle(.secondary)
                    if route.isGreen {
                        Text("Least fuel")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SierraTheme.Colors.ember)
            }
        }
        .padding(12)
        .background(isSelected
                    ? SierraTheme.Colors.ember.opacity(0.08)
                    : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? SierraTheme.Colors.ember : Color.clear, lineWidth: 1.5)
        )
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

        if routeOptions.isEmpty {
            await fetchRouteOptions()
        }

        // BUG-09 FIX: Block trip start if no routes were obtained
        guard !routeOptions.isEmpty else {
            errorMessage = "Unable to fetch route. Please check network connection and try again."
            showError = true
            isStarting = false
            return
        }

        do {
            try await store.startActiveTrip(tripId: tripId, startMileage: mileage)

            if let trip = trip,
               let originLat = trip.originLatitude,
               let originLng = trip.originLongitude,
               let destLat = trip.destinationLatitude,
               let destLng = trip.destinationLongitude {
                // BUG-09 FIX: Use `try` instead of `try?` so errors are surfaced
                try await TripService.updateTripCoordinates(
                    tripId: tripId,
                    originLat: originLat,
                    originLng: originLng,
                    destLat: destLat,
                    destLng: destLng,
                    routePolyline: routeOptions[selectedRouteIndex].geometry
                )
            }

            onStarted()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isStarting = false
    }

    private func fetchRouteOptions() async {
        guard let trip = trip,
              let originLat = trip.originLatitude,
              let originLng = trip.originLongitude,
              let destLat = trip.destinationLatitude,
              let destLng = trip.destinationLongitude else { return }

        isFetchingRoutes = true
        defer { isFetchingRoutes = false }

        do {
            let mapRoutes = try await MapService.fetchRoutes(
                originLat: originLat, originLng: originLng,
                destLat: destLat, destLng: destLng,
                avoidTolls: avoidTolls,
                avoidHighways: avoidHighways
            )

            routeOptions = mapRoutes.map { RouteOption(from: $0) }
            selectedRouteIndex = 0
        } catch let error as MapServiceError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - RouteOption

struct RouteOption {
    let label: String
    let distanceKm: Double
    let durationMinutes: Double
    let geometry: String
    let isGreen: Bool
    let steps: [RouteStep]

    init(label: String, distanceKm: Double, durationMinutes: Double, geometry: String, isGreen: Bool, steps: [RouteStep] = []) {
        self.label = label
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.geometry = geometry
        self.isGreen = isGreen
        self.steps = steps
    }

    init(from mapRoute: MapRoute) {
        self.label = mapRoute.label
        self.distanceKm = mapRoute.distanceKm
        self.durationMinutes = mapRoute.durationMinutes
        self.geometry = mapRoute.geometry
        self.isGreen = mapRoute.isGreen
        self.steps = mapRoute.steps
    }
}

