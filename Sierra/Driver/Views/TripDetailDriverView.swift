import SwiftUI
import MapKit

/// Driver-side trip detail view with lifecycle actions.
/// The navigation map (Mapbox) launches full-screen when the driver taps
/// "Start Navigation" in StartTripSheet (auto-launched) or the
/// "Navigate" button on an active trip.
struct TripDetailDriverView: View {

    let tripId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPreInspection = false
    @State private var showStartTrip = false
    @State private var showNavigation = false
    @State private var showProofOfDelivery = false
    @State private var showPostInspection = false
    @State private var showFuelLog = false
    @State private var showMaintenanceRequest = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var navigatePulse = false

    private var trip: Trip? { store.trips.first { $0.id == tripId } }
    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var vehicle: Vehicle? {
        guard let vId = trip?.vehicleId, let uuid = UUID(uuidString: vId) else { return nil }
        return store.vehicle(for: uuid)
    }

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    VStack(spacing: 16) {
                        statusBanner(trip)
                        tripInfoCard(trip)

                        // Map preview — always shown when coordinates available,
                        // or a placeholder encouraging the admin to set them.
                        routeMapCard(trip)

                        if let vehicle { vehicleCard(vehicle) }
                        flowStepsCard(trip)
                        actionButtons(trip)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                ContentUnavailableView("Trip Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showPreInspection) {
            if let trip, let vehicle {
                NavigationStack {
                    PreTripInspectionView(
                        tripId: trip.id,
                        vehicleId: vehicle.id,
                        driverId: user?.id ?? UUID(),
                        inspectionType: .preTripInspection,
                        onComplete: { showPreInspection = false }
                    )
                }
            }
        }
        .sheet(isPresented: $showStartTrip) {
            if let trip {
                NavigationStack {
                    StartTripSheet(tripId: trip.id) {
                        // Dismiss the sheet, then auto-launch the navigation map
                        // with a short delay so the sheet dismiss animation completes
                        // before the fullScreenCover presentation starts.
                        showStartTrip = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            showNavigation = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showProofOfDelivery) {
            if let trip {
                NavigationStack {
                    ProofOfDeliveryView(tripId: trip.id, driverId: user?.id ?? UUID()) {
                        showProofOfDelivery = false
                    }
                }
            }
        }
        .sheet(isPresented: $showPostInspection) {
            if let trip, let vehicle {
                NavigationStack {
                    PostTripInspectionView(
                        tripId: trip.id,
                        vehicleId: vehicle.id,
                        driverId: user?.id ?? UUID()
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showNavigation) {
            if let trip {
                TripNavigationContainerView(trip: trip)
                    .environment(AppDataStore.shared)
            }
        }
        .sheet(isPresented: $showFuelLog) {
            if let vehicleId = vehicle?.id, let driverId = user?.id {
                FuelLogView(vehicleId: vehicleId, driverId: driverId, tripId: trip?.id)
            }
        }
        .sheet(isPresented: $showMaintenanceRequest) {
            if let vehicleId = vehicle?.id, let driverId = user?.id {
                DriverMaintenanceRequestView(
                    vehicleId: vehicleId,
                    driverId: driverId,
                    tripId: trip?.id
                )
            }
        }
        .onAppear {
            if trip?.status == .active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    navigatePulse = true
                }
            }
        }
    }

    // MARK: - Route Map Card
    // Shows a live MapKit preview with origin + destination pins.
    // Tapping the map on an active trip launches navigation immediately.

    @ViewBuilder
    private func routeMapCard(_ trip: Trip) -> some View {
        let hasCoords = trip.originLatitude != nil && trip.originLongitude != nil
                     && trip.destinationLatitude != nil && trip.destinationLongitude != nil

        VStack(alignment: .leading, spacing: 0) {
            if hasCoords,
               let oLat = trip.originLatitude, let oLng = trip.originLongitude,
               let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {

                let originCoord = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
                let destCoord   = CLLocationCoordinate2D(latitude: dLat, longitude: dLng)

                // Compute a region that contains both pins with some padding
                let minLat = min(oLat, dLat)
                let maxLat = max(oLat, dLat)
                let minLng = min(oLng, dLng)
                let maxLng = max(oLng, dLng)
                let spanLat = max((maxLat - minLat) * 1.5, 0.05)
                let spanLng = max((maxLng - minLng) * 1.5, 0.05)
                let center  = CLLocationCoordinate2D(
                    latitude:  (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                )
                let region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
                )

                ZStack(alignment: .bottom) {
                    Map(initialPosition: .region(region)) {
                        // Origin pin
                        Annotation(trip.origin, coordinate: originCoord) {
                            ZStack {
                                Circle().fill(SierraTheme.Colors.alpineMint)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(radius: 3)
                        }
                        // Destination pin
                        Annotation(trip.destination, coordinate: destCoord) {
                            ZStack {
                                Circle().fill(SierraTheme.Colors.ember)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "mappin")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(radius: 3)
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(true)  // non-interactive preview

                    // Active trip overlay — tap to launch navigation
                    if trip.status == .active {
                        Button {
                            showNavigation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Tap to Open Navigation")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.55), in: Capsule())
                        }
                        .padding(.bottom, 12)
                    }
                }

            } else {
                // No coordinates — show a placeholder
                HStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Route preview unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Ask your fleet manager to set GPS coordinates for this trip.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Flow Steps Card
    // Shows the driver exactly where they are in the workflow so the path
    // to navigation is obvious even on a Scheduled trip.

    private func flowStepsCard(_ trip: Trip) -> some View {
        let steps: [(icon: String, label: String, done: Bool)] = [
            ("checklist",       "Pre-Trip Inspection",  trip.preInspectionId != nil),
            ("play.fill",       "Start Trip",           trip.status == .active || trip.status == .completed),
            ("location.fill",   "Navigate",             false),
            ("shippingbox.fill","Complete Delivery",    trip.proofOfDeliveryId != nil),
            ("checklist",       "Post-Trip Inspection", trip.postInspectionId != nil),
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Text("TRIP FLOW")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .kerning(1)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(step.done ? SierraTheme.Colors.alpineMint : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 32, height: 32)
                        Image(systemName: step.done ? "checkmark" : step.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(step.done ? .white : .secondary)
                    }
                    Text(step.label)
                        .font(.subheadline)
                        .foregroundStyle(step.done ? .primary : .secondary)
                    Spacer()
                    if step.label == "Navigate" && trip.status == .active {
                        Text("TAP BELOW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SierraTheme.Colors.alpineMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SierraTheme.Colors.alpineMint.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.4))
                        .frame(height: 1)
                        .padding(.leading, 60)
                }
            }
            .padding(.bottom, 6)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Status Banner

    private func statusBanner(_ trip: Trip) -> some View {
        HStack {
            Circle().fill(statusColor(trip.status)).frame(width: 10, height: 10)
            Text(trip.status.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor(trip.status))
            Spacer()
            Text(trip.priority.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(priorityColor(trip.priority), in: Capsule())
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Trip Info Card

    private func tripInfoCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.taskId)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 6) {
                Label(trip.origin, systemImage: "location.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SierraTheme.Colors.alpineMint)
                Rectangle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 1, height: 16)
                    .padding(.leading, 8)
                Label(trip.destination, systemImage: "mappin.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SierraTheme.Colors.ember)
            }

            Divider()

            Label(
                trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                systemImage: "calendar"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if !trip.deliveryInstructions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delivery Instructions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(trip.deliveryInstructions)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(SierraTheme.Colors.ember)
                .frame(width: 44, height: 44)
                .background(SierraTheme.Colors.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.name) \(vehicle.model)").font(.subheadline.weight(.semibold))
                Text(vehicle.licensePlate)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            switch trip.status {
            case .scheduled:
                if trip.preInspectionId == nil {
                    actionButton("Begin Pre-Trip Inspection", icon: "checklist", color: SierraTheme.Colors.ember) {
                        showPreInspection = true
                    }
                } else {
                    actionButton("Start Trip", icon: "play.fill", color: SierraTheme.Colors.alpineMint) {
                        showStartTrip = true
                    }
                }

            case .active:
                // Primary: Navigate button with pulse animation
                Button {
                    showNavigation = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.body.weight(.bold))
                        Text("Navigate")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [SierraTheme.Colors.alpineMint, SierraTheme.Colors.alpineMint.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(
                        color: SierraTheme.Colors.alpineMint.opacity(navigatePulse ? 0.6 : 0.2),
                        radius: navigatePulse ? 14 : 6,
                        y: 4
                    )
                    .scaleEffect(navigatePulse ? 1.01 : 1.0)
                }
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: navigatePulse)

                if trip.proofOfDeliveryId == nil {
                    actionButton("Complete Delivery", icon: "shippingbox.fill", color: SierraTheme.Colors.ember) {
                        showProofOfDelivery = true
                    }
                } else if trip.postInspectionId == nil {
                    actionButton("Post-Trip Inspection", icon: "checklist", color: SierraTheme.Colors.info) {
                        showPostInspection = true
                    }
                } else {
                    completionSummary(trip)
                }

                // Trip-scoped quick actions — always available during active trip
                actionButton("Log Fuel", icon: "fuelpump.fill", color: .orange) {
                    showFuelLog = true
                }
                actionButton("Report Issue", icon: "wrench.and.screwdriver.fill", color: .red.opacity(0.8)) {
                    showMaintenanceRequest = true
                }

            case .completed:
                completionSummary(trip)

            default:
                EmptyView()
            }
        }
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func completionSummary(_ trip: Trip) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(SierraTheme.Colors.alpineMint)
            Text("Trip Completed").font(.headline)
            if let endDate = trip.actualEndDate {
                Text(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .scheduled: return SierraTheme.Colors.info
        case .active:    return SierraTheme.Colors.warning
        case .completed: return SierraTheme.Colors.alpineMint
        case .cancelled: return SierraTheme.Colors.danger
        }
    }

    private func priorityColor(_ priority: TripPriority) -> Color {
        switch priority {
        case .low:    return .gray
        case .normal: return SierraTheme.Colors.info
        case .high:   return SierraTheme.Colors.warning
        case .urgent: return SierraTheme.Colors.danger
        }
    }
}
