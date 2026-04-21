//
//  TorsoAnchorBuilder.swift
//  AcessNet
//
//  Construye un marco de referencia ESTABLE del torso a partir de una
//  VNHumanBodyPose3DObservation, filtrando ejes con One-Euro y garantizando
//  ortonormalidad con Gram-Schmidt post-filtro.
//
//  Por qué no filtrar los joints sueltos y construir el marco luego:
//    Si filtras cada joint independiente, los ejes dejan de ser ortogonales
//    (cada uno tiene latencia distinta) → el torso se deforma. Se filtra el
//    resultado: (origin, right, up) y se reconstruye forward = right × up.
//

import Foundation
import simd
import Vision

// MARK: - Result

struct TorsoFrame {
    /// Transform en el sistema de referencia de la CÁMARA (no world).
    /// El coordinator lo lleva a world con `cameraTransform * matrix`.
    let matrix: simd_float4x4

    /// Altura estimada del sujeto en metros.
    let height: Float

    /// Distancia hip→chest (spine length) en metros.
    let torsoLength: Float

    /// 0..1, mínimo de confidence entre joints del torso.
    let confidence: Float
}

// MARK: - Builder

final class TorsoAnchorBuilder {

    // Filtros por componente del marco torso.
    private let fOrigin = OneEuroFilterVec3(minCutoff: 1.0, beta: 0.05)
    private let fRight  = OneEuroFilterVec3(minCutoff: 0.8, beta: 0.10)
    private let fUp     = OneEuroFilterVec3(minCutoff: 0.8, beta: 0.10)
    // Forward se deriva post-filtro → nunca se filtra directo.

    // Calibración de torsoLength: se lockea tras N frames estables.
    private(set) var calibratedTorsoLength: Float? = nil
    private var recentTorsoLengths: [Float] = []
    private let stabilityWindow = 30
    private let stabilityThresholdMeters: Float = 0.025  // ±2.5 cm

    // MARK: - Build

    /// Devuelve nil si la observation no tiene joints de torso válidos.
    func build(from observation: VNHumanBodyPose3DObservation,
               timestamp ts: TimeInterval) -> TorsoFrame? {

        // 1) Extraer joints clave del torso.
        //    VNHumanBodyPose3DObservation.JointName:
        //       .root (hip center), .spine, .centerShoulder ("chest"),
        //       .leftShoulder, .rightShoulder
        guard
            let root  = try? observation.recognizedPoint(.root),
            let spine = try? observation.recognizedPoint(.spine),
            let chest = try? observation.recognizedPoint(.centerShoulder),
            let lsh   = try? observation.recognizedPoint(.leftShoulder),
            let rsh   = try? observation.recognizedPoint(.rightShoulder)
        else {
            return nil
        }

        // 2) Transformar joints de HIP-SPACE (donde Vision los devuelve) al
        //    espacio CÁMARA usando cameraOriginMatrix.inverse.
        //
        //    `cameraOriginMatrix` = "pose de la cámara relativa al hip joint"
        //    → su inversa lleva puntos de hip-space a camera-space.
        //
        //    Sin este paso, los valores de joint.position son offsets pequeños
        //    internos del cuerpo (ej. 10-30cm) y no reflejan la distancia
        //    real al sujeto.
        let cameraFromHip = observation.cameraOriginMatrix.inverse
        func pos(_ p: VNHumanBodyRecognizedPoint3D) -> SIMD3<Float> {
            let cameraSpace = cameraFromHip * p.position
            return SIMD3(cameraSpace.columns.3.x, cameraSpace.columns.3.y, cameraSpace.columns.3.z)
        }
        let pRoot  = pos(root)
        let pSpine = pos(spine)
        let pChest = pos(chest)
        let pLSh   = pos(lsh)
        let pRSh   = pos(rsh)

        // 3) Origen: centroide de 4 puntos estables (shoulders + spine + chest).
        let origin = (pLSh + pRSh + pSpine + pChest) * 0.25

        // 4) Ejes crudos.
        //    Y (up)    = spine → chest
        //    X (right) = leftShoulder → rightShoulder
        //    Z (fwd)   = X × Y
        var up    = Self.safeNormalize(pChest - pSpine, fallback: SIMD3(0, 1, 0))
        var right = Self.safeNormalize(pRSh - pLSh,     fallback: SIMD3(1, 0, 0))

        // Gram-Schmidt pre-filtro (para que los filtros reciban ejes limpios).
        right = Self.safeNormalize(right - simd_dot(right, up) * up,
                                   fallback: SIMD3(1, 0, 0))

        // 5) Filtrado.
        let fo = fOrigin.filter(origin, timestamp: ts)
        var fr = Self.safeNormalize(fRight.filter(right, timestamp: ts),
                                    fallback: SIMD3(1, 0, 0))
        let fu = Self.safeNormalize(fUp.filter(up, timestamp: ts),
                                    fallback: SIMD3(0, 1, 0))
        // Re-ortogonalizar POST-filtro (crítico).
        fr = Self.safeNormalize(fr - simd_dot(fr, fu) * fu,
                                fallback: SIMD3(1, 0, 0))
        let ff = Self.safeNormalize(simd_cross(fr, fu), fallback: SIMD3(0, 0, 1))

        // 6) Componer simd_float4x4 (columnas: right, up, forward, origin).
        let matrix = simd_float4x4(
            SIMD4(fr, 0),
            SIMD4(fu, 0),
            SIMD4(ff, 0),
            SIMD4(fo, 1)
        )

        // 7) Altura y torsoLength.
        let height: Float = observation.heightEstimation == .measured
            ? observation.bodyHeight
            : 1.70  // fallback razonable cuando no hay LiDAR measured
        let torsoLen = simd_length(pChest - pRoot)
        updateCalibration(torsoLen: torsoLen)

        // 8) Confidence (observation-level en Vision 3D; los joints 3D no exponen
        //    confidence individual — solo los 2D).
        let conf = observation.confidence

        return TorsoFrame(
            matrix: matrix,
            height: height,
            torsoLength: calibratedTorsoLength ?? torsoLen,
            confidence: conf
        )
    }

    func reset() {
        fOrigin.reset(); fRight.reset(); fUp.reset()
        calibratedTorsoLength = nil
        recentTorsoLengths.removeAll()
    }

    // MARK: - Calibración de torsoLength

    private func updateCalibration(torsoLen: Float) {
        // Ya calibrado → no recalcular.
        guard calibratedTorsoLength == nil else { return }

        recentTorsoLengths.append(torsoLen)
        if recentTorsoLengths.count > stabilityWindow {
            recentTorsoLengths.removeFirst()
        }
        guard recentTorsoLengths.count == stabilityWindow else { return }

        // Estable si la variación max-min es baja.
        let maxV = recentTorsoLengths.max() ?? 0
        let minV = recentTorsoLengths.min() ?? 0
        if (maxV - minV) < stabilityThresholdMeters {
            let avg = recentTorsoLengths.reduce(0, +) / Float(recentTorsoLengths.count)
            calibratedTorsoLength = avg
            #if DEBUG
            print("[Torso] Calibrated length: \(String(format: "%.3f", avg)) m")
            #endif
        }
    }

    // MARK: - Helpers

    private static func translation(of m: simd_float4x4) -> SIMD3<Float> {
        SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
    }

    private static func safeNormalize(_ v: SIMD3<Float>,
                                      fallback: SIMD3<Float>) -> SIMD3<Float> {
        let len = simd_length(v)
        return len > 1e-5 ? v / len : fallback
    }
}
