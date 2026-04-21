//
//  BreathingProfileView.swift
//  AcessNet
//
//  Perfil de sensibilidad respiratoria. Ajusta umbrales PPI y AQI
//  automáticamente según condiciones médicas y hábitos del usuario.
//

import SwiftUI

struct BreathingProfileView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var theme: WeatherTheme {
        WeatherTheme(condition: WeatherCondition(rawValue: appSettings.weatherOverrideRaw) ?? .overcast)
    }

    var body: some View {
        ZStack {
            theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    sensitivityPreviewCard(theme: theme)
                    conditionsSection(theme: theme)
                    habitsSection(theme: theme)
                    disclaimerCard
                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Breathing Profile")
                    .font(.headline)
                    .foregroundColor(theme.textTint)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#4ECDC4"), Color(hex: "#6EE7D9")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text("Personaliza tu sensibilidad")
                .font(.title3.bold())
                .foregroundColor(theme.textTint)
                .multilineTextAlignment(.center)

            Text("AirWay ajustará los umbrales de PM2.5, O₃ y las alertas PPI del Watch según tu perfil.")
                .font(.footnote)
                .foregroundColor(theme.textTint.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Sensitivity preview

    private func sensitivityPreviewCard(theme: WeatherTheme) -> some View {
        let multiplier = appSettings.sensitivityMultiplier
        let percentage = Int((1 - multiplier) * 100)
        let color: Color = {
            if multiplier >= 0.95 { return Color(hex: "#8EE4AF") }
            if multiplier >= 0.75 { return Color(hex: "#FFD93D") }
            return Color(hex: "#FF6B6B")
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TU PERFIL")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textTint.opacity(0.6))
                    .tracking(1)
                Spacer()
                Circle().fill(color).frame(width: 8, height: 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(multiplier >= 0.95 ? "Estándar" : "\(percentage)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textTint)
                if multiplier < 0.95 {
                    Text("más sensible")
                        .font(.subheadline)
                        .foregroundColor(theme.textTint.opacity(0.7))
                }
            }

            Text(previewDescription(multiplier: multiplier))
                .font(.footnote)
                .foregroundColor(theme.textTint.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func previewDescription(multiplier: Double) -> String {
        let pm25Threshold = Int(35 * multiplier)
        if multiplier >= 0.95 {
            return "Usamos umbrales OMS estándar. PM2.5 alerta: 35 µg/m³."
        }
        return "PM2.5 alerta a \(pm25Threshold) µg/m³ (vs. 35 estándar). Recibirás avisos antes."
    }

    // MARK: - Conditions section

    private func conditionsSection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CONDICIONES MÉDICAS")

            VStack(spacing: 8) {
                ConditionCard(
                    icon: "lungs.fill",
                    title: "Asma",
                    subtitle: "Sensibilidad alta a PM2.5 y O₃",
                    tint: Color(hex: "#FF6B6B"),
                    isOn: $appSettings.hasAsthma
                )
                ConditionCard(
                    icon: "wind",
                    title: "EPOC / enfermedad pulmonar",
                    subtitle: "Máxima prioridad en alertas",
                    tint: Color(hex: "#FF8A5B"),
                    isOn: $appSettings.hasCOPD
                )
                ConditionCard(
                    icon: "heart.fill",
                    title: "Cardiopatía",
                    subtitle: "NO₂ y PM2.5 afectan al corazón",
                    tint: Color(hex: "#E74C3C"),
                    isOn: $appSettings.hasHeartCondition
                )
                ConditionCard(
                    icon: "figure.stand.dress",
                    title: "Embarazo",
                    subtitle: "Protege al feto de contaminantes",
                    tint: Color(hex: "#F5A9C1"),
                    isOn: $appSettings.isPregnant
                )
                ConditionCard(
                    icon: "person.2.fill",
                    title: "Persona mayor (65+)",
                    subtitle: "Sistema respiratorio más vulnerable",
                    tint: Color(hex: "#B88EFF"),
                    isOn: $appSettings.isElderly
                )
            }
        }
    }

    // MARK: - Habits section

    private func habitsSection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("HÁBITOS Y ENTORNO")

            VStack(spacing: 8) {
                ConditionCard(
                    icon: "figure.run",
                    title: "Deporte al aire libre",
                    subtitle: "Mayor ventilación = mayor exposición",
                    tint: Color(hex: "#4ECDC4"),
                    isOn: $appSettings.isOutdoorAthlete
                )
                ConditionCard(
                    icon: "figure.and.child.holdinghands",
                    title: "Niño en casa",
                    subtitle: "Sistema respiratorio en desarrollo",
                    tint: Color(hex: "#FFD93D"),
                    isOn: $appSettings.hasChildAtHome
                )
                ConditionCard(
                    icon: "smoke.fill",
                    title: "Fumador",
                    subtitle: "Ayuda a medir exposición acumulada",
                    tint: Color(hex: "#8B8B8B"),
                    isOn: $appSettings.isSmoker
                )
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            Text("AirWay no sustituye el consejo médico. Consulta a tu doctor antes de cambiar hábitos basados en la app.")
                .font(.caption2)
                .foregroundColor(theme.textTint.opacity(0.55))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(theme.textTint.opacity(0.6))
            .tracking(1)
    }
}

// MARK: - Condition Card

private struct ConditionCard: View {
    @Environment(\.weatherTheme) private var theme
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isOn ? tint.opacity(0.25) : theme.textTint.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isOn ? tint : theme.textTint.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.textTint)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textTint.opacity(0.55))
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isOn ? tint : theme.textTint.opacity(0.25))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? tint.opacity(0.08) : theme.textTint.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isOn ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        BreathingProfileView()
            .environmentObject(AppSettings.shared)
    }
}
