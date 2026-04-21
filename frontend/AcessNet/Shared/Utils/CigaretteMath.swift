//
//  CigaretteMath.swift
//  AcessNet
//
//  Matemática pura de "cigarette equivalence" para predecir exposición
//  ANTES de caminar un trayecto. Pensada para el Trip Briefing.
//
//  Fórmula:
//    dose_µg = PM2.5 × VR × DF × Δt × vulnMult
//    cigs    = dose_µg / 79.2
//
//  Constantes científicas y coeficientes replican el
//  CigaretteEquivalenceEngine del Watch (Berkeley Earth, EPA EFH Ch.6,
//  ICRP 66 / MPPD). Ver Watch engine para derivación completa.
//

import Foundation

// MARK: - Walk Activity Level

/// Nivel de esfuerzo al caminar. Afecta ventilación y deposición
/// pulmonar.
enum WalkActivityLevel: String, CaseIterable, Identifiable {
    case rest       // quieto (espera de semáforo)
    case light      // caminar tranquilo ~3-4 km/h
    case brisk      // caminar enérgico ~5-6 km/h
    case jogging    // trote ~8 km/h

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rest:    return "Descanso"
        case .light:   return "Normal"
        case .brisk:   return "Rápido"
        case .jogging: return "Trote"
        }
    }

    var icon: String {
        switch self {
        case .rest:    return "figure.stand"
        case .light:   return "figure.walk"
        case .brisk:   return "figure.walk.motion"
        case .jogging: return "figure.run"
        }
    }

    /// m/s — velocidad típica (para recalcular duración al cambiar ritmo)
    var speedMps: Double {
        switch self {
        case .rest:    return 0.0
        case .light:   return 1.1   // ~4 km/h
        case .brisk:   return 1.5   // ~5.4 km/h
        case .jogging: return 2.2   // ~7.9 km/h
        }
    }

    /// Ventilation rate (m³/h) — EPA EFH Ch.6
    var ventilationRate: Double {
        switch self {
        case .rest:    return 0.50
        case .light:   return 1.00
        case .brisk:   return 1.80
        case .jogging: return 2.80
        }
    }

    /// Deposition fraction — ICRP 66 / MPPD
    var depositionFraction: Double {
        switch self {
        case .rest:    return 0.30
        case .light:   return 0.35
        case .brisk:   return 0.42
        case .jogging: return 0.50
        }
    }

    /// MET (Metabolic Equivalent of Task) para kcal = MET × kg × horas
    var met: Double {
        switch self {
        case .rest:    return 1.0
        case .light:   return 3.0
        case .brisk:   return 4.3
        case .jogging: return 7.0
        }
    }
}

// MARK: - Cigarette Math

/// Wrapper inmutable que calcula la exposición a PM2.5 de un segmento
/// de caminata y la traduce a "cigarros equivalentes" (Berkeley Earth).
struct CigaretteMath {

    // MARK: Scientific constants

    /// Berkeley Earth (Muller 2015): 22 µg/m³ durante 24h = 1 cigarro
    static let pm25PerCigaretteDay: Double = 22.0

    /// Dosis depositada de referencia por cigarro-equivalente (µg).
    /// = 22 µg/m³ × 0.5 m³/h × 24 h × 0.30 DF = 79.2 µg
    static let referenceDosePerCigarette: Double = 79.2

    /// Peso corporal por defecto para cálculo de kcal (kg).
    static let defaultBodyWeightKg: Double = 70.0

    // MARK: Inputs

    /// PM2.5 promedio a lo largo del trayecto (µg/m³).
    let pm25Avg: Double

    /// Duración del segmento caminando (segundos).
    let durationSeconds: TimeInterval

    /// Nivel de actividad.
    let activity: WalkActivityLevel

    /// Perfil de vulnerabilidad del usuario (opcional).
    let vulnerability: VulnerabilityProfile?

    /// Peso corporal para cálculo de kcal (kg).
    let bodyWeightKg: Double

    init(
        pm25Avg: Double,
        durationSeconds: TimeInterval,
        activity: WalkActivityLevel = .light,
        vulnerability: VulnerabilityProfile? = nil,
        bodyWeightKg: Double = CigaretteMath.defaultBodyWeightKg
    ) {
        self.pm25Avg = max(0, pm25Avg)
        self.durationSeconds = max(0, durationSeconds)
        self.activity = activity
        self.vulnerability = vulnerability
        self.bodyWeightKg = bodyWeightKg
    }

