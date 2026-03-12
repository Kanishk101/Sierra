import SwiftUI

// MARK: - TripCardView

/// Card displaying a single trip's summary — used in trip lists and dashboard.
///
///     TripCardView(
///         taskID: "TRP-20260311-0042",
///         route: "Mumbai → Pune Hub",
///         driverName: "James Turner",
///         vehicleInfo: "Hauler Alpha · FL-1024",
///         status: .active,
///         priority: .high,
///         timeInfo: "Started 1h ago"
///     )
struct TripCardView: View {

    let taskID: String
    let route: String
    var driverName: String? = nil
    var vehicleInfo: String? = nil
    let status: TaskStatus
    var priority: PriorityLevel? = nil
    var timeInfo: String? = nil

    var body: some View {
        SierraCard(borderAccentColor: status.dotColor) {
            VStack(alignment: .leading, spacing: Spacing.xs) {

                // ── Header ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(taskID)
                            .monoData(11)
                            .foregroundStyle(SierraTheme.Colors.granite)

                        Text(route)
                            .sierraStyle(.cardTitle)

                        if let subtitle = assignmentSubtitle {
                            Text(subtitle)
                                .sierraStyle(.secondaryBody)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    SierraBadge(status)
                }

                // ── Footer: priority + time ──
                if priority != nil || timeInfo != nil {
                    HStack(spacing: Spacing.xs) {
                        if let priority {
                            SierraBadge(
                                label: priority.label,
                                dotColor: priority.color,
                                backgroundColor: priority.color.opacity(0.12),
                                foregroundColor: priority.color,
                                size: .compact,
                                icon: priority.icon
                            )
                        }
                        if let timeInfo {
                            Text(timeInfo)
                                .sierraStyle(.caption)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var assignmentSubtitle: String? {
        let parts = [driverName, vehicleInfo].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
