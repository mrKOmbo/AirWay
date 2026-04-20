//
//  WeatherBackground.swift
//  AcessNet
//
//  Fondo dinámico con animaciones SwiftUI (Canvas + TimelineView)
//

import SwiftUI

// MARK: - Weather Background

struct WeatherBackground: View {
    let condition: WeatherCondition
    /// Si nil, se resuelve automáticamente desde AppSettings.shared.isAirWayTheme
    /// (así cualquier vista adopta el modo AirWay global sin cambios).
    var isAirWayOverride: Bool? = nil
    @State private var cloudOffset: CGFloat = -100

    /// Compatibilidad hacia atrás: permite `WeatherBackground(condition:, isAirWay:)` si se quiere fijar.
    init(condition: WeatherCondition, isAirWay: Bool? = nil) {
        self.condition = condition
        self.isAirWayOverride = isAirWay
    }

    private var isAirWay: Bool {
        isAirWayOverride ?? AppSettings.shared.isAirWayTheme
    }

    var body: some View {
        ZStack {
            // Layer 1: Gradient base
            LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)

            // Layer 2a (clima): vignette oscura sutil
            if !isAirWay {
                RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 150, endRadius: 500)
            }

            // Layer 2b (AirWay light): aurora radial cian + teal (como .aw-aurora de la web)
            if isAirWay {
                RadialGradient(
                    colors: [Color(hex: "#59B7D1").opacity(0.18), .clear],
                    center: UnitPoint(x: 0.08, y: 0.0),
                    startRadius: 0, endRadius: 600
                )
                RadialGradient(
                    colors: [Color(hex: "#0099FF").opacity(0.14), .clear],
                    center: UnitPoint(x: 1.0, y: 0.12),
                    startRadius: 0, endRadius: 550
                )
                RadialGradient(
                    colors: [Color(hex: "#4AA1B3").opacity(0.12), .clear],
                    center: UnitPoint(x: 0.5, y: 1.1),
                    startRadius: 0, endRadius: 500
                )
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2.0), value: condition)
        .animation(.easeInOut(duration: 0.45), value: isAirWay)
    }

    // MARK: - Particle Layer

    @ViewBuilder
    private var particleLayer: some View {
        switch condition {
        case .rainy:
            RainView(intensity: 100)
        case .stormy:
            RainView(intensity: 180)
            StormFlashView()
        case .sunny:
            // Sol removido por preferencia del usuario — solo polvo flotante sutil
            FloatingDustView()
        case .cloudy:
            FloatingDustView()
        case .overcast:
            RainView(intensity: 30)
        }
    }

    // MARK: - Gradients

    private var gradientColors: [Color] {
        // AirWay (modo claro de la web): base #FAFBFC con tintes cian/azul muy sutiles
        if isAirWay {
            return [Color(hex: "#F3F7FB"), Color(hex: "#FAFBFC"), Color(hex: "#EAF2F8")]
        }
        switch condition {
        case .sunny:  return [Color(hex: "#1A3050"), Color(hex: "#2A5080"), Color(hex: "#183060")]
        case .cloudy: return [Color(hex: "#1A2235"), Color(hex: "#253045"), Color(hex: "#141A28")]
        case .overcast: return [Color(hex: "#18202E"), Color(hex: "#222C3C"), Color(hex: "#121820")]
        case .rainy:  return [Color(hex: "#142040"), Color(hex: "#1E3060"), Color(hex: "#0E1830")]
        case .stormy: return [Color(hex: "#180C30"), Color(hex: "#251548"), Color(hex: "#100820")]
        }
    }

    private var glowColors: [Color] {
        switch condition {
        // Sol removido: glow neutro azulado en lugar del halo dorado
        case .sunny:  return [Color(hex: "#4A6080").opacity(0.12), .clear]
        case .cloudy: return [Color(hex: "#4A6080").opacity(0.12), .clear]
        case .overcast: return [Color(hex: "#5A6A7A").opacity(0.2), .clear]
        case .rainy:  return [Color(hex: "#2050B0").opacity(0.15), .clear]
        case .stormy: return [Color(hex: "#6030A0").opacity(0.15), .clear]
        }
    }

    private var glowCenter: UnitPoint {
        // Siempre desde arriba, sin el offset a topTrailing del sol
        .top
    }

    // MARK: - Animated Clouds

    private var animatedClouds: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack {
                if condition == .rainy || condition == .stormy {
                    // Rainy/Stormy: muchas nubes pequeñas, solo arriba
                    ForEach(0..<6, id: \.self) { i in
                        let xBase = CGFloat(i) * (w / 5) - 40
                        let size = CGFloat.random(in: 120...180)
                        Ellipse()
                            .fill(.white.opacity(0.06))
                            .frame(width: size, height: size * 0.35)
                            .blur(radius: 20)
                            .offset(
                                x: xBase + cloudOffset * (i % 2 == 0 ? 0.5 : -0.3),
                                y: CGFloat(i % 3) * 25 + 20
                            )
                    }
                } else {
                    // Overcast/Cloudy: nubes más visibles y densas
                    let opacity: Double = condition == .overcast ? 0.12 : 0.07

                    Ellipse()
                        .fill(.white.opacity(opacity))
                        .frame(width: 280, height: 60)
                        .blur(radius: 30)
                        .offset(x: cloudOffset, y: 30)

                    Ellipse()
                        .fill(.white.opacity(opacity * 0.9))
                        .frame(width: 220, height: 50)
                        .blur(radius: 25)
                        .offset(x: -cloudOffset * 0.7 + 60, y: 70)

                    Ellipse()
                        .fill(.white.opacity(opacity * 0.7))
                        .frame(width: 300, height: 55)
                        .blur(radius: 35)
                        .offset(x: cloudOffset * 0.5 - 40, y: 110)

                    Ellipse()
                        .fill(.white.opacity(opacity * 0.5))
                        .frame(width: 200, height: 45)
                        .blur(radius: 28)
                        .offset(x: -cloudOffset * 0.4 + 80, y: 150)
                }
            }
            .frame(width: w, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                cloudOffset = 80
            }
        }
    }
}

