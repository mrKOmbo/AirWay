//
//  OrganSensitivityMatrix.swift
//  AcessNet
//
//  Tabla poblacional (NO diagnóstica) que pondera cuánto afecta cada
//  contaminante a cada órgano, según la literatura:
//    - WHO Global Air Quality Guidelines 2021
//    - GBD 2021 (Global Burden of Disease)
//    - Harvard Six Cities (Dockery 1993 / Laden 2006)
//    - Burnett IER 2014 (expuesta-respuesta)
//    - PNAS 2023 (UFP → BBB → neuroinflamación)
//    - Lancet Planetary Health 2019 (NO2 → asma pediátrica)
//
//  Valores normalizados: pulmón × PM2.5 = 1.00 (referencia).
//

import Foundation

enum Pollutant: String, CaseIterable, Hashable {
    case pm25   // μg/m³
    case no2    // μg/m³  (convertible a ppb)
    case o3     // μg/m³
    case co     // mg/m³  ó ppm
    case so2    // μg/m³
    case hcho   // μg/m³  formaldehído
}

enum TargetOrgan: String, CaseIterable, Hashable {
    case lungs    // alvéolo + parénquima
    case bronchi  // vías aéreas
    case heart
    case brain
    case kidney
    case liver
    case placenta // solo si VulnerabilityProfile.isPregnant
    case eyes
    case skin
    case gut

    /// Mapeo al nombre USDZ (acepta fallback plural).
    var usdzNames: [String] {
        switch self {
        // "heart_lungs" es el entity combo (USDZ único con pulmón+corazón).
        // Se incluye en ambas categorías para que reciba damage de PM2.5 y CO.
        case .lungs:    return ["lung_left", "lung_right", "heart_lungs"]
        case .bronchi:  return ["bronchi_left", "bronchi_right", "trachea"]
        case .heart:    return ["heart", "aorta", "heart_lungs"]
        case .brain:    return ["brain"]
        case .kidney:   return ["kidney_left", "kidney_right"]
        case .liver:    return ["liver"]
        case .placenta: return ["placenta"]
        case .eyes:     return ["eyes"]
        case .skin:     return ["skin"]
        case .gut:      return ["gut", "intestine"]
        }
    }
}

enum OrganSensitivityMatrix {

    // MARK: - Sensibilidad (adimensional, 0..1)

    static let sensitivity: [TargetOrgan: [Pollutant: Double]] = [
        .lungs:    [.pm25: 1.00, .no2: 0.50, .o3: 0.80, .so2: 0.40, .hcho: 0.30],
        .bronchi:  [.pm25: 0.60, .no2: 0.90, .o3: 0.70, .so2: 0.80, .hcho: 0.50],
        .heart:    [.pm25: 0.70, .co: 0.95, .no2: 0.15, .o3: 0.20],
        .brain:    [.pm25: 0.45, .co: 0.85, .no2: 0.10, .o3: 0.10],
        .kidney:   [.pm25: 0.30, .co: 0.10, .no2: 0.05],
        .liver:    [.pm25: 0.20, .no2: 0.10],
        .placenta: [.pm25: 0.80, .co: 0.40, .no2: 0.20, .o3: 0.20],
        .eyes:     [.o3: 0.70, .so2: 0.60, .hcho: 0.80],
        .skin:     [.o3: 0.50, .hcho: 0.20],
        .gut:      [.pm25: 0.25],
    ]

    // MARK: - Clearance half-life (el daño "se cura" con t½)

    /// Tiempo de vida media del daño visible, en segundos.
    /// Fuentes: ICRP 66 (alveolar ~70d), mucociliar ~24h, COHb ~5h, BBB UFP ~30d.
    static let halfLifeSeconds: [TargetOrgan: Double] = [
        .lungs:    70 * 86400,
        .bronchi:  24 * 3600,
        .heart:    5 * 3600,         // si dominado por CO
        .brain:    30 * 86400,
        .kidney:   30 * 86400,
        .liver:    14 * 86400,
        .placenta: 9 * 30 * 86400,   // gestación
        .eyes:     12 * 3600,
        .skin:     7 * 86400,
        .gut:      7 * 86400,
    ]

    // MARK: - Normalización por órgano

    /// Denominador con el que se normaliza la suma de exposiciones ponderadas
    /// para obtener damage ∈ [0..1]. Derivado empíricamente para que 24h a
    /// WHO-guideline intermedio ≈ damage 0.20 (leve).
    static let damageNormalizer: [TargetOrgan: Double] = [
        .lungs:    300.0,
        .bronchi:  250.0,
        .heart:    200.0,
        .brain:    180.0,
        .kidney:   400.0,
        .liver:    500.0,
        .placenta: 250.0,
        .eyes:     100.0,
        .skin:     150.0,
        .gut:      500.0,
    ]

    // MARK: - Helpers

    /// Calcula la contribución puntual de un sample (concentration × sensitivity × Δt × vr × df).
    /// Unidades: µg (equivalente).
    static func contribution(
        pollutant: Pollutant,
        concentration: Double,   // µg/m³ (o mg/m³ para CO — se escala)
        organ: TargetOrgan,
        ventilationRate: Double, // m³/h
        depositionFraction: Double,
        durationHours: Double,
        vulnerabilityMultiplier: Double = 1.0
    ) -> Double {
        let s = sensitivity[organ]?[pollutant] ?? 0
        guard s > 0 else { return 0 }
        // CO viene en mg/m³ o ppm; normalizamos a la escala de PM2.5 para la suma.
        let cNorm: Double = pollutant == .co ? concentration * 1000 : concentration
        return cNorm
            * s
            * ventilationRate
            * depositionFraction
            * durationHours
            * vulnerabilityMultiplier
    }

    /// Aplicar decay a un damage acumulado.
    static func decay(damage: Double, elapsedSeconds: Double, organ: TargetOrgan) -> Double {
        let halfLife = halfLifeSeconds[organ] ?? 86400
        return damage * pow(0.5, elapsedSeconds / halfLife)
    }
}
