import Foundation
import Supabase
import Functions

// MARK: - NotificationDeliveryService
//
// Calls the deliver-due-notifications edge function which marks all past-due
// scheduled notifications as is_delivered=true. The DB trigger
// fn_send_push_on_notification_delivered then fires for each one, sending
// the push at the correct scheduled time rather than at insert time.
//
// Called from AppDataStore.loadDriverData() and loadAll() on every app load.
// This is an effective substitute for pg_cron (which isn't available on this project).

struct NotificationDeliveryService {

    static func deliverDueNotifications() async {
        guard let _ = AuthManager.shared.currentUser else { return }

        do {
            struct DeliveryResponse: Decodable { let delivered: Int }
            let result: DeliveryResponse = try await SupabaseManager
                .invokeEdgeWithSessionRecovery("deliver-due-notifications")
            if result.delivered > 0 {
                print("[NotificationDeliveryService] Delivered \(result.delivered) scheduled notification(s)")
            }
        } catch {
            // Non-fatal: notification delivery is best-effort
            print("[NotificationDeliveryService] Non-fatal delivery error: \(error)")
        }
    }
}
