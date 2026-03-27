import SwiftUI

struct DriverTripCard: View {
    let trip: Trip
    let vehicle: Vehicle?
    let isWaitingForVehicleReassignment: Bool
    let isJustAccepted: Bool
    let isAccepting: Bool
    let onAccept: () -> Void
    let onShowTripDetail: () -> Void
    let onNavigate: () -> Void
    let onPostTripInspection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bus.fill")
                    .font(SierraFont.scaled(14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                Text(trip.taskId)
                    .font(SierraFont.scaled(13, weight: .bold, design: .monospaced))
                    .foregroundColor(.appOrange)
                Spacer()
                PriorityBadge(priority: trip.priority)
            }

            HStack(spacing: 10) {
                cityLabel(trip.origin)
                RouteArrow()
                cityLabel(trip.destination)
            }

            if let vehicle {
                HStack(spacing: 8) {
                    Text(vehicle.licensePlate)
                        .font(SierraFont.scaled(12, weight: .bold, design: .monospaced))
                        .foregroundColor(.appOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                    Text("\(vehicle.name) \(vehicle.model)")
                        .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(SierraFont.scaled(13))
                    .foregroundColor(.appTextSecondary)
                Text(trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }

            if let deadline = trip.responseDeadline {
                deadlineBadge(deadline: deadline)
            }

            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1)
                .padding(.vertical, 2)

            actionButtons
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: trip.priority.color.opacity(0.10), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isJustAccepted
                        ? Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.5)
                        : trip.priority.color.opacity(0.22),
                    lineWidth: isJustAccepted ? 2 : 1
                )
        )
        .scaleEffect(isJustAccepted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isJustAccepted)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let status: TripStatus = trip.isDriverWorkflowCompleted ? .completed : trip.status.normalized
        let isCompleted = status == .completed
        let isCancelled = status == .cancelled
        let needsPostTrip = trip.requiresPostTripInspection
        let postTripDone = isCompleted && trip.postInspectionId != nil
        let hasPreInspection = trip.preInspectionId != nil
        let isAcceptedScheduled = status == .scheduled && trip.acceptedAt != nil
        let isAcceptedAwaitingInspection = (isAcceptedScheduled || isJustAccepted) && !hasPreInspection
        let isPendingAcceptanceLike =
            !isAcceptedAwaitingInspection &&
            (status == .pendingAcceptance ||
             (status == .scheduled && trip.acceptedAt == nil && !hasPreInspection))
        let navProgress = TripNavigationCoordinator.sessionProgress(for: trip.id) ?? 0
        let navigationLockedByProgress = navProgress >= 0.999
        let isReadyToStart = isAcceptedScheduled && hasPreInspection && trip.scheduledDate <= Date()

        if isPendingAcceptanceLike {
            DriverTripCardActionButton(
                title: "Accept Trip",
                icon: "hand.thumbsup.fill",
                style: .solidDark,
                action: onAccept,
                isDisabled: isAccepting
            )
        } else if isWaitingForVehicleReassignment {
            HStack(spacing: 12) {
                DriverTripCardActionButton(
                    title: "Waiting for Vehicle",
                    icon: "hourglass",
                    style: .neutral
                )
                DriverTripCardActionButton(
                    title: "Accepted",
                    icon: "checkmark.seal.fill",
                    style: .success
                )
            }
        } else if isAcceptedAwaitingInspection {
            HStack(spacing: 12) {
                DriverTripCardActionButton(
                    title: "View Details",
                    icon: "doc.text.magnifyingglass",
                    style: .outlineOrange,
                    action: onShowTripDetail
                )
                DriverTripCardActionButton(
                    title: "Accepted",
                    icon: "checkmark.seal.fill",
                    style: .success
                )
            }
        } else if needsPostTrip {
            SlideToStartInspectionButton(
                label: "Post-Trip Inspection",
                controlHeight: 44,
                onComplete: onPostTripInspection
            )
        } else if postTripDone {
            HStack(spacing: 12) {
                NavigationLink(value: trip.id) {
                    DriverTripCardActionButton(
                        title: "View Details",
                        icon: "doc.text.magnifyingglass",
                        style: .outlineOrange
                    )
                }
                .buttonStyle(.plain)

                DriverTripCardActionButton(
                    title: "Completed",
                    icon: "checkmark.circle.fill",
                    style: .success
                )
            }
        } else {
            HStack(spacing: 12) {
                if isAcceptedScheduled && !hasPreInspection {
                    DriverTripCardActionButton(
                        title: "View Details",
                        icon: "doc.text.magnifyingglass",
                        style: .outlineOrange,
                        action: onShowTripDetail
                    )
                } else {
                    NavigationLink(value: trip.id) {
                        DriverTripCardActionButton(
                            title: "View Details",
                            icon: "doc.text.magnifyingglass",
                            style: .outlineOrange
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isCancelled {
                    DriverTripCardActionButton(
                        title: "Cancelled",
                        icon: "xmark.circle.fill",
                        style: .cancelled
                    )
                } else if isAcceptedScheduled && !hasPreInspection {
                    DriverTripCardActionButton(
                        title: "Accepted",
                        icon: "checkmark.seal.fill",
                        style: .success
                    )
                } else if isReadyToStart {
                    DriverTripCardActionButton(
                        title: "Navigate",
                        icon: "location.fill",
                        style: .solidNavigate,
                        action: onNavigate
                    )
                } else if status == .active && !trip.hasEndedNavigationPhase && !navigationLockedByProgress {
                    DriverTripCardActionButton(
                        title: "Navigate",
                        icon: "location.fill",
                        style: .solidNavigate,
                        action: onNavigate
                    )
                } else {
                    DriverTripCardActionButton(
                        title: statusDisplayName(status),
                        icon: "clock.fill",
                        style: .neutral
                    )
                }
            }
        }
    }

    private func cityLabel(_ text: String) -> some View {
        let words = text.split(separator: " ")
        let city = String(words.first ?? Substring(text))
        let rest = words.dropFirst().joined(separator: " ")

        return VStack(alignment: .leading, spacing: 1) {
            Text(city.uppercased())
                .font(SierraFont.scaled(18, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !rest.isEmpty {
                Text(rest)
                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func deadlineBadge(deadline: Date) -> some View {
        let isOverdue = deadline < Date()
        let isUrgent = deadline < Date().addingTimeInterval(2 * 3600) && !isOverdue

        return HStack(spacing: 6) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark.fill")
                .font(SierraFont.scaled(13, weight: .semibold))
                .foregroundColor(isOverdue ? .red : .appOrange)
            Text(isOverdue ? "Response Overdue" : "Respond by \(deadline.formatted(.dateTime.hour().minute()))")
                .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                .foregroundColor(isOverdue ? .red : .appOrange)
            Spacer()
            if isUrgent {
                Text("< 2h left")
                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.appOrange))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill((isOverdue ? Color.red : Color.appOrange).opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke((isOverdue ? Color.red : Color.appOrange).opacity(0.2), lineWidth: 1))
    }

    private func statusDisplayName(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "Pending Acceptance"
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .accepted: return "Scheduled"
        case .rejected: return "Cancelled"
        }
    }
}
