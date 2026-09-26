//
//  WatchBridge.swift
//  fitness-watch (iPhone)
//
//  Receives CSV files transferred from the Watch.
//

import Foundation
import WatchConnectivity

@MainActor
@Observable
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private(set) var statusMessage: String = "Waiting for Watch…"
    private(set) var isActivated = false

    /// Where we keep recordings on the phone until Supabase upload succeeds.
    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else {
            statusMessage = "WatchConnectivity not supported on this device"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                statusMessage = "Watch link failed: \(error.localizedDescription)"
                isActivated = false
                return
            }
            isActivated = (activationState == .activated)
            statusMessage = isActivated ? "Watch link ready" : "Watch link not active"
        }
    }

    /// Apple delivers the Watch file here. The incoming URL is temporary —
    /// we must copy it somewhere permanent (Documents) immediately.
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let tempURL = file.fileURL
        let metadata = file.metadata ?? [:]
        let fileName = tempURL.lastPathComponent

        Task { @MainActor in
            let destination = Self.recordingsDirectory.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: tempURL, to: destination)

                // Persist a small JSON sidecar so the UI knows label/reps/upload state.
                let record = LocalRecording(
                    id: (metadata["session_id"] as? String) ?? UUID().uuidString,
                    fileName: fileName,
                    label: (metadata["label"] as? String) ?? "unknown",
                    trueReps: (metadata["true_reps"] as? Int) ?? 0,
                    weightKg: metadata["weight_kg"] as? Double,
                    subjectID: (metadata["subject_id"] as? String) ?? "subject_01",
                    wrist: (metadata["wrist"] as? String) ?? "left",
                    createdAt: Date(),
                    uploadState: .pending
                )
                RecordingStore.shared.add(record)
                statusMessage = "Received \(fileName)"

                // Auto-upload so you don't need to tap anything between sets.
                Task {
                    await Self.autoUpload(record)
                }
            } catch {
                statusMessage = "Receive failed: \(error.localizedDescription)"
            }
        }
    }

    private static func autoUpload(_ recording: LocalRecording) async {
        var updated = recording
        updated.uploadState = .uploading
        RecordingStore.shared.update(updated)

        do {
            let path = try await SupabaseUploader.upload(
                recording,
                fileURL: RecordingStore.shared.fileURL(for: recording)
            )
            updated.uploadState = .uploaded
            updated.supabasePath = path
            updated.lastError = nil
            RecordingStore.shared.update(updated)
            RecordingStore.shared.deleteLocalFiles(for: updated)
            WatchBridge.shared.statusMessage = "Uploaded \(recording.fileName) to Supabase"
        } catch {
            updated.uploadState = .failed
            updated.lastError = error.localizedDescription
            RecordingStore.shared.update(updated)
            WatchBridge.shared.statusMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // iOS requires these when the counterpart app supports complication / dual sessions.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // After switching watches, re-activate.
        session.activate()
    }
}