    // MARK: Derived

    /// Δt en horas.
    var durationHours: Double { durationSeconds / 3600.0 }

    /// Multiplicador por edad/condición (niño 1.6, mayor 1.3, base 1.0).
    var vulnerabilityMultiplier: Double {
        guard let p = vulnerability else { return 1.0 }
        if p.isChild   { return 1.6 }
        if p.isElderly { return 1.3 }
        return 1.0
    }

    /// Dosis depositada en los pulmones durante el trayecto (µg).
    var dosedMicrograms: Double {
        pm25Avg
            * activity.ventilationRate
            * activity.depositionFraction
            * durationHours
            * vulnerabilityMultiplier
    }

    /// Cigarros equivalentes (puede ser fraccionario, ej. 0.4).
    var cigarettesEquivalent: Double {
        dosedMicrograms / Self.referenceDosePerCigarette
    }

    /// kcal aproximadas gastadas (MET × kg × horas).
    var kcalBurned: Double {
        activity.met * bodyWeightKg * durationHours
    }

    /// Veredicto cualitativo según cigarros + kcal.
    var verdict: WalkVerdict {
        let c = cigarettesEquivalent
        let kcal = kcalBurned

        // Pondera: dolor (cigarros) vs beneficio (kcal).
        // Estos umbrales están calibrados para AQI CDMX típico.
        if c < 0.3 && kcal > 30 { return .goForIt }
        if c < 0.6               { return .worthIt }
        if c < 1.0               { return .thinkTwice }
        return .takeTheCar
    }
}

// MARK: - Verdict

enum WalkVerdict {
    case goForIt        // "Camínalo sin dudar"
    case worthIt        // "Vale la pena"
    case thinkTwice     // "Piénsalo — hay trade-offs"
    case takeTheCar     // "Mejor en auto / otro horario"
    case unknown        // "Falta info del aire en esta zona"

    var title: String {
        switch self {
        case .goForIt:    return "Camínalo"
        case .worthIt:    return "Vale la pena"
        case .thinkTwice: return "Piénsalo"
        case .takeTheCar: return "Mejor en auto"
        case .unknown:    return "Sin datos de aire"
        }
    }

    var glowHex: String {
        switch self {
        case .goForIt:    return "#2ECC71"  // verde
        case .worthIt:    return "#7ED957"  // verde claro
        case .thinkTwice: return "#FFB830"  // ámbar
        case .takeTheCar: return "#FF3B3B"  // rojo
        case .unknown:    return "#8EACC0"  // gris-azul
        }
    }

    var tone: String {
        switch self {
        case .goForIt:
            return "Ganas calorías y casi no inhalas nada malo. Buen trato."
        case .worthIt:
            return "El aire está aceptable. El ejercicio compensa."
        case .thinkTwice:
            return "Inhalas lo equivalente a fumar parte de un cigarro. Decídelo tú."
        case .takeTheCar:
            return "El aire está pesado en el trayecto. Considera otra hora o modo."
        case .unknown:
            return "Aún no tenemos suficientes estaciones cerca del trayecto. Abre la capa AQI para cargar datos."
        }
    }
}

// MARK: - Driver Cabin Variant

/// Variante para el conductor de un auto: la exposición se reduce por
/// infiltración de cabina. Sin HEPA ~30%, con HEPA ~5-10%.
extension CigaretteMath {

    enum CabinFiltration {
        case none           // ventanas abiertas — exposición = 1.0
        case standard       // AC cerrado — 0.30
        case hepa           // HEPA cabin filter — 0.08

        var infiltrationFactor: Double {
            switch self {
            case .none:     return 1.0
            case .standard: return 0.30
            case .hepa:     return 0.08
            }
        }
    }

    /// Cigarros equivalentes para el conductor (PM2.5 atenuado por cabina).
    static func cabinCigarettes(
        pm25RouteAvg: Double,
        durationSeconds: TimeInterval,
        filtration: CabinFiltration = .standard,
        vulnerability: VulnerabilityProfile? = nil
    ) -> Double {
        let effectivePM25 = pm25RouteAvg * filtration.infiltrationFactor
        return CigaretteMath(
            pm25Avg: effectivePM25,
            durationSeconds: durationSeconds,
            activity: .rest,      // conductor sentado
            vulnerability: vulnerability
        ).cigarettesEquivalent
    }
}
