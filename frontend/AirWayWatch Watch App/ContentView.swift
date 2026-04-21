//
//  ContentView.swift
//  AirWayWatch Watch App
//
//  Main watch interface with PPI Score as the hero element.
//  Shows personal pollution impact, AQI data, and navigation to detail views.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var biometricReader = BiometricReader()
    @StateObject private var baselineEngine = BaselineEngine()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    // Lazy-initialized after baselineEngine is ready
    @State private var ppiEngine: PPIScoreEngine?
    @State private var workoutManager: WorkoutManager?

    // MARK: - AQI Data (from iPhone)
    @State private var currentAQI: Int = 0
    @State private var currentLocation: String = "—"
    @State private var currentQualityLevel: String = "—"
    @State private var pm25: Double = 0
    @State private var pm10: Double = 0

    // MARK: - PPI State
    @State private var ppiScore: Int = 0
    @State private var ppiZone: PPIZone = .green
    @State private var isMonitoring = false

    // Timer for periodic PPI recalculation
    @State private var ppiTimer: Timer?

    // Cigarette equivalence engine
    @StateObject private var cigaretteEngine = CigaretteEquivalenceEngine()

    // Demo mode
    @StateObject private var demoMode = PPIDemoMode.shared
    @State private var isDemoActive = false

    var body: some View {
        CompatibleNavigation {
            ScrollView {
                VStack(spacing: 14) {
                    // Location header
                    Text(currentLocation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .textCase(.uppercase)

                    // PPI Score Gauge — HERO ELEMENT
                    NavigationLink(destination: ppiDetailView) {
                        PPIScoreView(
                            score: ppiScore,
                            zone: ppiZone,
                            isCalibrating: !baselineEngine.isCalibrated,
                            scoringPaused: ppiEngine?.scoringPaused ?? false,
                            pauseReason: ppiEngine?.pauseReason,
                            availableMetrics: ppiEngine?.availableMetrics ?? 0
                        )
                    }
                    .buttonStyle(.plain)

                    // AQI Display (secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "aqi.medium")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))

                        Text("AQI: \(currentAQI)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text(currentQualityLevel)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )

                    // PM Indicators
                    VStack(spacing: 6) {
                        PMRow(label: "PM2.5", value: pm25)
                        PMRow(label: "PM10", value: pm10)
                    }

                    // Cigarette Equivalence Badge
                    if cigaretteEngine.cigarettesToday > 0 || isMonitoring || isDemoActive {
                        NavigationLink(destination: ExposureView(cigaretteEngine: cigaretteEngine)) {
                            CigaretteBadgeView(
                                cigarettes: cigaretteEngine.cigarettesToday,
                                ratePerHour: cigaretteEngine.currentRatePerHour
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Heart Rate live indicator (if monitoring)
                    if let hr = biometricReader.heartRate {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.red)

                            Text(String(format: "%.0f bpm", hr))
                                .font(.caption.bold())
                                .foregroundColor(.white)

                            Spacer()

                            if let baseline = baselineEngine.currentBaseline(for: .heartRate)?.value {
                                let diff = hr - baseline
                                Text(String(format: "%+.0f", diff))
                                    .font(.caption2.bold())
                                    .foregroundColor(diff > 5 ? Color(hex: "#FF9F0A") : .white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                    }

                    // Quick actions
                    VStack(spacing: 6) {
                        // Start/Stop monitoring button
                        Button(action: toggleMonitoring) {
                            HStack {
                                Image(systemName: isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.caption)
                                Text(isMonitoring ? "Stop Monitoring" : "Start PPI Monitor")
                                    .font(.caption)
                            }
                            .foregroundColor(isMonitoring ? .orange : .green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill((isMonitoring ? Color.orange : Color.green).opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)

                        // Demo Mode Button (for testing/presentation)
                        Button(action: toggleDemo) {
                            HStack {
                                Image(systemName: isDemoActive ? "stop.fill" : "play.fill")
                                    .font(.caption)
                                Text(isDemoActive ? "Stop Demo" : "Demo Mode")
                                    .font(.caption)
                            }
                            .foregroundColor(isDemoActive ? .red : .cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill((isDemoActive ? Color.red : Color.cyan).opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)

                        // Demo phase indicator
                        if isDemoActive {
                            Text(demoMode.demoPhase.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cyan.opacity(0.8))
                                .padding(.vertical, 2)
                        }

                        NavigationLink(destination: ExposureView(cigaretteEngine: cigaretteEngine)) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text("Today's Exposure")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: RouteMapView()) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.caption)
                                Text("Route Map")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .airWayBackground()
        }
        .onAppear {
            setupPPI()
            healthKitManager.requestAuthorization()
        }
        .onDisappear {
            ppiTimer?.invalidate()
        }
        .onReceive(connectivityManager.$lastAQIUpdate) { aqiData in
            guard let data = aqiData else { return }
            currentAQI = data.aqi
            currentLocation = data.location
            currentQualityLevel = data.qualityLevel
            pm25 = data.pm25
            pm10 = data.pm10
        }
    }

    // MARK: - PPI Detail Destination

    private var ppiDetailView: some View {
        PPIDetailView(
            score: ppiScore,
            zone: ppiZone,
            components: ppiEngine?.components ?? PPIComponents(
                spO2Score: nil, hrvScore: nil, hrScore: nil, respScore: nil,
                spO2Deviation: nil, hrvDeviation: nil, hrDeviation: nil, respDeviation: nil
            ),
            heartRate: biometricReader.heartRate,
            hrv: biometricReader.hrv,
            spO2: biometricReader.spO2,
            respiratoryRate: biometricReader.respiratoryRate,
            heartRateBaseline: baselineEngine.currentBaseline(for: .heartRate)?.value,
            hrvBaseline: baselineEngine.currentBaseline(for: .hrv)?.value,
            spO2Baseline: baselineEngine.currentBaseline(for: .spO2)?.value,
            respBaseline: baselineEngine.currentBaseline(for: .respiratoryRate)?.value,
            activityState: ppiEngine?.activityState ?? .resting,
            isCalibrated: baselineEngine.isCalibrated,
            aqi: currentAQI > 0 ? currentAQI : nil
        )
    }

    // MARK: - Setup

    private func setupPPI() {
        PPILog.content.notice(" setupPPI() — creating engine and workout manager")
        let engine = PPIScoreEngine(baselineEngine: baselineEngine)
        ppiEngine = engine

        let wm = WorkoutManager(biometricReader: biometricReader)
        workoutManager = wm

        // Bootstrap baselines from HealthKit history
        baselineEngine.bootstrapFromHealthKit(healthStore: HealthKitManager.shared.healthStore) { success in
            PPILog.content.notice(" HealthKit bootstrap complete: \(success) calibrated=\(self.baselineEngine.isCalibrated)")
        }
    }

    // MARK: - Monitoring Toggle

    private func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        isMonitoring = true
        workoutManager?.startMonitoring()
        biometricReader.startMonitoring()

        // Recalculate PPI every 30 seconds
        ppiTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            recalculatePPI()
        }
        // Initial calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            recalculatePPI()
        }
    }

    private func stopMonitoring() {
        isMonitoring = false
        workoutManager?.stopMonitoring()
        biometricReader.stopMonitoring()
        ppiTimer?.invalidate()
        ppiTimer = nil
    }

    private func recalculatePPI() {
        guard let engine = ppiEngine else {
            PPILog.content.notice(" recalculatePPI: engine is nil!")
            return
        }

        let oldZone = engine.currentZone

        // Use demo data if demo is active, otherwise use real biometrics
        let hr: Double?
        let hrvVal: Double?
        let spo2Val: Double?
        let respVal: Double?

        if isDemoActive {
            hr = demoMode.heartRate
            hrvVal = demoMode.hrv
            spo2Val = demoMode.spO2
            respVal = demoMode.respiratoryRate
            currentAQI = demoMode.aqi
            currentLocation = demoMode.location
            currentQualityLevel = demoMode.aqi <= 50 ? "Good" : demoMode.aqi <= 100 ? "Moderate" : "Unhealthy"
            pm25 = Double(demoMode.aqi) * 0.4
            pm10 = Double(demoMode.aqi) * 0.6

            PPILog.content.notice(" DEMO feed: HR=\(String(format: "%.1f", hr!)) HRV=\(String(format: "%.1f", hrvVal!)) SpO2=\(String(format: "%.2f", spo2Val!)) Resp=\(String(format: "%.1f", respVal!)) AQI=\(currentAQI)")

            // Feed demo baselines on first tick, then lock them
            if engine.availableMetrics == 0 {
                PPILog.content.notice("Seeding baselines for demo...")
                for _ in 0..<6 {
                    baselineEngine.update(metric: .heartRate, value: demoMode.baselineHR)
                    baselineEngine.update(metric: .hrv, value: demoMode.baselineHRV)
                    baselineEngine.update(metric: .spO2, value: demoMode.baselineSpO2)
                    baselineEngine.update(metric: .respiratoryRate, value: demoMode.baselineResp)
                }
                // LOCK baselines so demo deviations don't corrupt them
                engine.skipBaselineUpdate = true
                let cal = baselineEngine.isCalibrated
                PPILog.content.notice("Baselines seeded & locked. Calibrated=\(cal)")
            }

            // Update biometric reader display values
            biometricReader.updateHeartRateFromWorkout(demoMode.heartRate)
        } else {
            hr = biometricReader.heartRate
            hrvVal = biometricReader.hrv
            spo2Val = biometricReader.spO2
            respVal = biometricReader.respiratoryRate
            PPILog.content.notice(" REAL biometrics: HR=\(hr ?? -1) HRV=\(hrvVal ?? -1) SpO2=\(spo2Val ?? -1) Resp=\(respVal ?? -1)")
        }

        let score = engine.calculate(
            heartRate: hr,
            hrv: hrvVal,
            spO2: spo2Val,
            respiratoryRate: respVal
        )

        ppiScore = score
        ppiZone = engine.currentZone

        PPILog.content.notice(" >>> PPI SCORE=\(score) zone=\(ppiZone.rawValue) (was \(oldZone.rawValue))")

        // Haptic feedback on zone change
        if oldZone != engine.currentZone {
            PPILog.content.notice(" ZONE CHANGE: \(oldZone.rawValue) -> \(engine.currentZone.rawValue) — triggering haptic")
        }
        PPIHapticManager.shared.checkZoneTransition(from: oldZone, to: engine.currentZone)

        // Accumulate cigarette dose
        if pm25 > 0 {
            let activityState = engine.activityState
            let respRate = isDemoActive ? respVal : biometricReader.respiratoryRate
            let vulnProfile = connectivityManager.vulnerabilityProfile

            cigaretteEngine.accumulateDose(
                pm25: pm25,
                activityState: activityState,
                respiratoryRate: respRate,
                vulnerabilityProfile: vulnProfile
            )

            // Save to shared defaults for complication
            CigaretteComplicationStore.update(
                cigarettes: cigaretteEngine.cigarettesToday,
                ratePerHour: cigaretteEngine.currentRatePerHour,
                pm25: pm25
            )
        }

        // Send to iPhone
        let snapshot = engine.createSnapshot()
        connectivityManager.sendPPIScore(snapshot)

        let cigSnapshot = cigaretteEngine.createSnapshot()
        connectivityManager.sendCigaretteData(cigSnapshot)
    }

    // MARK: - Demo Mode

    private func toggleDemo() {
        if isDemoActive {
            stopDemo()
        } else {
            startDemoMode()
        }
    }

    private func startDemoMode() {
        PPILog.content.notice("====== STARTING DEMO MODE ======")
        isDemoActive = true
        demoMode.startDemo(scenario: .healthy)

        // Reset baselines, PPI, and cigarette dose for demo
        baselineEngine.resetAllBaselines()
        ppiEngine?.reset()
        cigaretteEngine.resetDaily()

        // Start PPI timer if not already running
        if ppiTimer == nil {
            setupPPI()
            PPILog.content.notice(" PPI timer started (every 2s)")
            ppiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                recalculatePPI()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                PPILog.content.notice(" First PPI calculation triggered")
                recalculatePPI()
            }
        }
    }

    private func stopDemo() {
        PPILog.content.notice("====== STOPPING DEMO MODE ======")
        isDemoActive = false
        demoMode.stopDemo()
        ppiEngine?.skipBaselineUpdate = false
        ppiTimer?.invalidate()
        ppiTimer = nil
        ppiScore = 0
        ppiZone = .green
    }
}

// MARK: - Supporting Views

struct PMRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(String(format: "%.1f \u{00B5}g/m\u{00B3}", value))
                .font(.caption).bold()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct WeatherItem: View {
    let icon: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.caption2).bold()
                .foregroundColor(.white)
        }
    }
}

struct CompatibleNavigation<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(watchOS 9.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
        }
    }
}

#Preview {
    ContentView()
}
