//
//  RecordingStore.swift
//  fitness-watch (iPhone)
//
//  Tiny on-phone database of recordings we received from the Watch.
//  Uses a JSON file — simple for Phase 1 (SwiftData can come later).
//

import Foundation

@MainActor
@Observable
final class RecordingStore {
    static let shared = RecordingStore()

    private(set) var recordings: [LocalRecording] = []

    private var storeURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("recordings_index.json")
    }

    private init() {
        load()
    }

    func add(_ recording: LocalRecording) {
        // Newest first in the UI.
        recordings.removeAll { $0.id == recording.id }
        recordings.insert(recording, at: 0)
        save()
    }

    func update(_ recording: LocalRecording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index] = recording
        save()
    }

    func fileURL(for recording: LocalRecording) -> URL {
        WatchBridge.recordingsDirectory.appendingPathComponent(recording.fileName)
    }

    func deleteLocalFiles(for recording: LocalRecording) {
        let url = fileURL(for: recording)
        try? FileManager.default.removeItem(at: url)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else {
            recordings = []
            return
        }
        recordings = (try? JSONDecoder().decode([LocalRecording].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
