//
//  XRayHologramMaterial.swift
//  AcessNet
//
//  Factory del CustomMaterial XRay holográfico.
//  Crea un material con:
//    - SurfaceShader xraySurface
//    - GeometryModifier xrayGeometry
//    - blending transparent
//    - lightingModel unlit (para que el emissive se vea puro)
//    - custom.value = SIMD4 con (damage, pulseRate, pulseAmp, glow)
//

import RealityKit
import Metal
import Foundation
import UIKit

enum XRayHologramFactory {

    /// Diagnóstico: si es `true`, devuelve SimpleMaterial translúcido en vez de
    /// CustomMaterial. Útil para aislar si el crash es del shader custom.
    static var debugForceSimpleMaterial = true

    // Cached library — se crea una sola vez.
    private static let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    private static let library: MTLLibrary? = device?.makeDefaultLibrary()

    /// Crea un CustomMaterial con el shader XRay.
    /// Si el library o los functions no están disponibles (ej. preview sin GPU),
    /// cae a un SimpleMaterial translúcido como fallback.
    static func makeMaterial(
        damage: Float = 0,
        pulseRate: Float = 1.2,
        pulseAmp: Float = 0.012,
        glow: Float = 2.2
    ) -> Material {
        // Diagnóstico: forzar SimpleMaterial para aislar bug de CustomMaterial.
        if debugForceSimpleMaterial {
            return fallbackMaterial(damage: damage)
        }

        guard let library else {
            AnatomyLog.error(category: .shader, "Metal library is nil (device=\(device == nil ? "nil" : "ok")) — using fallback SimpleMaterial")
            return fallbackMaterial(damage: damage)
        }

        do {
            let surfaceShader = CustomMaterial.SurfaceShader(
                named: "xraySurface",
                in: library
            )
            let geometryModifier = CustomMaterial.GeometryModifier(
                named: "xrayGeometry",
                in: library
            )

            var mat = try CustomMaterial(
                surfaceShader: surfaceShader,
                geometryModifier: geometryModifier,
                lightingModel: .unlit
            )
            // Obligatorio para que set_opacity funcione.
            mat.blending = .transparent(opacity: .init(scale: 1.0))
            // .back (no .none) — `.none` duplica passes de shadow caster y
            // rompe el pipeline de RealityKit en iOS 26 con transparent materials.
            mat.faceCulling = .back
            mat.custom.value = SIMD4<Float>(damage, pulseRate, pulseAmp, glow)
            return mat
        } catch {
            let msg = error.localizedDescription
            AnatomyLog.error(category: .shader, "CustomMaterial failed: \(msg) — using fallback SimpleMaterial")
            return fallbackMaterial(damage: damage)
        }
    }

    /// Aplica el shader X-Ray a todos los ModelEntity bajo `root`, usando los
    /// parámetros por órgano del LoadedOrgans. También registra el
    /// XRayOrganComponent para que XRaySystem los actualice cada frame.
    @MainActor
    static func applyRecursive(to root: Entity, defaults: [String: OrganDefaults]) {
        AnatomyLog.info(
            category: .shader,
            "applyRecursive start — debugForceSimpleMaterial=\(debugForceSimpleMaterial)"
        )
        var applied = 0
        var usedFallback = false
        var pbrReplaced = 0
        root.visit { entity in
            guard let model = entity as? ModelEntity,
                  var modelComp = entity.components[ModelComponent.self]
            else { return }

            // Buscar el cfg del órgano basado en el nombre del entity o de un ancestro.
            let organName = findOrganName(for: entity, defaults: defaults)
            let cfg = defaults[organName] ?? OrganDefaults(
                pulseRateHz: 0.25, pulseAmp: 0.008, baseColor: SIMD3(0.49, 0.83, 0.99)
            )

            let mat = makeMaterial(
                damage: 0,
                pulseRate: cfg.pulseRateHz,
                pulseAmp: cfg.pulseAmp,
                glow: 2.2
            )
            if !(mat is CustomMaterial) { usedFallback = true }

            // Si el material actual NO es SimpleMaterial ni CustomMaterial (ej. PBR
            // del USDZ importado), registramos el reemplazo para debug.
            let hadPBR = modelComp.materials.contains(where: { !($0 is SimpleMaterial) && !($0 is CustomMaterial) })
            if hadPBR { pbrReplaced += 1 }

            // Conservar el número de material slots del mesh (cada mesh puede
            // tener 1..N slots).
            let slotCount = max(1, modelComp.materials.count)
            modelComp.materials = Array(repeating: mat, count: slotCount)
            model.components.set(modelComp)

            // Registrar Component ECS para que XRaySystem lo toque cada frame.
            model.components.set(XRayOrganComponent(
                damageLevel: 0,
                currentDamage: 0,
                pulseRateHz: cfg.pulseRateHz,
                pulseAmp: cfg.pulseAmp,
                glowIntensity: 2.2
            ))
            applied += 1
        }
        AnatomyLog.info(category: .shader, "applyRecursive: processed \(applied) entities (fallback=\(usedFallback), pbrReplaced=\(pbrReplaced))")
    }

    /// Busca el nombre del órgano subiendo por los parents hasta encontrar uno
    /// en `defaults`. Útil para ModelEntity descendentes de USDZ con nombres
    /// sin sentido (Mesh_0, Geometry_1, etc.).
    private static func findOrganName(for entity: Entity, defaults: [String: OrganDefaults]) -> String {
        var current: Entity? = entity
        while let e = current {
            if defaults[e.name] != nil {
                return e.name
            }
            current = e.parent
        }
        return entity.name
    }

    // MARK: - Fallback

    /// SimpleMaterial translúcido con color saturado para aproximar el look
    /// holográfico sin depender del CustomMaterial (que crashea en iOS 26).
    /// roughness alto = sin reflejos especulares, se ve plano translúcido.
    private static func fallbackMaterial(damage: Float) -> Material {
        let color: SIMD3<Float> = {
            switch damage {
            case ..<0.20: return SIMD3(0.10, 0.70, 1.00)   // cyan saturado
            case ..<0.40: return SIMD3(0.96, 0.73, 0.26)   // amber
            case ..<0.65: return SIMD3(1.00, 0.54, 0.24)   // orange
            default:      return SIMD3(1.00, 0.28, 0.28)   // red
            }
        }()
        return SimpleMaterial(
            color: UIColor(
                red:   CGFloat(color.x),
                green: CGFloat(color.y),
                blue:  CGFloat(color.z),
                alpha: 0.45
            ),
            roughness: 1.0,
            isMetallic: false
        )
    }
}
