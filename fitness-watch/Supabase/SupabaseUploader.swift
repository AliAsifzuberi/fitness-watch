//
//  SupabaseUploader.swift
//  fitness-watch (iPhone)
//
//  Uploads a CSV to Supabase Storage and inserts a metadata row via REST.
//  We use URLSession (built into iOS) so you learn the basics before SDKs.
//

import Foundation

enum SupabaseUploaderError: LocalizedError {
    case missingSecrets
    case badResponse(Int, String)
    case missingFile

    var errorDescription: String? {
        switch self {
        case .missingSecrets:
            return "Add fitness-watch/Secrets.plist (see Secrets.example.plist)"
        case .badResponse(let code, let body):
            return "Supabase HTTP \(code): \(body)"
        case .missingFile:
            return "CSV file missing on phone"
        }
    }
}

enum SupabaseUploader {
    /// Upload CSV bytes to Storage, then insert a row into `recordings`.
    static func upload(_ recording: LocalRecording, fileURL: URL) async throws -> String {
        guard let config = SupabaseConfig.load() else {
            throw SupabaseUploaderError.missingSecrets
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SupabaseUploaderError.missingFile
        }

        let data = try Data(contentsOf: fileURL)
        // Path inside the bucket — keep it unique and easy to find.
        let objectPath = "\(recording.subjectID)/\(recording.fileName)"

        try await uploadToStorage(
            data: data,
            objectPath: objectPath,
            config: config
        )

        try await insertMetadata(
            recording: recording,
            storagePath: objectPath,
            config: config
        )

        return objectPath
    }

    // MARK: - Storage
    //
    // POST /storage/v1/object/{bucket}/{path}
    // Headers: apikey, Authorization: Bearer <anon key>, Content-Type: text/csv

    private static func uploadToStorage(
        data: Data,
        objectPath: String,
        config: SupabaseConfig.Values
    ) async throws {
        // Build URL as a string so nested paths (subject/file.csv) work correctly.
        let urlString = config.projectURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/storage/v1/object/\(config.bucket)/\(objectPath)"

        guard let url = URL(string: urlString) else {
            throw SupabaseUploaderError.badResponse(-1, "Bad storage URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        // Upsert so re-uploads of the same filename replace instead of failing.
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseUploaderError.badResponse(code, body)
        }
    }

    // MARK: - Database
    //
    // POST /rest/v1/recordings
    // Body: JSON row matching the table we create in Supabase.

    private static func insertMetadata(
        recording: LocalRecording,
        storagePath: String,
        config: SupabaseConfig.Values
    ) async throws {
        let urlString = config.projectURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/rest/v1/recordings"
        guard let url = URL(string: urlString) else {
            throw SupabaseUploaderError.badResponse(-1, "Bad REST URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        var payload: [String: Any] = [
            "session_id": recording.id,
            "label": recording.label,
            "true_reps": recording.trueReps,
            "subject_id": recording.subjectID,
            "wrist": recording.wrist,
            "file_name": recording.fileName,
            "storage_path": storagePath
        ]
        if let weightKg = recording.weightKg {
            payload["weight_kg"] = weightKg
        } else {
            payload["weight_kg"] = NSNull()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseUploaderError.badResponse(code, body)
        }
    }
}
