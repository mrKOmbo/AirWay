//
//  PPIDashboardView.swift
//  AcessNet
//
//  Main PPI dashboard on iPhone. Shows PPI Score, cigarette equivalence,
//  biometric breakdown, and vulnerability profile.
//  Uses simulated data when Apple Watch is not connected.
//

import SwiftUI

struct PPIDashboardView: View {
    @Environment(\.weatherTheme) private var theme
    @ObservedObject var connectivityManager = PhoneConnectivityManager.shared

    @State private var showingVulnerabilityProfile = false
    @State private var showingDisclaimer = false
    @State private var demoAnimationProgress: Double = 0

    // MARK: - Data Sources (real or simulated)

    private var isLive: Bool {
        connectivityManager.latestPPIScore != nil
    }

    private var ppi: PPIScoreData {
        connectivityManager.latestPPIScore ?? Self.demoPPI
    }

    private var bio: BiometricUpdateData {
        connectivityManager.latestBiometrics ?? Self.demoBiometrics
    }

    private var cig: CigaretteData {
        connectivityManager.latestCigaretteData ?? Self.demoCigarettes
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

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                if !isLive { demoBanner }
                heroScoreCard
                cigaretteCard
                biometricGrid
                componentScoresCard
                vulnerabilityCard
                howItWorksCard
                disclaimerFooter
            }
            .padding(.horizontal, 16)
            .avoidTabBar(extraPadding: 16)
        }
        .background(theme.pageBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                demoAnimationProgress = 1.0
            }
        }
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("PERSONAL POLLUTION IMPACT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.4))
                .tracking(2)

            Text("Health Monitor")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(theme.textTint)
        }
        .padding(.top, 54)
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Simulated Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.9))
                Text("Connect Apple Watch for real-time data")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTint.opacity(0.5))
            }

            Spacer()

            Image(systemName: "applewatch.and.arrow.forward")
                .font(.system(size: 16))
                .foregroundColor(.cyan.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cyan.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Hero PPI Score

    private var heroScoreCard: some View {
        let score = ppi.score
        let zone = PPIZone.from(score: score)
        let color = zoneColor(for: zone)

        return VStack(spacing: 14) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(theme.textTint.opacity(0.06), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 190, height: 190)

                // Colored arc
                Circle()
                    .trim(from: 0, to: CGFloat(Double(score) / 100.0) * 0.75 * demoAnimationProgress)
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
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .frame(width: 190, height: 190)
                    .animation(.easeInOut(duration: 1.2), value: score)

                // Center content
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText())

                    Text("PPI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textTint.opacity(0.35))
                        .tracking(4)

                    Text(zone.labelES)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
            }

            // Status row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ppi.baselineCalibrated ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(ppi.baselineCalibrated ? "Calibrado" : "Calibrando...")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textTint.opacity(0.45))
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < ppi.availableMetrics ? color : theme.textTint.opacity(0.15))
                            .frame(width: 5, height: 5)
                    }
                    Text("\(ppi.availableMetrics)/4")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textTint.opacity(0.45))
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(color.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Cigarette Equivalence Card

    private var cigaretteCard: some View {
        let cigs = cig.cigarettesToday
        let color = cigColor(cigs)

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("\u{1F6AC}")
                        .font(.system(size: 14))
                    Text("CIGARETTE EQUIVALENCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textTint.opacity(0.45))
                        .tracking(1.2)
                }

                Spacer()

                Text("Berkeley Earth")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(theme.textTint.opacity(0.25))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.textTint.opacity(0.06)))
            }

            // Hero number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", cigs))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 1) {
                    Text("cigarrillos")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.6))
                    Text("equivalentes hoy")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTint.opacity(0.35))
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statPill(
                    icon: "speedometer",
                    label: "Tasa actual",
                    value: String(format: "%.2f/hr", cig.currentRatePerHour),
                    color: color
                )

                Spacer()

                statPill(
                    icon: "scalemass.fill",
                    label: "Dosis depositada",
                    value: String(format: "%.1f \u{00B5}g", cig.cumulativeDoseUg),
                    color: theme.textTint
                )
            }

            // Activity impact
            if cig.activityBreakdown.exercisePercentage > 5 {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(String(format: "%.0f%% de tu dosis fue durante actividad", cig.activityBreakdown.exercisePercentage))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange.opacity(0.85))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.08))
                )
            }

            // WHO/EPA comparison bar
            whoComparisonBar(cigs: cigs, color: color)

            Text("22 \u{00B5}g/m\u{00B3} PM2.5 en 24h = 1 cigarrillo (mortalidad). Ajustado por tu ventilaci\u{00F3}n real via Apple Watch.")
                .font(.system(size: 9))
                .foregroundColor(theme.textTint.opacity(0.2))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func statPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color.opacity(0.6))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(theme.textTint.opacity(0.35))
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(theme.textTint.opacity(0.9))
        }
    }

    private func whoComparisonBar(cigs: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Legend
            HStack(spacing: 14) {
                legendDot(color: .green, label: "OMS: 0.23")
                legendDot(color: .yellow, label: "EPA: 1.59")
                legendDot(color: color, label: String(format: "T\u{00FA}: %.1f", cigs))
            }

            // Bar
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.textTint.opacity(0.06))
                        .frame(height: 8)

                    // Fill to user level
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: markerX(cigs, max: 8, width: w), height: 8)
                        .opacity(0.4)

                    // WHO marker
                    markerLine(x: markerX(0.23, max: 8, width: w), color: .green, label: "OMS")
                    // EPA marker
                    markerLine(x: markerX(1.59, max: 8, width: w), color: .yellow, label: "EPA")
                    // User marker
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .shadow(color: color.opacity(0.5), radius: 4)
                        .offset(x: markerX(cigs, max: 8, width: w) - 6)
                }
            }
            .frame(height: 16)
        }
    }

    private func markerLine(x: CGFloat, color: Color, label: String) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 14)
            .offset(x: x - 1)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.5))
        }
    }

    // MARK: - Biometric Grid

    private var biometricGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BIOMETRICS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.45))
                .tracking(1.5)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                bioTile(icon: "heart.fill", label: "Heart Rate",
                        value: bio.heartRate.map { String(format: "%.0f", $0) },
                        unit: "bpm", date: bio.heartRateDate, color: .red,
                        baseline: "68 bpm base")

                bioTile(icon: "waveform.path.ecg", label: "HRV",
                        value: bio.hrv.map { String(format: "%.0f", $0) },
                        unit: "ms", date: bio.hrvDate, color: .purple,
                        baseline: "52 ms base")

                bioTile(icon: "lungs.fill", label: "SpO2",
                        value: bio.spO2.map { String(format: "%.1f", $0) },
                        unit: "%", date: bio.spO2Date, color: .blue,
                        baseline: "98.2% base")

                bioTile(icon: "wind", label: "Resp Rate",
                        value: bio.respiratoryRate.map { String(format: "%.0f", $0) },
                        unit: "brpm", date: bio.respiratoryRateDate, color: .cyan,
                        baseline: "14.5 base")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.cardColor)
        )
    }

    private func bioTile(icon: String, label: String, value: String?,
                         unit: String, date: Date?, color: Color, baseline: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.55))
            }

            if let v = value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(v)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textTint)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.35))
                }
            } else {
                Text("\u{2014}")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textTint.opacity(0.15))
            }

            Text(baseline)
                .font(.system(size: 8))
                .foregroundColor(theme.textTint.opacity(0.25))

            if let d = date {
                Text(timeAgo(d))
                    .font(.system(size: 8))
                    .foregroundColor(theme.textTint.opacity(0.2))
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

    private var componentScoresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPONENT SCORES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.45))
                .tracking(1.5)

            compRow(label: "SpO2", score: ppi.components.spO2Score,
                    deviation: ppi.components.spO2Deviation, weight: 0.35,
                    devFmt: "%.1f pp", icon: "lungs.fill")
            compRow(label: "HRV", score: ppi.components.hrvScore,
                    deviation: ppi.components.hrvDeviation, weight: 0.30,
                    devFmt: "%.1f%%", icon: "waveform.path.ecg")
            compRow(label: "Heart Rate", score: ppi.components.hrScore,
                    deviation: ppi.components.hrDeviation, weight: 0.20,
                    devFmt: "%+.0f bpm", icon: "heart.fill")
            compRow(label: "Resp Rate", score: ppi.components.respScore,
                    deviation: ppi.components.respDeviation, weight: 0.15,
                    devFmt: "%+.1f%%", icon: "wind")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.cardColor)
        )
    }

    private func compRow(label: String, score: Double?, deviation: Double?,
                         weight: Double, devFmt: String, icon: String) -> some View {
        let color = scoreColor(score)
        return HStack(spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color.opacity(0.1)))

            // Label + deviation
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textTint)
                    Text(String(format: "%.0f%%", weight * 100))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.25))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(theme.textTint.opacity(0.06)))
                }
                if let dev = deviation {
                    Text(String(format: devFmt, dev) + " from baseline")
                        .font(.system(size: 9))
                        .foregroundColor(color.opacity(0.7))
                }
            }

            Spacer()

            // Score
            if let s = score {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", s))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    // Mini bar
                    GeometryReader { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.3))
                            .frame(width: 36, height: 3)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: CGFloat(s / 100.0) * 36, height: 3)
                            }
                    }
                    .frame(width: 36, height: 3)
                }
            } else {
                Text("\u{2014}")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textTint.opacity(0.15))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardColor.opacity(0.6))
        )
    }

    // MARK: - Vulnerability Profile

    private var vulnerabilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VULNERABILITY PROFILE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.45))
                    .tracking(1.5)

                Spacer()

                Button(action: { showingVulnerabilityProfile = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                        Text("Editar")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#4AA1B3"))
                }
            }

            HStack(spacing: 20) {
                // Multiplier
                VStack(spacing: 4) {
                    Text(String(format: "%.1fx", profile.multiplier))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(profile.multiplier > 1.5 ? .orange : theme.textTint)

                    Text("Multiplicador")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTint.opacity(0.4))
                }
                .frame(width: 80)

                // Risk factors
                VStack(alignment: .leading, spacing: 4) {
                    Text("Factores de riesgo")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTint.opacity(0.4))

                    if profile.riskFactors.isEmpty {
                        Text("Ninguno configurado")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTint.opacity(0.25))
                    } else {
                        FlowLayout(spacing: 4) {
                            ForEach(profile.riskFactors, id: \.self) { factor in
                                Text(factor)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(theme.textTint.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(Color.orange.opacity(0.15))
                                    )
                            }
                        }
                    }
                }
            }

            Text("Las personas con condiciones respiratorias o cardiovasculares son m\u{00E1}s sensibles. El multiplicador ajusta tu PPI Score.")
                .font(.system(size: 9))
                .foregroundColor(theme.textTint.opacity(0.25))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.cardColor)
        )
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW PPI WORKS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.45))
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 10) {
                stepRow(num: "1", icon: "brain.head.profile.fill",
                        text: "Aprende tu baseline biom\u{00E9}trico personal en 7 d\u{00ED}as")
                stepRow(num: "2", icon: "applewatch.radiowaves.left.and.right",
                        text: "Mide desviaciones en tiempo real via Apple Watch")
                stepRow(num: "3", icon: "function",
                        text: "PPI = SpO2 (35%) + HRV (30%) + HR (20%) + Resp (15%)")
                stepRow(num: "4", icon: "person.crop.circle.badge.checkmark.fill",
                        text: "Ajusta por tu perfil de vulnerabilidad y actividad")
                stepRow(num: "5", icon: "arrow.triangle.branch",
                        text: "El mismo aire afecta diferente a un asm\u{00E1}tico que a un atleta")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.cardColor)
        )
    }

    private func stepRow(num: String, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#4AA1B3"))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#4AA1B3").opacity(0.1))
                )

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(theme.textTint.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerFooter: some View {
        VStack(spacing: 6) {
            Text("Este score es solo informativo. No constituye consejo m\u{00E9}dico. Si experimentas dificultad respiratoria o dolor en el pecho, contacta a un profesional de salud.")
                .font(.system(size: 9))
                .foregroundColor(theme.textTint.opacity(0.2))
                .multilineTextAlignment(.center)

            Text("PPI Score: Pope et al. 2009 \u{2022} Cigarettes: Berkeley Earth 2015 \u{2022} Ventilation: EPA EFH Ch.6")
                .font(.system(size: 7))
                .foregroundColor(theme.textTint.opacity(0.12))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
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
        guard let s = score else { return theme.textTint.opacity(0.15) }
        switch s {
        case 0..<25: return Color(hex: "#4CD964")
        case 25..<50: return Color(hex: "#FFD60A")
        case 50..<75: return Color(hex: "#FF9F0A")
        default: return Color(hex: "#FF3B30")
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

    private func markerX(_ val: Double, max maxVal: Double, width: CGFloat) -> CGFloat {
        CGFloat(min(val, maxVal) / maxVal) * (width - 12)
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 60 { return "Ahora" }
        if s < 3600 { return "Hace \(Int(s / 60))m" }
        if s < 86400 { return "Hace \(Int(s / 3600))h" }
        return "Hace \(Int(s / 86400))d"
    }

    // MARK: - Simulated Data

    private static let demoPPI = PPIScoreData(
        score: 38,
        zone: .yellow,
        components: PPIComponents(
            spO2Score: 22.5, hrvScore: 45.0, hrScore: 30.2, respScore: 18.0,
            spO2Deviation: 1.8, hrvDeviation: 18.0, hrDeviation: 8.0, respDeviation: 12.0
        ),
        activityState: "resting",
        availableMetrics: 4,
        baselineCalibrated: true,
        timestamp: Date()
    )

    private static let demoBiometrics = BiometricUpdateData(
        heartRate: 76, heartRateDate: Date().addingTimeInterval(-120),
        hrv: 38, hrvDate: Date().addingTimeInterval(-300),
        spO2: 96.4, spO2Date: Date().addingTimeInterval(-180),
        respiratoryRate: 18, respiratoryRateDate: Date().addingTimeInterval(-600),
        timestamp: Date()
    )

    private static let demoCigarettes = CigaretteData(
        cigarettesToday: 2.3,
        currentRatePerHour: 0.18,
        cumulativeDoseUg: 182.2,
        peakHour: 8,
        activityBreakdown: ActivityDoseBreakdown(
            restingDose: 95.0,
            lightActivityDose: 62.0,
            exerciseDose: 25.2,
            postExerciseDose: 0
        ),
        timestamp: Date()
    )
}

// MARK: - FlowLayout (for risk factor tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
