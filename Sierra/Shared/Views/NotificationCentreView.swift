import SwiftUI

/// Shared notification centre — reads from AppDataStore.notifications (Safeguard 5).
struct NotificationCentreView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var sortedNotifications: [SierraNotification] {
        store.notifications.sorted { $0.sentAt > $1.sentAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedNotifications.isEmpty {
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
                } else {
                    List {
                        ForEach(sortedNotifications) { notif in
                            notificationRow(notif)
                                .onTapGesture {
                                    Task { await markRead(notif) }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        Task { await markAllRead() }
                    }
                    .font(.caption)
                    .disabled(store.unreadNotificationCount == 0)
                }
            }
        }
    }

    // MARK: - Row

    private func notificationRow(_ notif: SierraNotification) -> some View {
        HStack(spacing: 12) {
            // Unread dot
            Circle()
                .fill(notif.isRead ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)

            Image(systemName: notifIcon(notif.type))
                .font(.title3)
                .foregroundStyle(notifColor(notif.type))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.title)
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
        case .sosAlert: return "sos.circle.fill"
        case .defectAlert: return "wrench.trianglebadge.exclamationmark"
        case .routeDeviation: return "location.slash.fill"
        case .maintenanceOverdue: return "clock.badge.exclamationmark"
        case .tripAssigned: return "map.fill"
        case .tripCancelled: return "xmark.circle.fill"
        case .vehicleAssigned: return "car.fill"
        case .maintenanceApproved: return "checkmark.seal.fill"
        case .maintenanceRejected: return "xmark.seal.fill"
        case .geofenceViolation: return "exclamationmark.shield.fill"
        case .inspectionFailed: return "doc.text.fill"
        case .general: return "bell.fill"
        }
    }

    private func notifColor(_ type: NotificationType) -> Color {
        switch type {
        case .sosAlert, .defectAlert: return .red
        case .routeDeviation, .geofenceViolation: return .orange
        case .maintenanceOverdue, .inspectionFailed: return .yellow
        case .tripAssigned, .vehicleAssigned: return .blue
        case .maintenanceApproved: return .green
        case .tripCancelled, .maintenanceRejected: return .red
        case .general: return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }

    // Safeguard 5: only these two calls to Supabase are allowed
    private func markRead(_ notif: SierraNotification) async {
        guard !notif.isRead else { return }
        do {
            try await NotificationService.markAsRead(notificationId: notif.id)
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
}
