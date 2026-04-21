//
//  NavigationProgressBar.swift
//  AcessNet
//
//  Barra de progreso de navegación con distancia y ETA restantes
//

import SwiftUI

// MARK: - Navigation Progress Bar

struct NavigationProgressBar: View {
    @Environment(\.weatherTheme) private var theme
    let progress: Double                 // 0.0 - 1.0
    let distanceRemaining: Double        // Metros
    let eta: TimeInterval                // Segundos
    let averageAQI: Double?              // AQI promedio de la ruta

    var body: some View {
        VStack(spacing: 10) {
            // Stats row arriba
            HStack(spacing: 10) {
                statInline(
                    icon: "location.fill",
                    value: distanceRemainingFormatted,
                    label: "restante",
                    color: Color(hex: "#60A5FA")
                )
                statDivider
                statInline(
                    icon: "clock.fill",
                    value: etaFormatted,
                    label: "ETA",
                    color: Color(hex: "#34D399")
                )
                Spacer(minLength: 4)
                percentageBadge
            }

            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTint.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: progressGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(min(1.0, max(0.0, progress))),
                            height: 8
                        )
                        .shadow(color: progressGradientColors.first?.opacity(0.5) ?? .clear, radius: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.textTint.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    private func statInline(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Text(value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
            }
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(theme.textTint.opacity(0.1))
            .frame(width: 1, height: 24)
    }

    private var percentageBadge: some View {
        Text("\(Int(progress * 100))%")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(theme.textTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: progressGradientColors,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: progressGradientColors.first?.opacity(0.4) ?? .clear, radius: 5)
    }

    // MARK: - Computed Properties

    /// Distancia restante formateada
    private var distanceRemainingFormatted: String {
        if distanceRemaining < 1000 {
            return "\(Int(distanceRemaining)) m"
        } else {
            return String(format: "%.1f km", distanceRemaining / 1000)
        }
    }

    /// ETA formateado
    private var etaFormatted: String {
        let minutes = Int(eta / 60)

        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }

    /// Colores del gradiente de progreso (basado en AQI promedio de ruta)
    private var progressGradientColors: [Color] {
        guard let aqi = averageAQI else {
            return [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")]
        }
        if aqi < 50 {
            return [Color(hex: "#34D399"), Color(hex: "#10B981")]
        } else if aqi < 100 {
            return [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")]
        } else if aqi < 150 {
            return [Color(hex: "#FB923C"), Color(hex: "#EA580C")]
        } else {
            return [Color(hex: "#F87171"), Color(hex: "#DC2626")]
        }
    }
}

// MARK: - Compact Progress Bar (vista reducida)

struct CompactProgressBar: View {
    @Environment(\.weatherTheme) private var theme
    let progress: Double
    let distanceRemaining: Double
    let eta: TimeInterval

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(theme.textTint.opacity(0.1), lineWidth: 3)
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                            startPoint: .top, endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Text("\(Int(progress * 100))")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(Color(hex: "#60A5FA"))
                    Text(distanceRemainingFormatted)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.textTint)
                        .monospacedDigit()
                }
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(Color(hex: "#34D399"))
                    Text(etaFormatted)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.7))
                }
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(theme.textTint.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private var distanceRemainingFormatted: String {
        if distanceRemaining < 1000 {
            return "\(Int(distanceRemaining))m"
        } else {
            return String(format: "%.1fkm", distanceRemaining / 1000)
        }
    }

    private var etaFormatted: String {
        let minutes = Int(eta / 60)
        if minutes < 1 {
            return "< 1min"
        } else if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)m"
        }
    }
}

// MARK: - Detailed Progress Info (con estadísticas adicionales)

struct DetailedProgressInfo: View {
    @Environment(\.weatherTheme) private var theme
    let progress: Double
    let distanceRemaining: Double
    let distanceTraveled: Double
    let eta: TimeInterval
    let averageSpeed: Double?  // km/h
    let averageAQI: Double?

    var body: some View {
        VStack(spacing: 16) {
            // Barra de progreso principal
            NavigationProgressBar(
                progress: progress,
                distanceRemaining: distanceRemaining,
                eta: eta,
                averageAQI: averageAQI
            )

            // Stats grid
            HStack(spacing: 12) {
                // Distancia recorrida
                StatCard(
                    icon: "figure.walk",
                    label: "Traveled",
                    value: distanceTraveledFormatted
                )

                // Velocidad promedio
                if let speed = averageSpeed {
                    StatCard(
                        icon: "speedometer",
                        label: "Avg Speed",
                        value: "\(Int(speed)) km/h"
                    )
                }

                // AQI promedio
                if let aqi = averageAQI {
                    StatCard(
                        icon: "aqi.medium",
                        label: "Avg AQI",
                        value: "\(Int(aqi))",
                        valueColor: aqiColor(for: aqi)
                    )
                }
            }
        }
    }

    private var distanceTraveledFormatted: String {
        if distanceTraveled < 1000 {
            return "\(Int(distanceTraveled)) m"
        } else {
            return String(format: "%.1f km", distanceTraveled / 1000)
        }
    }

    private func aqiColor(for aqi: Double) -> Color {
        if aqi < 50 { return Color(hex: "#4CAF50") }
        else if aqi < 100 { return Color(hex: "#FFC107") }
        else if aqi < 150 { return Color(hex: "#FF9800") }
        else { return Color(hex: "#F44336") }
    }
}

// MARK: - Stat Card Helper

struct StatCard: View {
    @Environment(\.weatherTheme) private var theme
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Navigation Progress Bar") {
    VStack(spacing: 20) {
        Text("Progress Bars")
            .font(.title2.bold())
            .padding()

        // 25% progress - Good AQI
        NavigationProgressBar(
            progress: 0.25,
            distanceRemaining: 2300,
            eta: 420,
            averageAQI: 45
        )

        // 60% progress - Moderate AQI
        NavigationProgressBar(
            progress: 0.60,
            distanceRemaining: 850,
            eta: 180,
            averageAQI: 85
        )

        // 90% progress - Unhealthy AQI
        NavigationProgressBar(
            progress: 0.90,
            distanceRemaining: 120,
            eta: 60,
            averageAQI: 165
        )

        Divider()

        // Compact version
        CompactProgressBar(
            progress: 0.45,
            distanceRemaining: 1500,
            eta: 300
        )

        Divider()

        // Detailed version
        DetailedProgressInfo(
            progress: 0.70,
            distanceRemaining: 950,
            distanceTraveled: 2150,
            eta: 240,
            averageSpeed: 32,
            averageAQI: 78
        )

        Spacer()
    }
    .padding()
}
