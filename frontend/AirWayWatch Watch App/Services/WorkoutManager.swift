//
//  WorkoutManager.swift
//  AirWayWatch Watch App
//
//  Manages an HKWorkoutSession to enable continuous heart rate monitoring.
//  Uses .mindAndBody activity type to keep sensors active without
//  distorting the user's activity rings significantly.
//
//  This is the ONLY way to get real-time heart rate on watchOS —
//  background HR sampling happens every 5-10 min without a workout,
//  but during a workout session it samples every 1-5 seconds.
//

import Foundation
import HealthKit
import Combine

class WorkoutManager: NSObject, ObservableObject {
    private let healthStore: HKHealthStore
    private weak var biometricReader: BiometricReader?

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published var isActive = false
    @Published var latestHeartRate: Double = 0

    // MARK: - Units
    private let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())

    init(healthStore: HKHealthStore = HealthKitManager.shared.healthStore,
         biometricReader: BiometricReader? = nil) {
        self.healthStore = healthStore
        self.biometricReader = biometricReader
        super.init()
    }

    func setBiometricReader(_ reader: BiometricReader) {
        self.biometricReader = reader
    }

    // MARK: - Start Monitoring Session

    func startMonitoring() {
        guard !isActive else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        } catch {
            print("PPI WorkoutManager: Failed to create session — \(error.localizedDescription)")
            return
        }

        workoutSession?.delegate = self
        workoutBuilder?.delegate = self
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        let startDate = Date()
        workoutSession?.startActivity(with: startDate)
        workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.isActive = true
                }
            } else {
                print("PPI WorkoutManager: Failed to begin collection — \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    // MARK: - Stop Monitoring Session

    func stopMonitoring() {
        guard isActive else { return }

        workoutSession?.end()

        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.workoutBuilder?.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    self?.isActive = false
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            self.isActive = (toState == .running)
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("PPI WorkoutManager: Session failed — \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }

            guard let statistics = workoutBuilder.statistics(for: quantityType),
                  let mostRecent = statistics.mostRecentQuantity() else { continue }

            let bpm = mostRecent.doubleValue(for: bpmUnit)

            DispatchQueue.main.async {
                self.latestHeartRate = bpm
                // Forward to BiometricReader for PPI calculation
                self.biometricReader?.updateHeartRateFromWorkout(bpm)
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No-op: we don't track workout events for PPI
    }
}
