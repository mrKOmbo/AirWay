//
//  DataSourcesView.swift
//  AcessNet
//
//  Transparencia sobre las fuentes de datos: NASA TEMPO, OpenAQ, WAQI,
//  OpenMeteo, RAMA CDMX. Permite al usuario deshabilitar fuentes y ver
//  latencia/actualización.
//

import SwiftUI

struct DataSource: Identifiable, Hashable {
    let id: String
    let name: String
    let organization: String
    let description: String
    let icon: String
    let tint: Color
    let contaminants: [String]
    let latencyLabel: String
    let accent: String // emoji corto para narrativa
}

extension DataSource {
    static let tempo = DataSource(
        id: "tempo",
        name: "NASA TEMPO",
        organization: "NASA · GSFC",
        description: "Satélite geoestacionario que mide NO₂, O₃ y HCHO sobre Norteamérica cada hora, a 2.1 km de resolución.",
        icon: "globe.americas.fill",
        tint: Color(hex: "#4A90E2"),
        contaminants: ["NO₂", "O₃", "HCHO"],
        latencyLabel: "≈ 1 h · satelital",
        accent: "🛰️"
    )
    static let openaq = DataSource(
        id: "openaq",
        name: "OpenAQ",
        organization: "OpenAQ.org",
        description: "Red global de estaciones terrestres de bajo costo. Datos abiertos de PM2.5 y PM10 por comunidad.",
        icon: "antenna.radiowaves.left.and.right",
        tint: Color(hex: "#2ECC71"),
        contaminants: ["PM2.5", "PM10"],
        latencyLabel: "≈ 15 min · terrestre",
        accent: "🌍"
    )
    static let waqi = DataSource(
        id: "waqi",
        name: "WAQI",
        organization: "World Air Quality Index",
        description: "Índice agregado de >30 000 estaciones oficiales. Fallback cuando OpenAQ no cubre la zona.",
        icon: "aqi.medium",
        tint: Color(hex: "#F39C12"),
        contaminants: ["AQI", "PM2.5", "O₃"],
        latencyLabel: "≈ 30 min · terrestre",
        accent: "📊"
    )
    static let openmeteo = DataSource(
        id: "openmeteo",
        name: "Open-Meteo",
        organization: "Open-Meteo.com",
        description: "Modelo meteorológico abierto. Viento, temperatura y humedad alimentan la predicción de dispersión.",
        icon: "wind",
        tint: Color(hex: "#6EE7D9"),
        contaminants: ["Viento", "Temp", "Humedad"],
        latencyLabel: "≈ 10 min · modelo",
        accent: "💨"
    )
    static let rama = DataSource(
        id: "rama",
        name: "RAMA CDMX",
        organization: "SEDEMA Ciudad de México",
        description: "Red Automática de Monitoreo. 44 estaciones oficiales en la ZMVM, datos validados gubernamentales.",
        icon: "building.2.fill",
        tint: Color(hex: "#E74C3C"),
        contaminants: ["PM2.5", "O₃", "NO₂", "SO₂"],
        latencyLabel: "≈ 1 h · oficial",
        accent: "🏛️"
    )

    static let all: [DataSource] = [.tempo, .openaq, .waqi, .openmeteo, .rama]
}

struct DataSourcesView: View {
    @Environment(\.weatherTheme) private var theme
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        let theme = WeatherTheme(condition: WeatherCondition(rawValue: appSettings.weatherOverrideRaw) ?? .overcast)

        ZStack {
            theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    statusBanner(theme: theme)

                    VStack(spacing: 12) {
                        ForEach(DataSource.all) { source in
                            DataSourceCard(
                                source: source,
                                isEnabled: binding(for: source.id)
                            )
                        }
                    }

                    infoCard
                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Data Sources")
                    .font(.headline)
                    .foregroundColor(theme.textTint)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#4A90E2"), Color(hex: "#6EE7D9")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text("¿De dónde viene tu dato?")
                .font(.title3.bold())
                .foregroundColor(theme.textTint)
            Text("AirWay combina \(activeCount) fuentes activas. Desactiva las que no quieras usar.")
                .font(.footnote)
                .foregroundColor(theme.textTint.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private func statusBanner(theme: WeatherTheme) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activeCount > 0 ? Color(hex: "#2ECC71") : Color(hex: "#E74C3C"))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(activeCount > 0 ? Color(hex: "#2ECC71").opacity(0.3) : Color.clear, lineWidth: 6)
                        .scaleEffect(1.5)
                )
            Text(activeCount > 0
                 ? "\(activeCount)/\(DataSource.all.count) fuentes activas"
                 : "⚠️ Todas las fuentes están desactivadas")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textTint)
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(hex: "#4A90E2"))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardColor)
        )
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cómo los combinamos", systemImage: "questionmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textTint)
            Text("Cada punto del mapa pondera fuentes por cercanía y latencia. TEMPO se usa para columnas atmosféricas; OpenAQ/RAMA para la superficie; Open-Meteo modela dispersión.")
                .font(.caption)
                .foregroundColor(theme.textTint.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    // MARK: - helpers

    private var activeCount: Int {
        var n = 0
        if appSettings.useTEMPO { n += 1 }
        if appSettings.useOpenAQ { n += 1 }
        if appSettings.useWAQI { n += 1 }
        if appSettings.useOpenMeteo { n += 1 }
        if appSettings.useRAMA { n += 1 }
        return n
    }

    private func binding(for id: String) -> Binding<Bool> {
        switch id {
        case "tempo": return $appSettings.useTEMPO
        case "openaq": return $appSettings.useOpenAQ
        case "waqi": return $appSettings.useWAQI
        case "openmeteo": return $appSettings.useOpenMeteo
        case "rama": return $appSettings.useRAMA
        default: return .constant(false)
        }
    }
}

// MARK: - Data Source Card

private struct DataSourceCard: View {
    @Environment(\.weatherTheme) private var theme
    let source: DataSource
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(source.tint.opacity(isEnabled ? 0.25 : 0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: source.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isEnabled ? source.tint : theme.textTint.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(source.accent).font(.caption)
                        Text(source.name)
                            .font(.body.weight(.bold))
                            .foregroundColor(theme.textTint)
                    }
                    Text(source.organization)
                        .font(.caption)
                        .foregroundColor(theme.textTint.opacity(0.55))
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(source.tint)
            }

            if isEnabled {
                Text(source.description)
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(source.contaminants, id: \.self) { c in
                        Text(c)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(source.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(source.tint.opacity(0.15))
                            )
                    }
                    Spacer()
                    Label(source.latencyLabel, systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(theme.textTint.opacity(0.5))
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.textTint.opacity(isEnabled ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEnabled ? source.tint.opacity(0.25) : .clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

#Preview {
    NavigationStack {
        DataSourcesView()
            .environmentObject(AppSettings.shared)
    }
}
