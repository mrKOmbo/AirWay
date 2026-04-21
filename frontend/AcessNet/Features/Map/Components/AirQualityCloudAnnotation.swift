//
//  AQICloudMarker.swift
//  AcessNet
//
//  Nube estilizada como overlay de zona AQI en el mapa.
//  Reemplaza el par MapCircle + EnhancedAirQualityOverlay (2 overlays)
//  por un único Annotation con nube compuesta de SF Symbols.
//
//  Características:
//  - Tamaño geográfico: escala con el zoom de la cámara (opción 2b).
//  - Progressive density: 1/2/3 nubes según severidad AQI.
//  - Nube tenue en zonas "good" (opción 1b): confirma capa activa sin saturar.
//  - Cero blur GPU (.ultraThinMaterial) — solo SF Symbols teñidos.
//

import SwiftUI
import CoreLocation

// MARK: - Air Quality Cloud Annotation

struct AQICloudMarker: View {
    let zone: AirQualityZone

    /// Factor de escala calculado externamente desde la distancia de la cámara.
    /// 1.0 = tamaño de referencia (cámara a 5 km). <1 alejado, >1 cercano.
    let scale: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(cloudLayers.enumerated()), id: \.offset) { _, layer in
                cloudLayerView(layer)
            }

            if let icon = centerIcon {
                Image(systemName: icon)
                    .font(.system(size: baseSize * 0.32, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
        }
        .frame(width: frameSize, height: frameSize)
        .scaleEffect(clampedScale)
    }

    /// View builder extraído del body para ayudar al type-checker de Swift
    /// (el LinearGradient anidado en el body generaba "unable to type-check").
    @ViewBuilder
    private func cloudLayerView(_ layer: CloudLayer) -> some View {
        let topColor = zone.color.opacity(layer.opacity)
        let bottomColor = zone.color.opacity(layer.opacity * 0.7)
        let shadowTint = zone.color.opacity(layer.opacity * 0.4)

        Image(systemName: "cloud.fill")
            .font(.system(size: baseSize * layer.sizeFactor, weight: .black))
            .foregroundStyle(
                LinearGradient(
                    colors: [topColor, bottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(x: layer.offset.width, y: layer.offset.height)
            .shadow(color: shadowTint, radius: shadowRadius, y: 2)
    }

    // MARK: - Scale clamping

    /// Clamp del scale recibido para evitar que la nube sea demasiado chica
    /// (invisible) o demasiado grande (tapa todo el mapa).
    private var clampedScale: CGFloat {
        max(0.3, min(3.0, scale))
    }

    // MARK: - Sizing

    /// Tamaño base del SF Symbol cloud.fill antes de escala.
    /// Cambia según severidad para transmitir gravedad por tamaño.
    private var baseSize: CGFloat {
        switch zone.level {
        case .good:      return 26
        case .moderate:  return 32
        case .poor:      return 42
        case .unhealthy: return 50
        case .severe:    return 58
        case .hazardous: return 64
        }
    }

    private var frameSize: CGFloat {
        baseSize * 1.8  // Margen para offsets de nubes apiladas.
    }

    private var shadowRadius: CGFloat {
        switch zone.level {
        case .good:     return 2
        case .moderate: return 4
        case .poor:     return 6
        default:        return 8
        }
    }

    // MARK: - Cloud Layers

    /// Define cuántas nubes se superponen y cómo se distribuyen, según nivel AQI.
    /// Más severo → más nubes con offsets ligeramente caóticos para aspecto denso.
    private var cloudLayers: [CloudLayer] {
        switch zone.level {
        case .good:
            // Tenue confirmación de capa activa (opción 1b).
            return [
                CloudLayer(offset: .zero, sizeFactor: 1.0, opacity: 0.4)
            ]
        case .moderate:
            return [
                CloudLayer(offset: .zero, sizeFactor: 1.0, opacity: 0.75)
            ]
        case .poor:
            return [
                CloudLayer(offset: CGSize(width: -6, height: 2), sizeFactor: 0.85, opacity: 0.7),
                CloudLayer(offset: CGSize(width: 6, height: -1), sizeFactor: 1.0, opacity: 0.85)
            ]
        case .unhealthy:
            return [
                CloudLayer(offset: CGSize(width: -8, height: 3), sizeFactor: 0.8, opacity: 0.65),
                CloudLayer(offset: .zero, sizeFactor: 1.0, opacity: 0.9),
                CloudLayer(offset: CGSize(width: 9, height: -2), sizeFactor: 0.75, opacity: 0.7)
            ]
        case .severe:
            return [
                CloudLayer(offset: CGSize(width: -10, height: 4), sizeFactor: 0.85, opacity: 0.75),
                CloudLayer(offset: .zero, sizeFactor: 1.0, opacity: 0.95),
                CloudLayer(offset: CGSize(width: 11, height: -3), sizeFactor: 0.82, opacity: 0.8)
            ]
        case .hazardous:
            return [
                CloudLayer(offset: CGSize(width: -11, height: 5), sizeFactor: 0.9, opacity: 0.85),
                CloudLayer(offset: .zero, sizeFactor: 1.05, opacity: 1.0),
                CloudLayer(offset: CGSize(width: 12, height: -3), sizeFactor: 0.88, opacity: 0.9)
            ]
        }
    }

    // MARK: - Center Icon

    /// Icono alertante superpuesto para niveles serios.
    private var centerIcon: String? {
        switch zone.level {
        case .good, .moderate, .poor: return nil
        case .unhealthy:               return "exclamationmark"
        case .severe:                  return "exclamationmark.2"
        case .hazardous:               return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Cloud Layer

/// Parámetros de una capa de nube dentro del ZStack.
private struct CloudLayer {
    let offset: CGSize
    let sizeFactor: CGFloat   // Multiplicador sobre baseSize (0.7-1.1).
    let opacity: Double
}

// MARK: - Geographic Scale Helper

enum CloudScale {
    /// Distancia de referencia a la que la nube se muestra scale 1.0.
    /// 5000m = ~zoom de vista de barrio típica.
    static let referenceCameraDistance: CLLocationDistance = 5000

    /// Calcula el factor de escala aparente de una nube dado el zoom actual.
    /// Menor camera distance (más cerca) → mayor scale → nube más grande en pantalla.
    static func factor(for cameraDistance: CLLocationDistance) -> CGFloat {
        // Proteger contra división por valores muy pequeños.
        let safeDistance = max(cameraDistance, 500)
        let raw = referenceCameraDistance / safeDistance
        // Clamp final (el consumidor también clampea, doble seguridad).
        return CGFloat(max(0.3, min(3.0, raw)))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Cloud by AQI Level") {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.3, green: 0.3, blue: 0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 32) {
            previewRow(level: .good)
            previewRow(level: .moderate)
            previewRow(level: .poor)
            previewRow(level: .unhealthy)
            previewRow(level: .severe)
            previewRow(level: .hazardous)
        }
        .padding()
    }
}

@ViewBuilder
private func previewRow(level: AQILevel) -> some View {
    let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let aqi = mockAQI(for: level)
    let air = AirQualityPoint(coordinate: coord, aqi: aqi, pm25: 0)
    let zone = AirQualityZone(coordinate: coord, airQuality: air)

    HStack(spacing: 24) {
        Text(level.rawValue)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 100, alignment: .leading)

        AQICloudMarker(zone: zone, scale: 1.0)

        Spacer()
    }
}

private func mockAQI(for level: AQILevel) -> Double {
    switch level {
    case .good:      return 35
    case .moderate:  return 75
    case .poor:      return 125
    case .unhealthy: return 175
    case .severe:    return 250
    case .hazardous: return 400
    }
}
#endif
