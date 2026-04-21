//
//  AtmosphericBlobShape.swift
//  AcessNet
//
//  Formas orgánicas animadas para representar nubes de contaminación
//

import SwiftUI
import CoreLocation

// MARK: - Atmospheric Blob Shape

/// Forma orgánica irregular que simula una nube de contaminación
struct AtmosphericBlobShape: Shape {
    var animatableData: Double
    let points: Int
    let irregularity: Double

    init(points: Int = 8, irregularity: Double = 0.3, phase: Double = 0) {
        self.points = points
        self.irregularity = irregularity
        self.animatableData = phase
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Generar puntos de control para la forma orgánica
        var controlPoints: [CGPoint] = []

        for i in 0..<points {
            let angle = (Double(i) / Double(points)) * 2 * .pi

            // Variación del radio basada en ángulo y fase de animación
            let radiusVariation = 1.0 + irregularity * sin(angle * 3 + animatableData)
            let currentRadius = radius * radiusVariation

            let x = center.x + currentRadius * cos(angle)
            let y = center.y + currentRadius * sin(angle)

            controlPoints.append(CGPoint(x: x, y: y))
        }

        // Crear curva suave con bezier
        guard controlPoints.count > 2 else { return path }

        path.move(to: controlPoints[0])

        for i in 0..<controlPoints.count {
            let current = controlPoints[i]
            let next = controlPoints[(i + 1) % controlPoints.count]
            let nextNext = controlPoints[(i + 2) % controlPoints.count]

            // Punto de control para curva suave
            let controlPoint1 = CGPoint(
                x: current.x + (next.x - current.x) * 0.5,
                y: current.y + (next.y - current.y) * 0.5
            )

            let controlPoint2 = CGPoint(
                x: next.x - (nextNext.x - next.x) * 0.3,
                y: next.y - (nextNext.y - next.y) * 0.3
            )

            path.addCurve(to: next, control1: controlPoint1, control2: controlPoint2)
        }

        path.closeSubpath()

        return path
    }
}

// MARK: - Animated Atmospheric Blob

/// Vista de círculo estático de calidad del aire
/// SIN animaciones para máximo rendimiento
struct AnimatedAtmosphericBlob: View {
    let zone: AirQualityZone
    let enableRotation: Bool

    var body: some View {
        ZStack {
            // El RadialGradient "glow" se renderiza SOLO en zonas contaminadas.
            // Para zonas good/moderate el MapCircle del mapa ya marca el área;
            // añadir otro gradient aquí duplicaba pintado sin ganar claridad visual.
            if shouldShowIcon {
                // Glow radial (visible solo con contaminación real).
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                zone.color.opacity(zone.fillOpacity * 0.8),
                                zone.color.opacity(zone.fillOpacity * 0.5),
                                zone.color.opacity(zone.fillOpacity * 0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                // Icono central con fill sólido (evita .ultraThinMaterial costoso en GPU).
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(zone.color.opacity(0.8), lineWidth: 1.5)
                        )

                    Image(systemName: zone.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(zone.color)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                // Zona limpia: solo tap target invisible (mantiene interactividad
                // sin coste de pintado).
                Color.clear
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
        }
        .frame(width: 80, height: 80)
    }

    // MARK: - Computed Properties

    private var shouldShowIcon: Bool {
        zone.level == .unhealthy || zone.level == .severe || zone.level == .hazardous
    }
}

// MARK: - Enhanced Cloud Overlay (Reemplazo de MapCircle)

/// Vista optimizada para overlay de zona en el mapa.
/// Recibe `enableRotation` como prop plana para evitar rebuilds por @EnvironmentObject.
/// No usa `.id()` para que SwiftUI haga diff normal en vez de destruir/recrear.
struct EnhancedAirQualityOverlay: View {
    let zone: AirQualityZone
    let enableRotation: Bool

    var body: some View {
        AnimatedAtmosphericBlob(
            zone: zone,
            enableRotation: enableRotation
        )
    }
}

// MARK: - Preview

#Preview("Atmospheric Blobs") {
    ZStack {
        Color.black.opacity(0.1)

        VStack(spacing: 30) {
            Text("Atmospheric Blobs").font(.title.bold())

            HStack(spacing: 20) {
                // Good
                AnimatedAtmosphericBlob(
                    zone: AirQualityZone(
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        airQuality: AirQualityPoint(
                            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                            aqi: 35,
                            pm25: 15
                        )
                    ),
                    enableRotation: true
                )

                // Poor
                AnimatedAtmosphericBlob(
                    zone: AirQualityZone(
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        airQuality: AirQualityPoint(
                            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                            aqi: 125,
                            pm25: 55
                        )
                    ),
                    enableRotation: true
                )

                // Unhealthy
                AnimatedAtmosphericBlob(
                    zone: AirQualityZone(
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        airQuality: AirQualityPoint(
                            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                            aqi: 175,
                            pm25: 85
                        )
                    ),
                    enableRotation: false
                )
            }
        }
    }
}
