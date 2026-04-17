//
//  TripRecorderView.swift
//  AcessNet
//
//  Rediseño premium: velocímetro hero + stats glass + historial + summary visual.
//

import SwiftUI

struct TripRecorderView: View {
    @StateObject private var service = DrivingTelemetryService.shared
    @StateObject private var vehicleService = VehicleProfileService.shared
    @EnvironmentObject private var appSettings: AppSettings
    @State private var showingSummary: TripTelemetry?
    @Environment(\.dismiss) private var dismiss

    private var theme: WeatherTheme {
        WeatherTheme(condition: appSettings.weatherOverride ?? .overcast)
    }

    var body: some View {
        ZStack {
            theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if service.isRecording {
                        liveView
                    } else {
                        startView
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    HapticFeedback.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
            }
        }
        .toolbarBackground(theme.pageBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .environment(\.weatherTheme, theme)
        .sheet(item: $showingSummary) { trip in
            TripSummaryView(trip: trip)
                .environment(\.weatherTheme, theme)
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 14) {
            heroCarHeader
            vehicleCard
            startButton
            if !service.pastTrips.isEmpty {
                historyCard
            }
        }
    }

    private var heroCarHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#EF4444").opacity(0.35),
                                 Color(hex: "#991B1B").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 86, height: 86)
                    .blur(radius: 1)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#F87171"), Color(hex: "#EF4444")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            VStack(spacing: 2) {
                Text("Telemetría de viaje")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                Text("CoreMotion + GPS · sin hardware")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var vehicleCard: some View {
        if let v = vehicleService.activeProfile {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.green.opacity(0.4), .teal.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)
                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("VEHÍCULO ACTIVO")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(.green)
                    Text(v.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("ESTILO")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.4))
                    Text(v.drivingStyleLabel)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(styleColor(v.drivingStyle))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
        } else {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sin vehículo configurado")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Configura uno en Mi vehículo primero")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.orange.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private var startButton: some View {
        Button {
            HapticFeedback.confirm()
            service.startTrip(vehicleId: vehicleService.activeProfile?.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text("Iniciar viaje")
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: vehicleService.activeProfile == nil
                        ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]
                        : [Color(hex: "#EF4444"), Color(hex: "#B91C1C")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: vehicleService.activeProfile == nil ? .clear : Color(hex: "#EF4444").opacity(0.45),
                radius: 10, y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(vehicleService.activeProfile == nil)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HISTORIAL")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(service.pastTrips.count) viajes")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 6) {
                ForEach(service.pastTrips.prefix(5)) { trip in
                    historyRow(trip)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func historyRow(_ trip: TripTelemetry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(styleColor(trip.computedStyleMultiplier).opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(styleColor(trip.computedStyleMultiplier))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(trip.startedAt, style: .date)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Text(String(format: "%.1f km", trip.totalDistanceKm))
                    Text("·")
                    Text("\(Int(trip.durationMinutes)) min")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 4)
            Text(String(format: "×%.2f", trip.computedStyleMultiplier))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(styleColor(trip.computedStyleMultiplier))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(styleColor(trip.computedStyleMultiplier).opacity(0.12)))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: - Live View

    private var liveView: some View {
        VStack(spacing: 16) {
            recordingBadge
            speedometerHero
            liveStatsGrid
            stopCancelRow
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 6) {
            RecordingDot()
            Text("VIAJE EN CURSO")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: "#EF4444")))
        .shadow(color: Color(hex: "#EF4444").opacity(0.5), radius: 8)
        .padding(.top, 10)
    }

    private var speedometerHero: some View {
        let speedFrac = min(service.liveStats.speedKmh / 140, 1)
        return ZStack {
            // Ring fondo
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 14)
                .frame(width: 250, height: 250)

            // Ring progreso
            Circle()
                .trim(from: 0, to: CGFloat(speedFrac))
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: "#34D399"),
                            Color(hex: "#FBBF24"),
                            Color(hex: "#EF4444")
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * Double(speedFrac))
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 250, height: 250)
                .shadow(color: speedColor.opacity(0.5), radius: 10)
                .animation(.easeInOut(duration: 0.4), value: service.liveStats.speedKmh)

            // Centro: número + unit
            VStack(spacing: 0) {
                Text("\(Int(service.liveStats.speedKmh))")
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .shadow(color: speedColor.opacity(0.45), radius: 10)
                Text("km/h")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(.vertical, 10)
    }

    private var speedColor: Color {
        let s = service.liveStats.speedKmh
        if s < 40 { return Color(hex: "#34D399") }
        if s < 80 { return Color(hex: "#FBBF24") }
        return Color(hex: "#EF4444")
    }

    private var liveStatsGrid: some View {
        HStack(spacing: 8) {
            liveStatTile(
                icon: "road.lanes",
                value: String(format: "%.1f", service.liveStats.distanceKm),
                unit: "km",
                label: "Distancia",
                color: Color(hex: "#60A5FA")
            )
            liveStatTile(
                icon: "clock.fill",
                value: "\(Int(service.liveStats.durationMin))",
                unit: "min",
                label: "Tiempo",
                color: Color(hex: "#A78BFA")
            )
            liveStatTile(
                icon: service.liveStats.harshEvents > 2
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.seal.fill",
                value: "\(service.liveStats.harshEvents)",
                unit: "",
                label: "Eventos",
                color: service.liveStats.harshEvents > 2
                    ? Color(hex: "#F87171")
                    : Color(hex: "#34D399")
            )
        }
    }

    private func liveStatTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private var stopCancelRow: some View {
        VStack(spacing: 8) {
            Button {
                HapticFeedback.heavy()
                if let finished = service.endTrip() {
                    showingSummary = finished
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .heavy))
                    Text("Terminar viaje")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#EF4444"), Color(hex: "#B91C1C")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "#EF4444").opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.warning()
                service.cancelTrip()
            } label: {
                Text("Cancelar sin guardar")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func styleColor(_ m: Double) -> Color {
        switch m {
        case ..<1.05: return Color(hex: "#34D399")
        case 1.05..<1.15: return Color(hex: "#60A5FA")
        case 1.15..<1.25: return Color(hex: "#FBBF24")
        default: return Color(hex: "#EF4444")
        }
    }
}

// MARK: - Recording Dot (pulsante)

private struct RecordingDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .scaleEffect(pulse ? 1.6 : 1.0)
                .opacity(pulse ? 0 : 0.85)
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Trip Summary View (rediseño)

struct TripSummaryView: View {
    let trip: TripTelemetry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weatherTheme) private var theme

    private var styleMultiplier: Double { trip.computedStyleMultiplier }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        heroSuccess
                        metricsCard
                        drivingStyleCard
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Text("Listo")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // Hero
    private var heroSuccess: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.6), Color.teal.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.green.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Viaje guardado")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                Text("Tu perfil de conducción se actualizó")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.14), Color.teal.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
    }

    // Metrics grid
    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MÉTRICAS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }

            HStack(spacing: 8) {
                metricTile(icon: "road.lanes",
                           value: String(format: "%.2f", trip.totalDistanceKm),
                           unit: "km", label: "Distancia",
                           color: Color(hex: "#60A5FA"))
                metricTile(icon: "clock.fill",
                           value: "\(Int(trip.durationMinutes))",
                           unit: "min", label: "Duración",
                           color: Color(hex: "#A78BFA"))
                metricTile(icon: "speedometer",
                           value: String(format: "%.0f", trip.maxSpeedKmh),
                           unit: "km/h", label: "Máxima",
                           color: Color(hex: "#EF4444"))
            }
            HStack(spacing: 8) {
                metricTile(icon: "gauge.medium",
                           value: String(format: "%.0f", trip.avgSpeedKmh),
                           unit: "km/h", label: "Promedio",
                           color: Color(hex: "#34D399"))
                metricTile(icon: "mountain.2.fill",
                           value: String(format: "%.0f", trip.elevationGainM),
                           unit: "m", label: "Elevación",
                           color: Color(hex: "#FBBF24"))
                metricTile(icon: "hand.raised.fill",
                           value: "\(trip.idleSeconds)",
                           unit: "s", label: "Ralentí",
                           color: Color(hex: "#FB923C"))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func metricTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    // Driving style
    private var drivingStyleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ESTILO DE CONDUCCIÓN")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(styleColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.wave.circle.fill")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(styleColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(styleLabel)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(styleColor)
                    HStack(spacing: 2) {
                        Text("Multiplicador: ×")
                        Text(String(format: "%.2f", styleMultiplier))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
            }

            // Barra de estilo
            styleBar

            // Eventos
            HStack(spacing: 8) {
                eventTile(icon: "arrow.up.circle.fill",
                          value: "\(trip.harshAccels)",
                          label: "Aceleraciones\nbruscas",
                          color: Color(hex: "#F87171"))
                eventTile(icon: "arrow.down.circle.fill",
                          value: "\(trip.harshBrakes)",
                          label: "Frenadas\nbruscas",
                          color: Color(hex: "#FB923C"))
                eventTile(icon: "pause.circle.fill",
                          value: "\(trip.stopsCount)",
                          label: "Paradas\ncompletas",
                          color: Color(hex: "#60A5FA"))
            }

            // Advice
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(hex: "#FBBF24"))
                Text(styleAdvice)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#FBBF24").opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "#FBBF24").opacity(0.25), lineWidth: 1)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(styleColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var styleBar: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let progress = CGFloat((styleMultiplier - 0.85) / (1.30 - 0.85))
                let clamped = max(0.0, min(1.0, progress))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    LinearGradient(
                        colors: [Color(hex: "#34D399"),
                                 Color(hex: "#FBBF24"),
                                 Color(hex: "#EF4444")],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .mask(Capsule().frame(width: geo.size.width))

                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .offset(x: geo.size.width * clamped - 7)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Suave")
                Spacer()
                Text("Normal")
                Spacer()
                Text("Agresivo")
            }
            .font(.system(size: 8, weight: .heavy))
            .tracking(0.4)
            .foregroundColor(.white.opacity(0.4))
        }
    }

    private func eventTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // Style helpers
    private var styleLabel: String {
        switch styleMultiplier {
        case ..<0.95: return "Muy eficiente"
        case 0.95..<1.05: return "Suave"
        case 1.05..<1.15: return "Normal"
        case 1.15..<1.25: return "Agresivo"
        default: return "Muy agresivo"
        }
    }

    private var styleColor: Color {
        switch styleMultiplier {
        case ..<1.05: return Color(hex: "#34D399")
        case 1.05..<1.15: return Color(hex: "#60A5FA")
        case 1.15..<1.25: return Color(hex: "#FBBF24")
        default: return Color(hex: "#EF4444")
        }
    }

    private var styleAdvice: String {
        switch styleMultiplier {
        case ..<1.05:
            return "Tu conducción es eficiente. Cada viaje ahorra combustible y reduce emisiones."
        case 1.05..<1.15:
            return "Conducción normal. Acelerar más suave podría ahorrarte hasta 10% de gasolina."
        case 1.15..<1.25:
            return "Varias aceleraciones bruscas. Conducir más suave ahorra combustible y reduce estrés."
        default:
            return "Muchos eventos bruscos detectados. Anticipar cambios de velocidad mejora eficiencia."
        }
    }
}
