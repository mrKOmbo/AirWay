//
//  WalkingBriefingCard.swift
//  AcessNet
//
//  Card del modo "A pie" dentro del Trip Briefing.
//  Número hero de cigarros con multicolor glow + iconitos stagger +
//  sub-toggle de actividad + stats + verdict bar.
//

import SwiftUI
import CoreLocation

struct WalkingBriefingCard: View {
    let briefing: WalkingBriefing
    let hotspots: [WalkingHotspot]
    let destinationTitle: String
    var cleanerRouteActive: Bool = false
    var isFindingCleanerRoute: Bool = false
    let onActivityChange: (WalkActivityLevel) -> Void
    let onRequestCleanerRoute: () -> Void

    @Environment(\.weatherTheme) private var theme
    @State private var cigarettesAppeared = false
    @State private var hotspotShake: CGFloat = 0

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            heroSection
            cigaretteRow
            activityToggle
            statsGrid
            if !hotspots.isEmpty {
                hotspotBanner
            }
            verdictBar
        }
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .onAppear {
            // Reset + replay la animación de los iconos al aparecer.
            cigarettesAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    cigarettesAppeared = true
                }
            }
        }
        .onChange(of: briefing.activity) { _, _ in
            // Replay cuando el usuario cambia ritmo.
            cigarettesAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    cigarettesAppeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [verdictColor.opacity(0.55), verdictColor.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("A PIE")
                    .font(.caption2.bold())
                    .tracking(1.8)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text("\(briefing.durationLabel) · \(briefing.distanceLabel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer()
            aqiBadge
        }
    }

    private var aqiBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(aqiColor).frame(width: 6, height: 6)
            Text(aqiText)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var aqiText: String {
        if let a = briefing.aqiRouteAvg {
            return "AQI \(Int(a))"
        }
        return "AQI —"
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text(formattedCigs)
                .font(.system(size: briefing.hasAirData ? 68 : 54, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [verdictColor, verdictColor.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .monospacedDigit()
                .contentTransition(.numericText(value: briefing.cigarettes ?? 0))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: briefing.cigarettes)
                .accessibilityLabel(Text("\(formattedCigs) cigarros equivalentes"))
                .accessibilityValue(Text(briefing.verdict.title))

            Text(briefing.hasAirData ? "cigarros equivalentes" : "sin datos de aire")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.6))
                .tracking(0.5)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var formattedCigs: String {
        guard let c = briefing.cigarettes else { return "—" }
        return String(format: "%.2f", c)
    }

    // MARK: - Cigarette Row (staggered)

    @ViewBuilder
    private var cigaretteRow: some View {
        // Sin datos de aire, no mostrar iconitos (serían engañosos).
        if briefing.hasAirData {
            let cigs = briefing.cigarettes ?? 0
            let fullCount = min(Int(cigs.rounded(.down)), 5)
            let partial = cigs - Double(fullCount)
            let visibleItems = 5

            HStack(spacing: 8) {
                ForEach(0..<visibleItems, id: \.self) { i in
                    cigaretteIcon(filled: i < fullCount, partial: i == fullCount ? partial : 0)
                        .scaleEffect(cigarettesAppeared ? 1 : 0.3)
                        .opacity(cigarettesAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(i) * 0.07),
                            value: cigarettesAppeared
                        )
                }
                Spacer()
                Text("de 5")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.4))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func cigaretteIcon(filled: Bool, partial: Double) -> some View {
        ZStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(
                    filled
                        ? verdictColor.opacity(0.85)
                        : Color.white.opacity(0.09)
                )
            if !filled && partial > 0.05 {
                Image(systemName: "circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(verdictColor.opacity(0.85))
                    .mask(
                        Rectangle()
                            .frame(width: 22 * partial, height: 22)
                            .frame(width: 22, height: 22, alignment: .leading)
                    )
            }
            Text("🚬")
                .font(.system(size: 12))
                .opacity(filled || partial > 0.15 ? 1 : 0.25)
        }
    }

    // MARK: - Activity sub-toggle

    private var activityToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RITMO DE CAMINATA")
                .font(.caption2.bold())
                .tracking(1.5)
                .foregroundStyle(Color.black.opacity(0.4))

            HStack(spacing: 6) {
                ForEach(WalkActivityLevel.allCases) { a in
                    activityChip(for: a)
                }
            }
        }
    }

    private func activityChip(for level: WalkActivityLevel) -> some View {
        let active = (briefing.activity == level)
        return Button {
            guard briefing.activity != level else { return }
            HapticFeedback.light()
            onActivityChange(level)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: level.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(level.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? Color.black.opacity(0.85) : Color.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        active
                            ? LinearGradient(
                                colors: [theme.accent.opacity(0.95), theme.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.03)],
                                             startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        active ? Color.white.opacity(0.35) : Color.white.opacity(0.08),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statTile(
                icon: "aqi.medium",
                label: "PM2.5 inhalado",
                value: pm25Text,
                tint: .white.opacity(0.9)
            )
            statTile(
                icon: "flame.fill",
                label: "Calorías",
                value: String(format: "%.0f kcal", briefing.kcalBurned),
                tint: Color(hex: "#FF9E3D")
            )
        }
    }

    private var pm25Text: String {
        guard let µg = briefing.dosedMicrograms else { return "— µg" }
        return String(format: "%.0f µg", µg)
    }

    private func statTile(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        )
    }

    // MARK: - Hotspot banner

    private var hotspotBanner: some View {
        let totalMin = hotspots.reduce(0) { $0 + $1.minutesInZone }
        let worstAQI = Int(hotspots.map(\.aqi).max() ?? 0)
        let disabled = isFindingCleanerRoute || cleanerRouteActive
        return Button(action: {
            guard !disabled else { return }
            onRequestCleanerRoute()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bannerColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: cleanerRouteActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(bannerColor)
                        .font(.system(size: 15, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle(totalMin: totalMin, worstAQI: worstAQI))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                    Text(bannerSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                Spacer()
                if isFindingCleanerRoute {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if !cleanerRouteActive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.4))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(bannerColor.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(bannerColor.opacity(0.28), lineWidth: 0.8)
            )
            .offset(x: hotspotShake)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onAppear {
            guard !cleanerRouteActive else { return }
            // Micro-shake disruptivo al aparecer: -2, +2, -1, 0.
            let steps: [CGFloat] = [-2, 2, -1, 0]
            for (i, dx) in steps.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + 0.06 * Double(i)) {
                    withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.5)) {
                        hotspotShake = dx
                    }
                }
            }
        }
    }

    private var bannerColor: Color {
        cleanerRouteActive ? Color(hex: "#7ED957") : Color(hex: "#FF8C42")
    }

    private func bannerTitle(totalMin: Int, worstAQI: Int) -> String {
        cleanerRouteActive
            ? "Ruta limpia activa"
            : "Pasas ~\(totalMin) min en AQI \(worstAQI)"
    }

    private var bannerSubtitle: String {
        if isFindingCleanerRoute { return "Buscando alternativa con mejor aire..." }
        if cleanerRouteActive { return "Usando la ruta con menor exposición" }
        return "Toca para ver ruta con aire más limpio"
    }

    // MARK: - Verdict bar

    private var verdictBar: some View {
        HStack(spacing: 12) {
            Image(systemName: verdictIcon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(verdictColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(verdictColor.opacity(0.18))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(briefing.verdict.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                Text(briefing.verdict.tone)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(verdictColor.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(verdictColor.opacity(0.28), lineWidth: 0.8)
        )
    }

    // MARK: - Derived styling

    private var verdictColor: Color {
        Color(hex: briefing.verdict.glowHex)
    }

    private var verdictIcon: String {
        switch briefing.verdict {
        case .goForIt:    return "figure.walk.motion"
        case .worthIt:    return "hand.thumbsup.fill"
        case .thinkTwice: return "hand.raised.fill"
        case .takeTheCar: return "car.fill"
        case .unknown:    return "aqi.medium"
        }
    }

    private var aqiColor: Color {
        guard let aqi = briefing.aqiRouteAvg else { return Color(hex: "#8EACC0") }
        switch Int(aqi) {
        case ..<50:     return Color(hex: "#7ED957")
        case 50..<100:  return Color(hex: "#F9A825")
        case 100..<150: return Color(hex: "#FF8C42")
        case 150..<200: return Color(hex: "#FF3B3B")
        default:        return Color(hex: "#8E24AA")
        }
    }

    // MARK: - Card background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(verdictColor.opacity(0.28), lineWidth: 0.6)
    }
}

// MARK: - Preview

#Preview("Walking — verde") {
    PreviewWrapper(
        cigs: 0.18, aqi: 58, pm25: 14, kcal: 120, activity: .light, hotspots: []
    )
}

#Preview("Walking — ámbar + hotspot") {
    PreviewWrapper(
        cigs: 0.62, aqi: 128, pm25: 42, kcal: 150,
        activity: .brisk,
        hotspots: [.init(coordinate: .init(latitude: 19.4, longitude: -99.1), aqi: 158, durationInZoneSec: 240)]
    )
}

