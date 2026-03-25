import SwiftUI
import MapKit

/// Bottom sheet showing vehicle details when admin taps an annotation.
struct VehicleMapDetailSheet: View {

    let vehicle: Vehicle
    var viewModel: FleetLiveMapViewModel
    var onDismiss: () -> Void

    @Environment(AppDataStore.self) private var store
    @State private var latestVehicle: Vehicle?
    @State private var vehicleTrips: [Trip] = []
    @State private var isLoadingDetails = false
    @State private var detailsError: String?
    @State private var isSendingAlert = false
    @State private var alertSent = false

    private var displayedVehicle: Vehicle { latestVehicle ?? vehicle }

    private var activeTrip: Trip? {
        vehicleTrips.first { $0.status.normalized == .active }
    }

    private var assignedDriver: StaffMember? {
        guard let driverId = displayedVehicle.assignedDriverId?.lowercased() else { return nil }
        return store.staff.first { $0.id.uuidString.lowercased() == driverId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    vehicleHeader
                    Divider()

                    if isLoadingDetails {
                        ProgressView("Loading latest vehicle details...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let detailsError {
                        Text(detailsError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let trip = activeTrip {
                        activeTripSection(trip)
                    } else {
                        idleSection
                    }

                    allTripsSection
                }
                .padding(16)
            }
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { tripId in
                TripDetailView(tripId: tripId)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            Task {
                await loadLatestDetails()
                if let trip = activeTrip {
                    await viewModel.fetchBreadcrumb(vehicleId: displayedVehicle.id, tripId: trip.id)
                } else {
                    await viewModel.fetchRecentBreadcrumb(vehicleId: displayedVehicle.id)
                }
            }
        }
    }

    // MARK: - Vehicle Header

    private var vehicleHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: 50, height: 50)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayedVehicle.name) \(displayedVehicle.model)")
                    .font(.headline)
                Text(displayedVehicle.licensePlate)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(displayedVehicle.status.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }
            Spacer()
        }
    }

    // MARK: - Active Trip

    private func activeTripSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Trip info
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE TRIP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .kerning(1)

                Text(trip.taskId)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(SierraTheme.Colors.ember)

                HStack(spacing: 8) {
                    Label(trip.origin, systemImage: "location.circle.fill")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                    Text("\u{2192}")
                        .font(.caption)
                    Label(trip.destination, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            // Mini route preview map
            routePreviewMap(trip)


            // Driver info
            if let driver = assignedDriver {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundStyle(SierraTheme.Colors.info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(driver.name ?? "Unknown")
                            .font(.subheadline.weight(.medium))
                        Text(driver.phone ?? "No phone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                NavigationLink(value: trip.id) {
                    Text("View Full Trip")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(SierraTheme.Colors.info, in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task { await sendAlertToDriver() }
                } label: {
                    HStack(spacing: 4) {
                        if isSendingAlert {
                            ProgressView().tint(.white)
                        }
                        Text(alertSent ? "Sent ✓" : "Alert Driver")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(alertSent ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.warning,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSendingAlert || alertSent)
            }

            // ETA
            if let endDate = trip.scheduledEndDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("ETA: \(endDate.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Idle Section

    private var idleSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundStyle(.gray.opacity(0.5))
            Text("Vehicle is idle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Route Preview Mini Map

    @ViewBuilder
    private func routePreviewMap(_ trip: Trip) -> some View {
        Map {
            // Origin marker
            if let oLat = trip.originLatitude, let oLng = trip.originLongitude {
                Annotation("Origin", coordinate: CLLocationCoordinate2D(latitude: oLat, longitude: oLng)) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            // Current vehicle position
            if let lat = displayedVehicle.currentLatitude, let lng = displayedVehicle.currentLongitude {
                Annotation(displayedVehicle.licensePlate, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                    Image(systemName: "truck.box.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                }
            }

            // Destination marker
            if let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {
                Annotation("Destination", coordinate: CLLocationCoordinate2D(latitude: dLat, longitude: dLng)) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
            }

            // Breadcrumb trail
            if viewModel.breadcrumbCoordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.breadcrumbCoordinates)
                    .stroke(.orange, lineWidth: 3)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch displayedVehicle.status {
        case .active, .busy: return SierraTheme.Colors.info
        case .idle: return .gray
        case .inMaintenance: return .orange
        case .outOfService, .decommissioned: return SierraTheme.Colors.danger
        }
    }

    private var allTripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL TRIPS FOR THIS VEHICLE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .kerning(1)

            if vehicleTrips.isEmpty {
                Text("No trips found for this vehicle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(vehicleTrips) { trip in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(trip.taskId)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Spacer()
                            Text(trip.status.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(trip.origin) → \(trip.destination)")
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("Scheduled: \(trip.scheduledDate.formatted(.dateTime.day().month().hour().minute()))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func loadLatestDetails() async {
        isLoadingDetails = true
        detailsError = nil
        defer { isLoadingDetails = false }

        do {
            if let freshVehicle = try await VehicleService.fetchVehicle(id: vehicle.id) {
                latestVehicle = freshVehicle
            } else {
                latestVehicle = vehicle
            }
            vehicleTrips = try await TripService.fetchTrips(vehicleId: vehicle.id)
        } catch {
            detailsError = error.localizedDescription
            latestVehicle = vehicle
            vehicleTrips = store.trips.filter { $0.vehicleId?.lowercased() == vehicle.id.uuidString.lowercased() }
        }
    }

    private func sendAlertToDriver() async {
        guard let driverId = displayedVehicle.assignedDriverUUID else { return }
        isSendingAlert = true
        do {
            try await NotificationService.insertNotification(
                recipientId: driverId,
                type: .general,
                title: "Fleet Alert",
                body: "Fleet manager is requesting your attention for vehicle \(displayedVehicle.licensePlate).",
                entityType: "vehicle",
                entityId: displayedVehicle.id
            )
            alertSent = true
        } catch {
            print("[VehicleDetailSheet] Alert send failed: \(error)")
        }
        isSendingAlert = false
    }
}
