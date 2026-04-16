//
//  AppSettings.swift
//  AcessNet
//
//  Settings globales de la aplicación con persistencia usando UserDefaults
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Gestor centralizado de configuraciones de la app con persistencia
class AppSettings: ObservableObject {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Air Quality Performance Settings

    /// Habilita/deshabilita rotación de blobs atmosféricos
    /// - Impacto en rendimiento: BAJO (25 animaciones continuas)
    /// - Default: true (activado por defecto, efecto sutil)
    @AppStorage("enableAirQualityRotation")
    var enableAirQualityRotation: Bool = true {
        willSet {
            objectWillChange.send()
        }
    }

    /// Tamaño del grid de calidad del aire (NxN zonas)
    /// - 5x5 = 25 zonas (Recomendado)
    /// - 7x7 = 49 zonas (Rendimiento bajo)
    /// - 9x9 = 81 zonas (Solo para dispositivos potentes)
    @AppStorage("airQualityGridSize")
    var airQualityGridSize: Int = 5

    // MARK: - Proximity Filtering Settings

    /// Habilita filtrado por proximidad para elementos del mapa
    /// - Impacto en rendimiento: ALTO (reduce elementos renderizados hasta 50%)
    /// - Default: true (activado para mejor performance)
    @AppStorage("enableProximityFiltering")
    var enableProximityFiltering: Bool = true {
        willSet {
            objectWillChange.send()
        }
    }

    /// Radio de proximidad en kilómetros (1-5km)
    /// Define qué tan lejos del usuario se muestran elementos
    @AppStorage("proximityRadiusKm")
    var proximityRadiusKm: Double = 2.0 {
        willSet {
            objectWillChange.send()
        }
    }

    /// Radio de proximidad en metros (computed)
    var proximityRadiusMeters: CLLocationDistance {
        return proximityRadiusKm * 1000
    }

    // MARK: - Weather Override (Debug/Demo)

    /// Override manual del clima para testing
    @AppStorage("weatherOverride")
    var weatherOverrideRaw: String = "" {
        willSet { objectWillChange.send() }
    }

    var weatherOverride: WeatherCondition? {
        get { WeatherCondition(rawValue: weatherOverrideRaw) }
        set { weatherOverrideRaw = newValue?.rawValue ?? "" }
    }

    // MARK: - General Preferences

    /// Unidad de distancia preferida
    @AppStorage("useMetricUnits")
    var useMetricUnits: Bool = true

    /// Habilitar notificaciones inteligentes
    @AppStorage("enableSmartNotifications")
    var enableSmartNotifications: Bool = false

    // MARK: - Private Init

    private init() {
        // Validar valores al inicializar
        validateSettings()
    }

    // MARK: - Public Methods

    /// Resetear todas las configuraciones a valores por defecto
    func resetToDefaults() {
        enableAirQualityRotation = true
        airQualityGridSize = 5
        enableProximityFiltering = true
        proximityRadiusKm = 2.0
        useMetricUnits = true
        enableSmartNotifications = false

        print("⚙️ Configuraciones reseteadas a valores por defecto")
    }

    /// Obtener configuración de performance basada en nivel
    enum PerformancePreset {
        case maximum  // Todas las animaciones activadas
        case balanced // Balance entre visual y performance (default)
        case minimal  // Solo lo esencial
    }

    func applyPerformancePreset(_ preset: PerformancePreset) {
        switch preset {
        case .maximum:
            enableAirQualityRotation = true
            airQualityGridSize = 7

        case .balanced:
            enableAirQualityRotation = true
            airQualityGridSize = 5

        case .minimal:
            enableAirQualityRotation = false
            airQualityGridSize = 5
        }

        print("⚡ Performance preset aplicado: \(preset)")
    }

    // MARK: - Private Methods

    private func validateSettings() {
        // Asegurar que gridSize esté en rango válido
        if airQualityGridSize < 3 || airQualityGridSize > 11 {
            airQualityGridSize = 5
        }

        // Asegurar que sea impar para grid simétrico
        if airQualityGridSize % 2 == 0 {
            airQualityGridSize += 1
        }
    }

    // MARK: - Computed Properties

    /// Indicador de si las configuraciones están en modo "alto rendimiento"
    var isHighPerformanceMode: Bool {
        return airQualityGridSize <= 5
    }

    /// Número total aproximado de zonas en el grid
    var totalAirQualityZones: Int {
        return airQualityGridSize * airQualityGridSize
    }

    /// Estimación de animaciones activas
    var estimatedActiveAnimations: Int {
        let baseAnimationsPerZone = 2 // breathing + scale
        let rotationAnimationsPerZone = enableAirQualityRotation ? 1 : 0

        let animationsPerZone = baseAnimationsPerZone + rotationAnimationsPerZone
        return totalAirQualityZones * animationsPerZone
    }
}

// MARK: - Preview Helper

extension AppSettings {
    /// Instancia mock para previews de SwiftUI
    static var preview: AppSettings {
        let settings = AppSettings.shared
        settings.enableAirQualityRotation = true
        return settings
    }
}
