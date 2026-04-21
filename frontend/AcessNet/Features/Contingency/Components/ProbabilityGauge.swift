//
//  ProbabilityGauge.swift
//  AcessNet
//
//  Gauge circular animado para mostrar probabilidad de contingencia.
//

import SwiftUI

struct ProbabilityGauge: View {
    @Environment(\.weatherTheme) private var theme
    let probability: Double        // 0.0–1.0
    let ci80Lower: Double?
    let ci80Upper: Double?
    let o3ExpectedPpb: Double
    let horizonHours: Int

    @State private var animatedProbability: Double = 0
    @State private var displayPercent: Int = 0
    @State private var animateRing: Bool = false
    @State private var pulseHalo: Bool = false
    @State private var animateContent: Bool = false

    private var level: ProbabilityLevel {
        switch probability {
        case 0..<0.3:   return .low
        case 0.3..<0.6: return .moderate
        case 0.6..<0.8: return .high
        default:        return .veryHigh
        }
    }

    private var color: Color {
        switch level {
        case .low:      return Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
        case .moderate: return Color(red: 0.976, green: 0.659, blue: 0.145) // #F9A825 (ámbar legible sobre fondo claro)
        case .high:     return Color(red: 1.000, green: 0.596, blue: 0.000) // #FF9800
        case .veryHigh: return Color(red: 0.957, green: 0.263, blue: 0.212) // #F44336
        }
    }

    var body: some View {
        ZStack {
            // Pulsing radial halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 160
                    )
                )
                .scaleEffect(pulseHalo ? 1.08 : 0.9)
                .opacity(pulseHalo ? 0.9 : 0.45)
                .blur(radius: 14)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulseHalo)

            // Background ring
            Circle()
                .stroke(theme.textTint.opacity(0.06), lineWidth: 22)

            // Probability arc — solid color
            Circle()
                .trim(from: 0, to: CGFloat(animatedProbability))
                .stroke(color, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: animateRing ? 14 : 0)

            // Center content
            VStack(spacing: 4) {
                Text("\(displayPercent)%")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                    .contentTransition(.numericText())

                Text(level.label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.4)
                    .foregroundColor(color.opacity(0.95))

                Text("prob. Fase 1 · \(horizonHours)h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTint.opacity(0.45))

                if let lo = ci80Lower, let hi = ci80Upper {
                    HStack(spacing: 4) {
                        Text("O₃")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(theme.textTint.opacity(0.4))
                        Text("\(Int(round(o3ExpectedPpb))) ppb")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textTint.opacity(0.8))
                        Text("[\(Int(round(lo))) – \(Int(round(hi)))]")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textTint.opacity(0.45))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.textTint.opacity(0.06)))
                    .padding(.top, 4)
                }
            }
            .opacity(animateContent ? 1 : 0)
            .scaleEffect(animateContent ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: animateContent)
        }
        .onAppear { triggerAnimations() }
        .onChange(of: probability) { _, _ in
            displayPercent = 0
            animatedProbability = 0
            triggerAnimations()
        }
    }

    private func triggerAnimations() {
        pulseHalo = true
        animateContent = true
        withAnimation(.spring(response: 1.3, dampingFraction: 0.75).delay(0.2)) {
            animatedProbability = probability
            animateRing = true
        }
        // Count-up percentage
        let target = Int(round(probability * 100))
        let steps = max(target, 1)
        let duration = 1.1
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + duration * Double(i) / Double(steps)) {
                withAnimation(.linear(duration: 0.02)) {
                    displayPercent = i
                }
            }
        }
    }
}
