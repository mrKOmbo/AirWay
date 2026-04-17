//
//  HeroAirQualityCard.swift
//  AcessNet
//
//  Card cinematográfica estilo Apple con diseño premium
//

import SwiftUI
import CoreLocation

// MARK: - Hero Air Quality Card

/// Card de detalles con diseño cinematográfico premium
struct HeroAirQualityCard: View {
    let zone: AirQualityZone
    let onDismiss: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.9
    @State private var showRecommendations: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            heroHeader

            ScrollView {
                VStack(spacing: 18) {
                    mainAQISection
                    pollutantsGrid
                    healthImpactSection
                    recommendationsSection
                    actionsSection
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .background(
                Color(hex: "#0A0F1A").overlay(.ultraThinMaterial)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(zone.color.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: zone.color.opacity(0.45), radius: 25, y: 12)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        .scaleEffect(contentScale)
        .opacity(headerOpacity)
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    zone.color,
                    zone.color.opacity(0.8),
                    zone.color.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated blob pattern
            GeometryReader { geometry in
                ForEach(0..<3) { i in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(
                            x: CGFloat(i) * 80 - 80,
                            y: CGFloat(i) * 40 - 60
                        )
                        .blur(radius: 20)
                }
            }

            // Header content
            VStack(spacing: 16) {
                HStack {
                    Button(action: onDismiss) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // Share button
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()

                // Main AQI value
                VStack(spacing: 8) {
                    Text("AIR QUALITY INDEX")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(2)

                    Text("\(Int(zone.airQuality.aqi))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Image(systemName: zone.icon)
                            .font(.system(size: 16, weight: .semibold))

                        Text(zone.levelDescription)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.95))
                }

                Spacer()
            }
            .padding(20)
        }
        .frame(height: 280)
    }

    // MARK: - Main AQI Section

    private var mainAQISection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Air Quality Breakdown")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // AQI scale visualization
            AQIScaleView(currentAQI: zone.airQuality.aqi)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Pollutants Grid

    private var pollutantsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pollutant Levels")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PollutantCard(
                    icon: "aqi.medium",
                    name: "PM2.5",
                    value: zone.airQuality.pm25,
                    unit: "μg/m³",
                    color: zone.color,
                    safeLimit: 12.0
                )

                if let pm10 = zone.airQuality.pm10 {
                    PollutantCard(
                        icon: "aqi.high",
                        name: "PM10",
                        value: pm10,
                        unit: "μg/m³",
                        color: zone.color,
                        safeLimit: 50.0
                    )
                }

                if let no2 = zone.airQuality.no2 {
                    PollutantCard(
                        icon: "cloud.fill",
                        name: "NO₂",
                        value: no2,
                        unit: "ppb",
                        color: zone.color,
                        safeLimit: 40.0
                    )
                }

                if let o3 = zone.airQuality.o3 {
                    PollutantCard(
                        icon: "sun.max.fill",
                        name: "O₃",
                        value: o3,
                        unit: "ppb",
                        color: zone.color,
                        safeLimit: 60.0
                    )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Health Impact

    private var healthImpactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(zone.color)

                Text("Health Impact")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(zone.level.extendedHealthMessage)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)

            // Health risk indicator
            HealthRiskIndicator(level: zone.level)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)

                Text("Recommendations")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            ForEach(recommendationsForLevel, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)

                    Text(recommendation)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            ActionButton(
                icon: "map.fill",
                title: "Find Cleaner Route",
                color: .blue,
                action: {}
            )

            ActionButton(
                icon: "bell.badge.fill",
                title: "Notify When Air Improves",
                color: .purple,
                action: {}
            )
        }
    }

    // MARK: - Helper Components

    private struct PollutantCard: View {
        let icon: String
        let name: String
        let value: Double
        let unit: String
        let color: Color
        let safeLimit: Double

        var isAboveLimit: Bool {
            value > safeLimit
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)

                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if isAboveLimit {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", value))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Text("Safe: <\(Int(safeLimit)) \(unit)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private struct AQIScaleView: View {
        let currentAQI: Double

        var body: some View {
            VStack(spacing: 12) {
                // Scale bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background segments
                        HStack(spacing: 2) {
                            Rectangle().fill(Color(hex: "#34D399"))
                            Rectangle().fill(Color(hex: "#FBBF24"))
                            Rectangle().fill(Color(hex: "#FB923C"))
                            Rectangle().fill(Color(hex: "#F87171"))
                            Rectangle().fill(Color(hex: "#A78BFA"))
                            Rectangle().fill(Color(hex: "#881337"))
                        }
                        .frame(height: 10)
                        .clipShape(Capsule())

                        // Current position indicator
                        let position = min(currentAQI / 300.0, 1.0) * geometry.size.width

                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.35), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .offset(x: position - 11)
                    }
                }
                .frame(height: 24)

                // Scale labels
                HStack {
                    Text("0")
                    Spacer()
                    Text("50")
                    Spacer()
                    Text("100")
                    Spacer()
                    Text("150")
                    Spacer()
                    Text("200")
                    Spacer()
                    Text("300+")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private struct HealthRiskIndicator: View {
        let level: AQILevel

        var riskLevel: String {
            switch level {
            case .good, .moderate: return "Low Risk"
            case .poor: return "Moderate Risk"
            case .unhealthy: return "High Risk"
            case .severe, .hazardous: return "Very High Risk"
            }
        }

        var riskColor: Color {
            switch level {
            case .good, .moderate: return .green
            case .poor: return .orange
            case .unhealthy: return .red
            case .severe, .hazardous: return .purple
            }
        }

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(riskColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(riskColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(riskLevel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("For sensitive groups")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()
            }
            .padding(16)
            .background(riskColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct ActionButton: View {
        let icon: String
        let title: String
        let color: Color
        let action: () -> Void

        @State private var isPressed = false

        var body: some View {
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                action()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }

    // MARK: - Computed Properties

    private var recommendationsForLevel: [String] {
        switch zone.level {
        case .good:
            return [
                "Perfect conditions for outdoor activities",
                "All population groups can enjoy normal activities",
                "Great time for exercise and sports"
            ]
        case .moderate:
            return [
                "Air quality is acceptable for most people",
                "Sensitive individuals should consider limiting prolonged outdoor exertion",
                "Good time for most outdoor activities"
            ]
        case .poor:
            return [
                "Sensitive groups should reduce prolonged outdoor exertion",
                "Consider wearing a mask if spending extended time outdoors",
                "Keep windows closed during peak hours"
            ]
        case .unhealthy:
            return [
                "Everyone should limit prolonged outdoor exertion",
                "Wear a N95 or KN95 mask when outdoors",
                "Keep windows and doors closed",
                "Use air purifiers indoors"
            ]
        case .severe, .hazardous:
            return [
                "Avoid all outdoor activities",
                "Stay indoors with windows closed",
                "Use air purifiers with HEPA filters",
                "Wear N95/KN95 masks even for brief outdoor exposure"
            ]
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            contentScale = 1.0
            headerOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Hero Card") {
    ZStack {
        Color.black.opacity(0.3)

        HeroAirQualityCard(
            zone: AirQualityZone(
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    aqi: 125,
                    pm25: 55.5,
                    pm10: 88.2,
                    no2: 45.0,
                    o3: 72.0
                )
            ),
            onDismiss: {}
        )
        .padding(20)
    }
}
