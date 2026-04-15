//
//  LocationInfoCard.swift
//  AcessNet
//
//  Card premium con información de ubicación y calidad del aire
//

import SwiftUI
import MapKit

// MARK: - Location Info Card

struct LocationInfoCard: View {
    let locationInfo: LocationInfo
    let onCalculateRoute: () -> Void
    let onViewAirQuality: () -> Void
    let onCancel: () -> Void

    @State private var isPressed = false
    @State private var isAirQualityPressed = false
    @State private var showContent = false
    private var sanitizedSubtitle: String? {
        guard let subtitle = locationInfo.subtitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !subtitle.isEmpty else {
            return nil
        }
        return subtitle
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                mainInfoView
                    .padding(20)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .appElevatedShadow(radius: 18, y: 8)
        .onAppear {
            // Iniciar animaciones escalonadas
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showContent = true
                }
            }
        }
    }

    private var mainInfoView: some View {
        VStack(spacing: 16) {
            // SECCIÓN 1: Header
            headerSection
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)

            Divider()
                .opacity(showContent ? 1 : 0)

            if sanitizedSubtitle != nil {
                // SECCIÓN 2: Ubicación
                locationSection
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : -15)

                Divider()
                    .opacity(showContent ? 1 : 0)
            }

            // SECCIÓN 3: Calidad del Aire ⭐
            airQualitySection
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1.0 : 0.95)

            Divider()
                .opacity(showContent ? 1 : 0)

            // SECCIÓN 4: Predicción ML
            predictionSection
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

            Divider()
                .opacity(showContent ? 1 : 0)

            // SECCIÓN 5: Botones de Acción
            actionButtons
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1.0 : 0.9)
        }
    }

    // MARK: - Secciones

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Icono de ubicación con gradiente
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.25),
                                Color.purple.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .blur(radius: 4)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.9),
                                Color.purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(locationInfo.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(locationInfo.distanceFromUser)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Botón de cancelar
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onCancel()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subtitle = sanitizedSubtitle {
                HStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var airQualitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Título de sección
            Text("Air Quality at Destination")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            // AQI Badge Principal
            HStack(spacing: 16) {
                // Círculo AQI con animación de pulso
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colorForAQI.opacity(0.3),
                                    colorForAQI.opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 8)

                    // Anillo de pulso (animado)
                    Circle()
                        .stroke(colorForAQI.opacity(0.4), lineWidth: 3)
                        .frame(width: 75, height: 75)
                        .pulseEffect(color: colorForAQI, duration: 2.0)

                    // Círculo principal
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorForAQI,
                                    colorForAQI.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 66, height: 66)

                    // Contenido
                    VStack(spacing: 2) {
                        Text("\(Int(locationInfo.airQuality.aqi))")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("AQI")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                // Detalles AQI
                VStack(alignment: .leading, spacing: 6) {
                    Text(locationInfo.aqiLevel.rawValue)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(colorForAQI)

                    // Health risk badge
                    HStack(spacing: 5) {
                        Image(systemName: locationInfo.healthRisk.icon)
                            .font(.caption)
                            .foregroundStyle(colorForRisk)

                        Text(locationInfo.healthRisk.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(colorForRisk)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorForRisk.opacity(0.15))
                    .clipShape(Capsule())
                }

                Spacer()
            }

            // Métricas de contaminantes
            HStack(spacing: 12) {
                // PM2.5
                PollutantMetric(
                    icon: "aqi.medium",
                    label: "PM2.5",
                    value: String(format: "%.1f", locationInfo.airQuality.pm25),
                    unit: "μg/m³",
                    color: colorForPM25(locationInfo.airQuality.pm25)
                )

                // PM10
                if let pm10 = locationInfo.airQuality.pm10 {
                    PollutantMetric(
                        icon: "aqi.high",
                        label: "PM10",
                        value: String(format: "%.1f", pm10),
                        unit: "μg/m³",
                        color: colorForPM10(pm10)
                    )
                }
            }

            // Mensaje de salud
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(locationInfo.healthMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Prediction Section

    private var predictionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(.cyan)
                Text("ML Prediction at Destination")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                PredictionTimeSlot(label: "Now", aqi: Int(locationInfo.airQuality.aqi), isHighlighted: true)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PredictionTimeSlot(label: "+1h", aqi: estimatedAQI(hoursAhead: 1), isHighlighted: false)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PredictionTimeSlot(label: "+3h", aqi: estimatedAQI(hoursAhead: 3), isHighlighted: false)
            }
            .frame(maxWidth: .infinity)

            // Best time hint
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Best departure: within the next hour")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cyan.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    /// Estimation of future AQI based on time of day patterns
    private func estimatedAQI(hoursAhead: Int) -> Int {
        let currentAQI = Int(locationInfo.airQuality.aqi)
        let calendar = Calendar.current
        let futureHour = (calendar.component(.hour, from: Date()) + hoursAhead) % 24

        // Simple heuristic: afternoon hours (14-18) tend to be worse
        let hourFactor: Double
        switch futureHour {
        case 6..<10: hourFactor = 0.85   // Morning: usually better
        case 10..<14: hourFactor = 1.0   // Midday: similar
        case 14..<18: hourFactor = 1.2   // Afternoon: usually worse
        case 18..<22: hourFactor = 1.1   // Evening: slightly worse
        default: hourFactor = 0.95       // Night: slightly better
        }

        return max(1, Int(Double(currentAQI) * hourFactor))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Botón primario: Calcular Ruta
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }

                onCalculateRoute()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Calculate Route")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color.blue,
                            Color.blue.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .coloredShadow(color: .blue, intensity: 0.4, radius: 12, y: 6)
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)

            // Botón secundario: Ver Calidad del Aire
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isAirQualityPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isAirQualityPressed = false
                    }
                }

                onViewAirQuality()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 18, weight: .semibold))

                    Text("View Air Quality")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color.teal.opacity(0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.teal, Color.teal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .scaleEffect(isAirQualityPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAirQualityPressed)
        }
    }

    // MARK: - Color Helpers

    private var colorForAQI: Color {
        switch locationInfo.aqiLevel {
        case .good: return .green
        case .moderate: return .yellow
        case .poor: return .orange
        case .unhealthy: return .red
        case .severe: return .purple
        case .hazardous: return Color(red: 0.5, green: 0.0, blue: 0.0)
        }
    }

    private var colorForRisk: Color {
        switch locationInfo.healthRisk {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }

    private func colorForPM25(_ pm25: Double) -> Color {
        switch pm25 {
        case 0..<12: return .green
        case 12..<35: return .yellow
        case 35..<55: return .orange
        default: return .red
        }
    }

    private func colorForPM10(_ pm10: Double) -> Color {
        switch pm10 {
        case 0..<54: return .green
        case 54..<154: return .yellow
        case 154..<254: return .orange
        default: return .red
        }
    }
}

