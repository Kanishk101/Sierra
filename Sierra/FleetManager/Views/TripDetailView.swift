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
        .navigationTitle(trip?.taskId ?? "Trip Details")
        .toolbarTitleDisplayMode(.inline)
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
                        .font(SierraFont.scaled(20, weight: .bold, design: .monospaced))
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
                            Text("From").font(.caption).foregroundStyle(.secondary)
                            Text(t.origin).font(.subheadline.weight(.medium))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To").font(.caption).foregroundStyle(.secondary)
                            Text(t.destination).font(.subheadline.weight(.medium))
                        }
                    }
                }
                HStack {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text(t.scheduledDate.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.subheadline)
                }
            }

            // Assignment
            Section("Assignment") {
                if let dIdStr = t.driverId,
                   let dUUID = UUID(uuidString: dIdStr),
                   let driver = store.staffMember(for: dUUID) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(driver.initials)
                                    .font(SierraFont.scaled(14, weight: .bold))
                                    .foregroundStyle(.blue)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.displayName).font(.subheadline.weight(.medium))
                            if let phone = driver.phone {
                                Text(phone).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("No driver assigned").foregroundStyle(.secondary).italic()
                }

                if let vIdStr = t.vehicleId,
                   let vUUID = UUID(uuidString: vIdStr),
                   let vehicle = store.vehicle(for: vUUID) {
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(SierraFont.scaled(18))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vehicle.name) \(vehicle.model)").font(.subheadline.weight(.medium))
                            HStack(spacing: 6) {
                                Text(vehicle.licensePlate)
                                    .font(SierraFont.scaled(13, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("· \(vehicle.fuelType.rawValue)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    Text("No vehicle assigned").foregroundStyle(.secondary).italic()
                }
            }

            // Ride Details
            if !t.deliveryInstructions.isEmpty || !t.notes.isEmpty || t.distanceKm != nil {
                Section("Ride Details") {
                    if !t.deliveryInstructions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delivery Instructions").font(.caption).foregroundStyle(.secondary)
                            Text(t.deliveryInstructions).font(.subheadline)
                        }
                    }
                    if !t.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption).foregroundStyle(.secondary)
                            Text(t.notes).font(.subheadline)
                        }
                    }
                    if let km = t.distanceKm {
                        HStack {
                            Text("Distance").foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f km", km))
                        }
                    }
                }
            }

            Section("Trip Tracking") {
                trackingSection(for: t)
            }

            Section("Ride Summary") {
                rideSummarySection(for: t)
            }

            // Timeline
            if t.actualStartDate != nil || t.actualEndDate != nil {
                Section("Timeline") {
                    if let start = t.actualStartDate {
                        HStack {
                            Image(systemName: "play.circle.fill").foregroundStyle(.green)
                            Text("Started").foregroundStyle(.secondary)
                            Spacer()
                            Text(start.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.caption)
                        }
                    }
                    if let end = t.actualEndDate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                            Text("Completed").foregroundStyle(.secondary)
                            Spacer()
                            Text(end.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.caption)
                        }
                    }
                    if let dur = t.durationString {
                        HStack {
                            Image(systemName: "timer").foregroundStyle(.secondary)
                            Text("Duration").foregroundStyle(.secondary)
                            Spacer()
                            Text(dur).font(.caption)
                        }
                    }
                }
            }

            // Dispatch to Driver button:
            // Only shown for legacy Scheduled trips that haven't been accepted yet
            // (acceptedAt == nil means trip was not created through the new PendingAcceptance flow)
            if t.status == .scheduled && t.acceptedAt == nil && t.driverId != nil && t.vehicleId != nil {
                Section {
                    Button {
                        Task { await performDispatch() }
                    } label: {
                        HStack {
                            Spacer()
                            if isDispatching {
                                ProgressView().tint(.white)
                            } else {
                                Label("Dispatch to Driver", systemImage: "paperplane.fill")
                                    .font(SierraFont.scaled(16, weight: .semibold))
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

            // Awaiting acceptance info
            if let deadline = t.responseDeadline {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dispatched — Awaiting Driver Acceptance")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text("Deadline: \(deadline.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            // Accepted + awaiting start info
            if t.status == .scheduled && t.acceptedAt != nil {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trip Accepted by Driver")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                            Text("Driver can start within 30 min of scheduled time: \(t.scheduledDate.formatted(.dateTime.hour().minute()))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            // Cancel — only allowed before trip becomes Active
            if t.status == .pendingAcceptance || t.status == .scheduled {
                Section {
                    Button(role: .destructive) {
                        showCancelConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Cancel Trip", systemImage: "xmark.circle.fill")
                                .font(SierraFont.scaled(16, weight: .semibold))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: TripStatus) -> some View {
        let normalized = status.normalized
        let (text, color): (String, Color) = switch normalized {
        case .pendingAcceptance: ("Pending Acceptance", .orange)
        case .scheduled:         ("Scheduled",          .blue)
        case .active:            ("Active",             .green)
        case .completed:         ("Completed",          Color.secondary)
        case .cancelled:         ("Cancelled",          .red)
        default:                 (normalized.rawValue,  .secondary)
        }
        return Text(text)
            .font(SierraFont.scaled(13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
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
            .font(SierraFont.scaled(13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func vehicleStatusBadge(_ status: VehicleStatus?) -> some View {
        let text = status?.rawValue ?? "Unassigned"
        let color: Color = switch status {
        case .some(.active): .green
        case .some(.idle): .gray
        case .some(.busy): .orange
        case .some(.inMaintenance): .yellow
        case .some(.outOfService), .some(.decommissioned): .red
        case .none: .secondary
        }
        return Text(text)
            .font(SierraFont.scaled(13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func vehicleStatus(for trip: Trip) -> VehicleStatus? {
        guard let raw = trip.vehicleId, let id = UUID(uuidString: raw) else { return nil }
        return store.vehicle(for: id)?.status
    }

    private func rideSummarySection(for trip: Trip) -> some View {
        let pod = store.proofOfDeliveries.first(where: { $0.tripId == trip.id })
        let assignedVehicle: Vehicle? = {
            guard let raw = trip.vehicleId, let id = UUID(uuidString: raw) else { return nil }
            return store.vehicle(for: id)
        }()

        return VStack(spacing: 0) {
            summaryBlockHeader("Driver Submitted")
            if trip.startMileage == nil && trip.endMileage == nil && trip.proofOfDeliveryId == nil &&
                (pod?.notes?.isEmpty != false) && (trip.driverRatingNote?.isEmpty != false) {
                summaryValueRow("Submission", value: "No driver submission yet")
            } else {
                if let start = trip.startMileage {
                    summaryValueRow("Start Odometer", value: "\(Int(start)) km")
                }
                if let end = trip.endMileage {
                    summaryValueRow("End Odometer", value: "\(Int(end)) km")
                }
                if let recipient = pod?.recipientName, !recipient.isEmpty {
                    summaryValueRow("Recipient", value: recipient)
                }
                if let note = pod?.notes, !note.isEmpty {
                    summaryValueRow("POD Note", value: note)
                }
                if let feedback = trip.driverRatingNote, !feedback.isEmpty {
                    summaryValueRow("Driver Feedback", value: feedback)
                }
                summaryBadgeRow("Proof of Delivery") {
                    let done = trip.proofOfDeliveryId != nil
                    Text(done ? "Submitted" : "Pending")
                        .font(SierraFont.scaled(13, weight: .semibold))
                        .foregroundStyle(done ? .green : .orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((done ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                }
            }

            summarySectionDivider()

            summaryBlockHeader("Vehicle Summary")
            if let vehicle = assignedVehicle {
                summaryValueRow("Vehicle", value: "\(vehicle.name) \(vehicle.model)")
                summaryValueRow("Plate", value: vehicle.licensePlate)
                summaryValueRow("Fuel Type", value: vehicle.fuelType.rawValue)
                summaryValueRow("Odometer", value: "\(Int(vehicle.odometer)) km")
                summaryBadgeRow("Vehicle Status") {
                    vehicleStatusBadge(vehicle.status)
                }
            } else {
                summaryValueRow("Vehicle", value: "Not assigned")
            }

            summarySectionDivider()

            summaryBlockHeader("Trip Summary")
            summaryValueRow("Route", value: "\(trip.origin) → \(trip.destination)")
            summaryValueRow(
                "Scheduled",
                value: trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
            )
            if let actualStart = trip.actualStartDate {
                summaryValueRow(
                    "Actual Start",
                    value: actualStart.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                )
            }
            if let actualEnd = trip.actualEndDate {
                summaryValueRow(
                    "Actual End",
                    value: actualEnd.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                )
            }
            if let duration = trip.durationString {
                summaryValueRow("Duration", value: duration)
            }
            if let km = trip.distanceKm {
                summaryValueRow("Distance", value: String(format: "%.1f km", km))
            }
            summaryBadgeRow("Priority") {
                priorityBadge(trip.priority)
            }
            summaryBadgeRow("Status") {
                statusBadge(trip.status.normalized)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func summaryBlockHeader(_ title: String) -> some View {
        Text(title)
            .font(SierraFont.scaled(12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func summarySectionDivider() -> some View {
        Divider()
            .overlay(Color.gray.opacity(0.20))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private func summaryValueRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(SierraFont.scaled(15, weight: .medium))
                .foregroundStyle(Color.gray)
            Spacer(minLength: 8)
            Text(value)
                .font(SierraFont.scaled(15, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func summaryBadgeRow<Content: View>(_ title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title).font(SierraFont.scaled(15, weight: .medium)).foregroundStyle(Color.gray)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func trackingSection(for trip: Trip) -> some View {
        let status = trip.status.normalized
        let stageCount = stageCompletionCount(for: trip, status: status)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Trip Tracking", systemImage: "location.viewfinder")
                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(trackingStatusText(for: trip, status: status))
                    .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: trackingProgress(for: trip, status: status))
                .tint(.primary)

            HStack(spacing: 8) {
                trackingStep("Created", isActive: stageCount >= 1)
                trackingStep("Accepted", isActive: stageCount >= 2)
                trackingStep("Started", isActive: stageCount >= 3)
                trackingStep("Completed", isActive: stageCount >= 4)
            }
        }
    }

    private func trackingStep(_ title: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.primary : Color.secondary.opacity(0.25))
                .frame(width: 8, height: 8)
            Text(title)
                .font(SierraFont.scaled(10, weight: .medium, design: .rounded))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func trackingStatusText(for trip: Trip, status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance:
            return "Awaiting acceptance"
        case .scheduled:
            return trip.acceptedAt == nil ? "Scheduled" : "Accepted"
        case .active:
            return "In transit"
        case .completed:
            return "Completed"
        case .accepted:
            return "Accepted"
        case .cancelled, .rejected:
            return "Cancelled"
        }
    }

    private func stageCompletionCount(for trip: Trip, status: TripStatus) -> Int {
        switch status {
        case .pendingAcceptance:
            return 1
        case .scheduled:
            return trip.acceptedAt == nil ? 1 : 2
        case .active:
            return 3
        case .completed:
            return 4
        case .accepted:
            return 2
        case .cancelled, .rejected:
            return 1
        }
    }

    private func trackingProgress(for trip: Trip, status: TripStatus) -> Double {
        switch status {
        case .pendingAcceptance: return 0.20
        case .scheduled: return trip.acceptedAt == nil ? 0.35 : 0.55
        case .active: return 0.78
        case .completed: return 1.0
        case .accepted: return 0.55
        case .cancelled, .rejected: return 0.20
        }
    }

    // MARK: - Actions

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

    @MainActor
    private func cancelTrip() async {
        guard var t = trip else { return }

        // Guard: cannot cancel Active or Completed trips
        guard t.status == .pendingAcceptance || t.status == .scheduled else { return }

        if let dIdStr = t.driverId, let dUUID = UUID(uuidString: dIdStr),
           let vIdStr = t.vehicleId, let vUUID = UUID(uuidString: vIdStr) {
            try? await TripService.releaseResources(driverId: dUUID, vehicleId: vUUID)
        }

        if let dIdStr = t.driverId, let dUUID = UUID(uuidString: dIdStr),
           var driver = store.staffMember(for: dUUID) {
            driver.availability = .available
            try? await store.updateStaffMember(driver)
        }
        if let vIdStr = t.vehicleId, let vUUID = UUID(uuidString: vIdStr),
           var vehicle = store.vehicle(for: vUUID) {
            vehicle.assignedDriverId = nil
            vehicle.status = .idle
            try? await store.updateVehicle(vehicle)
        }

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
