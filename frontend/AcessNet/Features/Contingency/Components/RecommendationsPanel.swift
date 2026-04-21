//
//  RecommendationsPanel.swift
//  AcessNet
//
//  Acciones sugeridas según probabilidad + perfil del usuario.
//

import SwiftUI

struct RecommendationsPanel: View {
    @Environment(\.weatherTheme) private var theme
    let recommendations: [String]
    let probabilityLevel: ProbabilityLevel

    @State private var animate: Bool = false

    private var icon: String {
        switch probabilityLevel {
        case .low:      return "checkmark.seal.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .high, .veryHigh: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch probabilityLevel {
        case .low:      return Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
        case .moderate: return Color(red: 0.976, green: 0.659, blue: 0.145) // #F9A825 (ámbar legible sobre fondo claro)
        case .high:     return Color(red: 1.000, green: 0.596, blue: 0.000) // #FF9800
        case .veryHigh: return Color(red: 0.957, green: 0.263, blue: 0.212) // #F44336
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                .shadow(color: color.opacity(0.5), radius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("¿Qué hacer?")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(theme.textTint)
                    Text("Acciones sugeridas")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.0)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(recommendations.enumerated()), id: \.element) { index, rec in
                    recommendationRow(rec, index: index)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.textTint.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.35), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { animate = true }
        }
    }

    @ViewBuilder
    private func recommendationRow(_ rec: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.7), radius: 3)
            }
            .padding(.top, 2)

            Text(rec)
                .font(.system(size: 12.5))
                .foregroundColor(theme.textTint.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textTint.opacity(0.03))
        )
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : 12)
        .animation(.easeOut(duration: 0.4).delay(0.1 + Double(index) * 0.08), value: animate)
    }
}
