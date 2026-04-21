//
//  LocationInfoSheetPreview.swift
//  AcessNet
//
//  Debug harness para probar LocationInfoSheet aislado del ContentView.
//  Incluye:
//  - Vista interactiva (abrir/cerrar, cambiar detent, cambiar escenario AQI).
//  - #Preview blocks para Xcode Canvas (peek/medium/large + escenarios AQI).
//  - Mock factory para generar LocationInfo válidos sin backend.
//
//  NO se incluye en release builds (envuelto en #if DEBUG).
//

#if DEBUG

import SwiftUI
import CoreLocation

// MARK: - AQI Scenario

/// Escenarios AQI predefinidos para probar el sheet en distintos estados.
enum AQIDebugScenario: String, CaseIterable, Identifiable {
    case good       = "Good (42)"
    case moderate   = "Moderate (85)"
    case poor       = "Poor (125)"
    case unhealthy  = "Unhealthy (175)"
    case severe     = "Severe (250)"

    var id: String { rawValue }

    var aqi: Double {
        switch self {
        case .good:      return 42
        case .moderate:  return 85
        case .poor:      return 125
        case .unhealthy: return 175
        case .severe:    return 250
        }
    }

    var pm25: Double { aqi * 0.35 }
    var pm10: Double { aqi * 0.55 }
}

// MARK: - Mock Factory

enum LocationInfoMock {

    static func make(scenario: AQIDebugScenario = .moderate,
                     title: String = "Parque México",
                     subtitle: String? = "Condesa, CDMX",
                     distance: String = "1.2 km de tu ubicación") -> LocationInfo {
        let coord = CLLocationCoordinate2D(latitude: 19.4116, longitude: -99.1709)
        let airQuality = AirQualityPoint(
            coordinate: coord,
            aqi: scenario.aqi,
            pm25: scenario.pm25,
            pm10: scenario.pm10,
            timestamp: Date()
        )
        return LocationInfo(
            coordinate: coord,
            title: title,
            subtitle: subtitle,
            distanceFromUser: distance,
            airQuality: airQuality
        )
    }
}

// MARK: - Debug Harness View

/// Vista completa con fondo tipo mapa, selector de escenarios y botón para abrir el sheet.
/// Úsala en un #Preview o móntala temporalmente como root de la app para probar en el simulador.
struct LocationInfoSheetDebugHarness: View {

    // MARK: - State

    @State private var isSheetPresented: Bool = false
    @State private var detent: MapSheetDetent = .medium
    @State private var scenario: AQIDebugScenario = .moderate

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fondo simulando el mapa (gradiente similar al ContentView real).
            mapBackdrop

            // Controles en primer plano.
            VStack(spacing: 24) {
                Spacer()

                title

                scenarioPicker

                openSheetButton

                detentPicker

                Spacer()

                infoFooter
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)

            // Overlay del sheet.
            if isSheetPresented {
                LocationInfoSheet(
                    locationInfo: LocationInfoMock.make(scenario: scenario),
                    detent: $detent,
                    onCalculateRoute: {
                        print("🧪 DEBUG: onCalculateRoute tapped")
                        isSheetPresented = false
                    },
                    onViewAirQuality: {
                        print("🧪 DEBUG: onViewAirQuality tapped")
                    },
                    onCancel: {
                        print("🧪 DEBUG: onCancel (swipe down from peek)")
                        isSheetPresented = false
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }
        }
        .animation(MapSheetTokens.presentSpring, value: isSheetPresented)
    }

    // MARK: - Map Backdrop

    private var mapBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.30, blue: 0.61),
                    Color(red: 0.40, green: 0.76, blue: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Patrón tenue de círculos (simula zonas AQI)
            GeometryReader { geo in
                ForEach(0..<6) { i in
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 120, height: 120)
                        .offset(
                            x: CGFloat(i % 3) * geo.size.width / 3 - 40,
                            y: CGFloat(i / 3) * geo.size.height / 2 + CGFloat(i * 20)
                        )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Title

    private var title: some View {
        VStack(spacing: 6) {
            Text("LocationInfoSheet · Debug")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)

            Text("Redistribución con progressive disclosure")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Scenario Picker

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AQI SCENARIO")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 6) {
                ForEach(AQIDebugScenario.allCases) { s in
                    Button {
                        scenario = s
                    } label: {
                        Text(s.rawValue)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(scenario == s ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(scenario == s ? .white : .white.opacity(0.12))
                            )
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Open Sheet Button

    private var openSheetButton: some View {
        Button {
            isSheetPresented.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSheetPresented ? "xmark.circle.fill" : "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .heavy))
                Text(isSheetPresented ? "Cerrar sheet" : "Abrir sheet")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isSheetPresented
                        ? [Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.73, green: 0.11, blue: 0.11)]
                        : [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.12, green: 0.25, blue: 0.69)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detent Picker

    @ViewBuilder
    private var detentPicker: some View {
        if isSheetPresented {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETENT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 6) {
                    detentChip("Peek", target: .peek)
                    detentChip("Medium", target: .medium)
                    detentChip("Large", target: .large)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    private func detentChip(_ label: String, target: MapSheetDetent) -> some View {
        Button {
            withAnimation(MapSheetTokens.detentSpring) {
                detent = target
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(detent == target ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(detent == target ? .white : .white.opacity(0.12))
                )
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("💡 Prueba manual")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)

            Text("• Drag el handle bar para cambiar detent")
                .font(.system(size: 11))
            Text("• Tap handle para ciclar detents")
                .font(.system(size: 11))
            Text("• Swipe down desde peek para dismiss")
                .font(.system(size: 11))
            Text("• Tap backdrop (medium/large) para bajar")
                .font(.system(size: 11))
        }
        .foregroundStyle(.white.opacity(0.75))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Harness · Interactive") {
    LocationInfoSheetDebugHarness()
}

#Preview("Peek · Good AQI") {
    StaticSheetPreview(scenario: .good, initial: .peek)
}

#Preview("Medium · Moderate AQI") {
    StaticSheetPreview(scenario: .moderate, initial: .medium)
}

#Preview("Large · Unhealthy AQI") {
    StaticSheetPreview(scenario: .unhealthy, initial: .large)
}

#Preview("Large · Severe AQI") {
    StaticSheetPreview(scenario: .severe, initial: .large)
}

// MARK: - Static Preview Helper

/// Muestra el sheet directamente en un detent dado, sin controles externos.
/// Útil para revisar la redistribución en Canvas sin interacción.
private struct StaticSheetPreview: View {
    let scenario: AQIDebugScenario
    let initial: MapSheetDetent

    @State private var detent: MapSheetDetent

    init(scenario: AQIDebugScenario, initial: MapSheetDetent) {
        self.scenario = scenario
        self.initial = initial
        self._detent = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.30, blue: 0.61),
                    Color(red: 0.40, green: 0.76, blue: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LocationInfoSheet(
                locationInfo: LocationInfoMock.make(scenario: scenario),
                detent: $detent,
                onCalculateRoute: { print("Preview: calculate") },
                onViewAirQuality: { print("Preview: air quality") },
                onCancel: { print("Preview: cancel") }
            )
        }
    }
}

#endif
