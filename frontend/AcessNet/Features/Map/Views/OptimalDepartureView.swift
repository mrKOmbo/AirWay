//
//  OptimalDepartureView.swift
//  AcessNet
//
//  Vista rediseñada "Mejor momento para salir":
//  Hero dorado + chart gradient con star pulsante + detail glass + ranking semáforo.
//

import SwiftUI
import Charts
import CoreLocation
import os

struct OptimalDepartureView: View {
    @Environment(\.weatherTheme) private var theme
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let vehicle: VehicleProfile
    let userProfile: [String: Any]?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettings

    @State private var response: OptimalDepartureResponse?
    @State private var selectedIdx: Int = 0
    @State private var loading = true
    @State private var errorMsg: String?
    @State private var pulseBest: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if loading {
                            loadingCard
                        } else if let err = errorMsg {
                            errorCard(err)
                        } else if let r = response {
                            content(r)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Mejor momento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(theme.textTint)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(theme.textTint.opacity(0.1)))
                    }
                }
            }
            .environment(\.weatherTheme, theme)
            .task { await load() }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulseBest = true
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ r: OptimalDepartureResponse) -> some View {
        if let best = r.best {
            heroCard(best: best, savings: r.savingsIfBest, recommendation: r.recommendation)
        }

        windowsChartCard(r.windows)

        if r.windows.indices.contains(selectedIdx) {
            detailCard(r.windows[selectedIdx])
        }

        rankingCard(r.windows)
    }

    // MARK: - Hero Card

    private func heroCard(best: DepartureWindow, savings: DepartureSavings?, recommendation: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(theme.textTint)
                }
                .shadow(color: Color(hex: "#FBBF24").opacity(0.55), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HORA ÓPTIMA")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#FBBF24"))
                    Text(vehicle.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textTint.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()
                Text("Rank #\(best.rank)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#FBBF24").opacity(0.6)))
            }

            // Hora gigante
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(best.departTimeLabel)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                    .shadow(color: Color(hex: "#FBBF24").opacity(0.5), radius: 10)
                Spacer()
                scoreBadgeLarge(Int(best.score))
            }

            // Stats hero
            HStack(spacing: 8) {
                heroStat(
                    icon: "clock.fill",
                    value: "\(Int(best.durationMin))",
                    unit: "min",
                    label: "Duración",
                    color: Color(hex: "#60A5FA")
                )
                heroStat(
                    icon: "pesosign.circle.fill",
                    value: "\(Int(best.pesosCost))",
                    unit: "MXN",
                    label: "Costo",
                    color: Color(hex: "#34D399")
                )
                heroStat(
                    icon: "leaf.fill",
                    value: "\(best.aqiAvg)",
                    unit: "AQI",
                    label: best.aqiCategory,
                    color: aqiColor(best.aqiAvg)
                )
            }

            // Savings
            if let s = savings, s.pesos + s.minutes + Double(s.exposurePct) > 0.5 {
                savingsStripe(s)
            }

            // AI recommendation
            if let rec = recommendation {
                aiRecommendationCard(rec)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FBBF24").opacity(0.12),
                            Color(hex: "#818CF8").opacity(0.05)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#FBBF24").opacity(0.45),
                                 Color(hex: "#F59E0B").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func scoreBadgeLarge(_ score: Int) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("SCORE")
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                Text("/100")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.4))
            }
        }
    }

    private func heroStat(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.5))
            }
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(color.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textTint.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private func savingsStripe(_ s: DepartureSavings) -> some View {
        HStack(spacing: 0) {
            if s.pesos > 1 {
                savingTile(icon: "pesosign.circle.fill",
                           value: "$\(Int(s.pesos))",
                           label: "ahorro",
                           color: Color(hex: "#34D399"))
            }
            if s.minutes > 1 {
                savingDivider
                savingTile(icon: "clock.fill",
                           value: "\(Int(s.minutes))m",
                           label: "menos",
                           color: Color(hex: "#60A5FA"))
            }
            if s.exposurePct > 0 {
                savingDivider
                savingTile(icon: "lungs.fill",
                           value: "-\(s.exposurePct)%",
                           label: "exposición",
                           color: Color(hex: "#F472B6"))
            }
            if s.co2Kg > 0.01 {
                savingDivider
                savingTile(icon: "leaf.fill",
                           value: String(format: "%.1f", s.co2Kg),
                           label: "kg CO₂",
                           color: Color(hex: "#34D399"))
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private var savingDivider: some View {
        Rectangle().fill(theme.textTint.opacity(0.08)).frame(width: 1, height: 24)
    }

    private func savingTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textTint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(theme.textTint.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func aiRecommendationCard(_ rec: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(Color(hex: "#A78BFA"))
            VStack(alignment: .leading, spacing: 3) {
                Text("RECOMENDACIÓN AI")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.0)
                    .foregroundColor(Color(hex: "#A78BFA"))
                Text(rec)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#A78BFA").opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Windows Chart Card

    private func windowsChartCard(_ windows: [DepartureWindow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMPARATIVA")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Spacer()
                Text("\(windows.count) ventanas")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.4))
            }

            customBarChart(windows)

            HStack(spacing: 14) {
                legendDot(color: Color(hex: "#34D399"), label: "Óptimo ≥80")
                legendDot(color: Color(hex: "#FBBF24"), label: "Medio 50–79")
                legendDot(color: Color(hex: "#F87171"), label: "Bajo <50")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func customBarChart(_ windows: [DepartureWindow]) -> some View {
        GeometryReader { geo in
            let count = max(windows.count, 1)
            let spacing: CGFloat = 4
            let barWidth = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let maxScore: Double = max(windows.map(\.score).max() ?? 100, 1)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(windows.enumerated()), id: \.offset) { idx, w in
                    let isBest = w.rank == 1
                    let isSelected = idx == selectedIdx
                    let h = max(10, geo.size.height * CGFloat(w.score / maxScore) - 14)

                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedIdx = idx
                        }
                    } label: {
                        VStack(spacing: 2) {
                            if isBest {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(Color(hex: "#FBBF24"))
                                    .shadow(color: Color(hex: "#FBBF24").opacity(pulseBest ? 0.8 : 0.3),
                                            radius: isBest ? 6 : 0)
                                    .scaleEffect(pulseBest ? 1.15 : 1.0)
                            }
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    isBest
                                        ? LinearGradient(
                                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                            startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(
                                            colors: [scoreColor(w.score).opacity(0.9),
                                                     scoreColor(w.score).opacity(0.45)],
                                            startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: barWidth, height: h)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(
                                            isSelected ? .white : .clear,
                                            lineWidth: isSelected ? 1.5 : 0
                                        )
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 140)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.55))
        }
    }

    // MARK: - Detail Card

    private func detailCard(_ w: DepartureWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SALIR A LAS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(theme.textTint.opacity(0.45))
                    Text(w.departTimeLabel)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(theme.textTint)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    scorePill(w.score, large: true)
                    Text("Rank #\(w.rank)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.4))
                }
            }

            // Grid 3x2
            HStack(spacing: 8) {
                detailStat(icon: "clock.fill",
                           value: "\(Int(w.durationMin))",
                           unit: "min",
                           color: Color(hex: "#60A5FA"))
                detailStat(icon: "pesosign.circle.fill",
                           value: "$\(Int(w.pesosCost))",
                           unit: "MXN",
                           color: Color(hex: "#34D399"))
                detailStat(icon: "drop.fill",
                           value: String(format: "%.1f", w.liters),
                           unit: "L",
                           color: Color(hex: "#A78BFA"))
            }
            HStack(spacing: 8) {
                detailStat(icon: "leaf.fill",
                           value: "\(w.aqiAvg)",
                           unit: "AQI",
                           color: aqiColor(w.aqiAvg))
                detailStat(icon: "car.fill",
                           value: String(format: "×%.2f", w.trafficFactor),
                           unit: "tráfico",
                           color: Color(hex: "#FB923C"))
                detailStat(icon: "smoke.fill",
                           value: String(format: "%.1f", w.co2Kg),
                           unit: "kg CO₂",
                           color: Color(hex: "#F472B6"))
            }

            // SubScores
            if let sub = w.subScores {
                Divider().background(.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 9, weight: .heavy))
                        Text("DESGLOSE DEL SCORE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.0)
                    }
                    .foregroundColor(theme.textTint.opacity(0.5))

                    subScoreBar("Tiempo", sub.time, color: Color(hex: "#60A5FA"))
                    subScoreBar("Costo", sub.cost, color: Color(hex: "#34D399"))
                    subScoreBar("AQI", sub.aqi, color: Color(hex: "#FB923C"))
                    subScoreBar("Exposición", sub.exposure, color: Color(hex: "#F472B6"))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func detailStat(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textTint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(theme.textTint.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private func subScoreBar(_ label: String, _ value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.65))
                .frame(width: 74, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTint.opacity(0.06))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.55)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(value / 100)))
                }
            }
            .frame(height: 8)

            Text("\(Int(value))")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Ranking Card

    private func rankingCard(_ windows: [DepartureWindow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAS LAS VENTANAS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Spacer()
            }

            VStack(spacing: 6) {
                let sorted = windows.sorted(by: { $0.departDate < $1.departDate })
                ForEach(sorted) { win in
                    rankingRow(win)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func rankingRow(_ w: DepartureWindow) -> some View {
        let isBest = w.rank == 1
        let isSelected = response?.windows.firstIndex(of: w) == selectedIdx
        return Button {
            HapticFeedback.selection()
            if let i = response?.windows.firstIndex(of: w) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    selectedIdx = i
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Hora
                Text(w.departTimeLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(isBest ? Color(hex: "#FBBF24") : theme.textTint)
                    .monospacedDigit()
                    .frame(width: 54, alignment: .leading)

                if isBest {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }

                Spacer(minLength: 4)

                // Stats inline
                HStack(spacing: 8) {
                    smallStat(icon: "clock", value: "\(Int(w.durationMin))m", color: Color(hex: "#60A5FA"))
                    smallStat(icon: "pesosign.circle", value: "$\(Int(w.pesosCost))", color: Color(hex: "#34D399"))
                    smallStat(icon: "leaf", value: "\(w.aqiAvg)", color: aqiColor(w.aqiAvg))
                }

                // Score pill
                scorePill(w.score, large: false)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isBest
                            ? Color(hex: "#FBBF24").opacity(0.08)
                            : (isSelected ? .white.opacity(0.06) : theme.textTint.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isBest
                            ? Color(hex: "#FBBF24").opacity(0.4)
                            : (isSelected ? .white.opacity(0.2) : theme.textTint.opacity(0.05)),
                        lineWidth: isBest ? 1 : 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func smallStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textTint.opacity(0.85))
                .monospacedDigit()
        }
    }

    private func scorePill(_ score: Double, large: Bool) -> some View {
        let s = Int(score)
        return Text("\(s)")
            .font(.system(size: large ? 18 : 11, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(theme.textTint)
            .padding(.horizontal, large ? 12 : 7)
            .padding(.vertical, large ? 6 : 3)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [scoreColor(score), scoreColor(score).opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: scoreColor(score).opacity(0.4), radius: large ? 6 : 3)
    }

    // MARK: - Colors

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return Color(hex: "#34D399")
        case 60..<80: return Color(hex: "#A3E635")
        case 40..<60: return Color(hex: "#FBBF24")
        default: return Color(hex: "#F87171")
        }
    }

    private func aqiColor(_ aqi: Int) -> Color {
        switch aqi {
        case ..<51: return Color(hex: "#34D399")
        case 51..<101: return Color(hex: "#FBBF24")
        case 101..<151: return Color(hex: "#FB923C")
        case 151..<201: return Color(hex: "#F87171")
        case 201..<301: return Color(hex: "#A78BFA")
        default: return Color(hex: "#881337")
        }
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView().tint(theme.textTint)
            Text("Analizando 6 horas…")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.85))
            Text("Tráfico + tiempo + precio + aire")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(.orange)
            Text("No pudimos analizar")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(theme.textTint)
            Text(msg)
                .font(.system(size: 11))
                .foregroundColor(theme.textTint.opacity(0.55))
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.medium()
                Task { await load() }
            } label: {
                Text("Reintentar")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Color(hex: "#3B82F6")))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    // MARK: - Load

    private func load() async {
        loading = true
        errorMsg = nil
        AirWayLogger.ui.info(
            "OptimalDepartureView loading vehicle=\(self.vehicle.fullDisplayName, privacy: .public) profile=\(self.userProfile != nil, privacy: .public)"
        )
        defer { loading = false }

        let now = Date()
        let earliest = now
        let latest = now.addingTimeInterval(6 * 3600)

        do {
            response = try await DepartureOptimizerAPI.shared.suggest(
                origin: origin,
                destination: destination,
                vehicle: vehicle,
                earliest: earliest,
                latest: latest,
                stepMin: 30,
                userProfile: userProfile
            )
            if let best = response?.best,
               let idx = response?.windows.firstIndex(where: { $0.id == best.id }) {
                selectedIdx = idx
            }
        } catch {
            errorMsg = error.localizedDescription
            AirWayLogger.ui.error("OptimalDepartureView failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
