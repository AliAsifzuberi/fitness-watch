//
//  SupabaseConfig.swift
//  fitness-watch (iPhone)
//
//  Reads your project URL + anon key from Secrets.plist (not committed).
//

import Foundation

enum SupabaseConfig {
    struct Values {
        let projectURL: URL
        let anonKey: String
        let bucket: String
    }

    /// Returns nil if Secrets.plist is missing or incomplete.
    static func load() -> Values? {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: String],
            let urlString = dict["SUPABASE_URL"],
            let url = URL(string: urlString),
            let key = dict["SUPABASE_ANON_KEY"],
            !key.isEmpty,
            !urlString.contains("YOUR_")
        else {
            return nil
        }

        let bucket = dict["SUPABASE_BUCKET"] ?? "motion-recordings"
        return Values(projectURL: url, anonKey: key, bucket: bucket)
    }
}
