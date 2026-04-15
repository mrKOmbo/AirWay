//
//  PPIScoreEngine.swift
//  AirWayWatch Watch App
//
//  Personal Pollution Impact Score Engine.
//
//  PPI = w1 × ΔSpO2 + w2 × ΔHRV + w3 × ΔHR + w4 × ΔResp
//
//  Each Δ is the deviation from the user's personal baseline (7-day EMA
//  at the same time of day). Deviations are mapped to 0-100 via a
//  rescaled sigmoid function with clinically-calibrated parameters.
//
//  Weights (from epidemiological literature):
//    SpO2  0.35 — most direct respiratory indicator
//    HRV   0.30 — autonomic nervous system proxy
//    HR    0.20 — acute stress response
//    Resp  0.15 — respiratory distress signal
//
//  The score is smoothed via Double Exponential Smoothing (Holt's method)
//  to avoid jittery readings while preserving trend responsiveness.
//

import Foundation
import Combine

// MARK: - Activity State

enum ActivityState: String, Codable {
    case resting
    case lightActivity
    case exercise
    case postExercise

    /// During exercise/post-exercise, HR and HRV are dominated by exertion,
    /// so their weight for pollution scoring is drastically reduced.
    var weightModifiers: [BiometricMetric: Double] {
        switch self {
        case .resting:
            return [.spO2: 1.0, .hrv: 1.0, .heartRate: 1.0, .respiratoryRate: 1.0]
        case .lightActivity:
            return [.spO2: 1.0, .hrv: 0.7, .heartRate: 0.5, .respiratoryRate: 0.8]
        case .exercise:
            return [.spO2: 1.2, .hrv: 0.1, .heartRate: 0.1, .respiratoryRate: 0.3]
        case .postExercise:
            return [.spO2: 1.0, .hrv: 0.3, .heartRate: 0.2, .respiratoryRate: 0.5]
        }
    }
}

// MARK: - Sigmoid Parameters (from clinical literature)

private struct SigmoidParams {
    let midpoint: Double    // deviation value that maps to score ≈ 50
    let steepness: Double   // how sharply the curve rises
    let maxDeviation: Double // clamp extreme values

    static let spO2 = SigmoidParams(midpoint: 3.0, steepness: 1.2, maxDeviation: 10.0)
    static let hrv = SigmoidParams(midpoint: 25.0, steepness: 0.07, maxDeviation: 60.0)
    static let hr = SigmoidParams(midpoint: 12.0, steepness: 0.20, maxDeviation: 40.0)
    static let resp = SigmoidParams(midpoint: 20.0, steepness: 0.08, maxDeviation: 50.0)

    static func params(for metric: BiometricMetric) -> SigmoidParams {
        switch metric {
        case .spO2: return .spO2
        case .hrv: return .hrv
        case .heartRate: return .hr
        case .respiratoryRate: return .resp
        }
    }
}

// MARK: - Double Exponential Smoother (Holt's Method)

private class HoltSmoother {
    private var level: Double?
    private var trend: Double = 0
    private let alpha: Double // data smoothing
    private let beta: Double  // trend smoothing

    init(alpha: Double = 0.3, beta: Double = 0.1) {
        self.alpha = alpha
        self.beta = beta
    }

    func smooth(_ value: Double) -> Double {
        guard let prevLevel = level else {
            level = value
            return value
        }

        let newLevel = alpha * value + (1.0 - alpha) * (prevLevel + trend)
        trend = beta * (newLevel - prevLevel) + (1.0 - beta) * trend
        level = newLevel
        return newLevel
    }

    func reset() {
        level = nil
        trend = 0
    }
}

// MARK: - PPI Score Engine

class PPIScoreEngine: ObservableObject {
    private let baselineEngine: BaselineEngine
    private let smoother = HoltSmoother(alpha: 0.3, beta: 0.1)

    // Default weights from literature
    private let baseWeights: [BiometricMetric: Double] = [
        .spO2: 0.35,
        .hrv: 0.30,
        .heartRate: 0.20,
        .respiratoryRate: 0.15,
    ]

    // MARK: - Published State
    @Published var currentScore: Int = 0
    @Published var currentZone: PPIZone = .green
    @Published var previousZone: PPIZone = .green
    @Published var components = PPIComponents(
        spO2Score: nil, hrvScore: nil, hrScore: nil, respScore: nil,
        spO2Deviation: nil, hrvDeviation: nil, hrDeviation: nil, respDeviation: nil
    )
    @Published var activityState: ActivityState = .resting
    @Published var availableMetrics: Int = 0
    @Published var scoringPaused = false
    @Published var pauseReason: String?

