import SwiftUI

struct TripDetailView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripId: UUID

    @State private var showCancelConfirm = false
    @State private var isDispatching = false
    @State private var dispatchError: String?

    private var trip: Trip? {
        store.trips.first { $0.id == tripId }
    }

    var body: some View {
        Group {
            if let t = trip {
                tripContent(t)
            } else {
                ContentUnavailableView("Trip Not Found",
                                       systemImage: "arrow.triangle.swap",
                                       description: Text("This trip may have been deleted."))
            }
        }
        .navigationTitle(trip?.taskId ?? "Trip")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Cancel Trip?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Trip", role: .destructive) {
                Task { await cancelTrip() }
            }
            Button("Keep Trip", role: .cancel) {}
        } message: {
            Text("This will cancel the trip and free the assigned driver and vehicle.")
        }
        .alert("Dispatch Error", isPresented: .init(
            get: { dispatchError != nil },
            set: { if !$0 { dispatchError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(dispatchError ?? "")
        }
    }

    // MARK: - Content

    private func tripContent(_ t: Trip) -> some View {
        List {
            // Header
            Section {
                VStack(alignment: .center, spacing: 8) {
                    Text(t.taskId)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    statusBadge(t.status)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Route
            Section("Route") {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Rectangle().fill(.gray.opacity(0.3)).frame(width: 1, height: 20)
                        Circle().fill(.red).frame(width: 8, height: 8)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("From")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(t.origin)
                                .font(.subheadline)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(t.destination)
                                .font(.subheadline)
                        }
                    }
                }

                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(t.scheduledDate.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.caption)
                }
            }

            // Assignment
            Section("Assignment") {
                // Driver row
                if let dIdStr = t.driverId,
                   let dUUID = UUID(uuidString: dIdStr),
                   let driver = store.staffMember(for: dUUID) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(driver.initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.blue)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.displayName)
                                .font(.subheadline)
                            if let phone = driver.phone {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("No driver assigned")
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Vehicle row
                if let vIdStr = t.vehicleId,
                   let vUUID = UUID(uuidString: vIdStr),
                   let vehicle = store.vehicle(for: vUUID) {
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vehicle.name) \(vehicle.model)")
                                .font(.subheadline)
                            HStack(spacing: 6) {
                                Text(vehicle.licensePlate)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("· \(vehicle.fuelType.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("No vehicle assigned")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            // Details
            Section("Details") {
                HStack {
                    Text("Priority")
                        .foregroundStyle(.secondary)
                    Spacer()
                    priorityBadge(t.priority)
                }

                if !t.deliveryInstructions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery Instructions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(t.deliveryInstructions)
                            .font(.caption)
                    }
                }

                if !t.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(t.notes)
                            .font(.caption)
                    }
                }

                if let km = t.distanceKm {
                    HStack {
                        Text("Distance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f km", km))
                    }
                }
            }

            // Timeline
            if t.actualStartDate != nil || t.actualEndDate != nil {
                Section("Timeline") {
                    if let start = t.actualStartDate {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.green)
                            Text("Started")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(start.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.caption)
                        }
                    }
                    if let end = t.actualEndDate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Completed")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(end.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.caption)
                        }
                    }
                    if let dur = t.durationString {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(.secondary)
                            Text("Duration")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(dur)
                                .font(.caption)
                        }
                    }
                }
            }

            // Dispatch to Driver (only for scheduled trips with driver + vehicle assigned)
            if t.status == .scheduled && t.driverId != nil && t.vehicleId != nil {
                Section {
                    Button {
                        Task { await performDispatch() }
                    } label: {
                        HStack {
                            Spacer()
                            if isDispatching {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Dispatch to Driver", systemImage: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isDispatching ? Color.teal.opacity(0.5) : Color.teal)
                    )
                    .disabled(isDispatching)
                }
            }

            // Acceptance deadline info (shown when pending acceptance)
            if t.status == .pendingAcceptance, let deadline = t.acceptanceDeadline {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dispatched — Awaiting Driver Response")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text("Deadline: \(deadline.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            // Cancel (only for scheduled trips)
            if t.status == .scheduled {
                Section {
                    Button(role: .destructive) {
                        showCancelConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Cancel Trip", systemImage: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: TripStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .scheduled:          ("Scheduled",  .blue)
        case .pendingAcceptance:  ("Pending",     .orange)
        case .accepted:           ("Accepted",    .teal)
        case .active:             ("Active",      .green)
        case .completed:          ("Completed",   Color.secondary)
        case .rejected:           ("Rejected",    .red)
        case .cancelled:          ("Cancelled",   .red)
        }
        return Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func priorityBadge(_ priority: TripPriority) -> some View {
        let color: Color = switch priority {
        case .low:    .gray
        case .normal: .blue
        case .high:   .orange
        case .urgent: .red
        }
        return Text(priority.rawValue)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Dispatch Trip (async)

    @MainActor
    private func performDispatch() async {
        isDispatching = true
        do {
            try await store.dispatchTrip(tripId: tripId)
        } catch {
            dispatchError = error.localizedDescription
        }
        isDispatching = false
    }

    // MARK: - Cancel Trip (async)

    @MainActor
    private func cancelTrip() async {
        guard var t = trip else { return }

        // 1. Release at DB level first
        if let dIdStr = t.driverId,
           let dUUID  = UUID(uuidString: dIdStr),
           let vIdStr = t.vehicleId,
           let vUUID  = UUID(uuidString: vIdStr) {
            try? await TripService.releaseResources(driverId: dUUID, vehicleId: vUUID)
        }

        // 2. Sync local in-memory cache
        if let dIdStr = t.driverId,
           let dUUID = UUID(uuidString: dIdStr),
           var driver = store.staffMember(for: dUUID) {
            driver.availability = .available
            try? await store.updateStaffMember(driver)
        }
        if let vIdStr = t.vehicleId,
           let vUUID = UUID(uuidString: vIdStr),
           var vehicle = store.vehicle(for: vUUID) {
            vehicle.assignedDriverId = nil
            vehicle.status = .idle
            try? await store.updateVehicle(vehicle)
        }

        // 3. Cancel the trip record
        t.status = .cancelled
        do {
            try await store.updateTrip(t)
            dismiss()
        } catch {
            print("[TripDetailView] Cancel trip error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(tripId: UUID())
            .environment(AppDataStore.shared)
    }
}
