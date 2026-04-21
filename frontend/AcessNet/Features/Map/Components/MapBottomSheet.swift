//
//  MapBottomSheet.swift
//  AcessNet
//
//  Contenedor universal de bottom sheet para el mapa.
//  Reemplaza LocationInfoCard / HeroAirQualityCard / RouteInfoCard fragmentados.
//
//  Características:
//  - 3 detents nativos (peek / medium / large) con swipe drag.
//  - Handle bar interactivo con cambio de color al arrastrar.
//  - Backdrop dim progresivo (opción B: mapa interactivo en peek/medium).
//  - Estilos semánticos (.info / .hero / .compact) con tratamiento visual distinto.
//  - Animaciones consistentes desde MapSheetTokens.
//

import SwiftUI

// MARK: - Map Bottom Sheet

struct MapBottomSheet<Content: View>: View {

    // MARK: - Bindings / Config

    /// Detent actual del sheet, controlado externamente.
    @Binding var detent: MapSheetDetent

    /// Estilo visual del sheet.
    let style: MapSheetStyle

    /// Contenido del sheet. El caller es responsable de su padding interno
    /// (usamos MapSheetTokens.contentHorizontal por defecto en el container).
    @ViewBuilder let content: () -> Content

    /// Callback opcional cuando el usuario dismissa el sheet (swipe down desde peek).
    var onDismiss: (() -> Void)? = nil

    // MARK: - Internal State

    /// Offset actual de drag (en puntos), se resetea al soltar.
    @GestureState private var dragOffset: CGFloat = 0

    /// Flag interno para colorear el handle bar cuando se está arrastrando.
    @State private var isDragging: Bool = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let targetHeight = detent.height(in: screenHeight)
            let resolvedHeight = max(MapSheetTokens.handleAreaHeight,
                                      targetHeight - dragOffset)