    // Vulnerability profile
    var vulnerabilityProfile: VulnerabilityProfile = VulnerabilityProfile()

    // When true, don't update baselines (used during demo mode)
    var skipBaselineUpdate = false

    // Exercise tracking
    private var lastExerciseEnd: Date?
    private let postExerciseCooldownMinutes: Double = 30

    init(baselineEngine: BaselineEngine) {
        self.baselineEngine = baselineEngine
    }

    // MARK: - Activity State Detection

    func updateActivityState(currentHR: Double?) {
        // Skip activity detection during demo — all changes are from pollution, not exertion
        if skipBaselineUpdate {
            activityState = .resting
            return
        }

        guard let hr = currentHR else {
            activityState = .resting
            return
        }

        let hrBaseline = baselineEngine.currentBaseline(for: .heartRate)?.value ?? 72

        // 1.5x = exercise (e.g. 68 baseline → 102+ bpm)
        if hr > hrBaseline * 1.5 {
            activityState = .exercise
            lastExerciseEnd = nil
        } else if let lastExEnd = lastExerciseEnd {
            let minutesSince = Date().timeIntervalSince(lastExEnd) / 60.0
            if minutesSince < postExerciseCooldownMinutes {
                activityState = .postExercise
            } else {
                activityState = .resting
            }
        } else if activityState == .exercise {
            lastExerciseEnd = Date()
            activityState = .postExercise
        // 1.3x = light activity (e.g. 68 baseline → 88+ bpm)
        } else if hr > hrBaseline * 1.3 {
            activityState = .lightActivity
        } else {
            activityState = .resting
        }
    }

    // MARK: - Core PPI Calculation

    func calculate(
        heartRate: Double?,
        hrv: Double?,
        spO2: Double?,
        respiratoryRate: Double?
    ) -> Int {
        // Update activity state
        updateActivityState(currentHR: heartRate)

        let actState = activityState.rawValue
        PPILog.engine.notice("calculate() HR=\(heartRate ?? -1) HRV=\(hrv ?? -1) SpO2=\(spO2 ?? -1) Resp=\(respiratoryRate ?? -1) activity=\(actState)")

        // Check if scoring should be paused
        if activityState == .exercise {
            scoringPaused = true
            pauseReason = "Scoring paused during exercise"
            PPILog.engine.notice(" PAUSED: exercise detected")
            return currentScore // Return last valid score
        }
        if activityState == .postExercise {
            scoringPaused = true
            pauseReason = "Recovering from exercise"
            PPILog.engine.notice(" PAUSED: post-exercise cooldown")
            return currentScore
        }
        scoringPaused = false
        pauseReason = nil

        // Calculate individual metric scores
        let spO2Score = metricScore(for: .spO2, currentValue: spO2)
        let hrvScore = metricScore(for: .hrv, currentValue: hrv)
        let hrScore = metricScore(for: .heartRate, currentValue: heartRate)
        let respScore = metricScore(for: .respiratoryRate, currentValue: respiratoryRate)

        PPILog.engine.notice(" Metric scores: SpO2=\(spO2Score.map { String(format: "%.1f", $0) } ?? "nil") HRV=\(hrvScore.map { String(format: "%.1f", $0) } ?? "nil") HR=\(hrScore.map { String(format: "%.1f", $0) } ?? "nil") Resp=\(respScore.map { String(format: "%.1f", $0) } ?? "nil")")

        // Calculate deviations for display
        let spO2Dev = spO2.flatMap { baselineEngine.deviation(for: .spO2, currentValue: $0) }
        let hrvDev = hrv.flatMap { baselineEngine.deviation(for: .hrv, currentValue: $0) }
        let hrDev = heartRate.flatMap { baselineEngine.deviation(for: .heartRate, currentValue: $0) }
        let respDev = respiratoryRate.flatMap { baselineEngine.deviation(for: .respiratoryRate, currentValue: $0) }

        // Update components
        components = PPIComponents(
            spO2Score: spO2Score,
            hrvScore: hrvScore,
            hrScore: hrScore,
            respScore: respScore,
            spO2Deviation: spO2Dev,
            hrvDeviation: hrvDev,
            hrDeviation: hrDev,
            respDeviation: respDev
        )

        // Weighted sum with dynamic renormalization
        let metricScores: [(BiometricMetric, Double?)] = [
            (.spO2, spO2Score),
            (.hrv, hrvScore),
            (.heartRate, hrScore),
            (.respiratoryRate, respScore),
        ]

        var weightedSum = 0.0
        var totalWeight = 0.0
        var available = 0

        let activityMods = activityState.weightModifiers

        for (metric, score) in metricScores {
            guard let score = score,
                  let baseWeight = baseWeights[metric],
                  let activityMod = activityMods[metric] else { continue }

            let effectiveWeight = baseWeight * activityMod
            weightedSum += score * effectiveWeight
            totalWeight += effectiveWeight
            available += 1
        }

        availableMetrics = available

        // Need at least 1 metric to generate a score
        guard available >= 1, totalWeight > 0 else {
            PPILog.engine.notice(" No metrics available — returning 0")
            return 0
        }

        // Renormalize (distribute missing weight proportionally)
        var rawScore = weightedSum / totalWeight

        PPILog.engine.notice(" Weighted sum=\(String(format: "%.2f", weightedSum)) totalWeight=\(String(format: "%.2f", totalWeight)) rawScore=\(String(format: "%.2f", rawScore)) available=\(available)/4")

        // Apply vulnerability multiplier
        rawScore = min(100.0, rawScore * vulnerabilityProfile.multiplier)

        // Smooth to avoid jitter
        let smoothed = smoother.smooth(rawScore)

        // Clamp to 0-100
        let finalScore = max(0, min(100, Int(round(smoothed))))

        // Update state
        previousZone = currentZone
        currentScore = finalScore
        currentZone = PPIZone.from(score: finalScore)

        let zoneStr = self.currentZone.rawValue
        let vulnStr = String(format: "%.1fx", self.vulnerabilityProfile.multiplier)
        PPILog.engine.notice(">>> SCORE=\(finalScore) zone=\(zoneStr) raw=\(String(format: "%.1f", rawScore)) smoothed=\(String(format: "%.1f", smoothed)) vuln=\(vulnStr)")

        // Update baselines with current readings (skip during demo to keep baselines fixed)
        if !skipBaselineUpdate {
            if let hr = heartRate { baselineEngine.update(metric: .heartRate, value: hr) }
            if let h = hrv { baselineEngine.update(metric: .hrv, value: h) }
            if let s = spO2 { baselineEngine.update(metric: .spO2, value: s) }
            if let r = respiratoryRate { baselineEngine.update(metric: .respiratoryRate, value: r) }
        }

        return finalScore
    }

