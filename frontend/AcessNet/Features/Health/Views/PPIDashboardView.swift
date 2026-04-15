//
//  PPIDashboardView.swift
//  AcessNet
//
//  Main PPI dashboard on iPhone. Shows the current PPI Score received from Watch,
//  biometric breakdown, AQI correlation, and vulnerability profile.
//

import SwiftUI

struct PPIDashboardView: View {
    @ObservedObject var connectivityManager = PhoneConnectivityManager.shared

    // Local state
    @State private var showingVulnerabilityProfile = false

    private var ppiScore: PPIScoreData? {
        connectivityManager.latestPPIScore
    }

    private var biometrics: BiometricUpdateData? {
        connectivityManager.latestBiometrics
    }

    private var profile: VulnerabilityProfile {
        guard let data = UserDefaults.standard.data(forKey: "vulnerability_profile_data"),
              let decoded = try? JSONDecoder().decode(VulnerabilityProfile.self, from: data) else {
            return VulnerabilityProfile()
        }
        return decoded
    }

    private func saveProfile(_ profile: VulnerabilityProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "vulnerability_profile_data")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                VStack(spacing: 4) {
                    Text("PERSONAL POLLUTION IMPACT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)

                    Text("PPI Score")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)

                // MARK: - Hero Score Card
                heroScoreCard

                // MARK: - Cigarette Equivalence Card
                if let cigData = connectivityManager.latestCigaretteData {
                    cigaretteEquivalenceCard(cigData)
                }

                // MARK: - Watch Connection Status
                if !connectivityManager.isWatchConnected {
                    watchConnectionBanner
                }

                // MARK: - Biometric Breakdown
                if let bio = biometrics {
                    biometricBreakdownCard(bio)
                }

                // MARK: - Component Scores
                if let ppi = ppiScore {
                    componentScoresCard(ppi)
                }

                // MARK: - Vulnerability Profile
                vulnerabilityCard

                // MARK: - How It Works
                howItWorksCard

                // MARK: - Disclaimer
                Text("This score is for informational wellness purposes only. It does not constitute medical advice. If you experience breathing difficulty or chest pain, contact a healthcare professional.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
            }
            .padding(.horizontal)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#0A1D4D"), Color(hex: "#132D5E"), Color(hex: "#1A3A6E")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .sheet(isPresented: $showingVulnerabilityProfile) {
            VulnerabilityProfileView(
                profile: profile,
                onSave: { newProfile in
                    saveProfile(newProfile)
                    PhoneConnectivityManager.shared.sendVulnerabilityProfile(newProfile)
                }
            )
        }
    }

    // MARK: - Hero Score Card

    private var heroScoreCard: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 180, height: 180)

                // Colored arc
                Circle()
                    .trim(from: 0, to: CGFloat(Double(ppiScore?.score ?? 0) / 100.0) * 0.75)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#4CD964"),
                                Color(hex: "#FFD60A"),
                                Color(hex: "#FF9F0A"),
                                Color(hex: "#FF3B30"),
                            ]),
                            center: .center,
                            startAngle: .degrees(-225),
                            endAngle: .degrees(45)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .frame(width: 180, height: 180)

                // Center content
                VStack(spacing: 2) {
                    if let ppi = ppiScore {
                        Text("\(ppi.score)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(zoneColor(for: PPIZone.from(score: ppi.score)))

                        Text("PPI")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(3)

                        Text(PPIZone.from(score: ppi.score).labelES)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(zoneColor(for: PPIZone.from(score: ppi.score)))
                    } else {
                        Image(systemName: "applewatch")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Waiting for Watch")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            // Activity state
            if let ppi = ppiScore {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ppi.baselineCalibrated ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text(ppi.baselineCalibrated ? "Baseline calibrated" : "Calibrating baseline...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    Text("\(ppi.availableMetrics)/4 metrics")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Cigarette Equivalence Card

    private func cigaretteEquivalenceCard(_ data: CigaretteData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CIGARETTE EQUIVALENCE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)

                Spacer()

                Text("Berkeley Earth")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Hero number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\u{1F6AC}")
                    .font(.system(size: 24))

                Text(String(format: "%.1f", data.cigarettesToday))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(cigColor(data.cigarettesToday))

                VStack(alignment: .leading, spacing: 2) {
                    Text("cigarettes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("today")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Rate and dose
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Rate")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%.2f cigs/hr", data.currentRatePerHour))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Deposited Dose")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%.1f \u{00B5}g", data.cumulativeDoseUg))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            // Activity impact
            if data.activityBreakdown.exercisePercentage > 5 {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(String(format: "%.0f%% of dose during physical activity", data.activityBreakdown.exercisePercentage))
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }

            // WHO/EPA context bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    contextDot(color: .green, label: "WHO: 0.23")
                    contextDot(color: .yellow, label: "EPA: 1.59")
                    contextDot(color: cigColor(data.cigarettesToday),
                               label: String(format: "You: %.1f", data.cigarettesToday))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        // WHO marker
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: cigMarkerOffset(0.23, max: 8.0, width: geo.size.width))

                        // EPA marker
                        Circle()
                            .fill(.yellow)
                            .frame(width: 8, height: 8)
                            .offset(x: cigMarkerOffset(1.59, max: 8.0, width: geo.size.width))

                        // User marker
                        Circle()
                            .fill(cigColor(data.cigarettesToday))
                            .frame(width: 10, height: 10)
                            .offset(x: cigMarkerOffset(data.cigarettesToday, max: 8.0, width: geo.size.width))
                    }
                }
                .frame(height: 12)
            }

            // Disclaimer
            Text("Based on Berkeley Earth mortality equivalence (Muller 2015). Activity-adjusted for your ventilation rate. For awareness, not diagnosis.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cigColor(data.cigarettesToday).opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cigColor(data.cigarettesToday).opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func contextDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func cigColor(_ cigs: Double) -> Color {
        switch cigs {
        case ..<1:  return Color(hex: "#4CD964")
        case 1..<3: return Color(hex: "#FFD60A")
        case 3..<5: return Color(hex: "#FF9F0A")
        default:    return Color(hex: "#FF3B30")
        }
    }

    private func cigMarkerOffset(_ value: Double, max maxVal: Double, width: CGFloat) -> CGFloat {
        let clamped = min(value, maxVal)
        return CGFloat(clamped / maxVal) * (width - 10)
    }

    // MARK: - Watch Connection Banner

    private var watchConnectionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch.slash")
                .font(.caption)
                .foregroundColor(.orange)
            Text("Apple Watch not connected. PPI requires Watch for biometric data.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Biometric Breakdown

    private func biometricBreakdownCard(_ bio: BiometricUpdateData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BIOMETRICS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                bioMetricTile(
                    icon: "heart.fill",
                    label: "Heart Rate",
                    value: bio.heartRate.map { String(format: "%.0f", $0) },
                    unit: "bpm",
                    date: bio.heartRateDate,
                    color: .red
                )

                bioMetricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: bio.hrv.map { String(format: "%.0f", $0) },
                    unit: "ms",
                    date: bio.hrvDate,
                    color: .purple
                )

                bioMetricTile(
                    icon: "lungs.fill",
                    label: "SpO2",
                    value: bio.spO2.map { String(format: "%.1f", $0) },
                    unit: "%",
                    date: bio.spO2Date,
                    color: .blue
                )

                bioMetricTile(
                    icon: "wind",
                    label: "Resp Rate",
                    value: bio.respiratoryRate.map { String(format: "%.0f", $0) },
                    unit: "brpm",
                    date: bio.respiratoryRateDate,
                    color: .cyan
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func bioMetricTile(icon: String, label: String, value: String?,
                               unit: String, date: Date?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            if let v = value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(v)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.2))
            }

            if let d = date {
                Text(timeAgo(d))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Component Scores

    private func componentScoresCard(_ ppi: PPIScoreData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPONENT SCORES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            componentRow(label: "SpO2", score: ppi.components.spO2Score,
                         deviation: ppi.components.spO2Deviation, weight: "35%",
                         deviationFormat: "%.1f pp drop", icon: "lungs.fill")
            componentRow(label: "HRV", score: ppi.components.hrvScore,
                         deviation: ppi.components.hrvDeviation, weight: "30%",
                         deviationFormat: "%.1f%% decrease", icon: "waveform.path.ecg")
            componentRow(label: "Heart Rate", score: ppi.components.hrScore,
                         deviation: ppi.components.hrDeviation, weight: "20%",
                         deviationFormat: "%+.0f bpm", icon: "heart.fill")
            componentRow(label: "Resp Rate", score: ppi.components.respScore,
                         deviation: ppi.components.respDeviation, weight: "15%",
                         deviationFormat: "%+.1f%%", icon: "wind")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func componentRow(label: String, score: Double?, deviation: Double?,
                              weight: String, deviationFormat: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(scoreColor(score))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("(\(weight))")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                }
                if let dev = deviation {
                    Text(String(format: deviationFormat, dev))
                        .font(.system(size: 10))
                        .foregroundColor(scoreColor(score).opacity(0.8))
                }
            }

            Spacer()

            if let s = score {
                Text(String(format: "%.0f", s))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor(score))
            } else {
                Text("—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Vulnerability Profile Card

    private var vulnerabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VULNERABILITY PROFILE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)

                Spacer()

                Button(action: { showingVulnerabilityProfile = true }) {
                    Text("Edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#4AA1B3"))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sensitivity Multiplier")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.1fx", profile.multiplier))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(profile.multiplier > 1.5 ? .orange : .white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Risk Factors")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    if profile.riskFactors.isEmpty {
                        Text("None configured")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        Text(profile.riskFactors.joined(separator: ", "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }

            Text("People with respiratory or cardiovascular conditions are more sensitive to air pollution. The multiplier adjusts your PPI Score accordingly.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW PPI WORKS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 8) {
                formulaRow(emoji: "1.", text: "Learns your personal biometric baseline over 7 days")
                formulaRow(emoji: "2.", text: "Measures real-time deviations via Apple Watch sensors")
                formulaRow(emoji: "3.", text: "Weights: SpO2 (35%) + HRV (30%) + HR (20%) + Resp (15%)")
                formulaRow(emoji: "4.", text: "Adjusts for your vulnerability profile and activity state")
                formulaRow(emoji: "5.", text: "Same air affects an asthmatic differently than an athlete")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func formulaRow(emoji: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#4AA1B3"))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Helpers

    private func zoneColor(for zone: PPIZone) -> Color {
        switch zone {
        case .green: return Color(hex: "#4CD964")
        case .yellow: return Color(hex: "#FFD60A")
        case .orange: return Color(hex: "#FF9F0A")
        case .red: return Color(hex: "#FF3B30")
        }
    }

    private func scoreColor(_ score: Double?) -> Color {
        guard let s = score else { return .white.opacity(0.2) }
        switch s {
        case 0..<25: return Color(hex: "#4CD964")
        case 25..<50: return Color(hex: "#FFD60A")
        case 50..<75: return Color(hex: "#FF9F0A")
        default: return Color(hex: "#FF3B30")
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}