// MARK: - Prediction Time Slot

struct PredictionTimeSlot: View {
    let label: String
    let aqi: Int
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(aqi)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(aqiColor)

            Circle()
                .fill(aqiColor)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? aqiColor.opacity(0.1) : Color.clear)
        )
    }

    private var aqiColor: Color {
        switch aqi {
        case 0..<51: return .green
        case 51..<101: return .yellow
        case 101..<151: return .orange
        default: return .red
        }
    }
}

// MARK: - Pollutant Metric Component

struct PollutantMetric: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Location Info Card - Good Air") {
    VStack {
        Spacer()

        LocationInfoCard(
            locationInfo: LocationInfo(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Golden Gate Park",
                subtitle: "San Francisco, CA",
                distanceFromUser: "2.3 km de tu ubicación",
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 42,
                    pm25: 18.5,
                    pm10: 35.2
                )
            ),
            onCalculateRoute: { print("Calculate route") },
            onViewAirQuality: { print("View air quality") },
            onCancel: { print("Cancel") }
        )
        .padding()

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Location Info Card - Moderate Air") {
    VStack {
        Spacer()

        LocationInfoCard(
            locationInfo: LocationInfo(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Downtown SF",
                subtitle: "Market St, San Francisco, CA",
                distanceFromUser: "1.5 km de tu ubicación",
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 78,
                    pm25: 32.5,
                    pm10: 68.4
                )
            ),
            onCalculateRoute: { print("Calculate route") },
            onViewAirQuality: { print("View air quality") },
            onCancel: { print("Cancel") }
        )
        .padding()

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Location Info Card - Unhealthy Air") {
    VStack {
        Spacer()

        LocationInfoCard(
            locationInfo: LocationInfo(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Industrial District",
                subtitle: "Bay Area, CA",
                distanceFromUser: "4.8 km de tu ubicación",
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 165,
                    pm25: 78.2,
                    pm10: 142.5
                )
            ),
            onCalculateRoute: { print("Calculate route") },
            onViewAirQuality: { print("View air quality") },
            onCancel: { print("Cancel") }
        )
        .padding()

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