    // MARK: - Individual Metric Score (Rescaled Sigmoid)

    private func metricScore(for metric: BiometricMetric, currentValue: Double?) -> Double? {
        guard let value = currentValue else {
            PPILog.sigmoid.notice(" \(metric.rawValue): no value")
            return nil
        }

        guard let deviation = baselineEngine.deviation(for: metric, currentValue: value) else {
            PPILog.sigmoid.notice(" \(metric.rawValue): baseline not calibrated (value=\(String(format: "%.2f", value)))")
            return nil
        }

        let params = SigmoidParams.params(for: metric)

        // Clamp negative deviations (improvement) to 0
        let clampedDev = max(0, min(deviation, params.maxDeviation))

        // Sigmoid: 1 / (1 + exp(-steepness × (deviation - midpoint)))
        let rawSigmoid = 1.0 / (1.0 + exp(-params.steepness * (clampedDev - params.midpoint)))

        // Rescale so deviation=0 → score=0, deviation=max → score≈100
        let floor = 1.0 / (1.0 + exp(-params.steepness * (0 - params.midpoint)))
        let ceiling = 1.0 / (1.0 + exp(-params.steepness * (params.maxDeviation - params.midpoint)))

        let denominator = ceiling - floor
        guard denominator > 0.001 else { return 0 }

        let normalized = (rawSigmoid - floor) / denominator
        let result = max(0, min(100, normalized * 100.0))
        PPILog.sigmoid.notice(" \(metric.rawValue): deviation=\(String(format: "%.2f", deviation)) clamped=\(String(format: "%.2f", clampedDev)) -> score=\(String(format: "%.1f", result))")
        return result
    }

    // MARK: - Create Snapshot for Communication

    func createSnapshot() -> PPIScoreData {
        PPIScoreData(
            score: currentScore,
            zone: currentZone,
            components: components,
            activityState: activityState.rawValue,
            availableMetrics: availableMetrics,
            baselineCalibrated: baselineEngine.isCalibrated,
            timestamp: Date()
        )
    }

    // MARK: - Reset

    func reset() {
        smoother.reset()
        currentScore = 0
        currentZone = .green
        previousZone = .green
        scoringPaused = false
        pauseReason = nil
    }
}
