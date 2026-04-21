//
//  EnhancedAirQualityDashboard.swift
//  AcessNet
//
//  Dashboard mejorado con gráficos y visualizaciones avanzadas
//

import SwiftUI

// MARK: - Enhanced Air Quality Dashboard

/// Dashboard completo con gráficos y estadísticas visuales
struct EnhancedAirQualityDashboard: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var isExpanded: Bool
    let statistics: AirQualityGridManager.GridStatistics?
    let referencePoint: AirQualityReferencePoint
    let activeRoute: ScoredRoute?
    let onStartNavigation: (() -> Void)?

    @State private var animateCharts: Bool = false
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        VStack(spacing: 0) {
            // Header siempre visible
            headerView
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // Contenido expandido
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            ZStack {
                // Dark glass base
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.black.opacity(0.78))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                // Accent gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                dominantColor.opacity(0.18),
                                dominantColor.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            dominantColor.opacity(0.4),
                            .white.opacity(0.08)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: dominantColor.opacity(0.3), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Animated AQI indicator (más pequeño cuando hay ruta)
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                dominantColor.opacity(glowIntensity),
                                dominantColor.opacity(glowIntensity * 0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: activeRoute != nil ? 10 : 12,
                            endRadius: activeRoute != nil ? 20 : 24
                        )
                    )
                    .frame(width: activeRoute != nil ? 40 : 48, height: activeRoute != nil ? 40 : 48)
                    .blur(radius: 6)

                // Main circle
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                dominantColor,
                                dominantColor.opacity(0.8),
                                dominantColor,
                            ],
                            center: .center
                        )
                    )
                    .frame(width: activeRoute != nil ? 34 : 40, height: activeRoute != nil ? 34 : 40)

                // Icon
                Image(systemName: "aqi.medium")
                    .font(.system(size: activeRoute != nil ? 16 : 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(activeRoute != nil ? "Aire de la ruta" : "Calidad del aire")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(theme.textTint)

                    // Reference Point Indicator (solo cuando NO hay ruta)
                    if activeRoute == nil {
                        HStack(spacing: 3) {
                            Image(systemName: referencePoint.icon)
                                .font(.system(size: 8, weight: .heavy))
                            Text(referencePoint.displayName)
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundColor(referencePoint.coordinate != nil ? Color(hex: "#3B82F6") : Color(hex: "#34D399"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill((referencePoint.coordinate != nil
                                ? Color(hex: "#3B82F6")
                                : Color(hex: "#34D399")).opacity(0.18))
                        )
                        .overlay(
                            Capsule().stroke((referencePoint.coordinate != nil
                                ? Color(hex: "#3B82F6")
                                : Color(hex: "#34D399")).opacity(0.4), lineWidth: 0.8)
                        )
                    }
                }

                if activeRoute != nil {
                    HStack(spacing: 5) {
                        Text("AQI PROM")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(theme.textTint.opacity(0.5))

                        Text("\(Int(displayAQI))")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(dominantColor)
                            .monospacedDigit()

                        Text(displayLevel.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.6)
                            .foregroundColor(theme.textTint)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(dominantColor))
                    }
                } else if let stats = statistics {
                    HStack(spacing: 5) {
                        Text("AQI")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(theme.textTint.opacity(0.5))

                        Text("\(Int(stats.averageAQI))")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(dominantColor)
                            .monospacedDigit()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(dominantColor.opacity(0.8))
                    }
                }
            }

            Spacer()

            // Expand indicator
            ZStack {
                Circle()
                    .fill(dominantColor.opacity(0.18))
                    .frame(width: activeRoute != nil ? 28 : 32, height: activeRoute != nil ? 28 : 32)
                Circle()
                    .stroke(dominantColor.opacity(0.35), lineWidth: 1)
                    .frame(width: activeRoute != nil ? 28 : 32, height: activeRoute != nil ? 28 : 32)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: activeRoute != nil ? 11 : 12, weight: .heavy))
                    .foregroundColor(dominantColor)
            }
        }
        .padding(activeRoute != nil ? 12 : 14)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: activeRoute != nil ? 12 : 20) {
            Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)
                .padding(.horizontal, 14)

            // Donut Chart + Stats
            HStack(spacing: activeRoute != nil ? 16 : 24) {
                // Donut chart (solo mostrar para grid, no para rutas)
                if activeRoute == nil {
                    donutChartView
                        .frame(width: 120, height: 120)
                }

                // Stats breakdown
                statsBreakdownView
            }
            .padding(.horizontal, 16)

            Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)
                .padding(.horizontal, 14)

            // Level distribution bars
            levelDistributionView
                .padding(.horizontal, 16)

            // Solo mostrar Breathability y Quick Insights cuando NO hay ruta activa
            if activeRoute == nil {
                Divider()
                    .padding(.horizontal, 16)

                // Breathability Index integrado
                breathabilitySection
                    .padding(.horizontal, 16)

                // Quick insights
                quickInsightsView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                // Botón Start Navigation para rutas
                if let startNavigation = onStartNavigation {
                    Divider()
                        .padding(.horizontal, 16)

                    Button(action: {
                        HapticFeedback.medium()
                        startNavigation()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill.viewfinder")
                                .font(.system(size: 14, weight: .heavy))
                            Text("Iniciar navegación")
                                .font(.system(size: 14, weight: .heavy))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundColor(theme.textTint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#10B981").opacity(0.5), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                } else {
                    // Padding bottom más pequeño si no hay botón
                    Color.clear
                        .frame(height: 8)
                }
            }
        }
    }

    // MARK: - Donut Chart

    private var donutChartView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(theme.textTint.opacity(0.08), lineWidth: 20)

            // Animated segments
            if let stats = statistics, animateCharts {
                ForEach(Array(levelSegments.enumerated()), id: \.offset) { index, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(
                            segment.color,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }

            // Center content
            VStack(spacing: 1) {
                if let stats = statistics {
                    Text("\(stats.totalZones)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.textTint)
                        .monospacedDigit()

                    Text("ZONAS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(theme.textTint.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Stats Breakdown

    private var statsBreakdownView: some View {
        VStack(alignment: .leading, spacing: activeRoute != nil ? 8 : 10) {
            Text("DESGLOSE DE LA CALIDAD")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.55))

            if let route = activeRoute, let analysis = route.airQualityAnalysis {
                VStack(spacing: 6) {
                    StatRow(
                        icon: "checkmark.circle.fill",
                        label: "Bueno",
                        count: analysis.goodSegments,
                        color: Color(hex: "#34D399")
                    )
                    StatRow(
                        icon: "leaf.fill",
                        label: "Moderado",
                        count: analysis.moderateSegments,
                        color: Color(hex: "#FBBF24")
                    )
                    StatRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Pobre",
                        count: analysis.poorSegments,
                        color: Color(hex: "#FB923C")
                    )
                    StatRow(
                        icon: "xmark.shield.fill",
                        label: "Dañino",
                        count: analysis.unhealthySegments + analysis.severeSegments + analysis.hazardousSegments,
                        color: Color(hex: "#F87171")
                    )
                }
            } else if let stats = statistics {
                VStack(spacing: 6) {
                    StatRow(
                        icon: "checkmark.circle.fill",
                        label: "Bueno",
                        count: stats.goodCount,
                        color: Color(hex: "#34D399")
                    )
                    StatRow(
                        icon: "leaf.fill",
                        label: "Moderado",
                        count: stats.moderateCount,
                        color: Color(hex: "#FBBF24")
                    )
                    StatRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Pobre",
                        count: stats.poorCount,
                        color: Color(hex: "#FB923C")
                    )
                    StatRow(
                        icon: "xmark.shield.fill",
                        label: "Dañino",
                        count: stats.unhealthyCount + stats.severeCount + stats.hazardousCount,
                        color: Color(hex: "#F87171")
                    )
                }
            }
        }
    }

    // MARK: - Level Distribution

    private var levelDistributionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISTRIBUCIÓN POR NIVEL")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.55))

            if let route = activeRoute, let analysis = route.airQualityAnalysis {
                DistributionBar(
                    segments: [
                        (analysis.goodSegments, Color(hex: "#34D399")),
                        (analysis.moderateSegments, Color(hex: "#FBBF24")),
                        (analysis.poorSegments, Color(hex: "#FB923C")),
                        (analysis.unhealthySegments + analysis.severeSegments + analysis.hazardousSegments, Color(hex: "#F87171"))
                    ],
                    total: analysis.totalSegments,
                    animate: animateCharts
                )
            } else if let stats = statistics {
                DistributionBar(
                    segments: [
                        (stats.goodCount, Color(hex: "#34D399")),
                        (stats.moderateCount, Color(hex: "#FBBF24")),
                        (stats.poorCount, Color(hex: "#FB923C")),
                        (stats.unhealthyCount + stats.severeCount + stats.hazardousCount, Color(hex: "#F87171"))
                    ],
                    total: stats.totalZones,
                    animate: animateCharts
                )
            }
        }
    }

    // MARK: - Breathability Section

    private var breathabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESPIRABILIDAD")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.55))

            if statistics != nil {
                HStack(spacing: 12) {
                    animatedLungsIcon

                    VStack(alignment: .leading, spacing: 3) {
                        Text(breathabilityDescription)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(dominantColor)

                        Text(breathabilityDetail)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(theme.textTint.opacity(0.65))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    breathabilityScoreRing
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(dominantColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(dominantColor.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private var animatedLungsIcon: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(dominantColor.opacity(0.15))
                .frame(width: 52, height: 52)
                .scaleEffect(1.0 + (glowIntensity - 0.3) * 0.3)

            // Lungs icon
            Image(systemName: "lungs.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(dominantColor)
                .scaleEffect(1.0 + (glowIntensity - 0.3) * 0.4)

            // Breathing particles
            ForEach(0..<3) { i in
                Circle()
                    .fill(dominantColor.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .offset(y: -20 - (glowIntensity - 0.3) * 15)
                    .opacity(1.0 - (glowIntensity - 0.3) * 2)
                    .blur(radius: 1)
                    .offset(x: CGFloat(i - 1) * 6)
            }
        }
    }

    private var breathabilityScoreRing: some View {
        ZStack {
            Circle()
                .stroke(theme.textTint.opacity(0.1), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 46, height: 46)

            Circle()
                .trim(from: 0, to: breathabilityScore / 100)
                .stroke(
                    LinearGradient(
                        colors: [dominantColor, dominantColor.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-90))
                .shadow(color: dominantColor.opacity(0.5), radius: 4)

            Text("\(Int(breathabilityScore))")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textTint)
                .monospacedDigit()
        }
    }

    private var breathabilityScore: Double {
        guard let stats = statistics else { return 0 }
        return max(0, min(100, 100 - (stats.averageAQI / 2)))
    }

    private var breathabilityDescription: String {
        guard let stats = statistics else { return "N/A" }
        switch stats.dominantLevel {
        case .good:      return "Excelente"
        case .moderate:  return "Buena"
        case .poor:      return "Regular"
        case .unhealthy: return "Mala"
        case .severe:    return "Muy mala"
        case .hazardous: return "Peligrosa"
        }
    }

    private var breathabilityDetail: String {
        guard let stats = statistics else { return "" }
        switch stats.dominantLevel {
        case .good:      return "Perfecto para respirar afuera"
        case .moderate:  return "Seguro para la mayoría"
        case .poor:      return "Mascarilla para sensibles"
        case .unhealthy: return "Limita la exposición exterior"
        case .severe:    return "Usa mascarilla, reduce actividad"
        case .hazardous: return "Quédate adentro, usa purificadores"
        }
    }

    // MARK: - Quick Insights

    private var quickInsightsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INSIGHTS RÁPIDOS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.55))

            if let stats = statistics {
                HStack(spacing: 10) {
                    InsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: "\(Int(stats.averageAQI))",
                        label: "AQI prom",
                        color: dominantColor
                    )
                    InsightCard(
                        icon: dominantLevelIcon,
                        value: dominantLevelName,
                        label: "Dominante",
                        color: dominantColor
                    )
                }
            }
        }
    }

    // MARK: - Helper Components

    private struct StatRow: View {
    @Environment(\.weatherTheme) private var theme
        let icon: String
        let label: String
        let count: Int
        let color: Color

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(color)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(theme.textTint)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(color.opacity(0.18)))
                    .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.8))
            }
        }
    }

    private struct DistributionBar: View {
    @Environment(\.weatherTheme) private var theme
        let segments: [(Int, Color)]
        let total: Int
        let animate: Bool

        var body: some View {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let percentage = Double(segment.0) / Double(max(total, 1))
                        let width = geometry.size.width * percentage

                        RoundedRectangle(cornerRadius: 4)
                            .fill(segment.1)
                            .frame(width: animate ? width : 0)
                    }
                }
            }
            .frame(height: 12)
        }
    }

    private struct InsightCard: View {
    @Environment(\.weatherTheme) private var theme
        let icon: String
        let value: String
        let label: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(color)

                    Text(value)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.textTint)
                        .monospacedDigit()
                }

                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(theme.textTint.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Computed Properties

    /// AQI a mostrar: ruta si está activa, sino promedio del grid
    private var displayAQI: Double {
        if let route = activeRoute, let analysis = route.airQualityAnalysis {
            return analysis.averageAQI
        }
        return statistics?.averageAQI ?? 0
    }

    /// Nivel de AQI a mostrar
    private var displayLevel: AQILevel {
        if let route = activeRoute {
            return route.averageAQILevel
        }
        return statistics?.dominantLevel ?? .good
    }

    private var dominantColor: Color {
        let level = displayLevel
        switch level {
        case .good:      return Color(hex: "#34D399")
        case .moderate:  return Color(hex: "#FBBF24")
        case .poor:      return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe:    return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }

    private var dominantLevelName: String {
        statistics?.dominantLevel.rawValue ?? "N/A"
    }

    private var dominantLevelIcon: String {
        guard let stats = statistics else { return "questionmark" }
        return stats.dominantLevel.routingIcon
    }

    private var levelSegments: [(start: Double, end: Double, color: Color)] {
        guard let stats = statistics else { return [] }

        var segments: [(Double, Double, Color)] = []
        var currentPosition: Double = 0

        let levels: [(Int, Color)] = [
            (stats.goodCount, Color(hex: "#34D399")),
            (stats.moderateCount, Color(hex: "#FBBF24")),
            (stats.poorCount, Color(hex: "#FB923C")),
            (stats.unhealthyCount + stats.severeCount + stats.hazardousCount, Color(hex: "#F87171"))
        ]

        for level in levels {
            guard level.0 > 0 else { continue }
            let percentage = Double(level.0) / Double(stats.totalZones)
            segments.append((currentPosition, currentPosition + percentage, level.1))
            currentPosition += percentage
        }

        return segments
    }

    // MARK: - Animations

    private func startAnimations() {
        // Glow animation
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.6
        }

        // Chart animation with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateCharts = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Dashboard") {
    ZStack {
        Color.black.opacity(0.05)

        VStack {
            Spacer()

            EnhancedAirQualityDashboard(
                isExpanded: .constant(true),
                statistics: AirQualityGridManager.GridStatistics(
                    totalZones: 49,
                    averageAQI: 78,
                    goodCount: 15,
                    moderateCount: 20,
                    poorCount: 10,
                    unhealthyCount: 3,
                    severeCount: 1,
                    hazardousCount: 0
                ),
                referencePoint: .userLocation,
                activeRoute: nil,
                onStartNavigation: nil
            )
            .frame(maxWidth: 320)
            .padding()

            Spacer()
        }
    }
}
