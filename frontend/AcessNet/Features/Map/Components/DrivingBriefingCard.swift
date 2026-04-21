//
//  DrivingBriefingCard.swift
//  AcessNet
//
//  Card del modo "En coche" dentro del Trip Briefing.
//  Compone FuelEstimate + FuelStations en ruta + Optimal Departure +
//  equivalente de cigarros en cabina.
//

import SwiftUI
import CoreLocation

struct DrivingBriefingCard: View {
    let briefing: DrivingBriefing
    let vehicle: VehicleProfile?
    let destinationTitle: String
    let onOpenStations: () -> Void
    let onOpenDeparture: () -> Void
    let onAddVehicle: () -> Void
    var onRetry: (() -> Void)? = nil

    @Environment(\.weatherTheme) private var theme
    @State private var dropletsAnimated = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            costHero
            dropletsMeter
            // Sub-módulos independientes — cada uno decide su estado.
            if vehicle == nil {
                vehicleMissingStub
            } else {
                departureTile
                stationTile
            }
            environmentalTile
            cabinCigaretteTile
        }
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.8)) {
                    dropletsAnimated = true
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#3AA3FF"), Color(hex: "#3AA3FF").opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: "car.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("EN COCHE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text("\(briefing.durationLabel) · \(briefing.distanceLabel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer()
            aqiBadge
        }
    }

    private var aqiBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(aqiColor).frame(width: 6, height: 6)
            Text("AQI \(Int(briefing.aqiRouteAvg ?? 0))")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.black.opacity(0.75))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.05)))
        .overlay(Capsule().stroke(aqiColor.opacity(0.4), lineWidth: 0.5))
    }

    // MARK: - Cost hero

    @ViewBuilder
    private var costHero: some View {
        switch briefing.fuel {
        case .idle, .loading:
            costSkeleton
        case .ready(let est):
            costReady(estimate: est)
        case .failed(let msg):
            costError(message: msg)
        }
    }

    private var costSkeleton: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 54)
                .shimmerGlow()
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func costReady(estimate: FuelEstimate) -> some View {
        VStack(spacing: 4) {
            Text(estimate.pesosFormatted)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#2E7D32"), Color(hex: "#4CAF50")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .monospacedDigit()
                .contentTransition(.numericText(value: estimate.pesosCost))

            HStack(spacing: 6) {
                Text(estimate.litersFormatted)
                Text("·")
                if let v = vehicle { Text(v.displayName) } else { Text("estimado") }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.black.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func costError(message: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("No se pudo estimar el costo")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(hex: "#FF8C42"))
            Text(message)
                .font(.caption2)
                .foregroundStyle(Color.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let retry = onRetry {
                Button {
                    HapticFeedback.light()
                    retry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Reintentar")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.06)))
                    .overlay(Capsule().stroke(Color.black.opacity(0.14), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Droplets meter

    private var dropletsMeter: some View {
        HStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        i < filledDroplets
                            ? Color(hex: "#7ED957").opacity(0.92)
                            : Color.white.opacity(0.10)
                    )
                    .scaleEffect(dropletsAnimated && i < filledDroplets ? 1 : 0.6)
                    .opacity(dropletsAnimated || i >= filledDroplets ? 1 : 0)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.7)
                            .delay(Double(i) * 0.08),
                        value: dropletsAnimated
                    )
            }
            Spacer()
            if let estimate = briefing.fuel.value {
                Text(estimate.co2Formatted + " CO₂")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }

    private var filledDroplets: Int {
        guard let liters = briefing.fuel.value?.liters else { return 0 }
        // 8 tiles, escala 0..20L por defecto. Nunca más de 8.
        return min(8, max(0, Int((liters / 20.0 * 8.0).rounded(.up))))
    }

    // MARK: - Vehicle missing stub

    private var vehicleMissingStub: some View {
        Button(action: onAddVehicle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#FFB830").opacity(0.22))
                        .frame(width: 36, height: 36)
                    Image(systemName: "car.side.fill")
                        .foregroundStyle(Color(hex: "#FFB830"))
                        .font(.system(size: 15, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agrega tu vehículo")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                    Text("Para ver costo real, estaciones y mejor hora de salida")
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.58))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.42))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#FFB830").opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "#FFB830").opacity(0.28), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Departure tile

    @ViewBuilder
    private var departureTile: some View {
        switch briefing.departure {
        case .idle:
            EmptyView()
        case .loading:
            subModuleSkeleton(icon: "clock.fill", title: "Mejor hora para salir")
        case .failed:
            subModuleError(icon: "clock.fill", title: "Mejor hora no disponible")
        case .ready(let resp):
            if let best = resp.best {
                departureContent(best: best, savings: resp.savingsIfBest)
            }
        }
    }

    private func departureContent(best: DepartureWindow, savings: DepartureSavings?) -> some View {
        Button(action: onOpenDeparture) {
            HStack(spacing: 12) {
                iconBadge(system: "clock.fill", tint: Color(hex: "#3AA3FF"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mejor hora: \(best.departTimeLabel)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                    if let s = savings, s.pesos > 0 {
                        Text("Ahorras $\(Int(s.pesos)) + \(Int(s.minutes)) min")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#7ED957"))
                    } else {
                        Text("Salir ahora también está bien")
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.58))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.42))
            }
            .padding(12)
            .background(subModuleBackground(tint: Color(hex: "#3AA3FF")))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Station tile

    @ViewBuilder
    private var stationTile: some View {
        switch briefing.stations {
        case .idle, .loading:
            subModuleSkeleton(icon: "fuelpump.fill", title: "Estaciones en ruta")
        case .failed:
            subModuleError(icon: "fuelpump.fill", title: "Sin estaciones cercanas")
        case .ready(let stations):
            if let best = stations.min(by: { $0.price < $1.price }) {
                stationContent(station: best)
            } else {
                subModuleError(icon: "fuelpump.fill", title: "Sin estaciones cercanas")
            }
        }
    }

    private func stationContent(station: FuelStation) -> some View {
        Button(action: onOpenStations) {
            HStack(spacing: 12) {
                iconBadge(system: "fuelpump.fill", tint: brandColor(station.brand))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(station.brand)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.85))
                        Text(station.priceFormatted)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(hex: "#2E7D32"))
                            .monospacedDigit()
                    }
                    if let s = station.savingsFormatted {
                        Text("\(s) · \(station.distanceKmFormatted)")
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.58))
                    } else {
                        Text(station.distanceKmFormatted)
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.58))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.42))
            }
            .padding(12)
            .background(subModuleBackground(tint: brandColor(station.brand)))
        }
        .buttonStyle(.plain)
    }

    private func brandColor(_ b: String) -> Color {
        switch b.lowercased() {
        case "pemex": return Color(hex: "#2ECC71")
        case "shell": return Color(hex: "#FFDD33")
        case "bp": return Color(hex: "#57C785")
        case "mobil": return Color(hex: "#3AA3FF")
        default: return Color(hex: "#FF8C42")
        }
    }

    // MARK: - Environmental tile (CO₂ + árboles)

    @ViewBuilder
    private var environmentalTile: some View {
        if let estimate = briefing.fuel.value {
            HStack(spacing: 12) {
                iconBadge(system: "leaf.fill", tint: Color(hex: "#7ED957"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(estimate.co2Formatted) de CO₂")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                    if let trees = briefing.treesPerDayToOffset, trees > 0 {
                        Text("≈ \(trees) árboles/día para compensar")
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.58))
                    } else {
                        Text("Huella baja en este trayecto")
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.58))
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(subModuleBackground(tint: Color(hex: "#7ED957")))
        }
    }

    // MARK: - Cabin cigarette tile

    @ViewBuilder
    private var cabinCigaretteTile: some View {
        // Sólo tiene sentido mostrarlo si tenemos datos de aire.
        if briefing.hasAirData {
            HStack(spacing: 12) {
                iconBadge(system: "lungs.fill", tint: Color(hex: "#C78EFF"))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(briefing.cabinCigarettes.map { String(format: "%.2f", $0) } ?? "—")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .monospacedDigit()
                        Text("🚬 en cabina")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.black.opacity(0.82))
                    }
                    Text("Ventanas cerradas · filtro estándar")
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                Spacer()
            }
            .padding(12)
            .background(subModuleBackground(tint: Color(hex: "#C78EFF")))
        }
    }

    // MARK: - Sub-module helpers

    private func iconBadge(system: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.22))
                .frame(width: 36, height: 36)
            Image(systemName: system)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .bold))
        }
    }

    private func subModuleBackground(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 0.6)
            )
    }

    private func subModuleSkeleton(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(system: icon, tint: Color.white.opacity(0.45))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 10)
                    .shimmerGlow()
            }
            Spacer()
        }
        .padding(12)
        .background(subModuleBackground(tint: .white))
    }

    private func subModuleError(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(system: icon, tint: Color(hex: "#FF8C42"))
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))
            Spacer()
        }
        .padding(12)
        .background(subModuleBackground(tint: Color(hex: "#FF8C42")))
    }

    // MARK: - Styling helpers

    private var aqiColor: Color {
        let aqi = briefing.aqiRouteAvg ?? 0
        switch Int(aqi) {
        case ..<50:     return Color(hex: "#7ED957")
        case 50..<100:  return Color(hex: "#F9A825")
        case 100..<150: return Color(hex: "#FF8C42")
        case 150..<200: return Color(hex: "#FF3B3B")
        default:        return Color(hex: "#8E24AA")
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.black.opacity(0.1), lineWidth: 0.6)
    }
}