#Preview("Walking — rojo") {
    PreviewWrapper(
        cigs: 1.24, aqi: 188, pm25: 88, kcal: 180, activity: .jogging, hotspots: []
    )
}

private struct PreviewWrapper: View {
    let cigs: Double
    let aqi: Double
    let pm25: Double
    let kcal: Double
    let activity: WalkActivityLevel
    let hotspots: [WalkingHotspot]

    @State private var current: WalkActivityLevel

    init(
        cigs: Double, aqi: Double, pm25: Double, kcal: Double,
        activity: WalkActivityLevel, hotspots: [WalkingHotspot]
    ) {
        self.cigs = cigs
        self.aqi = aqi
        self.pm25 = pm25
        self.kcal = kcal
        self.activity = activity
        self.hotspots = hotspots
        _current = State(initialValue: activity)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A0F"), Color(hex: "#1B1E2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                WalkingBriefingCard(
                    briefing: WalkingBriefing(
                        distanceMeters: 1800,
                        durationSeconds: 23 * 60,
                        pm25RouteAvg: pm25,
                        aqiRouteAvg: aqi,
                        activity: current
                    ),
                    hotspots: hotspots,
                    destinationTitle: "Polanco",
                    onActivityChange: { current = $0 },
                    onRequestCleanerRoute: {}
                )
                .padding(.horizontal, 16)
                Spacer()
            }
        }
        .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
    }
}
