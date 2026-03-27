import SwiftUI
import MapKit
import CoreLocation
import Combine
import Contacts

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

@MainActor
final class AddressSearchLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func start() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func requestSingleFix() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[AddressSearchLocationProvider] Location error: \(error)")
        #endif
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedAlways || self.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
                manager.requestLocation()
            }
        }
    }
}

/// Reusable Mapbox Geocoding address search sheet.
struct AddressSearchSheet: View {
    let placeholder: String
    var showMyLocation: Bool = true
    let onSelect: (GeocodedAddress) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeocodedAddress] = []
    @State private var isSearching = false
    @State private var debounceTask: Task<Void, Never>?
    @StateObject private var locationProvider = AddressSearchLocationProvider()

    private let indiaLatitudeRange = 6.0...38.5
    private let indiaLongitudeRange = 68.0...98.5
    private let indiaBoundingBox = "68.0,6.0,98.5,38.5"

    var body: some View {
        NavigationStack {
            List {
                if showMyLocation {
                    Button {
                        selectMyLocation()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.appOrange, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("My Location")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let location = locationProvider.currentLocation {
                                    Text("Use exact coordinates (\(formatCoordinate(location.coordinate.latitude)), \(formatCoordinate(location.coordinate.longitude)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                } else if locationProvider.authorizationStatus == .denied || locationProvider.authorizationStatus == .restricted {
                                    Text("Location permission is disabled")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Tap to fetch your current coordinates")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowSeparator(.visible)
                }

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
            .onAppear { locationProvider.start() }
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 1 else {
                    results = []
                    return
                }
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    await search(trimmed)
                }
            }
        }
    }

    // MARK: - Mapbox Geocoding

    @MainActor
    private func search(_ text: String) async {
        isSearching = true
        defer { isSearching = false }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String
        let hasMapboxToken = (token?.isEmpty == false)

        async let appleResults = searchAppleMapsResults(trimmed)
        async let mapboxResults = hasMapboxToken ? searchMapboxResults(trimmed, token: token ?? "") : []

        let merged = deduplicateResults((await mapboxResults) + (await appleResults))
        results = Array(merged.prefix(30))
    }

    private func searchMapboxResults(_ text: String, token: String) async -> [GeocodedAddress] {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        var components = URLComponents(string: "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "autocomplete", value: "true"),
            URLQueryItem(name: "country", value: "IN"),
            URLQueryItem(name: "bbox", value: indiaBoundingBox),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "fuzzyMatch", value: "true"),
            URLQueryItem(name: "routing", value: "true"),
            URLQueryItem(name: "types", value: "poi,address,place,locality,neighborhood,district,region,postcode")
        ]
        if let location = locationProvider.currentLocation {
            queryItems.append(
                URLQueryItem(
                    name: "proximity",
                    value: "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                )
            )
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]] ?? []

            return features.compactMap { feature -> GeocodedAddress? in
                guard let geometry = feature["geometry"] as? [String: Any],
                      let coords = geometry["coordinates"] as? [Double],
                      coords.count >= 2 else { return nil }

                let latitude = coords[1]
                let longitude = coords[0]
                guard isInsideIndia(latitude: latitude, longitude: longitude) else { return nil }

                let placeName = feature["place_name"] as? String ?? ""
                let text = feature["text"] as? String ?? placeName
                return GeocodedAddress(
                    displayName: cleanedDisplayName(placeName),
                    shortName: cleanedShortName(text, fallback: placeName),
                    latitude: latitude,
                    longitude: longitude
                )
            }
        } catch {
            print("[AddressSearch] Geocoding error: \(error)")
            return []
        }
    }

    // MARK: - Apple Maps Fallback

    private func searchAppleMapsResults(_ text: String) async -> [GeocodedAddress] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 3_000_000, longitudinalMeters: 3_000_000
        )
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            return response.mapItems
                .filter { item in
                    let coordinate = item.location.coordinate
                    return isInsideIndia(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
                .map { item in
                    let coordinate = item.location.coordinate
                    let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let formattedAddress = item.placemark.postalAddress.map {
                        CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                            .replacingOccurrences(of: "\n", with: ", ")
                    } ?? item.placemark.title ?? title ?? "Unknown location"

                    return GeocodedAddress(
                        displayName: cleanedDisplayName(formattedAddress),
                        shortName: cleanedShortName(title, fallback: formattedAddress),
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                }
                .sorted { lhs, rhs in
                    lhs.shortName.localizedCaseInsensitiveCompare(rhs.shortName) == .orderedAscending
                }
        } else {
            return []
        }
    }

    private func deduplicateResults(_ items: [GeocodedAddress]) -> [GeocodedAddress] {
        var seen = Set<String>()
        var merged: [GeocodedAddress] = []

        for item in items {
            let key = [
                item.shortName.lowercased(),
                item.displayName.lowercased(),
                String(format: "%.4f", item.latitude),
                String(format: "%.4f", item.longitude)
            ].joined(separator: "|")

            if seen.insert(key).inserted {
                merged.append(item)
            }
        }

        return merged
    }

    private func isInsideIndia(latitude: Double, longitude: Double) -> Bool {
        indiaLatitudeRange.contains(latitude) && indiaLongitudeRange.contains(longitude)
    }

    private func cleanedDisplayName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedShortName(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return cleanedDisplayName(fallback.components(separatedBy: ",").first ?? fallback)
    }

    private func selectMyLocation() {
        if let location = locationProvider.currentLocation {
            onSelect(
                GeocodedAddress(
                    displayName: "My Location (\(formatCoordinate(location.coordinate.latitude)), \(formatCoordinate(location.coordinate.longitude)))",
                    shortName: "My Location",
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
            dismiss()
            return
        }
        locationProvider.requestSingleFix()
    }

    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

#Preview {
    AddressSearchSheet(placeholder: "Search address…") { result in
        print("Selected: \(result.displayName)")
    }
}
