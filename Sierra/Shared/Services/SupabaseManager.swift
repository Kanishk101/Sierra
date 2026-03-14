import Supabase
import Foundation

// MARK: - Supabase Global Client
// Used by all service files as `supabase`

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ldqcdngdlbbiojlnbnjg.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkcWNkbmdkbGJiaW9qbG5ibmpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzODUzMjMsImV4cCI6MjA4ODk2MTMyM30.gQm6e-Uafm5bXfpbNEDCbl6bFgi1Cweg-tHE58nNdRE",
    options: SupabaseClientOptions(
        auth: AuthOptions(
            // Opt in to new session-emit behavior early.
            // Emits the locally stored session immediately on restore
            // rather than waiting for a token refresh attempt first.
            // Required check: if you use the initial session to gate UI,
            // also check `session.isExpired` before trusting it.
            emitLocalSessionAsInitialSession: true
        )
    )
)

// MARK: - SupabaseManager (Wrapper for legacy code compatibility)

final class SupabaseManager {

    static let shared = SupabaseManager()
    private init() {}

    /// The underlying SupabaseClient.
    var client: SupabaseClient { supabase }

    /// Convenience Auth accessor.
    var auth: AuthClient { supabase.auth }

    /// Convenience Storage accessor.
    var storage: SupabaseStorageClient { supabase.storage }

    /// Returns a query builder for the given table name.
    func from(_ table: String) -> PostgrestQueryBuilder {
        supabase.from(table)
    }
}
