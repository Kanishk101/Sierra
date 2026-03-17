import SwiftUI
import MapKit

/// Sheet for creating a new geofence with map preview and geocoding.
struct CreateGeofenceSheet: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var geofenceDescription = ""
    @State private var geofenceType: GeofenceType = .warehouse
    @State private var radiusMeters: Double = 500
    @State private var alertOnEntry = true
    @State private var alertOnExit = false

    // Location
    @State private var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var hasSetLocation = false
    @State private var addressQuery = ""
    @State private var geocodedResults: [GeocodedResult] = []
    @State private var geocodeTask: Task<Void, Never>?

    // Map
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 50000,
            longitudinalMeters: 50000
        )
    )

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Map preview
                    mapPreview

                    // Address search
                    addressSearchSection

                    Divider()

                    // Fields
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Name")
                        TextField("e.g. Main Warehouse", text: $name)
                            .textFieldStyle(.roundedBorder)

                        fieldLabel("Description")
                        TextField("Optional description", text: $geofenceDescription)
                            .textFieldStyle(.roundedBorder)

                        fieldLabel("Type")
                        Picker("Type", selection: $geofenceType) {
                            ForEach(GeofenceType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        fieldLabel("Radius: \(Int(radiusMeters))m")
                        Slider(value: $radiusMeters, in: 100...5000, step: 50)
                            .tint(SierraTheme.Colors.ember)

                        Toggle("Alert on Entry", isOn: $alertOnEntry)
                            .font(.subheadline)
                        Toggle("Alert on Exit", isOn: $alertOnExit)
                            .font(.subheadline)
                    }

                    Spacer(minLength: 20)

                    // Safeguard 6: validate before saving
                    Button {
                        Task { await saveGeofence() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Save Geofence")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSave ? SierraTheme.Colors.ember : Color.gray,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canSave || isSaving)
                }
                .padding(16)
            }
            .navigationTitle("Create Geofence")
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
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(position: $cameraPosition) {
            if hasSetLocation {
                MapCircle(center: coordinate, radius: radiusMeters)
                    .foregroundStyle(geofenceColor.opacity(0.2))
                    .stroke(geofenceColor, lineWidth: 2)

                Annotation("", coordinate: coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(geofenceColor)
                }
            }
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { location in
            // Note: SwiftUI Map doesn't support direct tap-to-coordinate.
            // Admin should use address search to set coordinates.
        }
    }

    // MARK: - Address Search (Safeguard 3: 500ms debounce)

    private var addressSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Search Address")
            TextField("Enter address to geocode...", text: $addressQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: addressQuery) { _, newValue in
                    geocodeTask?.cancel()
                    geocodeTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                        guard !Task.isCancelled else { return }
                        await geocodeAddress(newValue)
                    }
                }

            if !geocodedResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(geocodedResults) { result in
                        Button {
                            selectGeocodedResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(result.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                        Divider()
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
    }

    private var geofenceColor: Color {
        switch geofenceType {
        case .warehouse: return .blue
        case .deliveryPoint: return .green
        case .restrictedZone: return .red
        case .custom: return .gray
        }
    }

    // Safeguard 6: validate
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && coordinate.latitude != 0
        && coordinate.longitude != 0
        && radiusMeters >= 100
        && radiusMeters <= 5000
    }

    // MARK: - Geocoding

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
                var results: [GeocodedResult] = []
                for feature in features {
                    let name = feature["text"] as? String ?? ""
                    let address = feature["place_name"] as? String ?? ""
                    if let center = feature["center"] as? [Double], center.count == 2 {
                        results.append(GeocodedResult(
                            name: name, address: address,
                            longitude: center[0], latitude: center[1]
                        ))
                    }
                }
                geocodedResults = results
            }
        } catch {
            print("[CreateGeofence] Geocoding error: \(error)")
        }
    }

    private func selectGeocodedResult(_ result: GeocodedResult) {
        coordinate = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
        hasSetLocation = true
        geocodedResults = []
        addressQuery = result.address

        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters * 4,
            longitudinalMeters: radiusMeters * 4
        ))
    }

    // MARK: - Save

    private func saveGeofence() async {
        guard canSave else { return }
        guard let adminId = AuthManager.shared.currentUser?.id else {
            errorMessage = "Not authenticated"
            showError = true
            return
        }

        isSaving = true
        do {
            try await GeofenceService.createGeofence(
                name: name,
                description: geofenceDescription,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: radiusMeters,
                geofenceType: geofenceType,
                alertOnEntry: alertOnEntry,
                alertOnExit: alertOnExit,
                createdByAdminId: adminId
            )

            // Refresh geofences
            let updated = try await GeofenceService.fetchAllGeofences()
            store.geofences = updated

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - GeocodedResult

struct GeocodedResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let longitude: Double
    let latitude: Double
}
