//
//  TripBriefingSheet.swift
//  AcessNet
//
//  Bottom-sheet flotante que compone el Trip Briefing completo:
//  toggle + card del modo activo + VersusBar + botones de acción.
//

import SwiftUI

struct TripBriefingSheet: View {
    @ObservedObject var viewModel: TripBriefingViewModel

    let onDismiss: () -> Void
    let onGo: () -> Void
    let onOpenStations: () -> Void
    let onOpenDeparture: () -> Void
    let onAddVehicle: () -> Void

    @Environment(\.weatherTheme) private var theme
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    // MARK: - Snap points

    enum SheetSnap: CaseIterable {
        case peek      // mínimo — solo barra compacta con destino + CTA
        case medium    // intermedio — agrega toggle + picker + versus + botones
        case full      // máximo — todo con card expandida

        /// Altura en puntos (no fracción de pantalla, para que la peek
        /// bar siempre sea corta sin importar el tamaño del dispositivo).
        func height(forScreen screen: CGFloat) -> CGFloat {
            switch self {
            case .peek:   return 170                          // barra compacta
            case .medium: return screen * 0.55
            case .full:   return screen * 0.88
            }
        }
    }

    @State private var currentSnap: SheetSnap = .peek
    @State private var dragOffset: CGFloat = 0

    // MARK: - Body

