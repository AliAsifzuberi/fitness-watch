//
//  RecordingsListView.swift
//  fitness-watch (iPhone)
//
//  Shows CSVs received from the Watch and uploads them to Supabase.
//

import SwiftUI

struct RecordingsListView: View {
    @State private var store = RecordingStore.shared
    @State private var watchBridge = WatchBridge.shared
    @State private var busyID: String?
    @State private var banner: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(watchBridge.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let banner {
                        Text(banner)
                            .font(.footnote)
                    }
                    if SupabaseConfig.load() == nil {
                        Text("Missing Secrets.plist — copy Secrets.example.plist → Secrets.plist and add your Supabase URL + anon key.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Recordings") {
                    if store.recordings.isEmpty {
                        Text("No recordings yet. Record a set on the Watch.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.recordings) { recording in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(recording.label)
                                    .font(.headline)
                                Text("\(recording.trueReps) reps · \(recording.fileName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(stateLabel(recording.uploadState))
                                    .font(.caption2)
                                    .foregroundStyle(stateColor(recording.uploadState))

                                if recording.uploadState != .uploaded {
                                    Button {
                                        Task { await upload(recording) }
                                    } label: {
                                        if busyID == recording.id {
                                            ProgressView()
                                        } else {
                                            Text("Upload to Supabase")
                                        }
                                    }
                                    .disabled(busyID != nil)
                                }

                                if let err = recording.lastError {
                                    Text(err)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Recordings")
        }
    }

    private func upload(_ recording: LocalRecording) async {
        busyID = recording.id
        banner = nil

        var updated = recording
        updated.uploadState = .uploading
        updated.lastError = nil
        store.update(updated)

        do {
            let path = try await SupabaseUploader.upload(
                recording,
                fileURL: store.fileURL(for: recording)
            )
            updated.uploadState = .uploaded
            updated.supabasePath = path
            store.update(updated)

            // Free phone storage after a successful cloud upload.
            store.deleteLocalFiles(for: updated)
            banner = "Uploaded \(recording.fileName)"
        } catch {
            updated.uploadState = .failed
            updated.lastError = error.localizedDescription
            store.update(updated)
            banner = error.localizedDescription
        }

        busyID = nil
    }

    private func stateLabel(_ state: UploadState) -> String {
        switch state {
        case .pending: return "On phone — not uploaded"
        case .uploading: return "Uploading…"
        case .uploaded: return "Uploaded to Supabase"
        case .failed: return "Upload failed"
        }
    }

    private func stateColor(_ state: UploadState) -> Color {
        switch state {
        case .pending: return .secondary
        case .uploading: return .orange
        case .uploaded: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    RecordingsListView()
}
