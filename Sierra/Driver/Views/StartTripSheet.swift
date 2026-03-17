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

    // Route options (fetched on Start Navigation tap — Safeguard 3)
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

                // Route options (shown after fetch)
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

                // Start Navigation — Safeguard 7: uses Task { }
                Button {
                    Task { await startNavigation() }
                } label: {
                    HStack {
                        if isStarting {
                            ProgressView()
                                .tint(.white)
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
            Image(systemName: route.label.contains("Green") ? "leaf.fill" : "bolt.fill")
                .foregroundStyle(route.label.contains("Green") ? .green : SierraTheme.Colors.ember)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.label)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    Text(String(format: "%.1f km", route.distanceKm))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f min", route.durationMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    /// Safeguard 3: Directions API fires ONCE on this button tap, never reactively.
    private func startNavigation() async {
        guard let mileage = Double(odometerText) else {
            errorMessage = "Please enter a valid odometer reading"
            showError = true
            return
        }

        isStarting = true

        // Fetch routes if not already fetched
        if routeOptions.isEmpty {
            await fetchRouteOptions()
            if routeOptions.isEmpty {
                // No routes fetched — continue without route data
                print("[StartTripSheet] No route options available, starting without Mapbox data")
            }
        }

        do {
            try await store.startActiveTrip(tripId: tripId, startMileage: mileage)

            // Save route coordinates if available
            if let trip = trip,
               let originLat = trip.originLatitude,
               let originLng = trip.originLongitude,
               let destLat = trip.destinationLatitude,
               let destLng = trip.destinationLongitude,
               !routeOptions.isEmpty {
                try? await TripService.updateTripCoordinates(
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

        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String else {
            print("[StartTripSheet] No MBXAccessToken in Info.plist")
            return
        }

        isFetchingRoutes = true

        var urlString = "https://api.mapbox.com/directions/v5/mapbox/driving/"
        urlString += "\(originLng),\(originLat);\(destLng),\(destLat)"
        urlString += "?alternatives=true&geometries=polyline6&overview=full&access_token=\(token)"

        if avoidTolls { urlString += "&exclude=toll" }
        if avoidHighways { urlString += (urlString.contains("exclude=") ? ",motorway" : "&exclude=motorway") }

        guard let url = URL(string: urlString) else {
            isFetchingRoutes = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let routes = json["routes"] as? [[String: Any]] {
                var options: [RouteOption] = []
                for (idx, route) in routes.prefix(2).enumerated() {
                    let distanceM = route["distance"] as? Double ?? 0
                    let durationS = route["duration"] as? Double ?? 0
                    let geometry = route["geometry"] as? String ?? ""
                    options.append(RouteOption(
                        label: idx == 0 ? "Fastest Route" : "Green Route (Fuel Efficient)",
                        distanceKm: distanceM / 1000.0,
                        durationMinutes: durationS / 60.0,
                        geometry: geometry
                    ))
                }
                routeOptions = options
            }
        } catch {
            print("[StartTripSheet] Route fetch error: \(error)")
        }

        isFetchingRoutes = false
    }
}

// MARK: - RouteOption

struct RouteOption {
    let label: String
    let distanceKm: Double
    let durationMinutes: Double
    let geometry: String
}
