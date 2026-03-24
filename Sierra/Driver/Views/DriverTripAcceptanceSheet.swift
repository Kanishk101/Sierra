import SwiftUI

// MARK: - DriverTripAcceptanceSheet
// Shown when a driver taps a PendingAcceptance trip.
// Trips are assigned work orders — the driver is expected to accept.
// No reject/decline option exists. Driver can dismiss ("Later") and
// the fleet manager will see the trip is still pending via the 24h deadline.

struct DriverTripAcceptanceSheet: View {

    let trip: Trip
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isAccepting  = false
    @State private var errorMessage: String?

    private var vehicle: Vehicle? {
        guard let idStr = trip.vehicleId, let uuid = UUID(uuidString: idStr) else { return nil }
        return store.vehicle(for: uuid)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Trip Details Card
                    tripDetailsCard

                    // MARK: Error Banner
                    if let msg = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // MARK: Accept Button
                    Button {
                        Task { await handleAccept() }
                    } label: {
                        Group {
                            if isAccepting {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill").font(.body.weight(.bold))
                                    Text("Accept Trip").font(.system(size: 18, weight: .bold))
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.20, green: 0.65, blue: 0.32),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3),
                                radius: 10, y: 4)
                    }
                    .disabled(isAccepting)
                }
                .padding()
            }
            .navigationTitle("Trip Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    // MARK: - Trip Details Card

    private var tripDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(trip.taskId)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1), in: Capsule())
                Spacer()
                Text(trip.priority.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(priorityColor(trip.priority), in: Capsule())
            }

            Divider()

            // Route
            VStack(alignment: .leading, spacing: 6) {
                Label(trip.origin, systemImage: "location.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                Label(trip.destination, systemImage: "mappin.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }

            Divider()

            // Date + Vehicle
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    trip.scheduledDate.formatted(.dateTime.weekday().month().day().hour().minute()),
                    systemImage: "calendar"
                )
                .font(.subheadline)

                if let v = vehicle {
                    Label("\(v.name) \(v.model) · \(v.licensePlate)", systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !trip.deliveryInstructions.isEmpty {
                    Label(trip.deliveryInstructions, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            // Acceptance Deadline
            if let deadline = trip.acceptanceDeadline {
                Divider()
                deadlineBanner(deadline)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    @ViewBuilder
    private func deadlineBanner(_ deadline: Date) -> some View {
        let isOverdue = deadline < Date()
        HStack(spacing: 8) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                .foregroundStyle(isOverdue ? .red : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(isOverdue ? "Response Overdue" : "Response Required")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isOverdue ? .red : .orange)
                Text(isOverdue
                    ? "Deadline passed \(deadline.formatted(.relative(presentation: .named)))"
                    : "Please respond by \(deadline.formatted(.dateTime.hour().minute()))"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            (isOverdue ? Color.red : Color.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // MARK: - Action Handler

    private func handleAccept() async {
        isAccepting = true
        errorMessage = nil
        defer { isAccepting = false }
        do {
            try await store.acceptTrip(tripId: trip.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func priorityColor(_ priority: TripPriority) -> Color {
        switch priority {
        case .low:    return .gray
        case .normal: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }
}
