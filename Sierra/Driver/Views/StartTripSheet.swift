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

        do {
            try await store.startActiveTrip(tripId: tripId, startMileage: mileage)

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

        // Build exclude string
        var exclusions: [String] = []
        if avoidTolls { exclusions.append("toll") }
        if avoidHighways { exclusions.append("motorway") }
        if !exclusions.isEmpty {
            urlString += "&exclude=\(exclusions.joined(separator: ","))"
        }

        guard let url = URL(string: urlString) else {
            isFetchingRoutes = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let routes = json["routes"] as? [[String: Any]], !routes.isEmpty {

                // Parse all returned routes
                struct RawRoute {
                    let distanceM: Double
                    let durationS: Double
                    let geometry: String
                }

                let rawRoutes: [RawRoute] = routes.prefix(3).compactMap { route in
                    guard let dist = route["distance"] as? Double,
                          let dur = route["duration"] as? Double,
                          let geo = route["geometry"] as? String else { return nil }
                    return RawRoute(distanceM: dist, durationS: dur, geometry: geo)
                }

                guard !rawRoutes.isEmpty else {
                    isFetchingRoutes = false
                    return
                }

                // Fastest = lowest duration
                let fastest = rawRoutes.min(by: { $0.durationS < $1.durationS })!

                // Green = lowest distance (correlates to least fuel — fewer km = less fuel burned)
                // Must be a different route from fastest if alternatives exist
                let green: RawRoute? = rawRoutes.count > 1
                    ? rawRoutes.filter { $0.geometry != fastest.geometry }
                               .min(by: { $0.distanceM < $1.distanceM })
                    : nil

                var options: [RouteOption] = [
                    RouteOption(
                        label: "Fastest Route",
                        distanceKm: fastest.distanceM / 1000.0,
                        durationMinutes: fastest.durationS / 60.0,
                        geometry: fastest.geometry,
                        isGreen: false
                    )
                ]

                if let g = green {
                    options.append(RouteOption(
                        label: "Green Route",
                        distanceKm: g.distanceM / 1000.0,
                        durationMinutes: g.durationS / 60.0,
                        geometry: g.geometry,
                        isGreen: true
                    ))
                }

                routeOptions = options
                selectedRouteIndex = 0
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
    let isGreen: Bool
}
