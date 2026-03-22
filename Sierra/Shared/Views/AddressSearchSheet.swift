import SwiftUI
import MapKit

struct GeocodedAddress: Identifiable, Hashable, Codable {
    let id: UUID
    let displayName: String
    let shortName: String
    let latitude: Double
    let longitude: Double

    init(displayName: String, shortName: String, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.displayName = displayName
        self.shortName = shortName
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Reusable Mapbox Geocoding address search sheet.
struct AddressSearchSheet: View {
    let placeholder: String
    let onSelect: (GeocodedAddress) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeocodedAddress] = []
    @State private var isSearching = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if results.isEmpty && !query.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "mappin.slash")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No results found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(results) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.shortName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(result.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: placeholder)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 3 else {
                    results = []
                    return
                }
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    await search(trimmed)
                }
            }
        }
    }

    // MARK: - Mapbox Geocoding

    @MainActor
    private func search(_ text: String) async {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
              !token.isEmpty else {
            // Fallback to MKLocalSearch if no Mapbox token
            await searchAppleMaps(text)
            return
        }

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json?access_token=\(token)&limit=8&country=IN&language=en&proximity=77.2090,28.6139"
        guard let url = URL(string: urlString) else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]] ?? []

            results = features.compactMap { feature -> GeocodedAddress? in
                guard let geometry = feature["geometry"] as? [String: Any],
                      let coords = geometry["coordinates"] as? [Double],
                      coords.count >= 2 else { return nil }
                let placeName = feature["place_name"] as? String ?? ""
                let text = feature["text"] as? String ?? placeName
                return GeocodedAddress(
                    displayName: placeName,
                    shortName: text,
                    latitude: coords[1],
                    longitude: coords[0]
                )
            }
        } catch {
            print("[AddressSearch] Geocoding error: \(error)")
            // Fallback to Apple Maps on error
            await searchAppleMaps(text)
        }
    }

    // MARK: - Apple Maps Fallback

    @MainActor
    private func searchAppleMaps(_ text: String) async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 3_000_000, longitudinalMeters: 3_000_000
        )
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            results = response.mapItems.map { item in
                let coordinate = item.location.coordinate
                return GeocodedAddress(
                    displayName: item.name ?? "Unknown location",
                    shortName: item.name ?? "",
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        } else {
            results = []
        }
    }
}

#Preview {
    AddressSearchSheet(placeholder: "Search address…") { result in
        print("Selected: \(result.displayName)")
    }
}
