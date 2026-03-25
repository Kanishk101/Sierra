import SwiftUI

/// Driver Alerts tab — shows all notifications sent to/from the driver.
/// FMS_SS orange theme with card-based layout.
struct DriverAlertsView: View {

    @Environment(AppDataStore.self) private var store

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var driverNotifications: [SierraNotification] {
        guard let userId = user?.id else { return [] }
        return store.notifications
            .filter { $0.recipientId == userId && $0.isVisible }
            .sorted { $0.sentAt > $1.sentAt }
    }

    private var unreadCount: Int {
        driverNotifications.filter { !$0.isRead }.count
    }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            if driverNotifications.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Alerts")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                        // Unread badge header
                        if unreadCount > 0 {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.appOrange)
                                    .frame(width: 8, height: 8)
                                Text("\(unreadCount) unread alert\(unreadCount == 1 ? "" : "s")")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.appOrange)
                                Spacer()

                                Button {
                                    markAllRead()
                                } label: {
                                    Text("Mark All Read")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.appOrange)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }

                        ForEach(driverNotifications) { notification in
                            alertCard(notification)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if let id = user?.id {
                await store.loadDriverData(driverId: id)
            }
        }
    }

    // MARK: - Alert Card

    private func alertCard(_ notification: SierraNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor(for: notification.type).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName(for: notification.type))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor(for: notification.type))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    if !notification.isRead {
                        Circle()
                            .fill(Color.appOrange)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(notification.body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(notification.sentAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.appTextSecondary.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(notification.isRead ? Color.appCardBg : Color.appOrange.opacity(0.04))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    notification.isRead
                        ? Color.appDivider.opacity(0.5)
                        : Color.appOrange.opacity(0.2),
                    lineWidth: 1
                )
        )
        .onTapGesture {
            markRead(notification)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appOrange.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.appOrange.opacity(0.4))
            }

            Text("No Alerts")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Text("You're all caught up.\nNew alerts will appear here.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func markRead(_ notification: SierraNotification) {
        guard !notification.isRead else { return }
        Task {
            try? await store.markNotificationRead(id: notification.id)
        }
    }

    private func markAllRead() {
        for n in driverNotifications where !n.isRead {
            Task {
                try? await store.markNotificationRead(id: n.id)
            }
        }
    }

    private func iconName(for type: NotificationType) -> String {
        switch type {
        case .tripAssigned:            return "bus.fill"
        case .tripAccepted:            return "checkmark.circle.fill"
        case .tripRejected:            return "xmark.circle.fill"
        case .tripCancelled:           return "xmark.octagon.fill"
        case .vehicleAssigned:         return "car.fill"
        case .maintenanceApproved:     return "wrench.and.screwdriver.fill"
        case .maintenanceRejected:     return "wrench.trianglebadge.exclamationmark"
        case .maintenanceOverdue:      return "exclamationmark.triangle.fill"
        case .sosAlert:                return "sos.circle.fill"
        case .defectAlert:             return "exclamationmark.shield.fill"
        case .routeDeviation:          return "arrow.triangle.branch"
        case .geofenceAlert:           return "location.slash.fill"
        case .documentExpiry:          return "doc.badge.clock.fill"
        case .inspectionFailed:        return "checklist.unchecked"
        case .emergency:               return "light.beacon.max.fill"
        case .maintenanceComplete:     return "checkmark.seal.fill"
        case .general:                 return "bell.fill"
        case .preInspectionReminder:   return "clock.badge.checkmark.fill"
        case .tripAcceptanceReminder:  return "hand.raised.fill"
        }
    }

    private func iconColor(for type: NotificationType) -> Color {
        switch type {
        case .tripAssigned, .vehicleAssigned:  return .appOrange
        case .tripAccepted, .maintenanceApproved, .maintenanceComplete:
            return Color.green
        case .tripRejected, .maintenanceRejected, .tripCancelled:
            return Color.red
        case .sosAlert, .emergency:            return Color.red
        case .maintenanceOverdue, .defectAlert, .inspectionFailed:
            return .orange
        case .routeDeviation, .geofenceAlert:   return .orange
        case .documentExpiry:                   return .orange
        case .general:                          return .appOrange
        case .preInspectionReminder, .tripAcceptanceReminder:
            return .appOrange
        }
    }
}

#Preview {
    NavigationStack {
        DriverAlertsView()
            .environment(AppDataStore.shared)
    }
}
