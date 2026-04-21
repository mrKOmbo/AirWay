//
//  LocationInfoSheet.swift
//  AcessNet
//
//  Redistribución de LocationInfoCard usando MapBottomSheet.
//  Progressive disclosure: el contenido visible depende del detent actual,
//  para que el mapa permanezca visible mientras el usuario decide.
//
//  PEEK (120pt):  ícono · nombre · AQI chip · CTA primaria.
//  MEDIUM (45%):  + AQI hero · PM2.5 / PM10 · CTA secundaria.
//  LARGE (90%):   + mensaje salud · predicción ML 3 slots · hint mejor hora.
//

import SwiftUI

// MARK: - Location Info Sheet (new)

struct LocationInfoSheet: View {
    let locationInfo: LocationInfo
    @Binding var detent: MapSheetDetent
    let onCalculateRoute: () -> Void
    let onViewAirQuality: () -> Void
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        MapBottomSheet(
            detent: $detent,
            style: .info,
            content: { content },
            onDismiss: onCancel
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            // PEEK — siempre visible
            peekSection
                .padding(.horizontal, MapSheetTokens.contentHorizontal)
                .padding(.bottom, detent == .peek ? MapSheetTokens.contentBottom : MapSheetTokens.sectionSpacing)

            // MEDIUM y LARGE — fade-in progresivo
            if detent.rank >= MapSheetDetent.medium.rank {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: MapSheetTokens.sectionSpacing) {
                        divider
                        airQualitySection
                        if detent.rank >= MapSheetDetent.large.rank {
                            divider
                            healthMessageSection
                            divider
                            predictionSection
                        }
                    }
                    .padding(.horizontal, MapSheetTokens.contentHorizontal)
                    .padding(.bottom, MapSheetTokens.contentBottom)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }
        }
        .animation(MapSheetTokens.detentSpring, value: detent)
    }

    // MARK: - PEEK Section

    private var peekSection: some View {
        VStack(spacing: MapSheetTokens.elementSpacing + 4) {
            // Row 1: Ícono · Nombre · Close
            HStack(spacing: 12) {
                locationIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationInfo.title)
                        .font(MapSheetTypography.title)
                        .foregroundStyle(MapSheetColor.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .heavy))
                        Text(locationInfo.distanceFromUser)
                            .font(MapSheetTypography.caption)
                    }
                    .foregroundStyle(MapSheetColor.textSecondary)
                }

                Spacer(minLength: 0)

                closeButton
            }

            // Row 2: AQI chip compacto (siempre visible, incluso en peek)
            aqiCompactChip

            // Row 3: CTA primaria (siempre visible)
            primaryCTA
        }
    }

    // MARK: - Location Icon

    private var locationIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [MapSheetColor.ml, MapSheetColor.mlDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
        }
        .shadow(color: MapSheetColor.mlDeep.opacity(0.4), radius: 6, y: 2)
    }

    // MARK: - Close Button (44x44 touch target)

    private var closeButton: some View {
        Button {
            HapticFeedback.light()
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: MapSheetTokens.closeIconSize, weight: .heavy))
                .foregroundStyle(MapSheetColor.textSecondary)
                .frame(width: MapSheetTokens.closeButtonSize,
                       height: MapSheetTokens.closeButtonSize)
                .background(Circle().fill(MapSheetColor.fillMedium))
                .overlay(Circle().stroke(MapSheetColor.strokeSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - AQI Compact Chip (peek)

    private var aqiCompactChip: some View {
        HStack(spacing: 10) {
            // Mini AQI dot + value
            HStack(spacing: 6) {
                Circle()
                    .fill(colorForAQI)
                    .frame(width: 10, height: 10)
                    .shadow(color: colorForAQI, radius: 4)

                Text("\(Int(locationInfo.airQuality.aqi))")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(MapSheetColor.textPrimary)
                    .monospacedDigit()

                Text("AQI")
                    .font(MapSheetTypography.caption)
                    .foregroundStyle(MapSheetColor.textTertiary)
            }

            Rectangle()
                .fill(MapSheetColor.separator)
                .frame(width: 1, height: 16)

            Text(locationInfo.aqiLevel.rawValue)
                .font(MapSheetTypography.label)
                .foregroundStyle(colorForAQI)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Risk pill
            HStack(spacing: 4) {
                Image(systemName: locationInfo.healthRisk.icon)
                    .font(.system(size: 9, weight: .heavy))
                Text(locationInfo.healthRisk.rawValue)
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(colorForRisk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(colorForRisk.opacity(0.18)))
            .overlay(Capsule().stroke(colorForRisk.opacity(0.4), lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MapSheetColor.fillSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MapSheetColor.strokeSubtle, lineWidth: 1)
        )
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        Button {
            HapticFeedback.medium()
            onCalculateRoute()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text("Calcular ruta")
                    .font(.system(size: 14, weight: .heavy))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        MapSheetColor.actionPrimary,
                        MapSheetColor.actionPrimaryDeep
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: MapSheetColor.actionPrimary.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(MapSheetColor.separator)
            .frame(height: 1)
    }

    // MARK: - AQI Section (medium+)

    private var airQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionOverline(
                icon: "aqi.medium",
                iconColor: colorForAQI,
                text: "CALIDAD DEL AIRE · DESTINO"
            )

            // Hero AQI circle + level
            HStack(spacing: 16) {
                aqiHeroCircle

                VStack(alignment: .leading, spacing: 6) {
                    Text(locationInfo.aqiLevel.rawValue)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(colorForAQI)

                    Text("\(Int(locationInfo.airQuality.aqi)) AQI")
                        .font(MapSheetTypography.caption)
                        .foregroundStyle(MapSheetColor.textTertiary)

                    HStack(spacing: 4) {
                        Image(systemName: locationInfo.healthRisk.icon)
                            .font(.system(size: 9, weight: .heavy))
                        Text(locationInfo.healthRisk.rawValue)
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundStyle(colorForRisk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(colorForRisk.opacity(0.18)))
                    .overlay(Capsule().stroke(colorForRisk.opacity(0.4), lineWidth: 1))
                }

                Spacer(minLength: 0)
            }

            // Pollutant metrics
            HStack(spacing: 10) {
                pollutantChip(
                    label: "PM2.5",
                    value: String(format: "%.1f", locationInfo.airQuality.pm25),
                    unit: "μg/m³",
                    color: colorForPM25(locationInfo.airQuality.pm25)
                )

                if let pm10 = locationInfo.airQuality.pm10 {
                    pollutantChip(
                        label: "PM10",
                        value: String(format: "%.1f", pm10),
                        unit: "μg/m³",
                        color: colorForPM10(pm10)
                    )
                }
            }

            // Secondary CTA
            secondaryCTA
        }
    }

    // MARK: - AQI Hero Circle

    private var aqiHeroCircle: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            colorForAQI.opacity(0.3),
                            colorForAQI.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 25,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .blur(radius: 6)

            // Ring
            Circle()
                .stroke(colorForAQI.opacity(0.35), lineWidth: 2)
                .frame(width: 72, height: 72)

            // Fill
            Circle()
                .fill(
                    LinearGradient(
                        colors: [colorForAQI, colorForAQI.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)

            Text("\(Int(locationInfo.airQuality.aqi))")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Pollutant Chip

    private func pollutantChip(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(MapSheetTypography.caption)
                    .foregroundStyle(MapSheetColor.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(MapSheetColor.textPrimary)
                    .monospacedDigit()

                Text(unit)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(MapSheetColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MapSheetColor.fillSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MapSheetColor.strokeSubtle, lineWidth: 1)
        )
    }

    // MARK: - Secondary CTA

    private var secondaryCTA: some View {
        Button {
            HapticFeedback.light()
            onViewAirQuality()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 13, weight: .heavy))
                Text("Ver calidad del aire")
                    .font(.system(size: 13, weight: .heavy))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MapSheetColor.fillMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                MapSheetColor.accent.opacity(0.55),
                                MapSheetColor.strokeSubtle
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Health Message (large)

    private var healthMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionOverline(
                icon: "heart.text.square.fill",
                iconColor: MapSheetColor.accent,
                text: "RECOMENDACIÓN"
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(MapSheetColor.actionPrimary)
                    .padding(.top, 1)

                Text(locationInfo.healthMessage)
                    .font(MapSheetTypography.body)
                    .foregroundStyle(MapSheetColor.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MapSheetColor.actionPrimary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MapSheetColor.actionPrimary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Prediction Section (large)

    private var predictionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionOverline(
                icon: "brain.head.profile",
                iconColor: MapSheetColor.accent,
                text: "PREDICCIÓN ML · DESTINO"
            )

            HStack(spacing: 8) {
                predictionSlot(label: "Ahora", aqi: Int(locationInfo.airQuality.aqi), highlighted: true)
                predictionArrow
                predictionSlot(label: "+1h", aqi: estimatedAQI(hoursAhead: 1), highlighted: false)
                predictionArrow
                predictionSlot(label: "+3h", aqi: estimatedAQI(hoursAhead: 3), highlighted: false)
            }

            // Best-hour hint
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(MapSheetColor.aqiModerate)
                Text("Mejor salida: en la próxima hora")
                    .font(MapSheetTypography.label)
                    .foregroundStyle(MapSheetColor.textPrimary.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MapSheetColor.aqiModerate.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MapSheetColor.aqiModerate.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var predictionArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(MapSheetColor.textTertiary)
    }

    private func predictionSlot(label: String, aqi: Int, highlighted: Bool) -> some View {
        let color = colorForAQIValue(aqi)
        return VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(MapSheetColor.textTertiary)

            Text("\(aqi)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(highlighted ? 0.6 : 0), radius: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(highlighted ? color.opacity(0.15) : MapSheetColor.fillSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(highlighted ? color.opacity(0.45) : MapSheetColor.strokeSubtle, lineWidth: 1)
        )
    }

    // MARK: - Section Overline Helper

    private func sectionOverline(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(iconColor)
            Text(text)
                .font(MapSheetTypography.overline)
                .tracking(MapSheetTypography.overlineTracking)
                .foregroundStyle(MapSheetColor.textTertiary)
        }
    }

    // MARK: - Estimation Heuristic (same as legacy)

    private func estimatedAQI(hoursAhead: Int) -> Int {
        let currentAQI = Int(locationInfo.airQuality.aqi)
        let calendar = Calendar.current
        let futureHour = (calendar.component(.hour, from: Date()) + hoursAhead) % 24

        let hourFactor: Double
        switch futureHour {
        case 6..<10:  hourFactor = 0.85
        case 10..<14: hourFactor = 1.00
        case 14..<18: hourFactor = 1.20
        case 18..<22: hourFactor = 1.10
        default:      hourFactor = 0.95
        }

        return max(1, Int(Double(currentAQI) * hourFactor))
    }

    // MARK: - Color Helpers

    private var colorForAQI: Color {
        colorForAQILevel(locationInfo.aqiLevel)
    }

    private func colorForAQILevel(_ level: AQILevel) -> Color {
        switch level {
        case .good:      return MapSheetColor.aqiGood
        case .moderate:  return MapSheetColor.aqiModerate
        case .poor:      return MapSheetColor.aqiPoor
        case .unhealthy: return MapSheetColor.aqiUnhealthy
        case .severe:    return MapSheetColor.aqiSevere
        case .hazardous: return MapSheetColor.aqiHazardous
        }
    }

    private func colorForAQIValue(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<51:    return MapSheetColor.aqiGood
        case 51..<101:  return MapSheetColor.aqiModerate
        case 101..<151: return MapSheetColor.aqiPoor
        case 151..<201: return MapSheetColor.aqiUnhealthy
        case 201..<301: return MapSheetColor.aqiSevere
        default:        return MapSheetColor.aqiHazardous
        }
    }

    private var colorForRisk: Color {
        switch locationInfo.healthRisk {
        case .low:      return MapSheetColor.aqiGood
        case .medium:   return MapSheetColor.aqiModerate
        case .high:     return MapSheetColor.aqiPoor
        case .veryHigh: return MapSheetColor.aqiUnhealthy
        }
    }

    private func colorForPM25(_ pm25: Double) -> Color {
        switch pm25 {
        case 0..<12:  return MapSheetColor.aqiGood
        case 12..<35: return MapSheetColor.aqiModerate
        case 35..<55: return MapSheetColor.aqiPoor
        default:      return MapSheetColor.aqiUnhealthy
        }
    }

    private func colorForPM10(_ pm10: Double) -> Color {
        switch pm10 {
        case 0..<54:    return MapSheetColor.aqiGood
        case 54..<154:  return MapSheetColor.aqiModerate
        case 154..<254: return MapSheetColor.aqiPoor
        default:        return MapSheetColor.aqiUnhealthy
        }
    }
}

// MARK: - Scale Button Style (press feedback)

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
