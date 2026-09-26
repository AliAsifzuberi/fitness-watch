//
//  MotionRecorder.swift
//  fitness-watch Watch App
//
//  Talks to the watch sensors via Core Motion and buffers samples.
//

import CoreMotion
import Foundation

/// `@Observable` (Swift Observation) tells SwiftUI: "re-draw when these properties change."
/// `@MainActor` means this class's UI-facing state is updated on the main thread.
@MainActor
@Observable
final class MotionRecorder {
    /// Target 50 samples/second → interval of 0.02 seconds.
    private let sampleInterval: TimeInterval = 1.0 / 50.0
    private let motionManager = CMMotionManager()

    private(set) var isRecording = false
    private(set) var sampleCount = 0
    private(set) var elapsedSeconds: Int = 0
    private(set) var lastSavedFileName: String?
    private(set) var lastSavedURL: URL?
    private(set) var lastSessionID: UUID?
    private(set) var lastLabel: ExerciseLabel?
    var statusMessage: String = "Idle"

    private var samples: [MotionSample] = []
    private var startDate: Date?
    private var elapsedTimer: Timer?
    private var activeLabel: ExerciseLabel?
    private var activeSessionID: UUID?

    /// Your anonymous ID for CSVs (Phase 1: just you).
    var subjectID: String = "subject_01"
    /// Locked decision: left wrist.
    var wrist: String = "left"

    func start(label: ExerciseLabel) {
        guard !isRecording else { return }

        // Device motion fuses accel + gyro into userAcceleration, rotationRate, gravity.
        guard motionManager.isDeviceMotionAvailable else {
            statusMessage = "Device motion unavailable"
            return
        }

        samples.removeAll(keepingCapacity: true)
        sampleCount = 0
        elapsedSeconds = 0
        lastSavedFileName = nil
        lastSavedURL = nil
        lastSessionID = nil
        lastLabel = nil
        activeLabel = label
        activeSessionID = UUID()
        startDate = Date()
        isRecording = true
        statusMessage = "Recording…"

        motionManager.deviceMotionUpdateInterval = sampleInterval

        // Core Motion delivers on a background queue — we hop back to MainActor for UI state.
        let queue = OperationQueue()
        queue.name = "MotionRecorderQueue"
        queue.maxConcurrentOperationCount = 1

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let motion else { return }
            Task { @MainActor in
                self?.handleMotion(motion, error: error)
            }
        }

        // Simple UI timer so you can see elapsed time on the watch face.
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    /// Stops sensors but keeps buffered samples so we can ask for true reps, then save.
    func finishSampling() {
        guard isRecording else { return }
        motionManager.stopDeviceMotionUpdates()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        isRecording = false
        statusMessage = "Enter true reps…"
    }

    /// Writes the CSV after the user confirms true reps (and optional weight).
    func save(trueReps: Int, weightKg: Double?) -> URL? {
        guard let label = activeLabel,
              let sessionID = activeSessionID,
              !samples.isEmpty else {
            statusMessage = "Nothing to save"
            return nil
        }

        do {
            let url = try CSVWriter.writeRecording(
                samples: samples,
                label: label,
                sessionID: sessionID,
                subjectID: subjectID,
                wrist: wrist,
                weightKg: weightKg,
                trueReps: trueReps
            )
            lastSavedFileName = url.lastPathComponent
            lastSavedURL = url
            lastSessionID = sessionID
            lastLabel = label
            statusMessage = "Saved \(sampleCount) samples — sending to iPhone…"
            return url
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
            return nil
        }
    }

    func cancel() {
        motionManager.stopDeviceMotionUpdates()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        isRecording = false
        samples.removeAll()
        sampleCount = 0
        activeLabel = nil
        activeSessionID = nil
        statusMessage = "Cancelled"
    }

    // MARK: - Private

    private func handleMotion(_ motion: CMDeviceMotion, error: Error?) {
        if let error {
            statusMessage = error.localizedDescription
            return
        }
        guard isRecording, let startDate else { return }

        let timestampMs = Int(Date().timeIntervalSince(startDate) * 1000)
        let user = motion.userAcceleration
        let rot = motion.rotationRate
        let grav = motion.gravity

        // userAcceleration is in g's (gravity already removed).
        // rotationRate is in radians/second.
        let sample = MotionSample(
            timestampMs: timestampMs,
            ax: user.x, ay: user.y, az: user.z,
            gx: rot.x, gy: rot.y, gz: rot.z,
            gravX: grav.x, gravY: grav.y, gravZ: grav.z
        )
        samples.append(sample)
        sampleCount = samples.count
    }
}
