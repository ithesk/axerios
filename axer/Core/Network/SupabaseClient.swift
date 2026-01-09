import Foundation
import Supabase

final class SupabaseClient {
    static let shared = SupabaseClient()

    let client: Supabase.SupabaseClient

    private init() {
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let url = URL(string: supabaseURL) else {
            fatalError("Missing Supabase configuration. Please add SUPABASE_URL and SUPABASE_ANON_KEY to Info.plist")
        }

        client = Supabase.SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }
}
