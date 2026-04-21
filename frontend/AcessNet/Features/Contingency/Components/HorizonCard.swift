//
//  HorizonCard.swift
//  AcessNet
//
//  Tarjeta compacta por horizonte (24h / 48h / 72h).
//

import SwiftUI

struct HorizonCard: View {
    @Environment(\.weatherTheme) private var theme
    let forecast: HorizonForecast
    var isSelected: Bool = false

    @State private var animate: Bool = false
    @State private var displayPercent: Int = 0

    private var color: Color {
        switch forecast.probabilityLevel {
        case .low:      return Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
        case .moderate: return Color(red: 0.976, green: 0.659, blue: 0.145) // #F9A825 (ámbar legible sobre fondo claro)
        case .high:     return Color(red: 1.000, green: 0.596, blue: 0.000) // #FF9800
        case .veryHigh: return Color(red: 0.957, green: 0.263, blue: 0.212) // #F44336
        }
    }

    private var horizonLabel: String {
        switch forecast.horizonH {
        case 24: return "Mañana"
        case 48: return "Pasado"
        case 72: return "En 3 días"
        default: return "\(forecast.horizonH) h"
        }
    }

    private var horizonIcon: String {
        switch forecast.horizonH {
        case 24: return "sunrise.fill"
        case 48: return "sun.max.fill"
        case 72: return "calendar"
        default: return "clock.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: horizonIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(color.opacity(0.18)))

                Text(horizonLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.textTint.opacity(0.9))

                Spacer()

                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.8), radius: isSelected ? 6 : 0)
            }

            Text("\(displayPercent)%")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())

            // Animated solid progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTint.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: animate ? geo.size.width * CGFloat(forecast.probFase1O3) : 0)
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 4)

            HStack(spacing: 4) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 8, weight: .bold))
                Text("O₃ \(Int(round(forecast.o3ExpectedPpb))) ppb")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundColor(theme.textTint.opacity(0.55))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.textTint.opacity(isSelected ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isSelected
                                    ? [color, color.opacity(0.4)]
                                    : [.white.opacity(0.1), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 1.5 : 0.8
                        )
                )
                .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 12, y: 4)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animate = true
            }
            // Count-up
            let target = forecast.probabilityPercent
            let steps = max(target, 1)
            let duration = 0.9
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + duration * Double(i) / Double(steps)) {
                    displayPercent = i
                }
            }
        }
    }
}
