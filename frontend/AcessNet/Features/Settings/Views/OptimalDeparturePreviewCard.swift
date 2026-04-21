//
//  OptimalDeparturePreviewCard.swift
//  AcessNet
//
//  Preview compacto de "Mejor momento para salir" para el Hub (lado derecho).
//  Muestra hora óptima hero + mini-chart de 12 ventanas + stats de ahorro.
//

import SwiftUI
import CoreLocation
import Combine

struct OptimalDeparturePreviewCard: View {
    let onExpand: () -> Void

    @Environment(\.weatherTheme) private var theme
    @State private var windows: [PreviewWindow] = OptimalDeparturePreviewCard.mockWindows
    @State private var bestIndex: Int = 1   // 07:30 index
    @State private var pulseBar: Bool = false

    struct PreviewWindow: Identifiable, Equatable {
        let id = UUID()
        let hour: String     // "07:00"
        let score: Double    // 0-100
        let aqi: Int
    }

    private var best: PreviewWindow { windows[bestIndex] }

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onExpand()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                header
                heroBestTime
                miniChart
                savingsRow
                footerCTA
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#818CF8").opacity(0.4), theme.textTint.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulseBar = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#818CF8").opacity(0.7), Color(hex: "#4338CA").opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 28, height: 28)
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(theme.textTint)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Mejor momento")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(theme.textTint)
                    .lineLimit(1)
                Text("\(windows.count) ventanas · 6h")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Text("4")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.55))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(theme.textTint.opacity(0.1)))
        }
    }

    // MARK: - Hero Best Time

    private var heroBestTime: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8, weight: .heavy))
                    Text("HORA ÓPTIMA")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.0)
                }
                .foregroundColor(Color(hex: "#FBBF24"))

                Text(best.hour)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                    .shadow(color: Color(hex: "#818CF8").opacity(0.45), radius: 6)
            }

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 2) {
                scoreBadge(Int(best.score))
                Text("AQI \(best.aqi)")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(aqiColor(best.aqi))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(aqiColor(best.aqi).opacity(0.15)))
                    .overlay(Capsule().stroke(aqiColor(best.aqi).opacity(0.4), lineWidth: 0.8))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FBBF24").opacity(0.14),
                                 Color(hex: "#818CF8").opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#FBBF24").opacity(0.35), lineWidth: 1)
        )
    }

    private func scoreBadge(_ score: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(score)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(theme.textTint)
            Text("/100")
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.5))
        }
    }

    // MARK: - Mini Chart (12 windows)

    private var miniChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let spacing: CGFloat = 2
                let barWidth = (geo.size.width - spacing * CGFloat(windows.count - 1)) / CGFloat(windows.count)
                let maxScore = windows.map(\.score).max() ?? 100
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(windows.enumerated()), id: \.offset) { idx, w in
                        let isBest = idx == bestIndex
                        let h = max(4, geo.size.height * CGFloat(w.score / maxScore))
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(
                                    isBest
                                        ? LinearGradient(
                                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                            startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(
                                            colors: [scoreColor(w.score).opacity(0.9),
                                                     scoreColor(w.score).opacity(0.5)],
                                            startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: barWidth, height: h)
                                .shadow(
                                    color: isBest ? Color(hex: "#FBBF24").opacity(pulseBar ? 0.7 : 0.3) : .clear,
                                    radius: isBest ? 6 : 0
                                )
                        }
                    }
                }
            }
            .frame(height: 48)

            HStack(spacing: 0) {
                Text(windows.first?.hour ?? "")
                Spacer()
                Text(windows[windows.count / 2].hour)
                Spacer()
                Text(windows.last?.hour ?? "")
            }
            .font(.system(size: 7, weight: .heavy))
            .foregroundColor(theme.textTint.opacity(0.4))
            .monospacedDigit()
        }
    }

    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case ..<40:  return Color(hex: "#F87171")
        case ..<65:  return Color(hex: "#FBBF24")
        default:     return Color(hex: "#34D399")
        }
    }

    private func aqiColor(_ a: Int) -> Color {
        switch a {
        case 0...50: return Color(hex: "#34D399")
        case 51...100: return Color(hex: "#FBBF24")
        case 101...150: return Color(hex: "#FB923C")
        default: return Color(hex: "#F87171")
        }
    }

    // MARK: - Savings Row

    private var savingsRow: some View {
        HStack(spacing: 0) {
            savingTile(icon: "pesosign.circle.fill", value: "$45", label: "ahorro", color: Color(hex: "#34D399"))
            divider
            savingTile(icon: "clock.fill", value: "18m", label: "menos", color: Color(hex: "#60A5FA"))
            divider
            savingTile(icon: "lungs.fill", value: "-30%", label: "expo", color: Color(hex: "#F472B6"))
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private var divider: some View {
        Rectangle().fill(theme.textTint.opacity(0.08)).frame(width: 1, height: 22)
    }

    private func savingTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textTint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 7, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(theme.textTint.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerCTA: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 9, weight: .heavy))
            Text("Analizar 12 ventanas")
                .font(.system(size: 10, weight: .heavy))
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundColor(theme.textTint)
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: [Color(hex: "#818CF8").opacity(0.85), Color(hex: "#4338CA").opacity(0.85)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Mock data

    private static let mockWindows: [PreviewWindow] = [
        .init(hour: "07:00", score: 78, aqi: 48),
        .init(hour: "07:30", score: 92, aqi: 42),  // best
        .init(hour: "08:00", score: 68, aqi: 58),
        .init(hour: "08:30", score: 52, aqi: 72),
        .init(hour: "09:00", score: 41, aqi: 88),
        .init(hour: "09:30", score: 38, aqi: 95),
        .init(hour: "10:00", score: 44, aqi: 92),
        .init(hour: "10:30", score: 55, aqi: 82),
        .init(hour: "11:00", score: 62, aqi: 75),
        .init(hour: "11:30", score: 70, aqi: 62),
        .init(hour: "12:00", score: 74, aqi: 55),
        .init(hour: "12:30", score: 80, aqi: 50),
    ]
}