            ZStack(alignment: .bottom) {
                // Backdrop dim (intensidad depende del detent).
                backdrop(screenHeight: screenHeight)

                // Sheet container con handle + content.
                sheetContainer
                    .frame(height: resolvedHeight)
                    .frame(maxWidth: .infinity)
                    .offset(y: 0) // El height controla la aparición, no offset.
                    .gesture(dragGesture(screenHeight: screenHeight))
                    .animation(MapSheetTokens.detentSpring, value: detent)
                    .animation(MapSheetTokens.detentSpring, value: dragOffset)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private func backdrop(screenHeight: CGFloat) -> some View {
        let baseOpacity = MapSheetTokens.backdropOpacity(for: detent)

        // Interpolar opacidad durante el drag para feedback en tiempo real.
        let dragProgress = dragOffset / max(screenHeight, 1)
        let adjusted = max(0, baseOpacity - Double(dragProgress) * 0.3)

        Color.black
            .opacity(adjusted)
            .ignoresSafeArea()
            .allowsHitTesting(detent != .peek)
            .onTapGesture {
                // Tap en el dim baja el detent un nivel.
                guard detent != .peek else { return }
                withAnimation(MapSheetTokens.detentSpring) {
                    detent = detent.nextDown
                }
                HapticFeedback.light()
            }
            .animation(MapSheetTokens.backdropAnimation, value: detent)
    }

    // MARK: - Sheet Container

    private var sheetContainer: some View {
        VStack(spacing: 0) {
            handleArea
            contentArea
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: MapSheetTokens.containerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MapSheetTokens.containerRadius,
                style: .continuous
            )
            .fill(MapSheetTokens.containerBaseColor)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: MapSheetTokens.containerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: MapSheetTokens.containerRadius,
                    style: .continuous
                )
                .fill(MapSheetTokens.containerMaterial)
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: MapSheetTokens.containerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MapSheetTokens.containerRadius,
                style: .continuous
            )
            .stroke(strokeGradient, lineWidth: MapSheetTokens.strokeWidth)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: MapSheetTokens.containerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MapSheetTokens.containerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: shadowColor,
            radius: MapSheetTokens.shadowRadius,
            y: MapSheetTokens.shadowOffsetY
        )
    }

    // MARK: - Handle Area

    private var handleArea: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(isDragging
                      ? MapSheetTokens.handleColorActive
                      : MapSheetTokens.handleColor)
                .frame(width: MapSheetTokens.handleWidth,
                       height: MapSheetTokens.handleHeight)
                .padding(.top, MapSheetTokens.handleTopInset)
                .padding(.bottom, MapSheetTokens.handleBottomInset)
                .animation(.easeOut(duration: 0.15), value: isDragging)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap en el handle cicla peek → medium → large → medium.
            let next: MapSheetDetent
            switch detent {
            case .peek:   next = .medium
            case .medium: next = .large
            case .large:  next = .peek
            }
            withAnimation(MapSheetTokens.detentSpring) {
                detent = next
            }
            HapticFeedback.light()
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .top)
            .clipped()
    }

    // MARK: - Drag Gesture

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                // Permitir drag hacia arriba (valor negativo) y abajo (positivo).
                // Cap el drag up para no exceder el large.
                let raw = value.translation.height
                state = raw
            }
            .onChanged { _ in
                if !isDragging {
                    isDragging = true
                }
            }
            .onEnded { value in
                isDragging = false
                handleDragEnded(translation: value.translation.height,
                                velocity: value.predictedEndTranslation.height - value.translation.height,
                                screenHeight: screenHeight)
            }
    }

    private func handleDragEnded(translation: CGFloat,
                                  velocity: CGFloat,
                                  screenHeight: CGFloat) {
        let threshold = MapSheetTokens.dragThreshold
        let fastVelocity = abs(velocity) > MapSheetTokens.dragVelocityThreshold

        // Dirección y magnitud del gesto.
        let isDraggingDown = translation > 0
        let pastThreshold = abs(translation) > threshold

        // Decisión de detent destino.
        let nextDetent: MapSheetDetent

        if fastVelocity {
            // Swipe rápido salta un detent en la dirección del gesto.
            nextDetent = isDraggingDown ? detent.nextDown : detent.nextUp
        } else if pastThreshold {
            // Swipe pausado cambia al detent adyacente.
            nextDetent = isDraggingDown ? detent.nextDown : detent.nextUp
        } else {
            // Movimiento insuficiente, volver al mismo detent (snap back).
            nextDetent = detent
        }

        // Si ya estábamos en peek y el usuario hace swipe down fuerte → dismiss.
        if detent == .peek && isDraggingDown && (fastVelocity || translation > threshold * 1.5) {
            onDismiss?()
            HapticFeedback.medium()
            return
        }

        withAnimation(MapSheetTokens.detentSpring) {
            detent = nextDetent
        }

        if nextDetent != detent {
            HapticFeedback.light()
        }
    }

    // MARK: - Style Computed Properties

    /// Gradient del stroke — cambia según el estilo.
    private var strokeGradient: LinearGradient {
        switch style {
        case .info, .compact:
            return LinearGradient(
                colors: [
                    MapSheetColor.strokeMedium,
                    MapSheetColor.strokeSubtle
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hero(let tint):
            return LinearGradient(
                colors: [
                    tint.opacity(0.55),
                    tint.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Color de sombra — tiene tinte si es .hero.
    private var shadowColor: Color {
        switch style {
        case .info, .compact:
            return MapSheetTokens.shadowColorNeutral
        case .hero(let tint):
            return tint.opacity(MapSheetTokens.shadowTintOpacity)
        }
    }
}

// MARK: - Convenience Modifier

extension View {
    /// Monta un MapBottomSheet sobre esta vista (que típicamente es el mapa).
    /// El sheet se posiciona en el bottom y mantiene el mapa interactivo en peek/medium.
    func mapBottomSheet<SheetContent: View>(
        detent: Binding<MapSheetDetent>,
        style: MapSheetStyle = .info,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        ZStack(alignment: .bottom) {
            self
            MapBottomSheet(
                detent: detent,
                style: style,
                content: content,
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Peek · Info") {
    StatefulPreviewWrapper(MapSheetDetent.peek) { detent in
        ZStack {
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            MapBottomSheet(detent: detent, style: .info) {
                VStack(alignment: .leading, spacing: MapSheetTokens.sectionSpacing) {
                    Text("PEEK · INFO")
                        .font(MapSheetTypography.overline)
                        .tracking(MapSheetTypography.overlineTracking)
                        .foregroundStyle(MapSheetColor.textTertiary)

                    Text("Tap handle to expand")
                        .font(MapSheetTypography.title)
                        .foregroundStyle(MapSheetColor.textPrimary)
                }
                .padding(.horizontal, MapSheetTokens.contentHorizontal)
                .padding(.bottom, MapSheetTokens.contentBottom)
            }
        }
    }
}

#Preview("Medium · Hero") {
    StatefulPreviewWrapper(MapSheetDetent.medium) { detent in
        ZStack {
            LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            MapBottomSheet(detent: detent, style: .hero(tint: MapSheetColor.ml)) {
                VStack(alignment: .leading, spacing: MapSheetTokens.sectionSpacing) {
                    Text("HERO STYLE")
                        .font(MapSheetTypography.overline)
                        .tracking(MapSheetTypography.overlineTracking)
                        .foregroundStyle(MapSheetColor.textTertiary)

                    Text("42")
                        .font(MapSheetTypography.display)
                        .foregroundStyle(MapSheetColor.aqiGood)

                    Text("Air quality · Good")
                        .font(MapSheetTypography.title)
                        .foregroundStyle(MapSheetColor.textPrimary)
                }
                .padding(.horizontal, MapSheetTokens.contentHorizontal)
                .padding(.bottom, MapSheetTokens.contentBottom)
            }
        }
    }
}

/// Helper para previews con @State interno.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
#endif
