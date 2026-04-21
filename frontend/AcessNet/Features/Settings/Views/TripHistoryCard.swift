//
//  TripHistoryCard.swift
//  AcessNet
//
//  Resumen de telemetría guardada (acumulados + últimos viajes).
//  Vive en el Hub de GasolinaMeter. La grabación en vivo se hace desde el mapa;
//  esta card es el archivo histórico.
//

import SwiftUI

struct TripHistoryCard: View {
    @ObservedObject private var service: DrivingTelemetryService = .shared
    let theme: WeatherTheme

    /// Handler para abrir la vista completa de historial (TripRecorderView).
    let onOpen: () -> Void

    /// Handler para ver el summary de un viaje específico.
    let onSelectTrip: (TripTelemetry) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if service.pastTrips.isEmpty {
                emptyState
            } else {
                totalsRow
                divider
                tripList
            }
        }
        .padding(16)
        .glassHistoryCard(theme: theme)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EF4444").opacity(0.35))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform.path.ecg")
                    .font(.callout)
                    .foregroundColor(theme.textTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Historial de viajes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textTint)
                Text("Grabación automática durante navegación")
                    .font(.caption2)
                    .foregroundColor(theme.textTint.opacity(0.6))
            }

            Spacer()

            if !service.pastTrips.isEmpty {
                Button(action: onOpen) {
                    Text("Ver todos")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.textTint.opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme.textTint.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sin viajes registrados")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.textTint.opacity(0.7))

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.5))
                Text("Inicia una navegación en el mapa o toca el botón REC para grabar.")
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Totals Row

    private var totalsRow: some View {
        HStack(spacing: 12) {
            totalTile(
                value: "\(service.pastTrips.count)",
                label: "viajes",
                color: Color(hex: "#22D3EE")
            )
            separator
            totalTile(
                value: String(format: "%.0f", totalKm),
                label: "km",
                color: Color(hex: "#34D399")
            )
            separator
            totalTile(
                value: String(format: "%.0f", totalMin),
                label: "min",
                color: Color(hex: "#FBBF24")
            )
            if totalHarsh > 0 {
                separator
                totalTile(
                    value: "\(totalHarsh)",
                    label: "bruscos",
                    color: Color(hex: "#F87171")
                )
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.textTint.opacity(0.1))
            .frame(width: 1, height: 26)
    }

    private func totalTile(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(theme.textTint.opacity(0.08))
            .frame(height: 1)
    }

    // MARK: - Trip List (últimos 3)

    private var tripList: some View {
        VStack(spacing: 6) {
            ForEach(Array(service.pastTrips.prefix(3))) { trip in
                TripHistoryRow(trip: trip, theme: theme, onTap: { onSelectTrip(trip) })
            }
        }
    }

    // MARK: - Computed Totals

    private var totalKm: Double {
        service.pastTrips.reduce(0) { $0 + $1.totalDistanceKm }
    }

    private var totalMin: Double {
        service.pastTrips.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalHarsh: Int {
        service.pastTrips.reduce(0) { $0 + $1.harshAccels + $1.harshBrakes }
    }
}

// MARK: - Trip History Row

private struct TripHistoryRow: View {
    let trip: TripTelemetry
    let theme: WeatherTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.textTint.opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: iconForTrip)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(styleColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(dateLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textTint)
                        Text("·")
                            .foregroundColor(theme.textTint.opacity(0.3))
                        Text(String(format: "%.1f km", trip.totalDistanceKm))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textTint.opacity(0.85))
                            .monospacedDigit()
                    }
                    Text(metricsSummary)
                        .font(.caption2)
                        .foregroundColor(theme.textTint.opacity(0.55))
                        .monospacedDigit()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(theme.textTint.opacity(0.3))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.textTint.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived Display

    private var dateLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: trip.startedAt, relativeTo: Date())
    }

    private var metricsSummary: String {
        let avg = Int(trip.avgSpeedKmh.rounded())
        let dur = Int(trip.durationMinutes.rounded())
        let harsh = trip.harshAccels + trip.harshBrakes
        return harsh > 0
            ? "\(dur) min · avg \(avg) km/h · \(harsh) bruscos"
            : "\(dur) min · avg \(avg) km/h"
    }

    /// Icono según el driving style multiplier. Suave → hoja, agresivo → llama.
    private var iconForTrip: String {
        let m = trip.computedStyleMultiplier
        switch m {
        case ..<0.95: return "leaf.fill"
        case 0.95..<1.10: return "car.fill"
        case 1.10..<1.20: return "bolt.fill"
        default:            return "flame.fill"
        }
    }

    private var styleColor: Color {
        let m = trip.computedStyleMultiplier
        switch m {
        case ..<0.95:      return Color(hex: "#34D399") // verde: suave
        case 0.95..<1.10:  return Color(hex: "#60A5FA") // azul: normal
        case 1.10..<1.20:  return Color(hex: "#FBBF24") // amarillo: brisk
        default:            return Color(hex: "#F87171") // rojo: agresivo
        }
    }
}

// MARK: - Glass Card Helper

private extension View {
    /// Glass card alineado con el estilo del resto del Hub.
    /// Duplicado mínimo porque el glassCard del Hub es private; si se quisiera
    /// consolidar en un modifier global, sería otro refactor.
    func glassHistoryCard(theme: WeatherTheme) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.textTint.opacity(0.08), lineWidth: 1)
            )
    }
}
