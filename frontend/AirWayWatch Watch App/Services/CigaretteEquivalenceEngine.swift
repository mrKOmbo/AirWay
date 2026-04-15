//
//  CigaretteEquivalenceEngine.swift
//  AirWayWatch Watch App
//
//  "Cigarette Equivalence" — real-time cumulative PM2.5 dose converted
//  to equivalent cigarettes smoked, adjusted for physical activity.
//
//  Science:
//    Berkeley Earth (Muller 2015): 22 µg/m³ PM2.5 over 24h ≈ 1 cigarette
//    This is a MORTALITY equivalence, not mass-based.
//
//  Our formula (activity-adjusted — unique, no other app does this):
//    Deposited Dose = Σ (PM2.5 × VR × DF × Δt × AgeFactor)
//    Cigarettes     = Deposited Dose / Reference Dose
//    Reference Dose = 22 × 0.5 × 24 × 0.30 = 79.2 µg
//
//  VR (Ventilation Rate) from EPA Exposure Factors Handbook Ch.6:
//    Rest=0.5, Light=1.0, Moderate=2.5, Heavy=4.5 m³/h
//
//  DF (Deposition Fraction) from ICRP 66 + MPPD model:
//    Rest=0.30, Light=0.35, Moderate=0.45, Heavy=0.55
//
//  When Apple Watch provides respiratory rate, VR is refined:
//    VE (L/min) = RR × TV(estimated)
//

import Foundation
import Combine

// MARK: - Cigarette Equivalence Engine

class CigaretteEquivalenceEngine: ObservableObject {

    // MARK: - Scientific Constants

    /// Berkeley Earth: 22 µg/m³ PM2.5 averaged over 24h = 1 cigarette (mortality basis)
    static let pm25PerCigaretteDay: Double = 22.0

    /// Reference deposited dose per cigarette-equivalent day (µg)
    /// = 22 µg/m³ × 0.5 m³/h × 24 h × 0.30 DF
    static let referenceDosePerCigarette: Double = 79.2

    /// Ventilation rates by activity state (m³/h) — EPA EFH Ch.6
    private static let ventilationRates: [ActivityState: Double] = [
        .resting:       0.50,
        .lightActivity: 1.00,
        .exercise:      2.50,
        .postExercise:  0.80,
    ]

    /// Deposition fractions by activity — ICRP 66 / MPPD model
    private static let depositionFractions: [ActivityState: Double] = [
        .resting:       0.30,
        .lightActivity: 0.35,
        .exercise:      0.45,
        .postExercise:  0.33,
    ]

    // MARK: - Published State

    @Published var cigarettesToday: Double = 0
    @Published var currentRatePerHour: Double = 0
    @Published var cumulativeDoseUg: Double = 0
    @Published var hourlyDoses: [HourlyDose] = (0..<24).map { HourlyDose(hour: $0, doseUg: 0) }
    @Published var peakHour: Int?
    @Published var activityBreakdown = ActivityDoseBreakdown()

    // MARK: - Persistence Keys

    private let defaults = UserDefaults(suiteName: "group.com.airway.shared") ?? .standard
    private static let kDose       = "cig_cumulative_dose"
    private static let kDate       = "cig_tracking_date"
    private static let kCount      = "cig_count_today"
    private static let kRate       = "cig_rate_per_hour"
    private static let kHourly     = "cig_hourly_doses"
    private static let kBreakdown  = "cig_activity_breakdown"

    // MARK: - Internal State

    private var lastAccumulationTime: Date?
    private var trackingDate: String = ""

    // MARK: - Init

    init() {
        loadPersistedState()
    }

    // MARK: - Core: Accumulate Dose