// MARK: - Rain View

struct RainView: View {
    let intensity: Int
    @State private var drops: [RainDrop] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate

                for drop in drops {
                    let elapsed = now.truncatingRemainder(dividingBy: drop.duration)
                    let progress = elapsed / drop.duration

                    let x = drop.x * size.width
                    let y = (progress * (size.height + 60)) - 30

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - drop.windOffset, y: y - drop.length))

                    context.stroke(
                        path,
                        with: .color(.white.opacity(drop.opacity)),
                        lineWidth: drop.width
                    )
                }
            }
        }
        .onAppear { generateDrops() }
    }

    private func generateDrops() {
        drops = (0..<intensity).map { _ in
            RainDrop(
                x: CGFloat.random(in: -0.1...1.1),
                length: CGFloat.random(in: 15...40),
                width: CGFloat.random(in: 0.5...1.5),
                opacity: Double.random(in: 0.1...0.35),
                duration: Double.random(in: 0.4...0.9),
                windOffset: CGFloat.random(in: 2...8)
            )
        }
    }
}

struct RainDrop {
    let x: CGFloat
    let length: CGFloat
    let width: CGFloat
    let opacity: Double
    let duration: Double
    let windOffset: CGFloat
}

// MARK: - Storm Flash

struct StormFlashView: View {
    @State private var flash: CGFloat = 0
    @State private var started = false

    var body: some View {
        Color.white
            .opacity(flash)
            .ignoresSafeArea()
            .onAppear {
                guard !started else { return }
                started = true
                scheduleFlash()
            }
    }

    private func scheduleFlash() {
        let delay = Double.random(in: 3...8)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.04)) { flash = 0.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeOut(duration: 0.06)) { flash = 0.02 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeIn(duration: 0.03)) { flash = 0.12 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.2)) { flash = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scheduleFlash()
            }
        }
    }
}

// MARK: - Sun Rays

struct SunRaysView: View {
    @State private var pulse: CGFloat = 0.85
    @State private var rayRotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            let corner = CGPoint(x: geo.size.width * 0.85, y: -10)

            ZStack {
                // Glow grande pulsante — esquina superior derecha
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFD060").opacity(0.35),
                                Color(hex: "#FFB830").opacity(0.15),
                                Color(hex: "#FF8C00").opacity(0.05),
                                .clear
                            ],
                            center: .center, startRadius: 10, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .scaleEffect(pulse)
                    .position(corner)

                // Rayos sutiles desde la esquina
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FFD060").opacity(0.08), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 250)
                        .rotationEffect(.degrees(Double(i) * 12.0 - 45 + rayRotation))
                        .position(corner)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = 1.15
            }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
        }
    }
}

// MARK: - Floating Dust

struct FloatingDustView: View {
    @State private var particles: [DustParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate

                for p in particles {
                    let elapsed = now.truncatingRemainder(dividingBy: p.duration)
                    let progress = elapsed / p.duration

                    let x = p.startX * size.width + sin(progress * .pi * 2 * p.wobble) * 20
                    let y = p.startY * size.height - progress * 60

                    let alpha = sin(progress * .pi) * p.maxAlpha

                    context.fill(
                        Path(ellipseIn: CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .onAppear { generateParticles() }
    }

    private func generateParticles() {
        particles = (0..<30).map { _ in
            DustParticle(
                startX: CGFloat.random(in: 0...1),
                startY: CGFloat.random(in: 0.1...1),
                size: CGFloat.random(in: 1.5...4),
                maxAlpha: Double.random(in: 0.06...0.2),
                duration: Double.random(in: 6...14),
                wobble: CGFloat.random(in: 0.5...2)
            )
        }
    }
}

struct DustParticle {
    let startX: CGFloat
    let startY: CGFloat
    let size: CGFloat
    let maxAlpha: Double
    let duration: Double
    let wobble: CGFloat
}
