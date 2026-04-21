//
//  VersusBar.swift
//  AcessNet
//
//  Franja comparativa que siempre muestra el trade-off entre
//  A pie ↔ En coche. Width proporcional al tiempo.
//

import SwiftUI

struct VersusBar: View {
    let walking: WalkingBriefing?
    let driving: DrivingBriefing?
    let activeMode: BriefingMode
    var hideDrivingIfMissing: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            row(
                icon: "figure.walk",
                label: walkLabel,
                proportion: walkingProportion,
                tint: Color(hex: "#7ED957"),
                active: activeMode == .walking
            )
            if showDrivingRow {
                row(
                    icon: "car.fill",
                    label: driveLabel,
                    proportion: drivingProportion,
                    tint: Color(hex: "#3AA3FF"),
                    active: activeMode == .driving
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#0A0A0F").opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        )
    }

    // MARK: - Row

    private func row(
        icon: String,
        label: String,
        proportion: Double,
        tint: Color,
        active: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(active ? tint : Color.white.opacity(0.58))
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(active ? 1 : 0.5), tint.opacity(active ? 0.55 : 0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(proportion)), height: 6)
                        .animation(.easeInOut(duration: 0.55), value: proportion)
                }
            }
            .frame(height: 6)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.68))
                .monospacedDigit()
                .frame(minWidth: 180, alignment: .trailing)
                .lineLimit(1)
        }
    }

    // MARK: - Data derivation

    private var maxDurationSec: TimeInterval {
        let w = walking?.durationSeconds ?? 0
        let d = driving?.durationSeconds ?? 0
        return max(w, d, 1)
    }

    private var walkingProportion: Double {
        guard let w = walking else { return 0 }
        return min(1, w.durationSeconds / maxDurationSec)
    }

    private var drivingProportion: Double {
        guard let d = driving else { return 0 }
        return min(1, d.durationSeconds / maxDurationSec)
    }

    /// Oculta la fila driving cuando el caller así lo indica (sin vehículo).
    private var showDrivingRow: Bool {
        if hideDrivingIfMissing && driving?.fuel.value == nil {
            return false
        }
        return true
    }

    private var walkLabel: String {
        guard let w = walking else { return "—" }
        let cigStr = w.cigarettes.map { String(format: "%.1f🚬", $0) } ?? "—🚬"
        return "\(w.durationLabel) · \(cigStr) · +\(Int(w.kcalBurned)) kcal"
    }

    private var driveLabel: String {
        guard let d = driving else { return "—" }
        let costStr: String
        if let est = d.fuel.value {
            costStr = est.pesosFormatted
        } else if d.fuel.isLoading {
            costStr = "..."
        } else {
            costStr = "—"
        }
        let cigStr = d.cabinCigarettes.map { String(format: "%.1f🚬", $0) } ?? "—🚬"
        return "\(d.durationLabel) · \(cigStr) · \(costStr)"
    }
}

// MARK: - Preview

#Preview("VersusBar") {
    var drive = DrivingBriefing(
        distanceMeters: 11400, durationSeconds: 18 * 60,
        pm25RouteAvg: 32, aqiRouteAvg: 82
    )
    drive.fuel = .ready(FuelEstimate(
        liters: 1.8, pesosCost: 42.8, co2Kg: 3.9, pm25Grams: 0.21,
        confidence: 0.85, distanceKm: 11.4, durationMin: 18,
        avgSpeedKmh: 38, avgGradePct: 1.2, stopsEstimated: 6,
        temperatureC: 22, vehicleDisplay: "Jetta 2020",
        breakdown: nil, kwh: nil
    ))

    let walk = WalkingBriefing(
        distanceMeters: 1800, durationSeconds: 23 * 60,
        pm25RouteAvg: 28, aqiRouteAvg: 78, activity: .light
    )

    return ZStack {
        LinearGradient(
            colors: [Color(hex: "#0A0A0F"), Color(hex: "#1B1E2A")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VersusBar(walking: walk, driving: drive, activeMode: .walking)
            .padding()
    }
}
