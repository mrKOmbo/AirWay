//
//  BaselineEngine.swift
//  AirWayWatch Watch App
//
//  Calculates personal baselines for biometric data using
//  Exponential Moving Average (EMA) with time-of-day buckets.
//
//  The day is divided into 6 × 4-hour buckets to capture circadian rhythm:
//  [00-04] [04-08] [08-12] [12-16] [16-20] [20-24]
//
//  Each bucket maintains its own EMA baseline for HR, HRV, SpO2, and RespRate.
//  This means "your normal HR at 7am" is separate from "your normal HR at 3pm".
//
//  Science: α = 0.15 gives an effective 7-day window.
//  Formula: baseline_new = α × current_value + (1 - α) × baseline_old
//

import Foundation
import HealthKit

// MARK: - Metric Enum

enum BiometricMetric: String, CaseIterable, Codable {
    case heartRate = "hr"
    case hrv = "hrv"
    case spO2 = "spo2"
    case respiratoryRate = "resp"
}

// MARK: - Baseline Data Structure

struct MetricBaseline: Codable {
    var value: Double
    var sampleCount: Int
    var lastUpdated: Date

    var isCalibrated: Bool {
        sampleCount >= 3
    }
}

struct TimeBucketBaselines: Codable {
    var hr: MetricBaseline?
    var hrv: MetricBaseline?
    var spO2: MetricBaseline?
    var resp: MetricBaseline?

    func baseline(for metric: BiometricMetric) -> MetricBaseline? {
        switch metric {
        case .heartRate: return hr
        case .hrv: return hrv
        case .spO2: return spO2
        case .respiratoryRate: return resp
        }
    }

    mutating func setBaseline(_ baseline: MetricBaseline, for metric: BiometricMetric) {
        switch metric {
        case .heartRate: hr = baseline
        case .hrv: hrv = baseline
        case .spO2: spO2 = baseline
        case .respiratoryRate: resp = baseline
        }
    }
}

// MARK: - BaselineEngine

class BaselineEngine: ObservableObject {
    // 6 buckets × 4 hours each
    static let bucketCount = 6
    static let bucketHours = 4

    private let storageKey = "ppi_baselines_v1"
    private let defaults: UserDefaults

    @Published var buckets: [TimeBucketBaselines]
    @Published var isCalibrated = false
    @Published var calibrationProgress: Double = 0 // 0.0 - 1.0

    // EMA smoothing factor: 0.15 ≈ 7-day effective window
    private let baseAlpha: Double = 0.15
    // After a gap >24h, converge faster
    private let gapAlpha: Double = 0.45
    // Gap threshold in seconds (24 hours)
    private let gapThreshold: TimeInterval = 86400

    init(suiteName: String? = nil) {
        if let suite = suiteName {
            self.defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        } else {
            self.defaults = UserDefaults.standard
        }

        // Load persisted baselines or create empty
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([TimeBucketBaselines].self, from: data),
           saved.count == BaselineEngine.bucketCount {
            self.buckets = saved
        } else {
            self.buckets = Array(repeating: TimeBucketBaselines(), count: BaselineEngine.bucketCount)
        }

        updateCalibrationStatus()
    }

    // MARK: - Time Bucket Resolution

