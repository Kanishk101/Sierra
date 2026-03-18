import SwiftUI

/// Driver-side trip detail view with lifecycle actions.
struct TripDetailDriverView: View {

    let tripId: UUID

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPreInspection = false
    @State private var showStartTrip = false
    @State private var showNavigation = false
    @State private var showProofOfDelivery = false
    @State private var showPostInspection = false
    @State private var errorMessage: String?
    @State private var showError = false

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
                        if let vehicle { vehicleCard(vehicle) }
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
                        onComplete: {
                            showPreInspection = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showStartTrip) {
            if let trip {
                NavigationStack {
                    StartTripSheet(tripId: trip.id) {
                        showStartTrip = false
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
    }

    // MARK: - Status Banner

    private func statusBanner(_ trip: Trip) -> some View {
        HStack {
            Circle()
                .fill(statusColor(trip.status))
                .frame(width: 10, height: 10)
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

            HStack(spacing: 20) {
                Label(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                Text("\(vehicle.name) \(vehicle.model)")
                    .font(.subheadline.weight(.semibold))
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
                actionButton("Navigate", icon: "location.fill", color: SierraTheme.Colors.alpineMint) {
                    showNavigation = true
                }
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
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
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
            Text("Trip Completed")
                .font(.headline)
            if let endDate = trip.actualEndDate {
                Text(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
