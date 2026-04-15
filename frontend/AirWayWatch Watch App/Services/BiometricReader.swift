//
//  BiometricReader.swift
//  AirWayWatch Watch App
//
//  Lee los 4 biométricos desde HealthKit:
//  - Heart Rate (real-time via WorkoutManager, or latest sample)
//  - HRV SDNN (latest opportunistic sample)
//  - SpO2 (latest background sample)
//  - Respiratory Rate (latest sleep sample)
//
//  Uses HKAnchoredObjectQuery for live updates and HKSampleQuery for polling.
//

import Foundation
import HealthKit
import Combine

class BiometricReader: ObservableObject {
    private let healthStore: HKHealthStore

    // MARK: - Published Biometric Values
    @Published var heartRate: Double?
    @Published var heartRateDate: Date?

    @Published var hrv: Double?
    @Published var hrvDate: Date?

    @Published var spO2: Double?
    @Published var spO2Date: Date?

    @Published var respiratoryRate: Double?
    @Published var respiratoryRateDate: Date?

    @Published var isMonitoring = false

    // MARK: - Anchored Queries (keep references to stop them)
    private var heartRateAnchorQuery: HKAnchoredObjectQuery?
    private var hrvObserverQuery: HKObserverQuery?
    private var spO2ObserverQuery: HKObserverQuery?
    private var respObserverQuery: HKObserverQuery?

    // MARK: - Units
    private let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
    private let msUnit = HKUnit.secondUnit(with: .milli)
    private let percentUnit = HKUnit.percent()
    private let brpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())

    init(healthStore: HKHealthStore = HealthKitManager.shared.healthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Start Monitoring All Available Metrics

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Fetch latest values immediately
        fetchAllLatest()

        // Set up observer queries for passive metrics (HRV, SpO2, RespRate)
        // Heart Rate is handled by WorkoutManager for real-time, but we also observe
        setupHeartRateAnchor()
        setupObserver(for: .heartRateVariabilitySDNN) { [weak self] in
            self?.fetchLatestHRV()
        }
        setupObserver(for: .oxygenSaturation) { [weak self] in
            self?.fetchLatestSpO2()
        }
        setupObserver(for: .respiratoryRate) { [weak self] in
            self?.fetchLatestRespiratoryRate()
        }
    }

    func stopMonitoring() {
        isMonitoring = false

        if let q = heartRateAnchorQuery { healthStore.stop(q) }
        if let q = hrvObserverQuery { healthStore.stop(q) }
        if let q = spO2ObserverQuery { healthStore.stop(q) }
        if let q = respObserverQuery { healthStore.stop(q) }

        heartRateAnchorQuery = nil
        hrvObserverQuery = nil
        spO2ObserverQuery = nil
        respObserverQuery = nil
    }

    // MARK: - Fetch All Latest Values (Polling)

    func fetchAllLatest() {
        fetchLatestHeartRate()
        fetchLatestHRV()
        fetchLatestSpO2()
        fetchLatestRespiratoryRate()
    }

    // MARK: - Heart Rate

    func fetchLatestHeartRate() {
        fetchLatest(.heartRate, unit: bpmUnit) { [weak self] value, date in
            DispatchQueue.main.async {
                self?.heartRate = value
                self?.heartRateDate = date
            }
        }
    }

    /// Update HR from WorkoutManager's live data (bypasses HealthKit query)
    func updateHeartRateFromWorkout(_ bpm: Double) {
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.heartRateDate = Date()
        }
    }

    private func setupHeartRateAnchor() {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        heartRateAnchorQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else { return }

        let bpm = latest.quantity.doubleValue(for: bpmUnit)
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.heartRateDate = latest.endDate
        }
    }

    // MARK: - HRV (SDNN)

    func fetchLatestHRV() {
        fetchLatest(.heartRateVariabilitySDNN, unit: msUnit) { [weak self] value, date in
            DispatchQueue.main.async {
                self?.hrv = value
                self?.hrvDate = date
            }
        }
    }

    // MARK: - SpO2

    func fetchLatestSpO2() {
        fetchLatest(.oxygenSaturation, unit: percentUnit) { [weak self] value, date in
            DispatchQueue.main.async {
                // HealthKit stores SpO2 as 0.0-1.0, convert to 0-100
                if let v = value {
                    self?.spO2 = v * 100.0
                } else {
                    self?.spO2 = nil
                }
                self?.spO2Date = date
            }
        }
    }

    // MARK: - Respiratory Rate

    func fetchLatestRespiratoryRate() {
        // Only look at last 24h since this is sleep-only data
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        guard let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: respType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self = self else { return }
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { self.respiratoryRate = nil; self.respiratoryRateDate = nil }
                return
            }
            let brpm = sample.quantity.doubleValue(for: self.brpmUnit)
            DispatchQueue.main.async {
                self.respiratoryRate = brpm
                self.respiratoryRateDate = sample.endDate
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Generic Latest Sample Fetcher

    private func fetchLatest(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double?, Date?) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil, nil)
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit), sample.endDate)
        }
        healthStore.execute(query)
    }

    // MARK: - Observer Query Setup (for passive metrics)

    private func setupObserver(for identifier: HKQuantityTypeIdentifier, handler: @escaping () -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
            if error == nil {
                handler()
            }
            completionHandler()
        }

        switch identifier {
        case .heartRateVariabilitySDNN: hrvObserverQuery = query
        case .oxygenSaturation: spO2ObserverQuery = query
        case .respiratoryRate: respObserverQuery = query
        default: break
        }

        healthStore.execute(query)
    }

    // MARK: - Data Freshness Check

    /// Returns how many of the 4 metrics have recent data (within specified minutes)
    func availableMetricsCount(withinMinutes minutes: Double = 60) -> Int {
        let threshold = Date().addingTimeInterval(-minutes * 60)
        var count = 0
        if let d = heartRateDate, d > threshold { count += 1 }
        if let d = hrvDate, d > threshold { count += 1 }
        if let d = spO2Date, d > threshold { count += 1 }
        if let d = respiratoryRateDate, d > threshold { count += 1 }
        return count
    }

    /// Creates a BiometricUpdateData snapshot for sending to iPhone
    func createSnapshot() -> BiometricUpdateData {
        BiometricUpdateData(
            heartRate: heartRate,
            heartRateDate: heartRateDate,
            hrv: hrv,
            hrvDate: hrvDate,
            spO2: spO2,
            spO2Date: spO2Date,
            respiratoryRate: respiratoryRate,
            respiratoryRateDate: respiratoryRateDate,
            timestamp: Date()
        )
    }
}
