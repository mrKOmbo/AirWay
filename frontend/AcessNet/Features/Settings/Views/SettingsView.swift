//
//  SettingsView.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        // Si AirWay está activo, el init auto-detecta y entrega paleta clara (navy sobre blanco).
        // Si no, usa la condición climática almacenada (temas oscuros).
        let theme = WeatherTheme(
            condition: WeatherCondition(rawValue: appSettings.weatherOverrideRaw) ?? .overcast
        )

        return ZStack {
            theme.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Circle()
                            .fill(Color(hex: "#4ECDC4"))
                            .frame(width: 12, height: 12)

                        Text("SETTINGS")
                            .font(.title3.bold())
                            .foregroundColor(theme.textTint)
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)

                    // MARK: - Personalización (nuevas propuestas)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERSONALIZACIÓN")
                            .font(.subheadline)
                            .foregroundColor(theme.textTint.opacity(0.7))
                            .tracking(1)

                        VStack(spacing: 10) {
                            NavigationLink {
                                BreathingProfileView()
                            } label: {
                                SettingsNavRow(
                                    icon: "lungs.fill",
                                    tint: Color(hex: "#FF6B6B"),
                                    title: "Breathing Profile",
                                    subtitle: appSettings.hasActiveBreathingProfile
                                        ? "Activo · sensibilidad \(Int((1 - appSettings.sensitivityMultiplier) * 100))% más alta"
                                        : "Personaliza umbrales según tu salud"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                AICopilotSettingsView()
                            } label: {
                                SettingsNavRow(
                                    icon: "sparkles",
                                    tint: Color(hex: "#4ECDC4"),
                                    title: "AI Copilot",
                                    subtitle: "Tono, memoria y modelo del asistente"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DataSourcesView()
                            } label: {
                                SettingsNavRow(
                                    icon: "point.3.filled.connected.trianglepath.dotted",
                                    tint: Color(hex: "#4A90E2"),
                                    title: "Fuentes de datos",
                                    subtitle: "NASA TEMPO · OpenAQ · WAQI · RAMA"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Air Quality Index Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AIR QUALITY INDEX")
                            .font(.subheadline)
                            .foregroundColor(theme.textTint.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "European AQI",
                                isSelected: appSettings.aqiStandardRaw == "european"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.aqiStandardRaw = "european"
                                }
                            }

                            SegmentButton(
                                title: "US AQI",
                                isSelected: appSettings.aqiStandardRaw == "us"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.aqiStandardRaw = "us"
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.cardColor)
                        )
                    }
                    .padding(.horizontal)

                    // Temperature Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TEMPERATURE")
                            .font(.subheadline)
                            .foregroundColor(theme.textTint.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "°C",
                                isSelected: appSettings.temperatureUnitRaw == "celsius"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.temperatureUnitRaw = "celsius"
                                }
                            }

                            SegmentButton(
                                title: "°F",
                                isSelected: appSettings.temperatureUnitRaw == "fahrenheit"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.temperatureUnitRaw = "fahrenheit"
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.cardColor)
                        )
                    }
                    .padding(.horizontal)

                    // Wind Speed Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WIND SPEED")
                            .font(.subheadline)
                            .foregroundColor(theme.textTint.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "Km/h",
                                isSelected: appSettings.windSpeedUnitRaw == "kmh"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.windSpeedUnitRaw = "kmh"
                                }
                            }

                            SegmentButton(
                                title: "Mph",
                                isSelected: appSettings.windSpeedUnitRaw == "mph"
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appSettings.windSpeedUnitRaw = "mph"
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.cardColor)
                        )
                    }
                    .padding(.horizontal)

                    // Weather Override Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WEATHER SIMULATION")
                            .font(.subheadline)
                            .foregroundColor(theme.textTint.opacity(0.7))
                            .tracking(1)

                        Text("Changes the app's visual theme")
                            .font(.caption)
                            .foregroundColor(theme.textTint.opacity(0.4))

                        let conditions: [(WeatherCondition, String, String)] = [
                            (.sunny, "sun.max.fill", "#FFB830"),
                            (.cloudy, "cloud.fill", "#8EACC0"),
                            (.overcast, "smoke.fill", "#7A8A9A"),
                            (.rainy, "cloud.rain.fill", "#5080C0"),
                            (.stormy, "cloud.bolt.rain.fill", "#8060C0")
                        ]

                        HStack(spacing: 8) {
                            // Auto button
                            Button {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    appSettings.weatherOverride = nil
                                }
                            } label: {
                                let isAuto = appSettings.weatherOverrideRaw.isEmpty
                                VStack(spacing: 6) {
                                    Image(systemName: "a.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(isAuto ? theme.textTint : theme.textTint.opacity(0.4))

                                    Text("Auto")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(isAuto ? theme.textTint : theme.textTint.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isAuto ? theme.textTint.opacity(0.15) : theme.textTint.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isAuto ? theme.textTint.opacity(0.3) : .clear, lineWidth: 1)
                                        )
                                )
                            }

                            ForEach(conditions, id: \.0) { condition, icon, color in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        appSettings.weatherOverride = condition
                                    }
                                } label: {
                                    let isSelected = appSettings.weatherOverride == condition
                                    VStack(spacing: 6) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(isSelected ? Color(hex: color) : theme.textTint.opacity(0.4))
                                            .symbolRenderingMode(.multicolor)

                                        Text(condition.rawValue)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(isSelected ? theme.textTint : theme.textTint.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isSelected ? Color(hex: color).opacity(0.15) : theme.textTint.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? Color(hex: color).opacity(0.4) : .clear, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }

                        // AirWay brand theme — paleta sincronizada con la página web
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                appSettings.isAirWayTheme = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#060A18"), Color(hex: "#0D1427"), Color(hex: "#0A1D4D")],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(hex: "#0099FF").opacity(0.5), lineWidth: 1)
                                        )

                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(hex: "#0099FF"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AirWay")
                                        .font(.subheadline.bold())
                                        .foregroundColor(theme.textTint)

                                    Text("Brand palette · same as the website")
                                        .font(.caption2)
                                        .foregroundColor(theme.textTint.opacity(0.55))
                                }

                                Spacer()

                                if appSettings.isAirWayTheme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "#0099FF"))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(appSettings.isAirWayTheme ? Color(hex: "#0099FF").opacity(0.12) : theme.textTint.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(appSettings.isAirWayTheme ? Color(hex: "#0099FF").opacity(0.5) : theme.textTint.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(theme.textTint.opacity(0.1))
                        .padding(.vertical, 24)

                    // Performance Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "PERFORMANCE")
                            .padding(.bottom, 16)

                        // Proximity Filtering Toggle
                        SettingsToggleRow(
                            title: "Proximity Filtering",
                            subtitle: "Show only nearby elements (\(Int(appSettings.proximityRadiusKm))km)",
                            isOn: $appSettings.enableProximityFiltering
                        )

                        Divider()
                            .background(theme.textTint.opacity(0.1))
                            .padding(.leading, 16)

                        // Proximity Radius Slider
                        if appSettings.enableProximityFiltering {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Visibility Radius")
                                        .font(.body)
                                        .foregroundColor(theme.textTint)

                                    Spacer()

                                    Text("\(Int(appSettings.proximityRadiusKm)) km")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(Color("AccentColor"))
                                }

                                Slider(
                                    value: $appSettings.proximityRadiusKm,
                                    in: 1...5,
                                    step: 0.5
                                )
                                .tint(Color("AccentColor"))

                                HStack {
                                    Text("1 km")
                                        .font(.caption2)
                                        .foregroundColor(theme.textTint.opacity(0.5))

                                    Spacer()

                                    Text("5 km")
                                        .font(.caption2)
                                        .foregroundColor(theme.textTint.opacity(0.5))
                                }
                            }
                            .padding(.vertical, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            Divider()
                                .background(theme.textTint.opacity(0.1))
                                .padding(.leading, 16)
                        }

                        // Performance Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: appSettings.enableProximityFiltering ? "checkmark.circle.fill" : "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(appSettings.enableProximityFiltering ? .green : .blue)

                                Text(appSettings.enableProximityFiltering ? "Performance Optimized" : "Showing All Elements")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.textTint.opacity(0.9))
                            }

                            Text("Grid: \(appSettings.totalAirQualityZones) zones • Static rendering")
                                .font(.caption2)
                                .foregroundColor(theme.textTint.opacity(0.6))

                            if appSettings.enableProximityFiltering {
                                Text("Elements beyond \(Int(appSettings.proximityRadiusKm))km are hidden for better performance.")
                                    .font(.caption2)
                                    .foregroundColor(theme.textTint.opacity(0.5))
                                    .padding(.top, 4)
                            } else {
                                Text("All elements are visible. Performance may vary with many elements.")
                                    .font(.caption2)
                                    .foregroundColor(theme.textTint.opacity(0.5))
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(appSettings.enableProximityFiltering ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // MARK: - Map Experience (Trip Briefing toggle)
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "MAPA · EXPERIENCIA")
                            .padding(.bottom, 16)

                        SettingsToggleRow(
                            title: "Trip Briefing",
                            subtitle: appSettings.useTripBriefing
                                ? "Pin muestra cigarros + gasolinera + huella"
                                : "Pin muestra la tarjeta clásica",
                            isOn: $appSettings.useTripBriefing
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: appSettings.useTripBriefing ? "sparkles" : "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(appSettings.useTripBriefing ? Color(hex: "#7ED957") : .blue)
                                Text(appSettings.useTripBriefing ? "Briefing activo" : "Modo clásico")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.textTint.opacity(0.9))
                            }
                            Text(appSettings.useTripBriefing
                                ? "Al poner un pin verás el modo A pie / En coche, con cigarros equivalentes, costo de gasolina, estaciones en ruta y mejor hora de salida."
                                : "Al poner un pin verás la tarjeta con AQI del destino y botón de calcular ruta.")
                                .font(.caption2)
                                .foregroundColor(theme.textTint.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(
                            appSettings.useTripBriefing
                                ? Color(hex: "#7ED957").opacity(0.10)
                                : Color.blue.opacity(0.10)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    // Support us Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Support us")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(theme.textTint)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            SupportButton(
                                icon: "star.fill",
                                title: "Rate"
                            )

                            Divider()
                                .background(theme.textTint.opacity(0.1))

                            SupportButton(
                                icon: "paperplane.fill",
                                title: "Share"
                            )

                            Divider()
                                .background(theme.textTint.opacity(0.1))

                            SupportButton(
                                icon: "square.grid.2x2.fill",
                                title: "More"
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(theme.cardColor)
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                }
                .avoidTabBar(extraPadding: 20)
            }
        }
        // Propagamos el theme para que los structs internos (SegmentButton, SupportButton, etc.)
        // lo lean vía @Environment. Importante: el env de MainTabView no lleva isAirWay en el
        // init explícito, así que reinyectamos aquí el theme construido con el detector automático.
        .environment(\.weatherTheme, theme)
        .navigationBarHidden(true)
    }
}

// MARK: - Supporting Views

struct SegmentButton: View {
    @Environment(\.weatherTheme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.bold())
                .foregroundColor(isSelected ? (theme.isAirWay ? .white : .black) : theme.textTint.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? (theme.isAirWay ? theme.textTint : Color.white) : Color.clear)
                )
        }
    }
}

struct SupportButton: View {
    @Environment(\.weatherTheme) private var theme
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(theme.textTint.opacity(0.8))
                    .frame(width: 30)

                Text(title)
                    .font(.body)
                    .foregroundColor(theme.textTint)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

struct SectionHeader: View {
    @Environment(\.weatherTheme) private var theme
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(theme.textTint.opacity(0.7))
            .tracking(1)
            .padding(.horizontal)
    }
}

struct SettingsNavRow: View {
    @Environment(\.weatherTheme) private var theme
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.textTint)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.textTint.opacity(0.35))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.textTint.opacity(0.05))
        )
    }
}

struct SettingsToggleRow: View {
    @Environment(\.weatherTheme) private var theme
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(theme.textTint)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.6))
            }
        }
        .tint(Color("AccentColor"))
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
