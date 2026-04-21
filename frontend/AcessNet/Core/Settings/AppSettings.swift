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

    /// Tema AirWay: paleta de marca (sincronizada con la página web).
    /// Se almacena como un valor sentinel dentro de `weatherOverrideRaw` para
    /// no añadir un @AppStorage nuevo y mantener exclusividad con los temas de clima.
    static let airWayThemeKey = "airWay"

    var isAirWayTheme: Bool {
        get { weatherOverrideRaw == Self.airWayThemeKey }
        set {
            if newValue {
                weatherOverrideRaw = Self.airWayThemeKey
            } else if weatherOverrideRaw == Self.airWayThemeKey {
                weatherOverrideRaw = ""
            }
        }
    }

    // MARK: - General Preferences

    /// Unidad de distancia preferida
    @AppStorage("useMetricUnits")
    var useMetricUnits: Bool = true

    /// Habilitar notificaciones inteligentes
    @AppStorage("enableSmartNotifications")
    var enableSmartNotifications: Bool = false

    // MARK: - Measurement Units (Propuesta #1 · fix persistencia)

    /// Estándar AQI — "european" | "us"
    @AppStorage("aqiStandard")
    var aqiStandardRaw: String = "european" {
        willSet { objectWillChange.send() }
    }

    /// Unidad de temperatura — "celsius" | "fahrenheit"
    @AppStorage("temperatureUnit")
    var temperatureUnitRaw: String = "celsius" {
        willSet { objectWillChange.send() }
    }

    /// Unidad de velocidad del viento — "kmh" | "mph"
    @AppStorage("windSpeedUnit")
    var windSpeedUnitRaw: String = "kmh" {
        willSet { objectWillChange.send() }
    }

    // MARK: - Breathing Profile (Propuesta #3)
    // Perfil de sensibilidad respiratoria. Modifica umbrales PPI y AQI.

    @AppStorage("bp_asthma") var hasAsthma: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_copd") var hasCOPD: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_heart") var hasHeartCondition: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_pregnant") var isPregnant: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_childAtHome") var hasChildAtHome: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_outdoorAthlete") var isOutdoorAthlete: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_smoker") var isSmoker: Bool = false { willSet { objectWillChange.send() } }
    @AppStorage("bp_elderly") var isElderly: Bool = false { willSet { objectWillChange.send() } }

    /// Multiplicador global sobre umbrales (ej. 0.7 = más sensible, usuario nota cambios antes)
    /// Se deriva del perfil respiratorio. 1.0 = población general.
    var sensitivityMultiplier: Double {
        var m = 1.0
        if hasAsthma { m -= 0.20 }
        if hasCOPD { m -= 0.25 }
        if hasHeartCondition { m -= 0.15 }
        if isPregnant { m -= 0.15 }
        if hasChildAtHome { m -= 0.10 }
        if isOutdoorAthlete { m -= 0.10 }
        if isElderly { m -= 0.15 }
        // fumador no reduce sensibilidad; el daño ya está, pero no cambia umbral
        return max(0.4, m) // piso de 0.4 para evitar alertas permanentes
    }

    /// ¿El usuario marcó al menos un flag del breathing profile?
    var hasActiveBreathingProfile: Bool {
        hasAsthma || hasCOPD || hasHeartCondition || isPregnant ||
        hasChildAtHome || isOutdoorAthlete || isSmoker || isElderly
    }

    // MARK: - AI Copilot (Propuesta #2)

    /// Tono del asistente — "technical" | "friendly" | "concise" | "motivational"
    @AppStorage("ai_tone")
    var aiToneRaw: String = "friendly" { willSet { objectWillChange.send() } }

    /// Idioma del asistente — "auto" | "es" | "en"
    @AppStorage("ai_language")
    var aiLanguageRaw: String = "auto" { willSet { objectWillChange.send() } }

    /// Modelo Gemini — "flash" (rápido) | "pro" (profundo)
    @AppStorage("ai_model")
    var aiModelRaw: String = "flash" { willSet { objectWillChange.send() } }

    /// Habilita la memoria del asistente
    @AppStorage("ai_memory_enabled")
    var aiMemoryEnabled: Bool = true { willSet { objectWillChange.send() } }

    /// Entradas de memoria del usuario (JSON array de strings, editables)
    @AppStorage("ai_memory_entries")
    var aiMemoryEntriesRaw: String = "[]" { willSet { objectWillChange.send() } }

    var aiMemoryEntries: [String] {
        get {
            guard let data = aiMemoryEntriesRaw.data(using: .utf8),
                  let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                aiMemoryEntriesRaw = str
            }
        }
    }

    // MARK: - Data Sources (Propuesta #4)
    // Toggle on/off por fuente. Permite al usuario deshabilitar fuentes individualmente.

    @AppStorage("ds_tempo") var useTEMPO: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ds_openaq") var useOpenAQ: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ds_waqi") var useWAQI: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ds_openmeteo") var useOpenMeteo: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("ds_rama") var useRAMA: Bool = true { willSet { objectWillChange.send() } }

    // MARK: - Trip Briefing (pin en mapa)

    /// Si está ON, el pin abre el nuevo "Trip Briefing" (walking/driving)
    /// en lugar de la `LocationInfoCard` clásica.
    @AppStorage("useTripBriefing")
    var useTripBriefing: Bool = true { willSet { objectWillChange.send() } }

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
        aqiStandardRaw = "european"
        temperatureUnitRaw = "celsius"
        windSpeedUnitRaw = "kmh"
        aiToneRaw = "friendly"
        aiLanguageRaw = "auto"
        aiModelRaw = "flash"
        aiMemoryEnabled = true
        aiMemoryEntriesRaw = "[]"
        useTEMPO = true
        useOpenAQ = true
        useWAQI = true
        useOpenMeteo = true
        useRAMA = true

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
