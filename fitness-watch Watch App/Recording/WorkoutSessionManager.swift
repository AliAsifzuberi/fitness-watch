//
//  WorkoutSessionManager.swift
//  fitness-watch Watch App
//
//  Starts a HealthKit workout so watchOS keeps our app (and sensors) alive.
//

import Foundation
import HealthKit

@MainActor
@Observable
final class WorkoutSessionManager: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isSessionActive = false
    var statusMessage: String = "Session idle"

    /// Ask the user for HealthKit permission (shows the system sheet once).
    func requestAuthorization() async {
        // Types we may read/write during a strength workout session.
        let types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: types, read: types)
            statusMessage = "Health authorized"
        } catch {
            statusMessage = "Health auth failed: \(error.localizedDescription)"
        }
    }

    func start() async {
        guard !isSessionActive else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()

            // `self` as delegate: HealthKit will call us when state changes.
            session.delegate = self
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            self.session = session
            self.builder = builder

            // Start collecting samples, then start the session clock.
            try await builder.beginCollection(at: Date())
            session.startActivity(with: Date())

            isSessionActive = true
            statusMessage = "Workout session on"
        } catch {
            statusMessage = "Session start failed: \(error.localizedDescription)"
        }
    }

    func stop() async {
        guard let session, let builder else {
            isSessionActive = false
            return
        }

        session.end()
        do {
            try await builder.endCollection(at: Date())
            // Discard for Phase 1 — we only needed the session to keep the app alive.
            // Later phases can `finishWorkout()` to save to Health.
            builder.discardWorkout()
        } catch {
            statusMessage = "Session end issue: \(error.localizedDescription)"
        }

        self.session = nil
        self.builder = nil
        isSessionActive = false
        statusMessage = "Session stopped"
    }
}

// MARK: - Delegates
//
// HealthKit uses the older "delegate" pattern: it calls methods on us when events happen.
// `extension` lets us group that protocol conformance separately from the main class body.

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            statusMessage = "Session state: \(toState.rawValue)"
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            statusMessage = "Session error: \(error.localizedDescription)"
            isSessionActive = false
        }
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Phase 1: ignore heart rate / energy — we only care about Core Motion CSV.
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
