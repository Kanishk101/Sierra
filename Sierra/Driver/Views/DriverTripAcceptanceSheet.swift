import SwiftUI

// MARK: - DriverTripAcceptanceSheet
// Dedicated acceptance sheet that appears when a driver taps a PendingAcceptance trip.
// Shows full trip details, an Accept button, and a collapsible Decline reason field.

struct DriverTripAcceptanceSheet: View {

    let trip: Trip
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isAccepting  = false
    @State private var isRejecting  = false
    @State private var showDecline  = false
    @State private var reason       = ""
    @State private var errorMessage: String?

    private var vehicle: Vehicle? {
        guard let idStr = trip.vehicleId, let uuid = UUID(uuidString: idStr) else { return nil }
        return store.vehicle(for: uuid)
    }

    private var reasonValid: Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
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
                    if !showDecline {
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
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.green.opacity(0.3), radius: 10, y: 4)
                        }
                        .disabled(isAccepting || isRejecting)
                    }

                    // MARK: Decline Section
                    VStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showDecline.toggle()
                                if !showDecline { reason = ""; errorMessage = nil }
                            }
                        } label: {
                            HStack {
                                Image(systemName: showDecline ? "chevron.up" : "chevron.down")
                                Text(showDecline ? "Cancel" : "Decline Trip")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(showDecline ? Color.secondary : Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                showDecline
                                    ? Color(.tertiarySystemFill)
                                    : Color.red.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.red.opacity(showDecline ? 0 : 0.25), lineWidth: 1)
                            )
                        }
                        .disabled(isAccepting || isRejecting)

                        if showDecline {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reason for declining")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                TextField("Please describe why you're declining this trip (min 10 characters)", text: $reason, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(reasonValid ? Color.green.opacity(0.4) : Color(.separator), lineWidth: 1)
                                    )

                                HStack {
                                    Text("\(reason.trimmingCharacters(in: .whitespacesAndNewlines).count) / 10 min")
                                        .font(.caption2)
                                        .foregroundStyle(reasonValid ? .green : .secondary)
                                    Spacer()
                                }

                                Button {
                                    Task { await handleReject() }
                                } label: {
                                    Group {
                                        if isRejecting {
                                            ProgressView().tint(.white)
                                        } else {
                                            HStack(spacing: 8) {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Confirm Decline")
                                            }
                                            .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(
                                        reasonValid ? Color.red : Color.gray,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                }
                                .disabled(!reasonValid || isRejecting || isAccepting)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    // MARK: - Action Handlers

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

    private func handleReject() async {
        isRejecting = true
        errorMessage = nil
        defer { isRejecting = false }
        do {
            try await store.rejectTrip(tripId: trip.id, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Style Helpers

    private func priorityColor(_ priority: TripPriority) -> Color {
        switch priority {
        case .low:    return .gray
        case .normal: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }
}
