import SwiftUI

/// HUD overlay on top of TripNavigationView.
/// Shows instruction banner, stats, speed badge, off-route warning, and action bar.
struct NavigationHUDOverlay: View {

    let coordinator: TripNavigationCoordinator
    var onEndTrip: () -> Void

    @State private var showEndTripConfirm = false
    @State private var showAddStop = false
    @State private var showSOSAlert = false
    @State private var showIncidentReport = false
    @State private var stopAddress = ""
    @State private var geocodeTask: Task<Void, Never>?
    @State private var geocodedResults: [GeocodedStop] = []

    var body: some View {
        VStack(spacing: 0) {
            // Top instruction banner
            if !coordinator.currentStepInstruction.isEmpty {
                instructionBanner
            }

            Spacer()

            // Off-route warning banner
            if coordinator.hasDeviated {
                deviationBanner
            }

            // Stats row
            statsRow

            // Speed badge + speed limit
            HStack {
                speedBadge
                if let limit = coordinator.currentSpeedLimit {
                    speedLimitSign(limit)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Action bar
            actionBar
        }
        .sheet(isPresented: $showAddStop) {
            addStopSheet
        }
        .sheet(isPresented: $showSOSAlert) {
            SOSAlertSheet(
                tripId: coordinator.trip.id,
                vehicleId: UUID(uuidString: coordinator.trip.vehicleId ?? "")
            )
        }
        .sheet(isPresented: $showIncidentReport) {
            IncidentReportSheet()
        }
        .alert("End Trip?", isPresented: $showEndTripConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("End Trip", role: .destructive) {
                onEndTrip()
            }
        } message: {
            Text("This will stop navigation and take you to delivery confirmation.")
        }
    }

    // MARK: - Instruction Banner

    private var instructionBanner: some View {
        HStack(spacing: 14) {
            // Maneuver icon — resolves from instruction text
            Image(systemName: maneuverIcon(for: coordinator.currentStepManeuver.isEmpty
                                           ? coordinator.currentStepInstruction
                                           : coordinator.currentStepManeuver))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                // Distance to next turn
                Text(formatDistance(coordinator.distanceRemainingMetres))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(coordinator.currentStepInstruction)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private func maneuverIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("left")    { return "arrow.turn.up.left" }
        if lower.contains("right")   { return "arrow.turn.up.right" }
        if lower.contains("u-turn")  { return "arrow.uturn.left" }
        if lower.contains("merge")   { return "arrow.merge" }
        if lower.contains("exit")    { return "arrow.triangle.turn.up.right.circle" }
        if lower.contains("arrive")  { return "mappin.circle.fill" }
        if lower.contains("depart")  { return "arrow.up.circle.fill" }
        return "arrow.up"
    }

    private func formatDistance(_ metres: Double) -> String {
        if metres >= 1000 {
            return String(format: "%.1f km", metres / 1000)
        } else {
            return String(format: "%.0f m", metres)
        }
    }

    // MARK: - Deviation Banner

    private var deviationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.black)
            Text("Off Route — Recalculating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.yellow)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: String(format: "%.1f km", coordinator.distanceRemainingMetres / 1000),
                label: "Distance"
            )
            Divider().frame(height: 30)
            statItem(
                value: coordinator.estimatedArrivalTime?.formatted(.dateTime.hour().minute()) ?? "--:--",
                label: "ETA"
            )
            Divider().frame(height: 30)
            statItem(
                value: String(format: "%.0f min", coordinator.distanceRemainingMetres > 0
                              ? (coordinator.estimatedArrivalTime?.timeIntervalSinceNow ?? 0) / 60
                              : 0),
                label: "Remaining"
            )
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Speed Badge

    private var speedBadge: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", max(0, coordinator.currentSpeedKmh)))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
            Text("km/h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, height: 60)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Speed Limit Sign

    private func speedLimitSign(_ limit: Int) -> some View {
        VStack(spacing: 2) {
            Circle()
                .stroke(.red, lineWidth: 4)
                .frame(width: 52, height: 52)
                .overlay(
                    Text("\(limit)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                )
            Text("km/h").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            actionButton("SOS", icon: "sos", color: SierraTheme.Colors.danger) {
                showSOSAlert = true
            }
            actionButton("Incident", icon: "exclamationmark.triangle.fill", color: .orange) {
                showIncidentReport = true
            }
            actionButton("Add Stop", icon: "plus.circle", color: SierraTheme.Colors.info) {
                showAddStop = true
            }
            actionButton("End Trip", icon: "xmark.circle", color: SierraTheme.Colors.ember) {
                showEndTripConfirm = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Add Stop Sheet (Safeguard 5: 500ms debounce)

    private var addStopSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Search for a stop...", text: $stopAddress)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .onChange(of: stopAddress) { _, newValue in
                        geocodeTask?.cancel()
                        geocodeTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                            guard !Task.isCancelled else { return }
                            await geocodeAddress(newValue)
                        }
                    }

                if geocodedResults.isEmpty {
                    ContentUnavailableView("Type an address to search", systemImage: "mappin.and.ellipse")
                } else {
                    List(geocodedResults) { result in
                        Button {
                            Task {
                                await coordinator.addStop(
                                    latitude: result.latitude,
                                    longitude: result.longitude,
                                    name: result.name
                                )
                            }
                            showAddStop = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).font(.subheadline.weight(.medium))
                                Text(result.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer()
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddStop = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func geocodeAddress(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            geocodedResults = []
            return
        }

        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String else { return }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json?access_token=\(token)&limit=5") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let features = json["features"] as? [[String: Any]] {
                var results: [GeocodedStop] = []
                for feature in features {
                    let name = feature["text"] as? String ?? ""
                    let address = feature["place_name"] as? String ?? ""
                    if let center = feature["center"] as? [Double], center.count == 2 {
                        results.append(GeocodedStop(
                            name: name,
                            address: address,
                            longitude: center[0],
                            latitude: center[1]
                        ))
                    }
                }
                geocodedResults = results
            }
        } catch {
            print("[HUD] Geocoding error: \(error)")
        }
    }
}

// MARK: - GeocodedStop

struct GeocodedStop: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let longitude: Double
    let latitude: Double
}
