import SwiftUI

/// Shared notification centre — reads from AppDataStore.notifications.
/// Shows both delivered notifications and upcoming scheduled reminders
/// (pre-inspection, acceptance) that are within 2 hours.
struct NotificationCentreView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    // Delivered + read notifications, newest first
    private var delivered: [SierraNotification] {
        store.notifications
            .filter { $0.isDelivered || $0.scheduledFor == nil }
            .sorted { $0.sentAt > $1.sentAt }
    }

    // Upcoming scheduled reminders within 2 hours, soonest first
    private var upcomingReminders: [SierraNotification] {
        store.notifications
            .filter { $0.isPendingUpcoming }
            .sorted { ($0.scheduledFor ?? .distantFuture) < ($1.scheduledFor ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if delivered.isEmpty && upcomingReminders.isEmpty {
                    emptyState
                } else {
                    List {
                        // ── Upcoming reminders section ───────────────────────
                        if !upcomingReminders.isEmpty {
                            Section {
                                ForEach(upcomingReminders) { notif in
                                    upcomingRow(notif)
                                }
                            } header: {
                                Label("Upcoming Reminders", systemImage: "clock.badge")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .textCase(nil)
                            }
                        }

                        // ── Delivered notifications ──────────────────────────
                        if !delivered.isEmpty {
                            Section {
                                ForEach(delivered) { notif in
                                    notificationRow(notif)
                                        .onTapGesture { Task { await markRead(notif) } }
                                }
                            } header: {
                                if !upcomingReminders.isEmpty {
                                    Text("Recent")
                                        .font(.caption.weight(.semibold))
                                        .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await store.loadAndSubscribeNotifications(for: currentUserId, forceRefresh: true)
            }
            .refreshable {
                await store.loadAndSubscribeNotifications(for: currentUserId, forceRefresh: true)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if store.unreadNotificationCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark All Read") {
                            Task { await markAllRead() }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No notifications")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Upcoming reminder row (not yet delivered)

    private func upcomingRow(_ notif: SierraNotification) -> some View {
        HStack(spacing: 12) {
            Image(systemName: notifIcon(notif.type))
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(notificationTitle(notif))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(notif.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // "in Xm" countdown badge
            if let mins = notif.minutesUntilDelivery {
                Text(mins == 0 ? "now" : "in \(mins)m")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Delivered notification row

    private func notificationRow(_ notif: SierraNotification) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(notif.isRead ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)

            Image(systemName: notifIcon(notif.type))
                .font(.title3)
                .foregroundStyle(notifColor(notif.type))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(notificationTitle(notif))
                    .font(.subheadline.weight(notif.isRead ? .regular : .semibold))
                    .lineLimit(1)
                Text(notif.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(timeAgo(notif.sentAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .opacity(notif.isRead ? 0.7 : 1.0)
    }

    // MARK: - Helpers

    private func notifIcon(_ type: NotificationType) -> String {
        switch type {
        case .sosAlert:                return "sos.circle.fill"
        case .defectAlert:             return "wrench.trianglebadge.exclamationmark"
        case .routeDeviation:          return "location.slash.fill"
        case .maintenanceOverdue:      return "clock.badge.exclamationmark"
        case .tripAssigned:            return "map.fill"
        case .tripAccepted:            return "checkmark.circle.fill"
        case .tripRejected:            return "xmark.circle.fill"
        case .tripCancelled:           return "minus.circle.fill"
        case .vehicleAssigned:         return "car.fill"
        case .maintenanceApproved:     return "checkmark.seal.fill"
        case .maintenanceRejected:     return "xmark.seal.fill"
        case .geofenceAlert:           return "exclamationmark.shield.fill"
        case .inspectionFailed:        return "doc.text.fill"
        case .documentExpiry:          return "calendar.badge.exclamationmark"
        case .emergency:               return "exclamationmark.octagon.fill"
        case .maintenanceComplete:     return "wrench.and.screwdriver.fill"
        case .partsApproved:           return "shippingbox.and.arrow.backward.fill"
        case .partsRejected:           return "shippingbox.fill"
        case .maintenanceRequest:      return "exclamationmark.triangle.fill"
        case .preInspectionReminder:   return "checklist"
        case .tripAcceptanceReminder:  return "clock.badge.exclamationmark"
        case .general:                 return "bell.fill"
        }
    }

    private func notifColor(_ type: NotificationType) -> Color {
        switch type {
        case .sosAlert, .defectAlert, .emergency, .tripCancelled, .maintenanceRejected:
            return .red
        case .routeDeviation, .geofenceAlert, .tripRejected,
             .preInspectionReminder, .tripAcceptanceReminder:
            return .orange
        case .maintenanceOverdue, .inspectionFailed, .documentExpiry:
            return .yellow
        case .tripAssigned, .tripAccepted, .vehicleAssigned:
            return .blue
        case .maintenanceApproved, .maintenanceComplete, .partsApproved:
            return .green
        case .partsRejected:
            return .red
        case .maintenanceRequest:
            return .orange
        case .general:
            return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60      { return "Now" }
        if interval < 3600    { return "\(Int(interval / 60))m" }
        if interval < 86400   { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }

    private func markRead(_ notif: SierraNotification) async {
        guard !notif.isRead else { return }
        do {
            try await NotificationService.markAsRead(id: notif.id)
            if let idx = store.notifications.firstIndex(where: { $0.id == notif.id }) {
                store.notifications[idx].isRead = true
            }
        } catch {
            print("[NotifCentre] markRead error: \(error)")
        }
    }

    private func markAllRead() async {
        do {
            try await NotificationService.markAllAsRead(for: currentUserId)
            for i in store.notifications.indices {
                store.notifications[i].isRead = true
            }
        } catch {
            print("[NotifCentre] markAllRead error: \(error)")
        }
    }

    private func notificationTitle(_ notif: SierraNotification) -> String {
        guard notif.type == .defectAlert else { return notif.title }

        let entity = notif.entityType?.lowercased() ?? ""
        if entity == "post_trip_warning" { return "Post-Trip Inspection Warning" }
        if entity == "pre_trip_warning"  { return "Pre-Trip Inspection Warning" }

        let combined = "\(notif.title) \(notif.body)".lowercased()
        if combined.contains("post-trip") { return "Post-Trip Inspection Warning" }
        if combined.contains("pre-trip")  { return "Pre-Trip Inspection Warning" }
        return notif.title
    }
}
