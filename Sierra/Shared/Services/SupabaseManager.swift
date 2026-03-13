import Foundation
import Supabase

// MARK: - SupabaseManager

/// Singleton wrapper around the Supabase Swift SDK client.
/// All services and view models access Supabase through this shared instance.
final class SupabaseManager {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Client

    let client: SupabaseClient

    // MARK: - Init

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://ldqcdngdlbbiojlnbnjg.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkcWNkbmdkbGJiaW9qbG5ibmpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzODUzMjMsImV4cCI6MjA4ODk2MTMyM30.gQm6e-Uafm5bXfpbNEDCbl6bFgi1Cweg-tHE58nNdRE"
        )
    }

    // MARK: - Convenience Accessors

    /// Supabase Auth client.
    var auth: AuthClient { client.auth }

    /// Supabase Realtime client.
    var realtime: some AnyObject { client.realtime as AnyObject }

    /// Supabase Storage client.
    var storage: SupabaseStorageClient { client.storage }

    // MARK: - Database Helper

    /// Returns a query builder for the given table name.
    func from(_ table: String) -> PostgrestQueryBuilder {
        client.from(table)
    }
}
