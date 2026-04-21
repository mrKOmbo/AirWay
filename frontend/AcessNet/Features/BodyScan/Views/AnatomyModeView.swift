//
//  AnatomyModeView.swift
//  AcessNet
//
//  4º modo del BodyScan Hub: X-Ray AR Pose.
//
//  Proyecta órganos 3D (USDZ) sobre el cuerpo de la persona escaneada en vivo,
//  con oclusión realista vía personSegmentationWithDepth y esqueleto 3D por
//  VNDetectHumanBodyPose3DRequest (iOS 17+).
//
//  El estado se consume desde AnatomyARCoordinator (Fase 3).
//

import SwiftUI

struct AnatomyModeView: View {

    @StateObject private var viewModel = AnatomyViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            AnatomyARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 110)
                Spacer()

                // Bottom stack: status + organs + slider + disclaimer.
                VStack(spacing: 8) {
                    if viewModel.state == .searching {
                        searchingHint
                    } else if viewModel.state == .tracking {
                        statusCard
                        organGrid
                    }

                    if viewModel.showDebugControls {
                        debugAQISlider
                    }

                    disclaimerBanner
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: viewModel.state.indicatorColor))
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: Color(hex: viewModel.state.indicatorColor).opacity(0.6), radius: 6)

            Text(viewModel.state.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            if viewModel.state == .tracking {
                metaChip(
                    icon: "ruler",
                    text: String(format: "%.2f m", viewModel.bodyHeight)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(.black.opacity(0.35))
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Searching hint

    private var searchingHint: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("Apunta a una persona")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text("Cuerpo completo, 1–2 m de distancia, buena luz")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Status card (resumen general)

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Ícono de estado dinámico
                Image(systemName: overallStatus.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(overallStatus.color)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(overallStatus.color.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(overallStatus.title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(overallStatus.color)
                        .tracking(1.2)
                    Text(overallStatus.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                // Cigarros equivalentes aproximados (simple estimación)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("CIGS-EQ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.55))
                    Text(String(format: "%.1f", cigarettesEq))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(overallStatus.color)
                }
            }

            Text(overallStatus.narrative)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(overallStatus.color.opacity(0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Organ grid (3 organs with full text)

    private var organGrid: some View {
        VStack(spacing: 6) {
            organCard(
                icon: "lungs.fill",
                title: "Pulmones",
                damage: viewModel.lungDamage,
                fact: lungFact(damage: viewModel.lungDamage)
            )
            organCard(
                icon: "heart.fill",
                title: "Corazón",
                damage: viewModel.heartDamage,
                fact: heartFact(damage: viewModel.heartDamage)
            )
            organCard(
                icon: "brain.head.profile",
                title: "Cerebro",
                damage: viewModel.brainDamage,
                fact: brainFact(damage: viewModel.brainDamage)
            )
        }
    }

    private func organCard(icon: String, title: String, damage: Float, fact: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(damageColor(damage))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(damageColor(damage).opacity(0.18))
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text(severityLabel(damage))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(damageColor(damage))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(damageColor(damage).opacity(0.18))
                        )
                }
                Text(fact)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)

            // Barra de damage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(damage * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(damageColor(damage))
                    .monospacedDigit()
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.1))
                    .frame(width: 40, height: 4)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(damageColor(damage))
                                .frame(width: max(2, CGFloat(damage) * 40), height: 4)
                            Spacer(minLength: 0)
                        }
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Debug slider

    private var debugAQISlider: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .semibold))
                Text("Simulador AQI")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                Spacer()
                Text("\(Int(viewModel.debugAQI)) · \(aqiCategory(viewModel.debugAQI))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(sliderColor)
            }
            .foregroundColor(.white.opacity(0.7))

            Slider(value: $viewModel.debugAQI, in: 0...500, step: 1)
                .tint(sliderColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var sliderColor: Color {
        switch viewModel.debugAQI {
        case ..<50:   return Color(hex: "#7DD3FC")
        case ..<100:  return Color(hex: "#4ADE80")
        case ..<150:  return Color(hex: "#F4B942")
        case ..<200:  return Color(hex: "#FF8A3D")
        case ..<300:  return Color(hex: "#FF5B5B")
        default:      return Color(hex: "#C084FC")
        }
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
            Text("Visualización educativa (WHO AQG 2021, GBD 2021, Harvard Six Cities). No sustituye atención médica.")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.55))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Status computation

    private struct Status {
        let title: String
        let subtitle: String
        let narrative: String
        let color: Color
        let icon: String
    }

    private var overallStatus: Status {
        let avg = (viewModel.lungDamage + viewModel.heartDamage + viewModel.brainDamage) / 3
        switch avg {
        case ..<0.20:
            return Status(
                title: "Estado saludable",
                subtitle: "Exposición mínima",
                narrative: "Los órganos del sujeto operan en condiciones normales según los promedios poblacionales para la calidad del aire actual.",
                color: Color(hex: "#4ADE80"),
                icon: "checkmark.shield.fill"
            )
        case ..<0.40:
            return Status(
                title: "Alerta leve",
                subtitle: "Exposición moderada",
                narrative: "Inflamación temprana en vías respiratorias. La literatura asocia estos niveles con irritación ocular y tos leve en individuos sensibles.",
                color: Color(hex: "#F4B942"),
                icon: "exclamationmark.triangle.fill"
            )
        case ..<0.65:
            return Status(
                title: "Exposición alta",
                subtitle: "Estrés orgánico",
                narrative: "El sistema respiratorio y cardiovascular muestran signos de estrés oxidativo. Cada +10 µg/m³ PM2.5 crónico se asocia a +14% mortalidad total (Harvard Six Cities).",
                color: Color(hex: "#FF8A3D"),
                icon: "lungs.fill"
            )
        default:
            return Status(
                title: "Exposición severa",
                subtitle: "Riesgo elevado",
                narrative: "Niveles peligrosos. GBD 2021 atribuye a este rango de exposición aumentos significativos en IAM, EPOC y neuroinflamación. Reducir tiempo al aire libre.",
                color: Color(hex: "#FF5B5B"),
                icon: "exclamationmark.octagon.fill"
            )
        }
    }

    /// Equivalencia Berkeley Earth 2015: 22 µg/m³ × 24h = 1 cigarro.
    private var cigarettesEq: Double {
        // AQI simplificado → PM2.5 aprox (AQI·0.7) → cigs en 8h (jornada)
        let pm25 = max(0, min(500, viewModel.debugAQI * 0.7))
        let dose8h = pm25 * 8.0 / 24.0
        return dose8h / 22.0
    }

    private func aqiCategory(_ aqi: Double) -> String {
        switch aqi {
        case ..<50:   return "Bueno"
        case ..<100:  return "Moderado"
        case ..<150:  return "Dañino sensibles"
        case ..<200:  return "Dañino"
        case ..<300:  return "Muy dañino"
        default:      return "Peligroso"
        }
    }

    // MARK: - Per-organ facts (educational)

    private func lungFact(damage: Float) -> String {
        switch damage {
        case ..<0.20: return "Respiración normal. Alveolos limpios."
        case ..<0.40: return "Irritación leve. PM2.5 depositándose en bronquios."
        case ..<0.65: return "Inflamación alveolar. EPOC se asocia a esta exposición crónica."
        default:      return "Daño respiratorio severo. Riesgo alto de infección y fibrosis."
        }
    }

    private func heartFact(damage: Float) -> String {
        switch damage {
        case ..<0.20: return "Ritmo cardíaco estable."
        case ..<0.40: return "+2-5 bpm sobre basal (PM2.5 eleva HR)."
        case ..<0.65: return "Estrés CV. +26% mortalidad CV por 10µg/m³ (Laden 2006)."
        default:      return "Riesgo elevado de arritmia e infarto según literatura."
        }
    }

    private func brainFact(damage: Float) -> String {
        switch damage {
        case ..<0.20: return "Sin evidencia de neuroinflamación."
        case ..<0.40: return "Partículas ultrafinas pueden cruzar BBB (Frontiers 2022)."
        case ..<0.65: return "Neuroinflamación detectable. Riesgo neurodegenerativo a largo plazo."
        default:      return "Exposición crónica se asocia a ↑ Alzheimer (PNAS 2023)."
        }
    }

    // MARK: - Severity helpers

    private func severityLabel(_ damage: Float) -> String {
        switch damage {
        case ..<0.20: return "Sano"
        case ..<0.40: return "Leve"
        case ..<0.65: return "Moderado"
        default:      return "Severo"
        }
    }

    private func damageColor(_ damage: Float) -> Color {
        switch damage {
        case ..<0.20: return Color(hex: "#7DD3FC")
        case ..<0.40: return Color(hex: "#F4B942")
        case ..<0.65: return Color(hex: "#FF8A3D")
        default:      return Color(hex: "#FF5B5B")
        }
    }
}

#Preview {
    AnatomyModeView()
}