    var body: some View {
        let screenH = UIScreen.main.bounds.height
        let baseHeight = currentSnap.height(forScreen: screenH)
        // `dragOffset > 0` = arrastre hacia abajo (reduce altura).
        // `dragOffset < 0` = arrastre hacia arriba (aumenta altura).
        let effectiveHeight = max(140, min(screenH * 0.92, baseHeight - dragOffset))
        let isPeek = (currentSnap == .peek && dragOffset == 0)

        VStack(spacing: 0) {
            grabberHandle
            // Contenido: peek bar compacto o pila completa según snap.
            if isPeek {
                peekBar
                    .transition(.opacity.combined(with: .offset(y: 4)))
            } else {
                expandedContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: effectiveHeight, alignment: .top)
        .background(sheetBackground)
        .overlay(sheetBorder)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewModel.mode)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: currentSnap)
    }

    // MARK: - Peek bar (estado mínimo)

    private var peekBar: some View {
        VStack(spacing: 10) {
            // Fila 1: icono modo + destino + X
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(peekAccent.opacity(0.35))
                        .frame(width: 34, height: 34)
                    Image(systemName: viewModel.mode.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("DESTINO")
                        .font(.caption2.bold())
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(viewModel.destinationTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.10)))
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar briefing")
            }

            // Fila 2: métrica clave + CTA
            HStack(spacing: 10) {
                peekMetrics
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onGo) {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.mode == .walking ? "figure.walk.motion" : "location.north.line.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(viewModel.mode == .walking ? "Caminar" : "Ir")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.78)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.6))
                    .shadow(color: theme.accent.opacity(0.45), radius: 10, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap en el peek bar expande a medium — UX típica de bottom sheets.
            snapTo(.medium)
        }
    }

    private var peekMetrics: some View {
        HStack(spacing: 10) {
            // Tiempo / distancia
            peekTile(
                icon: "clock.fill",
                value: peekDurationText,
                tint: peekAccent
            )
            // Métrica según modo: costo (auto) o cigarros (pie)
            peekTile(
                icon: viewModel.mode == .walking ? "lungs.fill" : "fuelpump.fill",
                value: peekSecondaryText,
                tint: viewModel.mode == .walking ? Color(hex: "#C78EFF") : Color(hex: "#7ED957")
            )
        }
    }

    private func peekTile(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.22), lineWidth: 0.6)
        )
    }

    private var peekDurationText: String {
        switch viewModel.mode {
        case .walking: return viewModel.walking?.durationLabel ?? "—"
        case .driving: return viewModel.driving?.durationLabel ?? "—"
        }
    }

    private var peekSecondaryText: String {
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

    private var peekAccent: Color {
        switch viewModel.mode {
        case .walking: return Color(hex: "#7ED957")
        case .driving: return Color(hex: "#3AA3FF")
        }
    }

    // MARK: - Expanded content (medium / full)

    private var expandedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                destinationHeader

                TripModeToggle(mode: $viewModel.mode)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)

                // Priority picker — qué prioriza el usuario para la ruta.
                RoutePriorityPicker(
                    selection: Binding(
                        get: { viewModel.routePriority },
                        set: { viewModel.setPriority($0) }
                    ),
                    suggested: viewModel.suggestedPriority
                )
                .padding(.horizontal, 4)

                VersusBar(
                    walking: viewModel.walking,
                    driving: viewModel.driving,
                    activeMode: viewModel.mode,
                    hideDrivingIfMissing: viewModel.vehicleSnapshot == nil
                )
                .animation(.easeInOut(duration: 0.4), value: viewModel.mode)

                actionsRow

                // Card del modo activo (scroll la alcanza en full).
                activeCard
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
                    .id(viewModel.mode)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Grabber (drag handle with gesture)

    private var grabberHandle: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 44, height: 5)
            )
            .contentShape(Rectangle())
            .gesture(sheetDragGesture)
            .accessibilityLabel("Arrastra para expandir o reducir el briefing")
            .accessibilityAction(named: "Expandir") { snapTo(.full) }
            .accessibilityAction(named: "Reducir") { snapTo(.peek) }
            .onTapGesture {
                // Tap al grabber alterna entre peek y medium.
                let next: SheetSnap = (currentSnap == .peek) ? .medium
                                    : (currentSnap == .medium) ? .full
                                    : .peek
                snapTo(next)
            }
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let proposed = value.translation.height
                // Limitar arrastre: no más allá de los extremos razonables.
                dragOffset = max(-600, min(400, proposed))
            }
            .onEnded { value in
                // `translation.height < 0` al subir → incrementa height.
                let velocityY = value.predictedEndTranslation.height - value.translation.height
                let currentY = currentSnap.height(forScreen: UIScreen.main.bounds.height) - dragOffset

                // Umbral por velocidad: gesto rápido salta de snap.
                let fastThreshold: CGFloat = 350
                if velocityY < -fastThreshold {
                    snapTo(nextUp(from: currentSnap))
                } else if velocityY > fastThreshold {
                    snapTo(nextDown(from: currentSnap))
                } else {
                    // Snap al más cercano por distancia.
                    let screen = UIScreen.main.bounds.height
                    let nearest = SheetSnap.allCases.min(by: {
                        abs($0.height(forScreen: screen) - currentY) < abs($1.height(forScreen: screen) - currentY)
                    }) ?? .peek
                    snapTo(nearest)
                }

                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    dragOffset = 0
                }
            }
    }

    private func snapTo(_ snap: SheetSnap) {
        guard snap != currentSnap else { return }
        HapticFeedback.soft()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            currentSnap = snap
        }
    }

    private func nextUp(from snap: SheetSnap) -> SheetSnap {
        switch snap {
        case .peek: return .medium
        case .medium: return .full
        case .full: return .full
        }
    }

    private func nextDown(from snap: SheetSnap) -> SheetSnap {
        switch snap {
        case .full: return .medium
        case .medium: return .peek
        case .peek: return .peek
        }
    }

    // MARK: - Grabber

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .padding(.bottom, 2)
    }

    // MARK: - Destination header

    private var destinationHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.35))
                    .frame(width: 30, height: 30)
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("DESTINO")
                    .font(.caption2.bold())
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.55))
                Text(viewModel.destinationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.10)))
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar briefing")
        }
    }

    // MARK: - Active card

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
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
                .tint(.white)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.cardColor.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.6)
        )
    }

    // MARK: - Actions row

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button(action: onGo) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.mode == .walking ? "figure.walk.motion" : "location.north.line.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.mode == .walking ? "Empezar caminata" : "Ir ahora")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
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

            shareButton

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

    private var shareButton: some View {
        Button(action: triggerShare) {
            secondaryIconBadge(icon: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Compartir veredicto")
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
                return "Voy a \(viewModel.destinationTitle): \(String(format: "%.1f", w.cigarettes ?? 0))🚬 y \(Int(w.kcalBurned)) kcal · AirWay"
            }
            return "Check el aire antes de caminar · AirWay"
        case .driving:
            if let d = viewModel.driving, let fuel = d.fuel.value {
                return "Voy a \(viewModel.destinationTitle): \(fuel.pesosFormatted) · \(fuel.co2Formatted) CO₂ · AirWay"
            }
            return "AirWay · Huella de mi viaje"
        }
    }

    /// Tarjeta auto-contenida que se exporta como imagen para compartir.
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
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Sheet chrome

    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(theme.pageBackground.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var sheetBorder: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.18),
                        .white.opacity(0.03),
                        theme.accent.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Vehicle snapshot accessor

extension TripBriefingViewModel {
    /// Exposición read-only del vehículo activo para la UI del sheet.
    var vehicleSnapshot: VehicleProfile? {
        // `vehicle` es privado al ViewModel; accedemos vía `VehicleProfileService.shared`.
        VehicleProfileService.shared.activeProfile
    }
}

// MARK: - Share Sheet Wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
