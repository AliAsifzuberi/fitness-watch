//
//  LocalRecording.swift
//  fitness-watch (iPhone)
//
//  Metadata about a CSV sitting on the phone (before/after Supabase upload).
//

import Foundation

enum UploadState: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
}

struct LocalRecording: Identifiable, Codable, Equatable {
    let id: String
    let fileName: String
    let label: String
    let trueReps: Int
    let weightKg: Double?
    let subjectID: String
    let wrist: String
    let createdAt: Date
    var uploadState: UploadState
    var lastError: String?
    var supabasePath: String?
}
