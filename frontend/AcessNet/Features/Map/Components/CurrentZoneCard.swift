//
//  CurrentZoneCard.swift
//  AcessNet
//
//  Card que muestra la zona de calidad del aire actual durante navegación
//

import SwiftUI
import CoreLocation

// MARK: - Current Zone Card

struct CurrentZoneCard: View {
    @Environment(\.weatherTheme) private var theme
    let zone: AirQualityZone?

    var body: some View {
        HStack(spacing: 14) {
            aqiBadgeLeft
                .frame(width: 80)

            Rectangle()
                .fill(theme.textTint.opacity(0.1))
                .frame(width: 1, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: zone?.icon ?? "aqi.medium")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(zone?.color ?? .gray)

                    Text(zone?.level.rawValue ?? "Desconocido")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(theme.textTint)
                }

                HStack(spacing: 6) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.55))
                    Text("PM2.5: \(Int(zone?.airQuality.pm25 ?? 0)) µg/m³")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.75))
                        .monospacedDigit()
                }

                if let zone = zone {
                    HStack(spacing: 4) {
                        Image(systemName: healthIcon(for: zone.level))
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(healthColor(for: zone.level))
                        Text(healthMessage(for: zone.level))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(healthColor(for: zone.level))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
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
                .stroke(
                    LinearGradient(
                        colors: [(zone?.color ?? .gray).opacity(0.5), .white.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: (zone?.color ?? .black).opacity(0.3), radius: 12, y: 5)
    }

    private var aqiBadgeLeft: some View {
        let aqi = Int(zone?.airQuality.aqi ?? 0)
        let color = zone?.color ?? .white
        return VStack(spacing: 2) {
            Text("\(aqi)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .shadow(color: color.opacity(0.5), radius: 6)

            Text("AQI")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(theme.textTint.opacity(0.55))
        }
    }

    // MARK: - Helper Methods

    private func healthIcon(for level: AQILevel) -> String {
        switch level {
        case .good:
            return "checkmark.circle.fill"
        case .moderate:
            return "exclamationmark.circle.fill"
        case .poor, .unhealthy:
            return "exclamationmark.triangle.fill"
        case .severe, .hazardous:
            return "xmark.octagon.fill"
        }
    }

    private func healthColor(for level: AQILevel) -> Color {
        switch level {
        case .good:      return Color(hex: "#34D399")
        case .moderate:  return Color(hex: "#FBBF24")
        case .poor:      return Color(hex: "#FB923C")
        case .unhealthy: return Color(hex: "#F87171")
        case .severe:    return Color(hex: "#A78BFA")
        case .hazardous: return Color(hex: "#881337")
        }
    }

    private func healthMessage(for level: AQILevel) -> String {
        switch level {
        case .good:      return "Seguro para todos"
        case .moderate:  return "Calidad aceptable"
        case .poor:      return "Afecta a sensibles"
        case .unhealthy: return "Afecta a todos"
        case .severe:    return "Alerta de salud"
        case .hazardous: return "Condiciones de emergencia"
        }
    }
}

// MARK: - Empty State Card

struct EmptyZoneCard: View {
    @Environment(\.weatherTheme) private var theme
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.textTint.opacity(0.08))
                    .frame(width: 44, height: 44)
                ProgressView().tint(Color(hex: "#22D3EE"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Cargando calidad del aire…")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(theme.textTint)

                Text("Obteniendo datos de la zona")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.55))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.textTint.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
}

// MARK: - Compact Zone Indicator (para vista pequeña)

struct CompactZoneIndicator: View {
    @Environment(\.weatherTheme) private var theme
    let zone: AirQualityZone?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(zone?.color ?? .gray)
                .frame(width: 10, height: 10)
                .shadow(color: (zone?.color ?? .gray).opacity(0.6), radius: 3)

            Text("\(Int(zone?.airQuality.aqi ?? 0))")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(zone?.color ?? .white)
                .monospacedDigit()

            Text(zone?.level.rawValue ?? "Desconocido")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.65))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(
            Capsule()
                .strokeBorder(zone?.strokeColor ?? .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Preview

#Preview("Current Zone Card") {
    VStack(spacing: 20) {
        Text("Current Zone Cards")
            .font(.title2.bold())
            .padding()

        // Good Air Quality
        CurrentZoneCard(zone: AirQualityZone(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 500,
            airQuality: AirQualityPoint(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                aqi: 45,
                pm25: 10.5,
                pm10: 18.2,
                timestamp: Date()
            )
        ))

        // Moderate Air Quality
        CurrentZoneCard(zone: AirQualityZone(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 500,
            airQuality: AirQualityPoint(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                aqi: 85,
                pm25: 35.5,
                pm10: 45.2,
                timestamp: Date()
            )
        ))

        // Unhealthy Air Quality
        CurrentZoneCard(zone: AirQualityZone(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 500,
            airQuality: AirQualityPoint(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                aqi: 165,
                pm25: 75.5,
                pm10: 95.2,
                timestamp: Date()
            )
        ))

        Divider()

        // Empty state
        EmptyZoneCard()

        Divider()

        // Compact indicator
        HStack(spacing: 12) {
            CompactZoneIndicator(zone: AirQualityZone(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radius: 500,
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 45,
                    pm25: 10.5,
                    pm10: 18.2,
                    timestamp: Date()
                )
            ))

            CompactZoneIndicator(zone: AirQualityZone(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radius: 500,
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 125,
                    pm25: 55.5,
                    pm10: 65.2,
                    timestamp: Date()
                )
            ))
        }

        Spacer()
    }
    .padding()
}
