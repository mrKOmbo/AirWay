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
    @State private var selectedAQI: AQIStandard = .european
    @State private var selectedTemperature: TemperatureUnit = .celsius
    @State private var selectedWindSpeed: WindSpeedUnit = .kmh

    enum AQIStandard {
        case european
        case us
    }

    enum TemperatureUnit {
        case celsius
        case fahrenheit
    }

    enum WindSpeedUnit {
        case kmh
        case mph
    }

    var body: some View {
        let theme = WeatherTheme(condition: WeatherCondition(rawValue: appSettings.weatherOverrideRaw) ?? .overcast)

        ZStack {
            // Background — dynamic
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
                            .foregroundColor(.white)
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)

                    // Air Quality Index Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AIR QUALITY INDEX")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "European AQI",
                                isSelected: selectedAQI == .european
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedAQI = .european
                                }
                            }

                            SegmentButton(
                                title: "US AQI",
                                isSelected: selectedAQI == .us
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedAQI = .us
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
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "°C",
                                isSelected: selectedTemperature == .celsius
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemperature = .celsius
                                }
                            }

                            SegmentButton(
                                title: "°F",
                                isSelected: selectedTemperature == .fahrenheit
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemperature = .fahrenheit
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
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "Km/h",
                                isSelected: selectedWindSpeed == .kmh
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedWindSpeed = .kmh
                                }
                            }

                            SegmentButton(
                                title: "Mph",
                                isSelected: selectedWindSpeed == .mph
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedWindSpeed = .mph
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
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        Text("Changes the app's visual theme")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))

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
                                VStack(spacing: 6) {
                                    Image(systemName: "a.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(appSettings.weatherOverrideRaw.isEmpty ? .white : .white.opacity(0.4))

                                    Text("Auto")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(appSettings.weatherOverrideRaw.isEmpty ? .white : .white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(appSettings.weatherOverrideRaw.isEmpty ? .white.opacity(0.15) : .white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(appSettings.weatherOverrideRaw.isEmpty ? .white.opacity(0.3) : .clear, lineWidth: 1)
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
                                            .foregroundColor(isSelected ? Color(hex: color) : .white.opacity(0.4))
                                            .symbolRenderingMode(.multicolor)

                                        Text(condition.rawValue)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isSelected ? Color(hex: color).opacity(0.15) : .white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? Color(hex: color).opacity(0.4) : .clear, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Color.white.opacity(0.1))
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
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)

                        // Proximity Radius Slider
                        if appSettings.enableProximityFiltering {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Visibility Radius")
                                        .font(.body)
                                        .foregroundColor(.white)

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
                                        .foregroundColor(.white.opacity(0.5))

                                    Spacer()

                                    Text("5 km")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.vertical, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            Divider()
                                .background(Color.white.opacity(0.1))
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
                                    .foregroundColor(.white.opacity(0.9))
                            }

                            Text("Grid: \(appSettings.totalAirQualityZones) zones • Static rendering")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))

                            if appSettings.enableProximityFiltering {
                                Text("Elements beyond \(Int(appSettings.proximityRadiusKm))km are hidden for better performance.")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            } else {
                                Text("All elements are visible. Performance may vary with many elements.")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(appSettings.enableProximityFiltering ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Support us Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Support us")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            SupportButton(
                                icon: "star.fill",
                                title: "Rate"
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SupportButton(
                                icon: "paperplane.fill",
                                title: "Share"
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

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

                    Spacer(minLength: 100)
                }
            }
        }
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
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? .white : .clear)
                )
        }
    }
}

struct SupportButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30)

                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .tracking(1)
            .padding(.horizontal)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
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
