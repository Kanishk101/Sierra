import SwiftUI

// MARK: - TripDetailView
// Shared detail view used by both Fleet Manager and Driver tabs.
// Accepts a tripId (UUID) and resolves the Trip from AppDataStore.

struct TripDetailView: View {

    @Environment(AppDataStore.self) private var store
    let tripId: UUID

    private var trip: Trip? { store.trip(for: tripId) }

    var body: some View {
        Group {
            if let trip {
                content(trip)
            } else {
                notFoundView
            }
        }
        .navigationTitle("Trip Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Not Found
    // ─────────────────────────────────────────────────────────────

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("Trip Not Found")
                .font(SierraFont.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Main Content
    // ─────────────────────────────────────────────────────────────

    private func content(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card — route + status
                headerCard(trip)

                // Details card
                detailsCard(trip)

                // Delivery instructions (if any)
                if !trip.deliveryInstructions.isEmpty {
                    instructionsCard(trip)
                }

                // Notes (if any)
                if !trip.notes.isEmpty {
                    notesCard(trip)
                }
            }
            .padding(16)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Header Card
    // ─────────────────────────────────────────────────────────────

    private func headerCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task ID + status badge
            HStack {
                Text(trip.taskId)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12), in: Capsule())

                Spacer()

                statusBadge(trip.status)
            }

            // Route
            VStack(alignment: .leading, spacing: 6) {
                routeRow(icon: "location.fill", color: SierraTheme.Colors.ember, label: trip.origin)
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                routeRow(icon: "flag.fill", color: SierraTheme.Colors.alpineMint, label: trip.destination)
            }

            // Priority
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(SierraFont.caption2)
                    .foregroundStyle(.secondary)
                Text("Priority: \(trip.priority.rawValue)")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func routeRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(SierraFont.body(15, weight: .semibold))
                .foregroundStyle(SierraTheme.Colors.primaryText)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Details Card
    // ─────────────────────────────────────────────────────────────

    private func detailsCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Details")

            // Vehicle
            if let vId = trip.vehicleId,
               let vUUID = UUID(uuidString: vId),
               let vehicle = store.vehicle(for: vUUID) {
                detailRow(icon: "car.fill", label: "Vehicle", value: "\(vehicle.name) \(vehicle.model) · \(vehicle.licensePlate)")
            }

            // Scheduled
            detailRow(
                icon: "calendar",
                label: "Scheduled",
                value: trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
            )

            // Actual start
            if let start = trip.actualStartDate {
                detailRow(
                    icon: "play.fill",
                    label: "Started",
                    value: start.formatted(.dateTime.day().month(.abbreviated).hour().minute())
                )
            }

            // Actual end / duration
            if let end = trip.actualEndDate {
                detailRow(
                    icon: "checkmark.circle.fill",
                    label: "Completed",
                    value: end.formatted(.dateTime.day().month(.abbreviated).hour().minute())
                )
                if let dur = trip.durationString {
                    detailRow(icon: "timer", label: "Duration", value: dur)
                }
            }

            // Distance
            if let km = trip.distanceKm {
                detailRow(icon: "road.lanes", label: "Distance", value: String(format: "%.1f km", km))
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Instructions / Notes Cards
    // ─────────────────────────────────────────────────────────────

    private func instructionsCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Delivery Instructions")
            Text(trip.deliveryInstructions)
                .font(SierraFont.body(14, weight: .regular))
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func notesCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Notes")
            Text(trip.notes)
                .font(SierraFont.body(14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Reusable Sub-Views
    // ─────────────────────────────────────────────────────────────

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(SierraFont.body(11, weight: .bold))
            .foregroundStyle(.secondary)
            .kerning(1.1)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(SierraFont.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(SierraFont.body(14, weight: .medium))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
            }
        }
    }

    private func statusBadge(_ status: TripStatus) -> some View {
        let color: Color = switch status {
        case .active:    .green
        case .scheduled: SierraTheme.Colors.sierraBlue
        case .completed: .gray
        case .cancelled: .red
        }
        return Text(status.rawValue)
            .font(SierraFont.body(12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TripDetailView(tripId: Trip.mockData[0].id)
            .environment(AppDataStore.shared)
    }
}
