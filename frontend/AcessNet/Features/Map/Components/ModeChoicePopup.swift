//
//  ModeChoicePopup.swift
//  AcessNet
//
//  PASO 1 del flujo de ruta: al poner pin, aparece un popup compacto
//  que pregunta al usuario cómo quiere llegar — CAMINAR o COCHE.
//  Tras elegir, se transita al paso 2 (RouteOptionsPanel).
//

import SwiftUI

struct ModeChoicePopup: View {
    let destinationTitle: String
    let onSelectMode: (BriefingMode) -> Void
    let onDismiss: () -> Void

    @Environment(\.weatherTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            header
            question
            modeButtons
        }
        .padding(18)
        .background(panelBackground)
        .overlay(panelBorder)
        .shadow(color: .black.opacity(0.25), radius: 22, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Header (destino + X)

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.7), theme.accent.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DESTINO")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text(destinationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black.opacity(0.06)))
                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar")
        }
    }

    // MARK: - Question

    private var question: some View {
        HStack {
            Text("¿Cómo prefieres ir?")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Mode buttons

    private var modeButtons: some View {
        HStack(spacing: 10) {
            modeButton(
                mode: .walking,
                icon: "figure.walk",
                title: "Caminar",
                subtitle: "A pie",
                accent: Color(hex: "#7ED957")
            )
            modeButton(
                mode: .driving,
                icon: "car.fill",
                title: "Coche",
                subtitle: "En auto",
                accent: Color(hex: "#3AA3FF")
            )
        }
    }

    private func modeButton(
        mode: BriefingMode,
        icon: String,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        Button {
            HapticFeedback.medium()
            onSelectMode(mode)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: accent.opacity(0.45), radius: 10, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.88))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
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

// MARK: - Preview

#Preview("ModeChoicePopup") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "#0A0A0F"), Color(hex: "#2E4A6B")],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        ModeChoicePopup(
            destinationTitle: "Calle Unidad Habitacional Belum 44",
            onSelectMode: { _ in },
            onDismiss: { }
        )
        .padding()
    }
    .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
}