// MARK: - Shimmer helper

private struct ShimmerGlowModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { g in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: g.size.width * 0.6)
                    .offset(x: phase * g.size.width)
                    .blendMode(.plusLighter)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

private extension View {
    func shimmerGlow() -> some View { modifier(ShimmerGlowModifier()) }
}

// MARK: - Preview

#Preview("Driving — loading") {
    let b = DrivingBriefing(
        distanceMeters: 11400, durationSeconds: 18 * 60,
        pm25RouteAvg: 32, aqiRouteAvg: 82
    )
    return DrivingPreviewWrapper(briefing: b, vehicle: VehicleProfile.sample)
}

#Preview("Driving — ready") {
    var b = DrivingBriefing(
        distanceMeters: 11400, durationSeconds: 18 * 60,
        pm25RouteAvg: 32, aqiRouteAvg: 82
    )
    b.fuel = .ready(FuelEstimate(
        liters: 1.8, pesosCost: 42.8, co2Kg: 3.9, pm25Grams: 0.21,
        confidence: 0.85, distanceKm: 11.4, durationMin: 18,
        avgSpeedKmh: 38, avgGradePct: 1.2, stopsEstimated: 6,
        temperatureC: 22, vehicleDisplay: "Jetta 2020", breakdown: nil, kwh: nil
    ))
    b.stations = .ready([
        FuelStation(
            id: "bp-ref", brand: "BP", name: "BP Reforma",
            address: "Av. Reforma 123", lat: 19.432, lon: -99.14,
            price: 23.4, fuelType: "magna", distanceM: 300, savingsPerLiter: 0.4
        )
    ])
    return DrivingPreviewWrapper(briefing: b, vehicle: VehicleProfile.sample)
}

#Preview("Driving — no vehicle") {
    let b = DrivingBriefing(
        distanceMeters: 11400, durationSeconds: 18 * 60,
        pm25RouteAvg: 32, aqiRouteAvg: 82
    )
    return DrivingPreviewWrapper(briefing: b, vehicle: nil)
}

private struct DrivingPreviewWrapper: View {
    let briefing: DrivingBriefing
    let vehicle: VehicleProfile?
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A0F"), Color(hex: "#1B1E2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView {
                DrivingBriefingCard(
                    briefing: briefing,
                    vehicle: vehicle,
                    destinationTitle: "Polanco",
                    onOpenStations: {},
                    onOpenDeparture: {},
                    onAddVehicle: {}
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 40)
            }
        }
        .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
    }
}
