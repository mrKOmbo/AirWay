//
//  AirQualityLegendView.swift
//  AcessNet
//
//  Leyenda interactiva para mostrar niveles de calidad del aire
//

import SwiftUI

// MARK: - Air Quality Legend View

/// Leyenda flotante que muestra los niveles de calidad del aire
struct AirQualityLegendView: View {
    @Binding var isExpanded: Bool
    let statistics: AirQualityGridManager.GridStatistics?

    @State private var glowIntensity: Double = 0.3

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#3B82F6").opacity(glowIntensity))
                            .frame(width: 36, height: 36)
                            .blur(radius: 6)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "aqi.medium")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Calidad del aire")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)

                        if let stats = statistics {
                            Text("AQI \(Int(stats.averageAQI))")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

                    VStack(spacing: 6) {
                        ForEach(AQILevel.allCases, id: \.self) { level in
                            AirQualityLegendRow(
                                level: level,
                                count: count(for: level)
                            )
                        }
                    }

                    if let stats = statistics {
                        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

                        HStack(spacing: 12) {
                            VStack(spacing: 1) {
                                Text("\(stats.totalZones)")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                Text("ZONAS")
                                    .font(.system(size: 8, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)

                            VStack(spacing: 1) {
                                Text("\(Int(stats.averageAQI))")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(colorForAQI(stats.averageAQI))
                                    .monospacedDigit()
                                Text("AQI PROM")
                                    .font(.system(size: 8, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
        .onAppear {
            startGlowAnimation()
        }
    }

    // MARK: - Helper Methods

    private func count(for level: AQILevel) -> Int {
        guard let stats = statistics else { return 0 }

        switch level {
        case .good: return stats.goodCount
        case .moderate: return stats.moderateCount
        case .poor: return stats.poorCount
        case .unhealthy: return stats.unhealthyCount
        case .severe: return stats.severeCount
        case .hazardous: return stats.hazardousCount
        }
    }

    private func colorForAQI(_ aqi: Double) -> Color {
        let level = AQILevel.from(aqi: Int(aqi))
        switch level {
        case .good: return Color(hex: "#34D399")
        case .moderate: return Color(hex: "#FBBF24")
        case .poor: return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe: return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }

    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 1.8)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.5
        }
    }
}

// MARK: - Air Quality Legend Row

/// Fila individual de la leyenda
struct AirQualityLegendRow: View {
    let level: AQILevel
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay(
                    Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.4), radius: 3)

            Text(level.rawValue)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(color))
            } else {
                Text("0")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(count > 0 ? color.opacity(0.08) : Color.clear)
        )
    }

    private var color: Color {
        switch level {
        case .good:      return Color(hex: "#34D399")
        case .moderate:  return Color(hex: "#FBBF24")
        case .poor:      return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe:    return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }
}

// MARK: - Compact Air Quality Indicator

/// Indicador compacto de calidad del aire (para cuando no hay espacio)
struct CompactAirQualityIndicator: View {
    let averageAQI: Double
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.6), radius: 3)

            Text("AQI \(Int(averageAQI))")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(isActive ? 1.0 : 0.5))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.6))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        .clipShape(Capsule())
        .opacity(isActive ? 1.0 : 0.6)
    }

    private var color: Color {
        let level = AQILevel.from(aqi: Int(averageAQI))
        switch level {
        case .good:      return Color(hex: "#34D399")
        case .moderate:  return Color(hex: "#FBBF24")
        case .poor:      return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe:    return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }
}

// MARK: - Preview

#Preview("Air Quality Legend") {
    VStack(spacing: 20) {
        Text("Legend Views").font(.title.bold())

        // Leyenda expandida
        AirQualityLegendView(
            isExpanded: .constant(true),
            statistics: AirQualityGridManager.GridStatistics(
                totalZones: 49,
                averageAQI: 75,
                goodCount: 12,
                moderateCount: 18,
                poorCount: 10,
                unhealthyCount: 6,
                severeCount: 2,
                hazardousCount: 1
            )
        )
        .frame(maxWidth: 300)

        // Leyenda colapsada
        AirQualityLegendView(
            isExpanded: .constant(false),
            statistics: AirQualityGridManager.GridStatistics(
                totalZones: 49,
                averageAQI: 75,
                goodCount: 12,
                moderateCount: 18,
                poorCount: 10,
                unhealthyCount: 6,
                severeCount: 2,
                hazardousCount: 1
            )
        )
        .frame(maxWidth: 300)

        // Indicador compacto
        HStack(spacing: 12) {
            CompactAirQualityIndicator(averageAQI: 45, isActive: true)
            CompactAirQualityIndicator(averageAQI: 95, isActive: true)
            CompactAirQualityIndicator(averageAQI: 155, isActive: false)
        }
    }
    .padding()
}
