//
//  AQIHeaderView.swift
//  AcessNet
//
//  Badge fijo en la parte superior del HealthMenu con el AQI actual.
//  Mock por ahora; se alimentará de la API real más adelante.
//

import SwiftUI

struct AQIHeaderView: View {
    @Environment(\.weatherTheme) private var theme

    let badge: HealthMenuViewModel.AQIBadge

    var body: some View {
        HStack(spacing: 14) {
            aqiCircle
            VStack(alignment: .leading, spacing: 4) {
                Text("\(badge.location) · \(badge.pollutant) \(badge.level)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textTint)
                    .tracking(0.4)
                Text(String(localized: "Calidad del aire en tiempo real"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTint.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTint.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [badge.tint.opacity(0.65), badge.tint.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: badge.tint.opacity(0.3), radius: 18, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Calidad del aire en \(badge.location): \(badge.pollutant) nivel \(badge.level). AQI \(badge.aqi)")
        )
    }

    private var aqiCircle: some View {
        ZStack {
            Circle()
                .fill(badge.tint.opacity(0.2))
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [badge.tint, badge.tint.opacity(0.3), badge.tint],
                        center: .center
                    ),
                    lineWidth: 3
                )
            VStack(spacing: -2) {
                Text("\(badge.aqi)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                Text("AQI")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.textTint.opacity(0.7))
                    .tracking(1.2)
            }
        }
        .frame(width: 52, height: 52)
    }
}
