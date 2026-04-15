//
//  PPIDemoMode.swift
//  AirWayWatch Watch App
//
//  Demo mode that simulates realistic biometric data for testing
//  and hackathon presentations without requiring a physical Apple Watch.
//
//  Simulates a scenario: user walks from clean zone into polluted zone.
//  HR gradually rises, HRV drops, SpO2 decreases — PPI score climbs.
//

import Foundation
import Combine

class PPIDemoMode: ObservableObject {
    static let shared = PPIDemoMode()

    @Published var isActive = false
    @Published var demoPhase: DemoPhase = .clean
    @Published var elapsedSeconds: Int = 0

    // Simulated biometric values
    @Published var heartRate: Double = 68
    @Published var hrv: Double = 52
    @Published var spO2: Double = 98.2
    @Published var respiratoryRate: Double = 14.5

    // Simulated AQI
    @Published var aqi: Int = 35
    @Published var location: String = "TLALPAN"

    // Baselines (the "normal" values for this simulated user)
    let baselineHR: Double = 68
    let baselineHRV: Double = 52
    let baselineSpO2: Double = 98.2
    let baselineResp: Double = 14.5

    private var timer: Timer?
    private var demoTimer: Timer?

    enum DemoPhase: String {
        case clean = "Clean Zone"
        case transition = "Entering Polluted Zone"
        case polluted = "High Pollution Zone"
        case recovery = "Returning to Clean Air"

        var targetAQI: Int {
            switch self {
            case .clean: return 35
            case .transition: return 85
            case .polluted: return 145
            case .recovery: return 50
            }
        }
    }

    private init() {}

    // MARK: - Start Demo

    func startDemo(scenario: DemoScenario = .healthy) {
        isActive = true
        elapsedSeconds = 0
        demoPhase = .clean

        // Set initial baselines based on scenario
        applyScenario(scenario)

        // Reset to baseline
        heartRate = baselineHR
        hrv = baselineHRV
        spO2 = baselineSpO2
        respiratoryRate = baselineResp
        aqi = 35

        PPILog.demo.notice("=== STARTED scenario=\(scenario.label) ===")
        PPILog.demo.notice("Baselines: HR=\(self.baselineHR) HRV=\(self.baselineHRV) SpO2=\(self.baselineSpO2) Resp=\(self.baselineResp)")

        // Tick every 2 seconds (simulates 30-second real intervals)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopDemo() {
        isActive = false
        timer?.invalidate()
        timer = nil
        PPILog.demo.notice(" === STOPPED ===")
    }

    // MARK: - Demo Scenarios

    enum DemoScenario {
        case healthy     // Young healthy person
        case asthmatic   // Person with asthma (higher sensitivity)
        case elderly     // 65+ with CVD

        var label: String {
            switch self {
            case .healthy: return "Healthy Adult"
            case .asthmatic: return "Asthmatic"
            case .elderly: return "Elderly + CVD"
            }
        }
    }

    private func applyScenario(_ scenario: DemoScenario) {
        // Scenarios don't change baselines — they change how fast/strong
        // the biometrics deviate. The vulnerability profile multiplier
        // handles this in PPIScoreEngine.
        switch scenario {
        case .healthy:
            location = "TLALPAN"
        case .asthmatic:
            location = "TLALPAN"
        case .elderly:
            location = "CENTRO"
        }
    }

    // MARK: - Simulation Tick

    private func tick() {
        elapsedSeconds += 2

        let oldPhase = demoPhase

        // Phase transitions (simulated 4-minute journey)
        switch elapsedSeconds {
        case 0..<20:
            demoPhase = .clean
        case 20..<50:
            demoPhase = .transition
        case 50..<90:
            demoPhase = .polluted
        default:
            demoPhase = .recovery
            if elapsedSeconds > 120 {
                // Loop back
                elapsedSeconds = 0
            }
        }

        // Gradually change values based on phase
        let targetAQI = demoPhase.targetAQI
        aqi = aqi + (targetAQI > aqi ? 1 : -1) * Int.random(in: 1...3)
        aqi = max(20, min(180, aqi))

        // PM2.5 correlates with AQI
        let pm25 = Double(aqi) * 0.4

        // Biometric deviations based on pollution level
        // Using dose-response: ~0.01pp SpO2 drop per 1µg/m³ PM2.5
        let noise = Double.random(in: -0.3...0.3)

        switch demoPhase {
        case .clean:
            heartRate = baselineHR + noise * 2
            hrv = baselineHRV + noise * 3
            spO2 = baselineSpO2 + noise * 0.1
            respiratoryRate = baselineResp + noise * 0.3

        case .transition:
            heartRate = lerp(heartRate, baselineHR + 8 + noise, t: 0.20)
            hrv = lerp(hrv, baselineHRV - 15 + noise, t: 0.20)
            spO2 = lerp(spO2, baselineSpO2 - 1.5 + noise * 0.1, t: 0.15)
            respiratoryRate = lerp(respiratoryRate, baselineResp + 4 + noise * 0.2, t: 0.18)

        case .polluted:
            heartRate = lerp(heartRate, baselineHR + 18 + noise, t: 0.18)
            hrv = lerp(hrv, baselineHRV - 25 + noise, t: 0.18)
            spO2 = lerp(spO2, baselineSpO2 - 3.5 + noise * 0.1, t: 0.12)
            respiratoryRate = lerp(respiratoryRate, baselineResp + 7 + noise * 0.3, t: 0.15)

        case .recovery:
            heartRate = lerp(heartRate, baselineHR + 2 + noise, t: 0.12)
            hrv = lerp(hrv, baselineHRV - 3 + noise, t: 0.10)
            spO2 = lerp(spO2, baselineSpO2 - 0.2 + noise * 0.05, t: 0.08)
            respiratoryRate = lerp(respiratoryRate, baselineResp + 0.5 + noise * 0.1, t: 0.10)
        }

        // Clamp values to realistic ranges
        heartRate = max(55, min(120, heartRate))
        hrv = max(15, min(80, hrv))
        spO2 = max(92, min(100, spO2))
        respiratoryRate = max(10, min(28, respiratoryRate))

        if oldPhase != demoPhase {
            PPILog.demo.notice("Phase changed: \(oldPhase.rawValue) -> \(self.demoPhase.rawValue)")
        }
        PPILog.demo.notice("t=\(self.elapsedSeconds)s phase=\(self.demoPhase.rawValue) AQI=\(self.aqi) HR=\(String(format: "%.1f", self.heartRate)) HRV=\(String(format: "%.1f", self.hrv)) SpO2=\(String(format: "%.2f", self.spO2)) Resp=\(String(format: "%.1f", self.respiratoryRate))")
    }

    private func lerp(_ current: Double, _ target: Double, t: Double) -> Double {
        current + (target - current) * t
    }
}
