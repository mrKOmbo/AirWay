//
//  XRaySystem.swift
//  AcessNet
//
//  ECS System que itera todas las entidades con XRayOrganComponent y actualiza
//  el SIMD4 `custom.value` de sus CustomMaterial cada frame. Hace:
//
//    1) Interpolación suave de damageLevel → currentDamage (damping exponencial).
//    2) Reasignación del material con el nuevo custom.value.
//
//  IMPORTANTE: hay que reasignar `model.materials` (no basta con mutar el
//  material existente) para que RealityKit suba el SIMD4 al GPU.
//

import RealityKit
import Foundation
import simd
import UIKit

final class XRaySystem: System {

    static let dependencies: [SystemDependency] = []
    static let query = EntityQuery(where: .has(XRayOrganComponent.self) && .has(ModelComponent.self))

    /// Controla la velocidad de transición entre damage levels (mayor = más rápido).
    private let damageSmoothing: Float = 4.5

    /// Tiempo global para la animación de pulso.
    private var globalTime: Float = 0

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        globalTime += dt

        context.scene.performQuery(Self.query).forEach { entity in
            guard var xray = entity.components[XRayOrganComponent.self] as XRayOrganComponent?,
                  var model = entity.components[ModelComponent.self] as ModelComponent?,
                  xray.enabled
            else { return }

            // 1) Damping exponencial hacia el target.
            let prev = xray.currentDamage
            let target = xray.damageLevel
            xray.currentDamage = prev + (target - prev) * (1 - exp(-damageSmoothing * dt))

            // 2) Pulso vía scale (sin shader — compatible con SimpleMaterial).
            //    Dos ondas sumadas para look orgánico, amplitud crece con damage.
            let ω = xray.pulseRateHz * 2.0 * .pi
            let pulseBase = sin(globalTime * ω)
            let pulseSecondary = 0.25 * sin(globalTime * ω * 2.13 + 0.7)
            let pulseAmplified: Float = (pulseBase + pulseSecondary) * (1.0 + xray.currentDamage * 0.5)
            // Scale multiplier: rango [0.97, 1.03] con amp 0.03. Damage amplifica.
            let scaleMultiplier = 1.0 + xray.pulseAmp * 3.0 * pulseAmplified
            entity.scale = SIMD3<Float>(repeating: scaleMultiplier)

            // 3) Si es SimpleMaterial, interpola su color según damage.
            //    Si es CustomMaterial (no usado por ahora), actualiza custom.value.
            model.materials = model.materials.map { base -> Material in
                if var cm = base as? CustomMaterial {
                    cm.custom.value = SIMD4(xray.currentDamage, xray.pulseRateHz, xray.pulseAmp, xray.glowIntensity)
                    return cm
                }
                if base is SimpleMaterial {
                    return Self.simpleMaterialFor(damage: xray.currentDamage)
                }
                return base
            }

            entity.components.set(model)
            entity.components.set(xray)
        }
    }

    /// Color SimpleMaterial según damage, animado por XRaySystem.
    /// roughness alto + menos alpha = look holográfico translúcido (no reflectivo).
    private static func simpleMaterialFor(damage: Float) -> SimpleMaterial {
        let color: SIMD3<Float>
        switch damage {
        case ..<0.20: color = SIMD3(0.10, 0.70, 1.00)   // cyan saturado
        case ..<0.40: color = SIMD3(0.96, 0.73, 0.26)   // amber
        case ..<0.65: color = SIMD3(1.00, 0.54, 0.24)   // orange
        default:      color = SIMD3(1.00, 0.28, 0.28)   // red
        }
        return SimpleMaterial(
            color: UIColor(
                red:   CGFloat(color.x),
                green: CGFloat(color.y),
                blue:  CGFloat(color.z),
                alpha: 0.45
            ),
            roughness: 1.0,      // sin reflejos especulares → translúcido puro
            isMetallic: false
        )
    }
}
