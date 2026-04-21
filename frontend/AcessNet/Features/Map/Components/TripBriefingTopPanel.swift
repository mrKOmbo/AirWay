//
//  TripBriefingTopPanel.swift
//  AcessNet
//
//  Panel superior deplegable que reemplaza al bottom sheet. Se ancla
//  debajo del search bar (top de la pantalla) y alterna entre:
//  - Colapsado (~110pt): destino + métrica clave + CTA + chevron.
//  - Expandido: toggle modo + picker prioridad + versus bar + acciones
//    + card del modo activo (scrollable si excede).
//

import SwiftUI

struct TripBriefingTopPanel: View {
    @ObservedObject var viewModel: TripBriefingViewModel

    let onDismiss: () -> Void
    let onGo: () -> Void
    let onOpenStations: () -> Void
    let onOpenDeparture: () -> Void
    let onAddVehicle: () -> Void

    @Environment(\.weatherTheme) private var theme
    @State private var isExpanded: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareImage: UIImage?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            collapsedHeader
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -6)),
                        removal: .opacity.combined(with: .offset(y: -4))
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .background(panelBackground)
        .overlay(panelBorder)
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: isExpanded)
        .animation(.easeInOut(duration: 0.35), value: viewModel.mode)
    }

    // MARK: - Collapsed header (siempre visible)

    private var collapsedHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icono modo activo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                modeAccent.opacity(0.65),
                                modeAccent.opacity(0.18)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                Image(systemName: viewModel.mode.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Título + métrica compacta
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("DESTINO")
                        .font(.caption2.bold())
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                }
                Text(viewModel.destinationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if !isExpanded {
                    compactMetrics
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Botones de acción (sólo en colapsado) + chevron + cerrar
            actions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var compactMetrics: some View {
        HStack(spacing: 6) {
            metricChip(icon: "clock.fill", text: durationText, tint: modeAccent)
            metricChip(
                icon: viewModel.mode == .walking ? "lungs.fill" : "fuelpump.fill",
                text: secondaryMetricText,
                tint: viewModel.mode == .walking ? Color(hex: "#C78EFF") : Color(hex: "#7ED957")
            )
        }
    }

    private func metricChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 0.5))
    }

    private var actions: some View {
        HStack(spacing: 6) {
            // Botón primario "Ir" (siempre visible en colapsado)
            if !isExpanded {
                Button(action: onGo) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.mode == .walking ? "figure.walk.motion" : "location.north.line.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(viewModel.mode == .walking ? "Caminar" : "Ir")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.78)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.6))
                    .shadow(color: theme.accent.opacity(0.45), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Chevron expandir/colapsar
            Button {
                HapticFeedback.soft()
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.12)))
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 0.6))
                    .rotation3DEffect(
                        .degrees(isExpanded ? 180 : 0),
                        axis: (x: 1, y: 0, z: 0)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Colapsar briefing" : "Expandir briefing")

            // Cerrar
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.10)))
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar briefing")
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Toggle modo
                TripModeToggle(mode: $viewModel.mode)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                // Priority picker
                RoutePriorityPicker(
                    selection: Binding(
                        get: { viewModel.routePriority },
                        set: { viewModel.setPriority($0) }
                    ),
                    suggested: viewModel.suggestedPriority
                )
                .padding(.horizontal, 4)

                // Versus bar
                VersusBar(
                    walking: viewModel.walking,
                    driving: viewModel.driving,
                    activeMode: viewModel.mode,
                    hideDrivingIfMissing: viewModel.vehicleSnapshot == nil
                )

                // Acciones (botón grande + share)
                expandedActions

                // Card del modo activo
                activeCard
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
                    .id(viewModel.mode)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: maxExpandedContentHeight)
    }

    /// Alto máximo del contenido expandido: evita que el panel tape
    /// todo el mapa. Se calcula para dejar ~35% de mapa visible.
    private var maxExpandedContentHeight: CGFloat {
        let screenH = UIScreen.main.bounds.height
        return min(screenH * 0.55, 520)
    }

    private var expandedActions: some View {
        HStack(spacing: 10) {
            Button(action: onGo) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.mode == .walking ? "figure.walk.motion" : "location.north.line.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.mode == .walking ? "Empezar caminata" : "Ir ahora")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.78)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.6)
                )
                .shadow(color: theme.accent.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: triggerShare) {
                secondaryIconBadge(icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartir veredicto")

            if viewModel.mode == .driving, viewModel.vehicleSnapshot != nil {
                Button(action: onOpenDeparture) {
                    secondaryIconBadge(icon: "clock.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Programar salida")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img, shareCaption])
            }
        }
    }

    private func secondaryIconBadge(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 46, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
            )
    }

    // MARK: - Active card (walking or driving)

    @ViewBuilder
    private var activeCard: some View {
        switch viewModel.mode {
        case .walking:
            if let walking = viewModel.walking {
                WalkingBriefingCard(
                    briefing: walking,
                    hotspots: viewModel.hotspots,
                    destinationTitle: viewModel.destinationTitle,
                    cleanerRouteActive: viewModel.cleanerRouteActive,
                    isFindingCleanerRoute: viewModel.isFindingCleanerRoute,
                    onActivityChange: { viewModel.setWalkActivity($0) },
                    onRequestCleanerRoute: { viewModel.requestCleanerWalkingRoute() }
                )
            } else {
                loadingPlaceholder(title: "Calculando ruta a pie...")
            }
        case .driving:
            if let driving = viewModel.driving {
                DrivingBriefingCard(
                    briefing: driving,
                    vehicle: viewModel.vehicleSnapshot,
                    destinationTitle: viewModel.destinationTitle,
                    onOpenStations: onOpenStations,
                    onOpenDeparture: onOpenDeparture,
                    onAddVehicle: onAddVehicle,
                    onRetry: { viewModel.reloadDriving() }
                )
            } else {
                loadingPlaceholder(title: "Calculando ruta en auto...")
            }
        }
    }

    private func loadingPlaceholder(title: String) -> some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.6)
        )
    }

    // MARK: - Derived text

    private var durationText: String {
        switch viewModel.mode {
        case .walking: return viewModel.walking?.durationLabel ?? "—"
        case .driving: return viewModel.driving?.durationLabel ?? "—"
        }
    }

    private var secondaryMetricText: String {
        switch viewModel.mode {
        case .walking:
            if let cigs = viewModel.walking?.cigarettes {
                return String(format: "%.2f 🚬", cigs)
            }
            return "— 🚬"
        case .driving:
            if let est = viewModel.driving?.fuel.value {
                return est.pesosFormatted
            }
            if viewModel.driving?.fuel.isLoading == true {
                return "..."
            }
            return "—"
        }
    }

    private var modeAccent: Color {
        switch viewModel.mode {
        case .walking: return Color(hex: "#7ED957")
        case .driving: return Color(hex: "#3AA3FF")
        }
    }

    // MARK: - Panel chrome (glass)

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(theme.pageBackground.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.18),
                        .white.opacity(0.04),
                        theme.accent.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Share

    private func triggerShare() {
        HapticFeedback.light()
        let snapshot = verdictSnapshot
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage {
            shareImage = img
            showShareSheet = true
        }
    }

    private var shareCaption: String {
        switch viewModel.mode {
        case .walking:
            if let w = viewModel.walking {
                let cigStr = w.cigarettes.map { String(format: "%.1f🚬", $0) } ?? "sin datos"
                return "Voy a \(viewModel.destinationTitle): \(cigStr) y \(Int(w.kcalBurned)) kcal · AirWay"
            }
            return "Check el aire antes de caminar · AirWay"
        case .driving:
            if let d = viewModel.driving, let fuel = d.fuel.value {
                return "Voy a \(viewModel.destinationTitle): \(fuel.pesosFormatted) · \(fuel.co2Formatted) CO₂ · AirWay"
            }
            return "AirWay · Huella de mi viaje"
        }
    }

    private var verdictSnapshot: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIRWAY · Trip Briefing")
                .font(.caption2.bold())
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.55))
            Text(viewModel.destinationTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            switch viewModel.mode {
            case .walking:
                if let w = viewModel.walking {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading) {
                            Text(String(format: "%.2f", w.cigarettes ?? 0))
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("cigarros equivalentes")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Divider().background(Color.white.opacity(0.2)).frame(height: 60)
                        VStack(alignment: .leading) {
                            Text("\(Int(w.kcalBurned)) kcal")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text(w.durationLabel)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Text("Veredicto: \(w.verdict.title)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(hex: w.verdict.glowHex))
                }
            case .driving:
                if let d = viewModel.driving, let fuel = d.fuel.value {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading) {
                            Text(fuel.pesosFormatted)
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("costo del viaje")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Divider().background(Color.white.opacity(0.2)).frame(height: 60)
                        VStack(alignment: .leading) {
                            Text(fuel.co2Formatted)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text("de CO₂")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Text(String(format: "En cabina: %.2f 🚬", d.cabinCigarettes ?? 0))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(hex: "#C78EFF"))
                }
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(
            LinearGradient(
                colors: [Color(hex: "#131722"), Color(hex: "#0A0A0F")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Share Sheet wrapper (local al panel)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