    /// Call every PPI tick (2s demo / 30s real).
    /// Returns updated cigarette count for the day.
    @discardableResult
    func accumulateDose(
        pm25: Double,
        activityState: ActivityState,
        respiratoryRate: Double? = nil,
        vulnerabilityProfile: VulnerabilityProfile? = nil
    ) -> Double {
        let now = Date()
        checkDayRollover(now)

        // Calculate Δt in hours
        var deltaHours: Double = 0
        if let lastTime = lastAccumulationTime {
            let raw = now.timeIntervalSince(lastTime) / 3600.0
            deltaHours = min(raw, 1.0) // Clamp — avoid huge jumps from app suspension
            if raw > 1.0 {
                PPILog.cigarette.notice("Large time gap \(String(format: "%.1f", raw))h — clamped to 1h")
            }
        }
        lastAccumulationTime = now

        // Always update instantaneous rate (even on first tick)
        updateCurrentRate(
            pm25: pm25, activityState: activityState,
            respiratoryRate: respiratoryRate,
            vulnerabilityProfile: vulnerabilityProfile
        )

        guard deltaHours > 0, pm25 > 0 else {
            return cigarettesToday
        }

        // --- Dose calculation ---
        let vr   = ventilationRate(for: activityState, respiratoryRate: respiratoryRate)
        let df   = depositionFraction(for: activityState)
        let vuln = ageMultiplier(for: vulnerabilityProfile)

        let doseDelta = pm25 * vr * df * deltaHours * vuln

        cumulativeDoseUg += doseDelta
        cigarettesToday = cumulativeDoseUg / Self.referenceDosePerCigarette

        // Track hourly + activity breakdown
        let hour = Calendar.current.component(.hour, from: now)
        updateHourlyDose(hour: hour, doseDelta: doseDelta)
        updateActivityBreakdown(state: activityState, doseDelta: doseDelta)
        updatePeakHour()
        persistState()

        let actStr = activityState.rawValue
        PPILog.cigarette.notice("dose+=\(String(format: "%.3f", doseDelta))ug cum=\(String(format: "%.1f", self.cumulativeDoseUg))ug cigs=\(String(format: "%.2f", self.cigarettesToday)) PM2.5=\(String(format: "%.1f", pm25)) VR=\(String(format: "%.2f", vr)) DF=\(String(format: "%.2f", df)) dt=\(String(format: "%.4f", deltaHours))h act=\(actStr)")

        return cigarettesToday
    }

    // MARK: - Ventilation Rate Estimation

    /// Uses real respiratory rate from Watch when available; falls back to activity table.
    private func ventilationRate(for activity: ActivityState, respiratoryRate: Double?) -> Double {
        if let rr = respiratoryRate, rr > 0 {
            // Estimate tidal volume from respiratory rate (physiological heuristic)
            let tv: Double // liters
            switch rr {
            case ..<14:  tv = 0.45  // deep rest / sleep
            case 14..<18: tv = 0.50  // normal rest
            case 18..<22: tv = 0.75  // light activity
            case 22..<30: tv = 1.20  // moderate
            default:      tv = 2.00  // heavy exercise
            }

            let veLpm = rr * tv                   // L/min
            let vrM3h = veLpm * 60.0 / 1000.0     // m³/h

            PPILog.cigarette.notice("  VR from RR: rr=\(String(format: "%.1f", rr)) TV=\(String(format: "%.2f", tv))L VE=\(String(format: "%.1f", veLpm))L/min -> \(String(format: "%.3f", vrM3h))m3/h")
            return max(0.2, min(5.0, vrM3h))
        }

        return Self.ventilationRates[activity] ?? 0.5
    }

    /// Deposition fraction by activity — nose vs mouth breathing
    private func depositionFraction(for activity: ActivityState) -> Double {
        Self.depositionFractions[activity] ?? 0.30
    }

    /// Children: ×1.6 (higher metabolic rate per kg, developing lungs)
    /// Elderly: ×1.3 (reduced mucociliary clearance)
    private func ageMultiplier(for profile: VulnerabilityProfile?) -> Double {
        guard let p = profile else { return 1.0 }
        if p.isChild { return 1.6 }
        if p.isElderly { return 1.3 }
        return 1.0
    }

    // MARK: - Instantaneous Rate

    private func updateCurrentRate(pm25: Double, activityState: ActivityState,
                                   respiratoryRate: Double?,
                                   vulnerabilityProfile: VulnerabilityProfile?) {
        let vr   = ventilationRate(for: activityState, respiratoryRate: respiratoryRate)
        let df   = depositionFraction(for: activityState)
        let vuln = ageMultiplier(for: vulnerabilityProfile)
        let dosePerHour = pm25 * vr * df * vuln
        currentRatePerHour = dosePerHour / Self.referenceDosePerCigarette
    }

    // MARK: - Hourly Tracking

    private func updateHourlyDose(hour: Int, doseDelta: Double) {
        guard hour >= 0, hour < 24, hour < hourlyDoses.count else { return }
        hourlyDoses[hour] = HourlyDose(
            hour: hour,
            doseUg: hourlyDoses[hour].doseUg + doseDelta
        )
    }

    private func updatePeakHour() {
        peakHour = hourlyDoses.max(by: { $0.doseUg < $1.doseUg })?.hour
    }

