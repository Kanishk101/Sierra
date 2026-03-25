import SwiftUI

/// Driver Alerts tab — shows all notifications sent to/from the driver.
/// Single scrollable view with native large title collapse.
struct DriverAlertsView: View {

    @Environment(AppDataStore.self) private var store
    @State private var showClearConfirm = false
    @State private var isClearing = false

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
        Group {
            if driverNotifications.isEmpty {
                VStack(spacing: 0) {
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    Spacer()
                    emptyState
                        .padding(.horizontal, 24)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerBar
                            .padding(.bottom, 6)

                        // Unread badge header
                        if unreadCount > 0 {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.appOrange)
                                    .frame(width: 8, height: 8)
                                Text("\(unreadCount) unread")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.appOrange)
                                Spacer()
                                Button { markAllRead() } label: {
                                    Text("Mark All Read")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.appOrange)
                                }
                            }
                            .padding(.horizontal, 4)
                        }

                        ForEach(driverNotifications) { notification in
                            alertCard(notification)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Clear all notifications?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllNotifications()
            }
        } message: {
            Text("This will remove all notifications from your alerts list.")
        }
        .refreshable {
            if let id = user?.id {
                await store.refreshDriverData(driverId: id, force: true)
            }
        }
    }

    // MARK: - Alert Card

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Text("Notifications")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Spacer()
            if !driverNotifications.isEmpty {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    if isClearing {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text("Clear")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                .disabled(isClearing)
            }
        }
    }

    private func alertCard(_ notification: SierraNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
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

                Text(alertSubtitle(for: notification))
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
            RoundedRectangle(cornerRadius: 22)
                .fill(notification.isRead ? Color.appCardBg : Color.appOrange.opacity(0.04))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    notification.isRead
                        ? Color.appDivider
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appOrange.opacity(0.08))
                    .frame(width: 72, height: 72)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.appOrange.opacity(0.4))
            }
            Text("No Notifications")
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
        Task { try? await store.markNotificationRead(id: notification.id) }
    }

    private func markAllRead() {
        for n in driverNotifications where !n.isRead {
            Task { try? await store.markNotificationRead(id: n.id) }
        }
    }

    private func clearAllNotifications() {
        guard let userId = user?.id else { return }
        isClearing = true
        Task {
            defer { isClearing = false }
            try? await store.clearAllNotifications(userId: userId)
        }
    }

    private func alertSubtitle(for notification: SierraNotification) -> String {
        guard notification.type == .tripAssigned else { return notification.body }

        let taskId = extractTaskId(from: notification.title)
            ?? extractTaskId(from: notification.body)

        let routeText = notification.body
            .split(separator: ".")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.contains("→") && !$0.isEmpty }

        if let taskId, let routeText {
            return "\(taskId) | \(routeText)"
        }
        if let taskId {
            return "\(taskId) | \(notification.body)"
        }
        return notification.body
    }

    private func extractTaskId(from text: String) -> String? {
        guard let range = text.range(of: #"TRP-\d{8}-[A-Z0-9]+"#, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
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
        case .partsApproved:           return "shippingbox.and.arrow.backward.fill"
        case .partsRejected:           return "shippingbox.fill"
        case .maintenanceRequest:      return "exclamationmark.triangle.fill"
        case .general:                 return "bell.fill"
        case .preInspectionReminder:   return "clock.badge.checkmark.fill"
        case .tripAcceptanceReminder:  return "hand.raised.fill"
        }
    }

    private func iconColor(for type: NotificationType) -> Color {
        switch type {
        case .tripAssigned, .vehicleAssigned:  return .appOrange
        case .tripAccepted, .maintenanceApproved, .maintenanceComplete, .partsApproved:
            return Color.green
        case .tripRejected, .maintenanceRejected, .tripCancelled, .partsRejected:
            return Color.red
        case .sosAlert, .emergency:            return Color.red
        case .maintenanceOverdue, .defectAlert, .inspectionFailed, .maintenanceRequest:
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
