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
                    .padding(18)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.58)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.78))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
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

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
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

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                .opacity(showContent ? 1 : 0)

            // SECCIÓN 4: Predicción ML
            predictionSection
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
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
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#A78BFA").opacity(0.3),
                                Color(hex: "#7C3AED").opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 28
                        )
                    )
                    .frame(width: 54, height: 54)
                    .blur(radius: 4)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(.white)
            }
            .shadow(color: Color(hex: "#7C3AED").opacity(0.45), radius: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(locationInfo.title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .heavy))
                    Text(locationInfo.distanceFromUser)
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            Button(action: {
                HapticFeedback.light()
                onCancel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subtitle = sanitizedSubtitle {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(hex: "#34D399"))

                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }
            }
        }
    }

    private var airQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Título de sección
            HStack(spacing: 5) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(colorForAQI)
                Text("CALIDAD DEL AIRE · DESTINO")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.55))
            }

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
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(colorForAQI)

                    HStack(spacing: 4) {
                        Image(systemName: locationInfo.healthRisk.icon)
                            .font(.system(size: 9, weight: .heavy))
                        Text(locationInfo.healthRisk.rawValue)
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(colorForRisk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(colorForRisk.opacity(0.18)))
                    .overlay(Capsule().stroke(colorForRisk.opacity(0.4), lineWidth: 1))
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
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(Color(hex: "#3B82F6"))

                Text(locationInfo.healthMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#3B82F6").opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "#3B82F6").opacity(0.3), lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Prediction Section

    private var predictionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            predictionHeader
            predictionTimeline
            predictionBestHint
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#22D3EE").opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#22D3EE").opacity(0.25), lineWidth: 1)
        )
    }

    private var predictionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(Color(hex: "#22D3EE"))
            Text("PREDICCIÓN ML · DESTINO")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private var predictionTimeline: some View {
        HStack(spacing: 8) {
            PredictionTimeSlot(label: "Ahora", aqi: Int(locationInfo.airQuality.aqi), isHighlighted: true)
            predictionArrow
            PredictionTimeSlot(label: "+1h", aqi: estimatedAQI(hoursAhead: 1), isHighlighted: false)
            predictionArrow
            PredictionTimeSlot(label: "+3h", aqi: estimatedAQI(hoursAhead: 3), isHighlighted: false)
        }
        .frame(maxWidth: .infinity)
    }

    private var predictionArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 8, weight: .heavy))
            .foregroundColor(.white.opacity(0.35))
    }

    private var predictionBestHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.fill")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color(hex: "#FBBF24"))
            Text("Mejor salida: en la próxima hora")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "#FBBF24").opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#FBBF24").opacity(0.3), lineWidth: 1)
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
        VStack(spacing: 8) {
            // Botón primario: Calcular Ruta
            Button(action: {
                HapticFeedback.medium()
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
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14, weight: .heavy))
                    Text("Calcular ruta")
                        .font(.system(size: 14, weight: .heavy))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "#3B82F6").opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)

            // Botón secundario: Ver Calidad del Aire
            Button(action: {
                HapticFeedback.light()
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
                HStack(spacing: 8) {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 13, weight: .heavy))
                    Text("Ver calidad del aire")
                        .font(.system(size: 13, weight: .heavy))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#22D3EE").opacity(0.55),
                                         Color.white.opacity(0.1)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isAirQualityPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAirQualityPressed)
        }
    }

    // MARK: - Color Helpers

    private var colorForAQI: Color {
        switch locationInfo.aqiLevel {
        case .good:      return Color(hex: "#34D399")
        case .moderate:  return Color(hex: "#FBBF24")
        case .poor:      return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe:    return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }

    private var colorForRisk: Color {
        switch locationInfo.healthRisk {
        case .low:      return Color(hex: "#34D399")
        case .medium:   return Color(hex: "#FBBF24")
        case .high:     return Color(hex: "#FB923C")
        case .veryHigh: return Color(hex: "#F87171")
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
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.55))

            Text("\(aqi)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(aqiColor)
                .monospacedDigit()

            Circle()
                .fill(aqiColor)
                .frame(width: 6, height: 6)
                .shadow(color: aqiColor.opacity(isHighlighted ? 0.6 : 0), radius: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? aqiColor.opacity(0.15) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHighlighted ? aqiColor.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var aqiColor: Color {
        switch aqi {
        case 0..<51:   return Color(hex: "#34D399")
        case 51..<101: return Color(hex: "#FBBF24")
        case 101..<151: return Color(hex: "#FB923C")
        default:        return Color(hex: "#F87171")
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
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text(unit)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
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
