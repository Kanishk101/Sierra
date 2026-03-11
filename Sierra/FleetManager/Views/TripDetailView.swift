import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

struct TripDetailView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripId: UUID

    @State private var showCancelConfirm = false

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
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Cancel Trip?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Trip", role: .destructive) {
                cancelTrip()
            }
            Button("Keep Trip", role: .cancel) {}
        } message: {
            Text("This will cancel the trip and free the assigned driver and vehicle.")
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
                        .foregroundStyle(navyDark)

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
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(t.origin)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("To")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(t.destination)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }

                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(t.scheduledDate.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.system(size: 14))
                }
            }

            // Assignment
            Section("Assignment") {
                // Driver card
                if let dId = t.driverId,
                   let driver = store.staffMember(forId: dId) {
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
                            Text(driver.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text(driver.phone)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("No driver assigned")
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Vehicle card
                if let vId = t.vehicleId,
                   let vehicle = store.vehicle(forId: vId) {
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(navyDark.opacity(0.6))
                            .frame(width: 40, height: 40)
                            .background(navyDark.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vehicle.name) \(vehicle.model)")
                                .font(.system(size: 15, weight: .semibold))
                            HStack(spacing: 6) {
                                Text(vehicle.licensePlate)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("· \(vehicle.fuelType.description)")
                                    .font(.system(size: 12))
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

                if !t.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(t.notes)
                            .font(.system(size: 14))
                    }
                }

                if let km = t.distanceKm {
                    HStack {
                        Text("Distance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(km, specifier: "%.1f") km")
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
                                .font(.system(size: 14))
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
                                .font(.system(size: 14))
                        }
                    }
                }
            }

            // Cancel
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
        case .scheduled: ("Scheduled", .blue)
        case .active:    ("Active", .green)
        case .completed: ("Completed", .gray)
        case .cancelled: ("Cancelled", .red)
        }
        return Text(text)
            .font(.system(size: 13, weight: .semibold))
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Cancel Trip

    private func cancelTrip() {
        guard var t = trip else { return }

        // Free driver
        if let dId = t.driverId,
           let driverUUID = UUID(uuidString: dId),
           var driver = store.staff.first(where: { $0.id == driverUUID }) {
            driver.status = .active
            store.updateStaff(driver)
        }

        // Free vehicle
        if let vId = t.vehicleId,
           var vehicle = store.vehicle(forId: vId) {
            vehicle.assignedDriverId = nil
            store.updateVehicle(vehicle)
        }

        // Cancel trip
        t.status = .cancelled
        store.updateTrip(t)
    }
}

#Preview {
    NavigationStack {
        TripDetailView(tripId: Trip.mockData[0].id)
            .environment(AppDataStore.shared)
    }
}
