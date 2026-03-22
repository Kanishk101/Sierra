import Foundation
import Supabase
import PostgREST

// MARK: - PushTokenService
// Registers the device's APNs push token to the `push_tokens` table in Supabase.
// Called from the AppDelegate when iOS provides a device token after the user
// grants push notification permission.
//
// The upsert uses (staff_id, device_token) as the conflict key — if the same
// token is registered multiple times (e.g., after app reinstall), it updates
// the `updated_at` timestamp rather than creating a duplicate row.

struct PushTokenService {

    static func registerToken(_ token: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        struct Payload: Encodable {
            let staff_id: String
            let device_token: String
            let platform: String
            let updated_at: String
        }

        let isoDate = ISO8601DateFormatter().string(from: Date())

        do {
            _ = try await supabase
                .from("push_tokens")
                .upsert(
                    Payload(
                        staff_id:     userId.uuidString,
                        device_token: token,
                        platform:     "ios",
                        updated_at:   isoDate
                    ),
                    onConflict: "staff_id,device_token"
                )
                .execute()
        } catch {
            print("[PushTokenService] registerToken failed: \(error)")
        }
    }

    /// Call this on sign-out to prevent push notifications being sent to a
    /// device that is no longer authenticated for this user.
    static func unregisterCurrentToken() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        // Fetch the token from the current device's UserDefaults
        guard let token = UserDefaults.standard.string(forKey: "sierra.devicePushToken") else { return }

        do {
            _ = try await supabase
                .from("push_tokens")
                .delete()
                .eq("staff_id", value: userId.uuidString)
                .eq("device_token", value: token)
                .execute()
        } catch {
            print("[PushTokenService] unregisterCurrentToken failed: \(error)")
        }
    }
}
