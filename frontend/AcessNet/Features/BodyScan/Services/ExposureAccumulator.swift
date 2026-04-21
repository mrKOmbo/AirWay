//
//  ExposureAccumulator.swift
//  AcessNet
//
//  Acumula samples de exposición a contaminantes (PM2.5, NO2, O3, CO, etc.)
//  y calcula el damageLevel [0..1] por órgano usando OrganSensitivityMatrix
//  con decay exponencial por t½.
//
//  Design:
//    - ObservableObject → el AnatomyViewModel se suscribe y anima los órganos.
//    - Ingest vía `ingest(sample:)` desde cualquier source (backend, debug slider).
//    - `tick()` llamado desde un Timer cada 1 s refresca el damage publicado.
//    - Samples se conservan en ring buffer de 24h (config configurable).
//

import Foundation
import Combine

// MARK: - Sample

struct ExposureSample {
    let timestamp: Date
    let pollutants: [Pollutant: Double]   // concentración en µg/m³ (CO: mg/m³)
    let ventilationRate: Double           // m³/h (según actividad)
    let depositionFraction: Double        // fracción alveolar (0..1)
    let vulnerabilityMultiplier: Double   // 1.0 base, 1.6 niño, etc.

    static func synthetic(aqi: Double) -> ExposureSample {
        // AQI simplificado (US-EPA) → PM2.5 aprox.
        let pm25 = max(0, min(500, aqi * 0.7))
        let no2  = max(0, min(200, aqi * 0.4))
        let o3   = max(0, min(300, aqi * 0.5))
        return ExposureSample(
            timestamp: Date(),
            pollutants: [.pm25: pm25, .no2: no2, .o3: o3, .co: aqi * 0.02],
            ventilationRate: 0.5,
            depositionFraction: 0.30,
            vulnerabilityMultiplier: 1.0
        )
    }
}

// MARK: - Accumulator

@MainActor
final class ExposureAccumulator: ObservableObject {

    // MARK: - Config

    /// Ventana máxima de historia (segundos). Default 24h.
    var historyWindowSec: TimeInterval = 24 * 3600

    /// Cap del buffer (samples).
    private let maxSamples = 4_000

    // MARK: - Published damage por órgano (0..1)

    @Published private(set) var damageByOrgan: [TargetOrgan: Double] = [:]

    /// Último sample ingestado (para el HUD).
    @Published private(set) var lastSample: ExposureSample?

    // MARK: - State

    private var samples: [ExposureSample] = []

    // MARK: - Ingest

    func ingest(_ sample: ExposureSample) {
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        pruneOld()
        lastSample = sample
        recompute()
    }

    /// Atajo: ingerir desde un AQI simple (debug).
    func ingestAQI(_ aqi: Double) {
        ingest(.synthetic(aqi: aqi))
    }

    /// Reiniciar historia (ej. nuevo usuario).
    func reset() {
        samples.removeAll()
        lastSample = nil
        damageByOrgan = [:]
    }

    // MARK: - Recomputación

    private func pruneOld() {
        let cutoff = Date().addingTimeInterval(-historyWindowSec)
        if let firstRecentIndex = samples.firstIndex(where: { $0.timestamp >= cutoff }),
           firstRecentIndex > 0 {
            samples.removeFirst(firstRecentIndex)
        }
    }

    /// Recalcula damage acumulado por órgano aplicando decay desde cada sample.
    private func recompute() {
        let now = Date()
        var result: [TargetOrgan: Double] = [:]

        for organ in TargetOrgan.allCases {
            let normalizer = OrganSensitivityMatrix.damageNormalizer[organ] ?? 300
            var accum = 0.0

            // Ventana efectiva del sample ≈ distancia al siguiente (default 60s).
            for i in 0..<samples.count {
                let sample = samples[i]
                let nextTime = i + 1 < samples.count ? samples[i + 1].timestamp : now
                let windowSec = nextTime.timeIntervalSince(sample.timestamp)
                let windowHours = max(0, windowSec / 3600.0)

                for (pollutant, conc) in sample.pollutants {
                    let contrib = OrganSensitivityMatrix.contribution(
                        pollutant: pollutant,
                        concentration: conc,
                        organ: organ,
                        ventilationRate: sample.ventilationRate,
                        depositionFraction: sample.depositionFraction,
                        durationHours: windowHours,
                        vulnerabilityMultiplier: sample.vulnerabilityMultiplier
                    )
                    // Decay desde ese sample hasta ahora.
                    let elapsed = now.timeIntervalSince(sample.timestamp)
                    let decayed = OrganSensitivityMatrix.decay(
                        damage: contrib,
                        elapsedSeconds: elapsed,
                        organ: organ
                    )
                    accum += decayed
                }
            }

            result[organ] = min(1.0, accum / normalizer)
        }

        damageByOrgan = result
    }
}

// MARK: - Convenience bridge con AnatomyViewModel

extension ExposureAccumulator {
    /// Copia los damage levels agregados al ViewModel (que el SwiftUI observa).
    func apply(to viewModel: AnatomyViewModel) {
        viewModel.lungDamage   = Float(damageByOrgan[.lungs]   ?? 0)
        viewModel.heartDamage  = Float(damageByOrgan[.heart]   ?? 0)
        viewModel.brainDamage  = Float(damageByOrgan[.brain]   ?? 0)
        viewModel.liverDamage  = Float(damageByOrgan[.liver]   ?? 0)
        viewModel.kidneyDamage = Float(damageByOrgan[.kidney]  ?? 0)
    }
}
