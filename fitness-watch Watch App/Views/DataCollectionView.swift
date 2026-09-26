//
//  DataCollectionView.swift
//  fitness-watch Watch App
//
//  One-handed gym UI: pick label → record → enter true reps → hand off to iPhone.
//

import SwiftUI

struct DataCollectionView: View {
    /// `@State` = this view owns these objects. When their `@Observable`
    /// properties change, SwiftUI redraws the parts that read them.
    @State private var recorder = MotionRecorder()
    @State private var sessionManager = WorkoutSessionManager()
    @State private var phoneBridge = PhoneBridge.shared

    @State private var selectedLabel: ExerciseLabel = .dumbbellCurl
    @State private var showingRepPrompt = false
    @State private var trueReps: Int = 10
    @State private var weightKgText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    labelPicker
                    statusBlock
                    controls
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Collect")
            .task {
                // Runs when the screen appears: ask for Health permission once.
                await sessionManager.requestAuthorization()
            }
            .sheet(isPresented: $showingRepPrompt) {
                repEntrySheet
            }
        }
    }

    private var labelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exercise")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Picker("Exercise", selection: $selectedLabel) {
                ForEach(ExerciseLabel.allCases) { label in
                    Text(label.displayName).tag(label)
                }
            }
            .pickerStyle(.navigationLink)
            .disabled(recorder.isRecording)
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recorder.isRecording ? "RECORDING" : "Ready")
                .font(.headline)
                .foregroundStyle(recorder.isRecording ? .red : .primary)

            Text("Samples: \(recorder.sampleCount)")
                .font(.caption2)
                .monospacedDigit()

            Text("Time: \(recorder.elapsedSeconds)s")
                .font(.caption2)
                .monospacedDigit()

            Text(recorder.statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(sessionManager.statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(phoneBridge.statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let name = recorder.lastSavedFileName {
                Text("Last: \(name)")
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if recorder.isRecording {
                Button(role: .destructive) {
                    recorder.finishSampling()
                    Task {
                        await sessionManager.stop()
                        showingRepPrompt = true
                    }
                } label: {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }

                Button("Cancel") {
                    Task {
                        recorder.cancel()
                        await sessionManager.stop()
                    }
                }
            } else {
                Button {
                    Task {
                        await sessionManager.start()
                        recorder.start(label: selectedLabel)
                    }
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private var repEntrySheet: some View {
        NavigationStack {
            Form {
                Stepper("True reps: \(trueReps)", value: $trueReps, in: 0...50)
                TextField("Weight kg (optional)", text: $weightKgText)
                Button("Save & Send to iPhone") {
                    saveAndSend()
                }
            }
            .navigationTitle("Log set")
        }
    }

    /// 1) Write a short-lived CSV on the Watch
    /// 2) Queue a WatchConnectivity file transfer to the iPhone
    /// 3) PhoneBridge deletes the Watch file after Apple confirms delivery
    private func saveAndSend() {
        let weight = Double(weightKgText)
        guard let url = recorder.save(trueReps: trueReps, weightKg: weight),
              let sessionID = recorder.lastSessionID,
              let label = recorder.lastLabel else {
            showingRepPrompt = false
            return
        }

        var metadata: [String: Any] = [
            "session_id": sessionID.uuidString,
            "label": label.rawValue,
            "true_reps": trueReps,
            "subject_id": recorder.subjectID,
            "wrist": recorder.wrist
        ]
        if let weight {
            metadata["weight_kg"] = weight
        }

        phoneBridge.sendRecording(fileURL: url, metadata: metadata)
        showingRepPrompt = false
    }
}

#Preview {
    DataCollectionView()
}
