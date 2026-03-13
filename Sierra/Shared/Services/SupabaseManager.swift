import Supabase
import Foundation

// MARK: - Supabase Global Client
// Used by all service files as `supabase`

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://tufmgxaycmeohczdvjsr.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR1Zm1neGF5Y21lb2hjemR2anNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMjM3MTksImV4cCI6MjA4ODg5OTcxOX0.Fy5DbP0VyfxrLgaQDtgDep9-E7ZcdrM92LFOcupW168"
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
