//
//  TreatmentCardView.swift
//  AcessNet
//
//  Tarjeta individual de la lista de tratamientos estilo "Cure Menu".
//

import SwiftUI

struct TreatmentCardView: View {
    @Environment(\.weatherTheme) private var theme

    let treatment: Treatment
    var onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onTap()
        }) {
            HStack(spacing: 14) {
                iconCircle
                VStack(alignment: .leading, spacing: 3) {
                    Text(treatment.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.textTint)
                        .lineLimit(1)
                    Text(treatment.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.textTint.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(treatment.title). \(treatment.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#7DD3FC").opacity(0.15))
            Circle()
                .stroke(Color(hex: "#7DD3FC").opacity(0.35), lineWidth: 1)
            Image(systemName: treatment.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#7DD3FC"))
        }
        .frame(width: 40, height: 40)
    }
}