    // MARK: - Activity Breakdown

    private func updateActivityBreakdown(state: ActivityState, doseDelta: Double) {
        switch state {
        case .resting:       activityBreakdown.restingDose += doseDelta
        case .lightActivity: activityBreakdown.lightActivityDose += doseDelta
        case .exercise:      activityBreakdown.exerciseDose += doseDelta
        case .postExercise:  activityBreakdown.postExerciseDose += doseDelta
        }
    }

    // MARK: - Day Rollover

    private func checkDayRollover(_ now: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: now)

        if todayStr != trackingDate {
            PPILog.cigarette.notice("Day rollover: \(self.trackingDate) -> \(todayStr)")
            resetDaily()
            trackingDate = todayStr
        }
    }

    // MARK: - Reset

    func resetDaily() {
        cumulativeDoseUg = 0
        cigarettesToday = 0
        currentRatePerHour = 0
        hourlyDoses = (0..<24).map { HourlyDose(hour: $0, doseUg: 0) }
        activityBreakdown = ActivityDoseBreakdown()
        peakHour = nil
        persistState()
    }

    // MARK: - Persistence

    private func persistState() {
        defaults.set(cumulativeDoseUg, forKey: Self.kDose)
        defaults.set(trackingDate, forKey: Self.kDate)
        defaults.set(cigarettesToday, forKey: Self.kCount)
        defaults.set(currentRatePerHour, forKey: Self.kRate)

        if let data = try? JSONEncoder().encode(hourlyDoses) {
            defaults.set(data, forKey: Self.kHourly)
        }
        if let data = try? JSONEncoder().encode(activityBreakdown) {
            defaults.set(data, forKey: Self.kBreakdown)
        }
    }

    private func loadPersistedState() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        trackingDate = defaults.string(forKey: Self.kDate) ?? todayStr

        if trackingDate != todayStr {
            trackingDate = todayStr
            resetDaily()
            return
        }

        cumulativeDoseUg = defaults.double(forKey: Self.kDose)
        cigarettesToday = defaults.double(forKey: Self.kCount)
        currentRatePerHour = defaults.double(forKey: Self.kRate)

        if let data = defaults.data(forKey: Self.kHourly),
           let decoded = try? JSONDecoder().decode([HourlyDose].self, from: data) {
            hourlyDoses = decoded
        }
        if let data = defaults.data(forKey: Self.kBreakdown),
           let decoded = try? JSONDecoder().decode(ActivityDoseBreakdown.self, from: data) {
            activityBreakdown = decoded
        }

        PPILog.cigarette.notice("Loaded: cigs=\(String(format: "%.2f", self.cigarettesToday)) dose=\(String(format: "%.1f", self.cumulativeDoseUg))ug date=\(self.trackingDate)")
    }

    // MARK: - Snapshot for WatchConnectivity

    func createSnapshot() -> CigaretteData {
        CigaretteData(
            cigarettesToday: cigarettesToday,
            currentRatePerHour: currentRatePerHour,
            cumulativeDoseUg: cumulativeDoseUg,
            peakHour: peakHour,
            activityBreakdown: activityBreakdown,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Data Types

struct HourlyDose: Codable, Identifiable {
    let hour: Int
    var doseUg: Double

    var id: Int { hour }

    var cigarettes: Double {
        doseUg / CigaretteEquivalenceEngine.referenceDosePerCigarette
    }

    var hourLabel: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "am" : "pm"
        return "\(h)\(ampm)"
    }
}

struct ActivityDoseBreakdown: Codable {
    var restingDose: Double = 0
    var lightActivityDose: Double = 0
    var exerciseDose: Double = 0
    var postExerciseDose: Double = 0

    var totalDose: Double {
        restingDose + lightActivityDose + exerciseDose + postExerciseDose
    }

    func cigarettes(_ dose: Double) -> Double {
        dose / CigaretteEquivalenceEngine.referenceDosePerCigarette
    }

    /// Percentage of total dose from exercise (shows impact of activity)
    var exercisePercentage: Double {
        guard totalDose > 0 else { return 0 }
        return (exerciseDose + lightActivityDose) / totalDose * 100.0
    }
}

/// Data transferred Watch → iPhone via WatchConnectivity
struct CigaretteData: Codable {
    let cigarettesToday: Double
    let currentRatePerHour: Double
    let cumulativeDoseUg: Double
    let peakHour: Int?
    let activityBreakdown: ActivityDoseBreakdown
    let timestamp: Date
}
