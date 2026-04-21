//
//  HealthMenuView.swift
//  AcessNet
//
//  Menú tipo "Cure" de Metal Gear Solid 3 adaptado a salud ambiental.
//  Top: AQI badge · Middle: modelo 3D BioDigital · Bottom: tratamientos.
//
//  Se presenta vía `.fullScreenCover` desde BodyScanHubView para cubrir
//  toda la pantalla (estética cinematográfica).
//

import SwiftUI

struct HealthMenuView: View {
    @Environment(\.weatherTheme) private var theme

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = HealthMenuViewModel()
    @State private var modelContainerRef: UUID = UUID()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    topBar
                    AQIHeaderView(badge: viewModel.currentAQIBadge)
                        .padding(.horizontal, 16)

                    modelContainer(height: modelHeight(in: geo))
                        .padding(.horizontal, 16)

                    treatmentsList
                }
                .padding(.top, safeTopPadding)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: organBinding) { organ in
            OrganDetailSheet(
                organ: organ,
                health: viewModel.bodyState.health(for: organ),
                onSeeMore: {
                    // TODO: navegar al detalle completo del órgano
                    print("🩺 ver más sobre: \(organ.rawValue)")
                },
                onClose: { viewModel.dismissOrganDetail() }
            )
        }
    }

    // MARK: - Layout helpers

    private var safeTopPadding: CGFloat { 12 }

    private func modelHeight(in geo: GeometryProxy) -> CGFloat {
        // Target: 60% vertical. iPad: un poco más grande por el ancho extra.
        let base = geo.size.height * 0.58
        return horizontalSizeClass == .regular ? base + 40 : base
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "#0A0A0F"),
                Color(hex: "#13141B"),
                Color(hex: "#0A0A0F")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "Volver"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(theme.textTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(theme.textTint.opacity(0.1), lineWidth: 1))
                )
            }
            .accessibilityLabel(String(localized: "Volver"))

            Spacer()

            VStack(alignment: .center, spacing: 1) {
                Text(String(localized: "Estado corporal"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "#7DD3FC")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(String(localized: "Diagnóstico ambiental"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.5))
                    .tracking(1.2)
                    .textCase(.uppercase)
            }

            Spacer()

            // Placeholder para equilibrar el chevron izquierdo.
            Color.clear.frame(width: 72, height: 32)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Model container

    private func modelContainer(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(theme.textTint.opacity(0.08), lineWidth: 1)
                )

            if let error = viewModel.loadError, viewModel.isModelReady == false {
                errorState(message: error)
            } else {
                AnatomicalModelView(
                    modelName: "anatomy_body",
                    bodyState: viewModel.bodyState,
                    onModelReady: viewModel.handleModelReady,
                    onLoadError: viewModel.handleLoadError,
                    onFallbackNotice: viewModel.handleFallbackNotice,
                    onOrganPicked: viewModel.didSelectOrgan
                )
                .id(modelContainerRef)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .accessibilityLabel(String(localized: "Modelo 3D del cuerpo humano. Toca un órgano para ver su estado."))
                .overlay(loadingOverlay, alignment: .center)
                .overlay(fallbackBanner, alignment: .top)
            }

            VStack {
                HStack {
                    Spacer()
                    resetCameraButton
                }
                Spacer()
                organLegend
            }
            .padding(14)
        }
        .frame(height: height)
    }

    /// Banner discreto cuando el modelo USDZ no existe y estamos en fallback.
    /// La VM marca el error pero `isModelReady` queda `true` porque el modelo
    /// de respaldo sí renderiza.
    @ViewBuilder
    private var fallbackBanner: some View {
        if let error = viewModel.loadError, viewModel.isModelReady {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(error)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
            }
            .foregroundColor(Color(hex: "#F4B942"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.55))
                    .overlay(Capsule().stroke(Color(hex: "#F4B942").opacity(0.35), lineWidth: 1))
            )
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if !viewModel.isModelReady && viewModel.loadError == nil {
            VStack(spacing: 10) {
                ProgressView()
                    .tint(theme.textTint)
                Text(String(localized: "Cargando modelo anatómico…"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.7))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black.opacity(0.55))
            )
        }
    }

    private var resetCameraButton: some View {
        Button {
            HapticFeedback.light()
            modelContainerRef = UUID() // fuerza recrear el VC → reset cámara
        } label: {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.9), .black.opacity(0.4))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel(String(localized: "Restablecer cámara"))
    }

    private var organLegend: some View {
        HStack(spacing: 8) {
            legendDot(label: String(localized: "Sano"), color: Color(hex: "#4ADE80"))
            legendDot(label: String(localized: "Leve"), color: Color(hex: "#F4B942"))
            legendDot(label: String(localized: "Moderado"), color: Color(hex: "#FF8A3D"))
            legendDot(label: String(localized: "Crítico"), color: Color(hex: "#FF5B5B"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.45))
                .overlay(Capsule().stroke(theme.textTint.opacity(0.08), lineWidth: 1))
        )
    }

    private func legendDot(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.75))
        }
    }

    // MARK: - Error state

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(String(localized: "No se pudo cargar el modelo"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textTint)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button(action: {
                viewModel.retryLoad()
                modelContainerRef = UUID()
            }) {
                Text(String(localized: "Reintentar"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#7DD3FC").opacity(0.85))
                    )
            }
        }
        .padding(20)
    }

    // MARK: - Treatments

    private var treatmentsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Recomendaciones"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.textTint.opacity(0.55))
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                Text("\(viewModel.treatments.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(theme.textTint.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(theme.textTint.opacity(0.08))
                    )
            }
            .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(viewModel.treatments) { treatment in
                        TreatmentCardView(treatment: treatment) {
                            viewModel.didTapTreatment(treatment)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Sheet binding

    private var organBinding: Binding<BodyHealthState.Organ?> {
        Binding(
            get: { viewModel.selectedOrgan },
            set: { newValue in
                if newValue == nil { viewModel.dismissOrganDetail() }
                else { viewModel.selectedOrgan = newValue }
            }
        )
    }
}

#Preview {
    HealthMenuView()
}
