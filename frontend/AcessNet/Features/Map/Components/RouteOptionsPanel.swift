//
//  RouteOptionsPanel.swift
//  AcessNet
//
//  PASO 2 del flujo de ruta: tras elegir modo (caminar/coche) se
//  muestran 3 opciones de ruta con las métricas específicas del modo.
//  El usuario toca una tarjeta para seleccionarla y luego "Ir ahora".
//

import SwiftUI

struct RouteOptionsPanel: View {
    @ObservedObject var viewModel: TripBriefingViewModel
    let onBack: () -> Void
    let onGo: () -> Void
    let onDismiss: () -> Void

    @Environment(\.weatherTheme) private var theme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            header
            modeBanner
            if isLoadingRoutes {
                loadingPlaceholder
            } else {
                optionsList
                goButton
            }
        }
        .padding(14)
        .background(panelBackground)
        .overlay(panelBorder)
        .shadow(color: .black.opacity(0.25), radius: 22, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: isLoadingRoutes)
    }

    /// Mientras MKDirections no haya resuelto las 3 variantes del modo activo,
    /// `previewRoute` está nil. Mostramos spinner en vez de cards vacías para
    /// que el usuario sepa que algo está pasando (no es un bug/blank screen).
    private var isLoadingRoutes: Bool {
        viewModel.previewRoute == nil
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(modeAccent)
                .scaleEffect(1.1)
            Text(viewModel.mode == .walking ? "Calculando rutas a pie…" : "Calculando rutas en coche…")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .transition(.opacity)
    }

    // MARK: - Header (back + destino + X)

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.black.opacity(0.06)))
                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volver")

            VStack(alignment: .leading, spacing: 1) {
                Text("RUTAS DISPONIBLES")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text(viewModel.destinationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.06)))
                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar")
        }
    }

    // MARK: - Mode banner (indica el modo activo)

    private var modeBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: viewModel.mode.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(modeAccent))
            Text(viewModel.mode == .walking ? "A pie" : "En coche")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
            Spacer()
            if !isLoadingRoutes {
                Text("Elige una ruta")
                    .font(.caption2)
                    .foregroundStyle(Color.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(modeAccent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(modeAccent.opacity(0.28), lineWidth: 0.6)
        )
    }

    // MARK: - Options list (scroll horizontal de 3 cards compactas)

    private var optionsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripPriority.allCases) { priority in
                    optionCard(priority: priority)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }

    private func optionCard(priority: TripPriority) -> some View {
        let isSelected = viewModel.routePriority == priority
        let accent = Color(hex: priority.accentHex)
        let isSuggested = (viewModel.suggestedPriority == priority)

        return Button {
            HapticFeedback.selection()
            viewModel.setPriority(priority)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Fila superior: icono + radio selector (más compacta)
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.72)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                        Image(systemName: priority.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    selectionIndicator(isSelected: isSelected, accent: accent)
                }

                // Título + tag sugerida (si aplica)
                VStack(alignment: .leading, spacing: 2) {
                    Text(priority.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .lineLimit(1)
                    if isSuggested {
                        suggestedTag(tint: accent)
                    }
                }

                // Métricas en columna (compactas para ancho pequeño)
                VStack(alignment: .leading, spacing: 2) {
                    metricsStack(priority: priority)
                }
            }
            .padding(10)
            .frame(width: 148, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.55) : Color.black.opacity(0.1),
                        lineWidth: isSelected ? 1.3 : 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isSelected)
        .accessibilityLabel(Text(priority.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // Métricas apiladas verticalmente — cabe mejor en card de 160pt.
    @ViewBuilder
    private func metricsStack(priority: TripPriority) -> some View {
        switch viewModel.mode {
        case .walking:
            walkingMetricsStack(priority: priority)
        case .driving:
            drivingMetricsStack(priority: priority)
        }
    }

    private func walkingMetricsStack(priority: TripPriority) -> some View {
        let base = viewModel.walking
        let factor = Self.factor(for: priority)
        let duration = (base?.durationSeconds ?? 0) * factor.duration
        let cigs: Double? = base.flatMap { b in
            b.cigarettes.map { $0 * factor.pm25 }
        }
        let minutes = Int((duration / 60.0).rounded())
        let kcal = Int((base?.kcalBurned ?? 0) * factor.duration)

        return VStack(alignment: .leading, spacing: 4) {
            stackedMetric(icon: "clock.fill", text: "\(minutes) min", tint: Color(hex: "#3AA3FF"))
            stackedMetric(
                icon: "lungs.fill",
                text: cigs.map { String(format: "%.2f 🚬", $0) } ?? "— 🚬",
                tint: Color(hex: "#C78EFF")
            )
            stackedMetric(icon: "flame.fill", text: "\(kcal) kcal", tint: Color(hex: "#FF9E3D"))
        }
    }

    private func drivingMetricsStack(priority: TripPriority) -> some View {
        let base = viewModel.driving
        let factor = Self.factor(for: priority)
        let duration = (base?.durationSeconds ?? 0) * factor.duration
        let minutes = Int((duration / 60.0).rounded())
        let cost: String
        if let est = base?.fuel.value {
            cost = "$\(Int(est.pesosCost * factor.duration))"
        } else if base?.fuel.isLoading == true {
            cost = "..."
        } else {
            cost = "—"
        }
        let aqi = Int((base?.aqiRouteAvg ?? 0) * factor.aqi)

        return VStack(alignment: .leading, spacing: 4) {
            stackedMetric(icon: "clock.fill", text: "\(minutes) min", tint: Color(hex: "#3AA3FF"))
            stackedMetric(icon: "fuelpump.fill", text: cost, tint: Color(hex: "#2E7D32"))
            if aqi > 0 {
                stackedMetric(icon: "aqi.medium", text: "AQI \(aqi)", tint: aqiColor(Double(aqi)))
            }
        }
    }

    private func stackedMetric(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 12)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.78))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func suggestedTag(tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
            Text("Sugerida")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.15)))
    }

    @ViewBuilder
    private func metricsLine(priority: TripPriority) -> some View {
        // Proyecta métricas simuladas según factor de priority para ambos modos.
        switch viewModel.mode {
        case .walking:
            walkingMetrics(priority: priority)
        case .driving:
            drivingMetrics(priority: priority)
        }
    }

    private func walkingMetrics(priority: TripPriority) -> some View {
        let base = viewModel.walking
        let factor = Self.factor(for: priority)
        let duration = (base?.durationSeconds ?? 0) * factor.duration
        let cigs: Double? = base.flatMap { b in
            b.cigarettes.map { $0 * factor.pm25 }
        }
        let minutes = Int((duration / 60.0).rounded())
        let kcal = Int((base?.kcalBurned ?? 0) * factor.duration)

        return HStack(spacing: 8) {
            metricChip(icon: "clock.fill", text: "\(minutes) min", tint: Color(hex: "#3AA3FF"))
            metricChip(
                icon: "lungs.fill",
                text: cigs.map { String(format: "%.2f 🚬", $0) } ?? "—",
                tint: Color(hex: "#C78EFF")
            )
            metricChip(icon: "flame.fill", text: "\(kcal) kcal", tint: Color(hex: "#FF9E3D"))
        }
    }

    private func drivingMetrics(priority: TripPriority) -> some View {
        let base = viewModel.driving
        let factor = Self.factor(for: priority)
        let duration = (base?.durationSeconds ?? 0) * factor.duration
        let minutes = Int((duration / 60.0).rounded())
        let cost: String
        if let est = base?.fuel.value {
            cost = "$\(Int(est.pesosCost * factor.duration))"
        } else if base?.fuel.isLoading == true {
            cost = "..."
        } else {
            cost = "—"
        }
        let aqi = Int((base?.aqiRouteAvg ?? 0) * factor.aqi)

        return HStack(spacing: 8) {
            metricChip(icon: "clock.fill", text: "\(minutes) min", tint: Color(hex: "#3AA3FF"))
            metricChip(icon: "fuelpump.fill", text: cost, tint: Color(hex: "#2E7D32"))
            if aqi > 0 {
                metricChip(icon: "aqi.medium", text: "AQI \(aqi)", tint: aqiColor(Double(aqi)))
            }
        }
    }

    private func metricChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.78))
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.09)))
    }

    private func selectionIndicator(isSelected: Bool, accent: Color) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accent : Color.black.opacity(0.15), lineWidth: 1.4)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)
            }
        }
    }

    // MARK: - Go button

    private var goButton: some View {
        Button(action: onGo) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.mode == .walking ? "figure.walk.motion" : "location.north.line.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(viewModel.mode == .walking ? "Empezar caminata" : "Ir ahora")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [modeAccent, modeAccent.opacity(0.78)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: modeAccent.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var modeAccent: Color {
        switch viewModel.mode {
        case .walking: return Color(hex: "#7ED957")
        case .driving: return Color(hex: "#3AA3FF")
        }
    }

    private func aqiColor(_ aqi: Double) -> Color {
        switch aqi {
        case ..<50:    return Color(hex: "#4CAF50")
        case 50..<100: return Color(hex: "#F9A825")
        case 100..<150: return Color(hex: "#FF8C42")
        case 150..<200: return Color(hex: "#FF3B3B")
        default:        return Color(hex: "#8E24AA")
        }
    }

    // Factores simulados que coinciden con los del ViewModel.
    private struct PriorityFactor {
        let aqi: Double
        let pm25: Double
        let duration: Double
    }

    private static func factor(for priority: TripPriority) -> PriorityFactor {
        switch priority {
        case .fast:     return PriorityFactor(aqi: 1.00, pm25: 1.00, duration: 1.00)
        case .balanced: return PriorityFactor(aqi: 0.92, pm25: 0.88, duration: 1.08)
        case .clean:    return PriorityFactor(aqi: 0.78, pm25: 0.70, duration: 1.22)
        }
    }

    // MARK: - Chrome

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.88))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
    }
}