    /// Returns 0-5 based on current hour
    static func currentBucket() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        return min(hour / bucketHours, bucketCount - 1)
    }

    static func bucket(for date: Date) -> Int {
        let hour = Calendar.current.component(.hour, from: date)
        return min(hour / bucketHours, bucketCount - 1)
    }

    // MARK: - Update Baseline with New Reading

    func update(metric: BiometricMetric, value: Double, at date: Date = Date()) {
        let bucketIndex = BaselineEngine.bucket(for: date)

        guard value.isFinite && !value.isNaN else { return }

        // Sanity bounds
        switch metric {
        case .heartRate where value < 20 || value > 250: return
        case .hrv where value < 1 || value > 500: return
        case .spO2 where value < 50 || value > 100: return
        case .respiratoryRate where value < 4 || value > 60: return
        default: break
        }

        let existing = buckets[bucketIndex].baseline(for: metric)

        if let existing = existing {
            // Calculate adaptive alpha based on time gap
            let timeSinceLastUpdate = date.timeIntervalSince(existing.lastUpdated)
            let alpha = timeSinceLastUpdate > gapThreshold ? gapAlpha : baseAlpha

            // EMA update
            let newValue = alpha * value + (1.0 - alpha) * existing.value
            PPILog.baseline.notice(" UPDATE \(metric.rawValue) bucket=\(bucketIndex) old=\(String(format: "%.2f", existing.value)) new=\(String(format: "%.2f", newValue)) input=\(String(format: "%.2f", value)) alpha=\(String(format: "%.2f", alpha)) samples=\(existing.sampleCount + 1)")
            let newBaseline = MetricBaseline(
                value: newValue,
                sampleCount: existing.sampleCount + 1,
                lastUpdated: date
            )
            buckets[bucketIndex].setBaseline(newBaseline, for: metric)
        } else {
            // First reading for this bucket — initialize directly
            let newBaseline = MetricBaseline(
                value: value,
                sampleCount: 1,
                lastUpdated: date
            )
            buckets[bucketIndex].setBaseline(newBaseline, for: metric)
        }

        persist()
        updateCalibrationStatus()
    }

    // MARK: - Get Current Baseline

    /// Returns the baseline for the current time bucket
    func currentBaseline(for metric: BiometricMetric) -> MetricBaseline? {
        let bucket = BaselineEngine.currentBucket()
        return buckets[bucket].baseline(for: metric)
    }

    /// Returns baseline for a specific time bucket
    func baseline(for metric: BiometricMetric, bucket: Int) -> MetricBaseline? {
        guard bucket >= 0 && bucket < BaselineEngine.bucketCount else { return nil }
        return buckets[bucket].baseline(for: metric)
    }

    // MARK: - Calculate Deviation

    /// Returns the deviation from baseline for a metric.
    /// Positive = worse (for PPI scoring purposes):
    ///   - SpO2: baseline - current (drop is bad)
    ///   - HRV: (baseline - current) / baseline × 100 (decrease is bad)
    ///   - HR: current - baseline (increase is bad)
    ///   - RespRate: (current - baseline) / baseline × 100 (increase is bad)
    func deviation(for metric: BiometricMetric, currentValue: Double) -> Double? {
        guard let baseline = currentBaseline(for: metric),
              baseline.isCalibrated else {
            let bucket = BaselineEngine.currentBucket()
            let bl = buckets[bucket].baseline(for: metric)
            PPILog.baseline.notice(" deviation(\(metric.rawValue)): NOT calibrated — bucket=\(bucket) samples=\(bl?.sampleCount ?? 0) isCalibrated=\(bl?.isCalibrated ?? false)")
            return nil
        }

        let base = baseline.value
        guard base > 0 else { return nil }

        let dev: Double
        switch metric {
        case .spO2:
            dev = base - currentValue
        case .hrv:
            dev = ((base - currentValue) / base) * 100.0
        case .heartRate:
            dev = currentValue - base
        case .respiratoryRate:
            dev = ((currentValue - base) / base) * 100.0
        }
        PPILog.baseline.notice(" deviation(\(metric.rawValue)): base=\(String(format: "%.2f", base)) current=\(String(format: "%.2f", currentValue)) -> dev=\(String(format: "%.2f", dev))")
        return dev
    }

    // MARK: - Bootstrap from HealthKit History

    /// Loads 7 days of historical data from HealthKit to initialize baselines.
    /// Called on first launch so the user doesn't have to wait 7 days.
    func bootstrapFromHealthKit(healthStore: HKHealthStore, completion: @escaping (Bool) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            completion(false)
            return
        }

        let metrics: [(HKQuantityTypeIdentifier, HKUnit, BiometricMetric, Double)] = [
            (.heartRate, HKUnit.count().unitDivided(by: .minute()), .heartRate, 1.0),
            (.heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli), .hrv, 1.0),
            (.oxygenSaturation, HKUnit.percent(), .spO2, 100.0), // Convert 0-1 to 0-100
            (.respiratoryRate, HKUnit.count().unitDivided(by: .minute()), .respiratoryRate, 1.0),
        ]

        let group = DispatchGroup()

        for (identifier, unit, metric, multiplier) in metrics {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

            group.enter()

            var interval = DateComponents()
            interval.hour = BaselineEngine.bucketHours

            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            let anchorDate = calendar.startOfDay(for: endDate)

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage],
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { [weak self] _, results, error in
                defer { group.leave() }
                guard let self = self, let collection = results else { return }

                collection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    let value = avg.doubleValue(for: unit) * multiplier
                    let bucketIndex = BaselineEngine.bucket(for: stats.startDate)
                    self.update(metric: metric, value: value, at: stats.startDate)
                    _ = bucketIndex // bucket is determined inside update()
                }
            }

            healthStore.execute(query)
        }

        group.notify(queue: .main) { [weak self] in
            self?.persist()
            self?.updateCalibrationStatus()
            completion(true)
        }
    }

    // MARK: - Calibration Status

    private func updateCalibrationStatus() {
        let currentBucket = BaselineEngine.currentBucket()
        let bucketData = buckets[currentBucket]

        // Count how many metrics are calibrated in current bucket
        var calibrated = 0
        var total = 0

        for metric in BiometricMetric.allCases {
            total += 1
            if let b = bucketData.baseline(for: metric), b.isCalibrated {
                calibrated += 1
            }
        }

        DispatchQueue.main.async {
            self.calibrationProgress = total > 0 ? Double(calibrated) / Double(total) : 0
            // Consider calibrated if at least HR is calibrated (the most available metric)
            self.isCalibrated = bucketData.hr?.isCalibrated ?? false
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(buckets) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Reset

    func resetAllBaselines() {
        buckets = Array(repeating: TimeBucketBaselines(), count: BaselineEngine.bucketCount)
        persist()
        updateCalibrationStatus()
    }
}
