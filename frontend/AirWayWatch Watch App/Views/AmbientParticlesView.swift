//
//  AmbientParticlesView.swift
//  AirWayWatch Watch App
//
//  Capa de partículas atmosféricas muy tenues para el fondo.
//  Render con Canvas + TimelineView: una sola pasada GPU por frame,
//  sin estado por partícula y sin allocations en el render loop.
//

import SwiftUI

struct AmbientParticlesView: View {
    var particleCount: Int = 14
    var baseOpacity: Double = 0.22

    private let particles: [ParticleSeed]

    init(particleCount: Int = 14, baseOpacity: Double = 0.22) {
        self.particleCount = particleCount
        self.baseOpacity = baseOpacity
        self.particles = (0..<particleCount).map { ParticleSeed(index: $0) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate

                for seed in particles {
                    let p = seed.position(at: now, in: size)
                    let radius = seed.radius
                    let opacity = baseOpacity * seed.opacityScale * p.fadeFactor

                    let rect = CGRect(
                        x: p.point.x - radius,
                        y: p.point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    let circle = Path(ellipseIn: rect)
                    context.fill(circle, with: .color(.white.opacity(opacity)))

                    if seed.hasGlow {
                        let glowRect = rect.insetBy(dx: -radius * 1.4, dy: -radius * 1.4)
                        let glow = Path(ellipseIn: glowRect)
                        context.fill(glow, with: .color(.white.opacity(opacity * 0.18)))
                    }
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Particle Seed (puro: posición = f(tiempo))

private struct ParticleSeed {
    let index: Int
    let radius: CGFloat
    let speed: Double          // ciclos por segundo en el eje Y
    let drift: Double          // amplitud del drift horizontal (en fracción de width)
    let driftSpeed: Double     // velocidad del swing horizontal
    let xAnchor: Double        // posición base X (0-1)
    let phase: Double          // desfase temporal
    let opacityScale: Double
    let hasGlow: Bool

    init(index: Int) {
        self.index = index
        var rng = SeededRandom(seed: UInt64(index &* 9176 &+ 31))

        self.radius = CGFloat(rng.next(in: 0.8...2.2))
        self.speed = rng.next(in: 0.012...0.035)        // muy lento — > 28s por loop
        self.drift = rng.next(in: 0.04...0.12)
        self.driftSpeed = rng.next(in: 0.18...0.45)
        self.xAnchor = rng.next(in: 0.05...0.95)
        self.phase = rng.next(in: 0...1)
        self.opacityScale = rng.next(in: 0.55...1.0)
        self.hasGlow = rng.next(in: 0...1) > 0.7
    }

    struct Resolved {
        let point: CGPoint
        let fadeFactor: Double  // 0-1, para fade-in/out en bordes
    }

    func position(at time: TimeInterval, in size: CGSize) -> Resolved {
        // Y normalizado 0-1 que sube continuamente (1 = abajo, 0 = arriba)
        let progress = (time * speed + phase).truncatingRemainder(dividingBy: 1.0)
        let yNorm = 1.0 - progress

        // Drift horizontal sinusoidal alrededor del xAnchor
        let driftOffset = sin(time * driftSpeed * .pi * 2 + phase * .pi * 2) * drift
        let xNorm = max(0.02, min(0.98, xAnchor + driftOffset))

        let x = xNorm * size.width
        let y = yNorm * size.height

        // Fade en los bordes verticales (entradas/salidas suaves)
        let fade: Double
        if progress < 0.1 {
            fade = progress / 0.1
        } else if progress > 0.9 {
            fade = (1.0 - progress) / 0.1
        } else {
            fade = 1.0
        }

        return Resolved(point: CGPoint(x: x, y: y), fadeFactor: fade)
    }
}

// MARK: - PRNG determinístico (no Foundation.Random — queremos reproducibilidad)

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func nextRaw() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let normalized = Double(nextRaw() % 10_000) / 10_000.0
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Reusable AirWay background (gradient + particles)

struct AirWayBackground: View {
    var particleCount: Int = 14
    var baseOpacity: Double = 0.22

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0A1D4D"),
                    Color(hex: "#4AA1B3")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            AmbientParticlesView(
                particleCount: particleCount,
                baseOpacity: baseOpacity
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the AirWay watch background (gradient + tenuous floating particles).
    func airWayBackground(particleCount: Int = 14, baseOpacity: Double = 0.22) -> some View {
        self.background(
            AirWayBackground(
                particleCount: particleCount,
                baseOpacity: baseOpacity
            )
        )
    }
}

#Preview {
    AirWayBackground()
}
