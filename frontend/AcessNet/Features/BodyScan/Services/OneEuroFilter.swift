//
//  OneEuroFilter.swift
//  AcessNet
//
//  Filtro adaptativo 1€ (Casiez et al. 2012) para signals noisy en AR.
//  El cutoff aumenta con la velocidad → preserva señal rápida sin jitter en
//  estado estacionario. Mejor que Kalman genérico para body tracking.
//
//  Tuning:
//    - minCutoff (Hz): baja para reducir jitter (más lag).
//    - beta:           sube para reducir lag (menos smoothing en movimiento).
//    - dCutoff:        suavizado de la derivada; raras veces tocar.
//
//  Referencia: https://gery.casiez.net/1euro/
//

import Foundation
import simd

// MARK: - Low-pass filter (bloque interno)

final class OneEuroLowPassFilter {
    private(set) var hatX: Float = 0      // último valor filtrado
    private(set) var rawX: Float = 0      // último valor crudo
    private(set) var initialized = false

    @discardableResult
    func filter(_ x: Float, alpha: Float) -> Float {
        let hat: Float
        if initialized {
            hat = alpha * x + (1 - alpha) * hatX
        } else {
            hat = x
            initialized = true
        }
        rawX = x
        hatX = hat
        return hat
    }

    func reset() {
        hatX = 0; rawX = 0; initialized = false
    }
}

// MARK: - OneEuroFilter (escalar)

final class OneEuroFilter {
    var minCutoff: Float   // Hz, sugerido: 0.5–1.5
    var beta: Float        // sugerido: 0.01–0.3
    var dCutoff: Float     // sugerido: 1.0

    private let xLPF = OneEuroLowPassFilter()
    private let dxLPF = OneEuroLowPassFilter()
    private var lastTime: TimeInterval = -1

    init(minCutoff: Float = 1.0, beta: Float = 0.05, dCutoff: Float = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    private func alpha(cutoff: Float, dt: Float) -> Float {
        let tau = 1 / (2 * .pi * cutoff)
        return 1 / (1 + tau / dt)
    }

    func filter(_ x: Float, timestamp t: TimeInterval) -> Float {
        let dt: Float
        if lastTime > 0 {
            dt = max(Float(t - lastTime), 1.0 / 120.0)  // clamp mínimo: 120 Hz
        } else {
            dt = 1.0 / 30.0
        }
        lastTime = t

        let dx: Float = xLPF.initialized ? (x - xLPF.rawX) / dt : 0
        let edx = dxLPF.filter(dx, alpha: alpha(cutoff: dCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(edx)
        return xLPF.filter(x, alpha: alpha(cutoff: cutoff, dt: dt))
    }

    func reset() {
        lastTime = -1
        xLPF.reset()
        dxLPF.reset()
    }
}

// MARK: - OneEuroFilterVec3 (3 filtros independientes)

final class OneEuroFilterVec3 {
    private let fx: OneEuroFilter
    private let fy: OneEuroFilter
    private let fz: OneEuroFilter

    init(minCutoff: Float = 1.0, beta: Float = 0.05, dCutoff: Float = 1.0) {
        fx = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fy = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fz = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }

    func filter(_ v: SIMD3<Float>, timestamp t: TimeInterval) -> SIMD3<Float> {
        SIMD3(
            fx.filter(v.x, timestamp: t),
            fy.filter(v.y, timestamp: t),
            fz.filter(v.z, timestamp: t)
        )
    }

    func updateParams(minCutoff: Float, beta: Float) {
        fx.minCutoff = minCutoff; fx.beta = beta
        fy.minCutoff = minCutoff; fy.beta = beta
        fz.minCutoff = minCutoff; fz.beta = beta
    }

    func reset() {
        fx.reset(); fy.reset(); fz.reset()
    }
}

// MARK: - OneEuroFilterQuat (filtra un cuaternión con hemisphere-flip)

final class OneEuroFilterQuat {
    private let fw: OneEuroFilter
    private let fx: OneEuroFilter
    private let fy: OneEuroFilter
    private let fz: OneEuroFilter
    private var prev: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private var hasPrev = false

    init(minCutoff: Float = 1.0, beta: Float = 0.10, dCutoff: Float = 1.0) {
        fw = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fx = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fy = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        fz = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }

    func filter(_ q: simd_quatf, timestamp t: TimeInterval) -> simd_quatf {
        // Hemisphere flip: alinear con el previo para evitar saltos de 180°.
        let aligned: simd_quatf = {
            guard hasPrev else { return q }
            return simd_dot(q.vector, prev.vector) < 0
                ? simd_quatf(vector: -q.vector)
                : q
        }()

        let w = fw.filter(aligned.real,   timestamp: t)
        let x = fx.filter(aligned.imag.x, timestamp: t)
        let y = fy.filter(aligned.imag.y, timestamp: t)
        let z = fz.filter(aligned.imag.z, timestamp: t)

        let raw = simd_quatf(ix: x, iy: y, iz: z, r: w)
        let normalized = simd_normalize(raw)
        prev = normalized
        hasPrev = true
        return normalized
    }

    func reset() {
        fw.reset(); fx.reset(); fy.reset(); fz.reset()
        prev = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        hasPrev = false
    }
}
