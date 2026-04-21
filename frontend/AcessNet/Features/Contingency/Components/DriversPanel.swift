//
//  DriversPanel.swift
//  AcessNet
//
//  Panel "¿Por qué?" — muestra top drivers que empujan la predicción.
//

import SwiftUI

struct DriversPanel: View {
    @Environment(\.weatherTheme) private var theme
    let drivers: [ForecastDriver]

    @State private var animate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.textTint.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.textTint.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("¿Por qué esta probabilidad?")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(theme.textTint)
                    Text("Top factores del modelo")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.0)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(drivers.prefix(5).enumerated()), id: \.element.id) { index, driver in
                    DriverRow(driver: driver, animate: animate, index: index)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.textTint.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.textTint.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { animate = true }
        }
    }
}

private struct DriverRow: View {
    @Environment(\.weatherTheme) private var theme
    let driver: ForecastDriver
    let animate: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.humanName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.9))
                    .lineLimit(1)
                if let value = driver.value {
                    Text(formatValue(value))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTint.opacity(0.5))
                }
            }
            Spacer(minLength: 6)
            ImportanceBar(importance: driver.importance, animate: animate, delay: 0.15 + Double(index) * 0.08)
                .frame(width: 80, height: 6)
        }
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : 10)
        .animation(.easeOut(duration: 0.4).delay(0.1 + Double(index) * 0.08), value: animate)
    }

    private func formatValue(_ v: Double) -> String {
        if abs(v) >= 100 {
            return String(format: "%.0f", v)
        } else if abs(v) >= 1 {
            return String(format: "%.1f", v)
        } else {
            return String(format: "%.3f", v)
        }
    }
}

private struct ImportanceBar: View {
    @Environment(\.weatherTheme) private var theme
    let importance: Double
    let animate: Bool
    let delay: Double

    private var intensity: Double { min(1.0, importance * 10) }

    private var color: Color {
        if intensity > 0.75 {
            return Color(red: 0.957, green: 0.263, blue: 0.212) // #F44336
        } else if intensity > 0.5 {
            return Color(red: 1.000, green: 0.596, blue: 0.000) // #FF9800
        } else if intensity > 0.25 {
            return Color(red: 0.976, green: 0.659, blue: 0.145) // #F9A825 (ámbar legible sobre fondo claro)
        } else {
            return Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.textTint.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: animate ? geo.size.width * intensity : 0)
                    .shadow(color: color.opacity(0.45), radius: 3)
                    .animation(.easeOut(duration: 0.7).delay(delay), value: animate)
            }
        }
    }
}
