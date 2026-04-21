//
//  OrganAnchorController.swift
//  AcessNet
//
//  Desacopla la frecuencia de Vision (15-30 fps) del render loop (60-120 fps).
//
//  - Vision produce TorsoFrames vía `updateFromVision(...)`.
//  - CADisplayLink interpola el transform anchor cada tick de display.
//  - Durante pérdidas breves (<200 ms) extrapola linealmente.
//  - Pérdidas largas (>500 ms) → fade-out con OpacityComponent.
//

import RealityKit
import QuartzCore
import simd

@MainActor
final class OrganAnchorController {

    // MARK: - State

    private weak var rootAnchor: AnchorEntity?
    private let modelTorsoLength: Float

    // Transforms (en world space).
    private var currentT: simd_float4x4 = matrix_identity_float4x4
    private var targetT:  simd_float4x4 = matrix_identity_float4x4

    // Escalado (interpolado también, para evitar "breathing" del modelo).
    private var currentScale: Float = 1.0
    private var targetScale:  Float = 1.0

    // Timing.
    private var lastVisionTime: CFTimeInterval = 0
    private var lastDelta: CFTimeInterval = 1.0 / 15.0

    // Opacidad durante tracking lost.
    private var currentOpacity: Float = 0

    // Buffer de últimas N poses para predicción lineal.
    private var poseBuffer: [(time: CFTimeInterval, origin: SIMD3<Float>)] = []
    private let poseBufferCap = 6

    // Display link.
    private var displayLink: CADisplayLink?

    // Umbrales.
    private let predictionWindowSec: CFTimeInterval = 0.20  // predice hasta 200 ms
    private let fadeOutWindowSec:    CFTimeInterval = 0.50  // fade completo a 500 ms

    // MARK: - Init

    init(rootAnchor: AnchorEntity, modelTorsoLength: Float) {
        self.rootAnchor = rootAnchor
        self.modelTorsoLength = modelTorsoLength

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Public API

    /// Llamado desde el main thread cada vez que Vision produce un TorsoFrame.
    func updateFromVision(worldTransform: simd_float4x4,
                          frame: TorsoFrame,
                          timestamp ts: CFTimeInterval) {
        // Commit del estado actual como nueva "origen" de la siguiente interpolación.
        currentT = Self.interpolated(from: currentT, to: targetT, alpha: 1)
        currentScale = targetScale
        targetT = worldTransform
        targetScale = max(0.5, min(2.0, frame.torsoLength / modelTorsoLength))

        if lastVisionTime > 0 {
            lastDelta = max(ts - lastVisionTime, 0.02)
        }
        lastVisionTime = ts

        // Buffer para predicción.
        let origin = SIMD3<Float>(
            worldTransform.columns.3.x,
            worldTransform.columns.3.y,
            worldTransform.columns.3.z
        )
        poseBuffer.append((ts, origin))
        if poseBuffer.count > poseBufferCap {
            poseBuffer.removeFirst()
        }
    }

    /// Llamado cuando el tracking se pierde (sin observation).
    func notifyTrackingLost() {
        // No limpiamos target — dejamos que el display link maneje el fade.
    }

    /// Reset completo (al salir de la vista o cambiar de sujeto).
    func reset() {
        currentT = matrix_identity_float4x4
        targetT  = matrix_identity_float4x4
        currentScale = 1
        targetScale = 1
        lastVisionTime = 0
        poseBuffer.removeAll()
        currentOpacity = 0
        rootAnchor?.isEnabled = false
    }

    // MARK: - Display link tick

    @objc private func tick() {
        guard let anchor = rootAnchor else { return }

        let now = CACurrentMediaTime()
        let since = now - lastVisionTime

        // Nunca hemos recibido tracking.
        if lastVisionTime == 0 {
            anchor.isEnabled = false
            return
        }

        if since < lastDelta * 1.5 {
            // Interpolación normal.
            let alpha = Float(min(max(since / lastDelta, 0), 1))
            anchor.setTransformMatrix(
                Self.interpolated(from: currentT, to: targetT, alpha: alpha),
                relativeTo: nil
            )
            anchor.scale = SIMD3(repeating: currentScale + (targetScale - currentScale) * alpha)
            setOpacity(on: anchor, to: 1.0)
            anchor.isEnabled = true
        } else if since < predictionWindowSec {
            // Extrapolación lineal corta.
            let predicted = extrapolated(at: now)
            anchor.setTransformMatrix(predicted, relativeTo: nil)
            anchor.scale = SIMD3(repeating: targetScale)
            setOpacity(on: anchor, to: 0.6)
        } else if since < fadeOutWindowSec {
            // Fade-out.
            let t = Float((since - predictionWindowSec) / (fadeOutWindowSec - predictionWindowSec))
            setOpacity(on: anchor, to: 0.6 * (1 - t))
        } else {
            // Desactivar.
            anchor.isEnabled = false
            setOpacity(on: anchor, to: 0)
        }
    }

    // MARK: - Interpolation / extrapolation

    private static func interpolated(from a: simd_float4x4,
                                     to b: simd_float4x4,
                                     alpha: Float) -> simd_float4x4 {
        let pA = SIMD3<Float>(a.columns.3.x, a.columns.3.y, a.columns.3.z)
        let pB = SIMD3<Float>(b.columns.3.x, b.columns.3.y, b.columns.3.z)
        let p  = simd_mix(pA, pB, SIMD3<Float>(repeating: alpha))

        let qA = simd_quaternion(upper3x3(a))
        let qB = simd_quaternion(upper3x3(b))
        let q  = simd_slerp(qA, qB, alpha)

        var m = simd_float4x4(q)
        m.columns.3 = SIMD4(p, 1)
        return m
    }

    private func extrapolated(at now: CFTimeInterval) -> simd_float4x4 {
        guard poseBuffer.count >= 2 else { return targetT }
        let a = poseBuffer[poseBuffer.count - 2]
        let b = poseBuffer[poseBuffer.count - 1]
        let dt = Float(max(b.time - a.time, 1e-3))
        let velocity = (b.origin - a.origin) / dt
        let elapsed = Float(now - lastVisionTime)
        let p = b.origin + velocity * elapsed

        // Rotación: mantener la última.
        var m = targetT
        m.columns.3 = SIMD4(p, 1)
        return m
    }

    private static func upper3x3(_ m: simd_float4x4) -> simd_float3x3 {
        simd_float3x3(
            SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
            SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
            SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        )
    }

    // MARK: - Opacity helper

    private func setOpacity(on anchor: Entity, to value: Float) {
        if currentOpacity == value { return }
        currentOpacity = value
        if var o = anchor.components[OpacityComponent.self] as OpacityComponent? {
            o.opacity = value
            anchor.components.set(o)
        } else {
            anchor.components.set(OpacityComponent(opacity: value))
        }
    }
}
