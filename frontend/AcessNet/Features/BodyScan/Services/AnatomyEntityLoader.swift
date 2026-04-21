//
//  AnatomyEntityLoader.swift
//  AcessNet
//
//  Carga el USDZ anatómico. Si no existe (p.ej. aún no se ha generado el
//  asset con BodyParts3D), genera un placeholder procedural equivalente:
//  primitives (esferas/cápsulas) nombradas correctamente para que todo el
//  pipeline (shader, damage mapping, anchoring) funcione sin asset real.
//
//  Convención de naming (compatible con USDZ final):
//    heart, lung_left, lung_right, brain, liver,
//    kidney_left, kidney_right, trachea, bronchi_left, bronchi_right, aorta
//
//  Offsets locales: coords en el TORSO frame (origin = centroide de
//  shoulders+spine+chest), metros, modelo "base" a torsoLength = 0.45 m.
//

import RealityKit
import Foundation
import simd
import UIKit

struct LoadedOrgans {
    /// Contenedor padre — se mete como hijo del rootAnchor del torso.
    let root: Entity

    /// Acceso rápido por nombre (heart, lung_left, …).
    let byName: [String: ModelEntity]

    /// Altura hip→chest del modelo base (m). Para scaling dinámico.
    let modelTorsoLength: Float

    /// Parámetros por-órgano para el shader XRay (pulse, etc.).
    let organDefaults: [String: OrganDefaults]
}

struct OrganDefaults {
    let pulseRateHz: Float
    let pulseAmp: Float
    let baseColor: SIMD3<Float>  // RGB linear
}

@MainActor
enum AnatomyEntityLoader {

    /// Debug: reemplaza todos los órganos por una esfera gigante cyan para
    /// confirmar si el anchor está bien posicionado.
    static var debugUseGiantSphere = false

    // MARK: - Mapping USDZ reales → órganos del placeholder

    /// Mapeo de archivos USDZ concretos en el bundle a órganos del placeholder.
    /// Si un USDZ existe, reemplaza el placeholder correspondiente.
    private struct USDZMapping {
        /// Nombre del archivo sin extensión (ojo: puede tener espacios/tildes).
        let fileName: String
        /// Nombre con el que el órgano queda registrado (para damage mapping).
        let targetOrganName: String
        /// Órganos del placeholder que reemplaza (ej. combo pulmón+corazón
        /// reemplaza heart, lung_left, lung_right).
        let replacesPlaceholders: [String]
        /// Tamaño target del lado más grande del bounding box (metros).
        let targetSize: Float
        /// Posición final en el torso frame (metros).
        let position: SIMD3<Float>
        /// Rotación adicional para corregir orientación del asset.
        let rotationEuler: SIMD3<Float>  // radianes, aplicado como yaw-pitch-roll
    }

    private static let usdzMappings: [USDZMapping] = [
        // Combo pulmón+corazón: va centrado en el pecho, reemplaza los 3.
        USDZMapping(
            fileName: "Modelo pulmón y corazón MDEIE",
            targetOrganName: "heart_lungs",
            replacesPlaceholders: ["heart", "lung_left", "lung_right"],
            targetSize: 0.30,
            position: SIMD3(0.0, 0.04, 0.0),
            rotationEuler: SIMD3(0, 0, 0)
        ),
        USDZMapping(
            fileName: "Cerebro Vascular",
            targetOrganName: "brain",
            replacesPlaceholders: ["brain"],
            targetSize: 0.14,
            position: SIMD3(0.0, 0.42, 0.0),
            // Sketchfab a veces exporta con Z-up. Corrige -90° en X.
            rotationEuler: SIMD3(-.pi / 2, 0, 0)
        ),
        USDZMapping(
            fileName: "Hígado Metástasis 3D",
            targetOrganName: "liver",
            replacesPlaceholders: ["liver"],
            targetSize: 0.16,
            position: SIMD3(0.06, -0.13, 0.0),
            rotationEuler: SIMD3(0, 0, 0)
        ),
    ]

    // MARK: - Entry point

    static func load() async -> LoadedOrgans {
        if debugUseGiantSphere {
            AnatomyLog.info(category: .loader, "debugUseGiantSphere=ON — using single giant cyan sphere")
            return buildGiantSphere()
        }

        // 1. Placeholder base con todos los órganos procedurales.
        var placeholder = buildPlaceholder()
        AnatomyLog.info(category: .loader, "Base placeholder: \(placeholder.byName.count) organs")

        // 2. Intentar cargar cada USDZ real y reemplazar los placeholders.
        for mapping in usdzMappings {
            guard let url = Bundle.main.url(forResource: mapping.fileName, withExtension: "usdz") else {
                AnatomyLog.info(category: .loader, "USDZ not found: \(mapping.fileName).usdz")
                continue
            }

            do {
                let loadedEntity = try await Entity(contentsOf: url)

                // Normalizar escala y posición.
                let normalized = normalizeLoaded(
                    entity: loadedEntity,
                    targetSize: mapping.targetSize,
                    position: mapping.position,
                    rotationEuler: mapping.rotationEuler,
                    organName: mapping.targetOrganName
                )

                // Remover los placeholders que reemplaza.
                var newByName = placeholder.byName
                for placeholderName in mapping.replacesPlaceholders {
                    if let old = newByName[placeholderName] {
                        old.removeFromParent()
                        newByName.removeValue(forKey: placeholderName)
                    }
                }

                // Agregar el USDZ real al root del torso.
                placeholder.root.addChild(normalized.wrapper)
                // Si es un ModelEntity directo, registrarlo en byName.
                // Si es un Entity padre, registrar children ModelEntity.
                newByName[mapping.targetOrganName] = normalized.primaryModel
                normalized.wrapper.visit { e in
                    if let m = e as? ModelEntity, !m.name.isEmpty {
                        newByName[m.name] = m
                    }
                }

                placeholder = LoadedOrgans(
                    root: placeholder.root,
                    byName: newByName,
                    modelTorsoLength: placeholder.modelTorsoLength,
                    organDefaults: placeholder.organDefaults
                )

                AnatomyLog.info(
                    category: .loader,
                    "✓ Loaded USDZ '\(mapping.fileName)' → \(mapping.targetOrganName), replaced: \(mapping.replacesPlaceholders.joined(separator: ","))"
                )
            } catch {
                let msg = error.localizedDescription
                AnatomyLog.error(category: .loader, "USDZ '\(mapping.fileName)' load failed: \(msg)")
            }
        }

        AnatomyLog.info(category: .loader, "Final organ count: \(placeholder.byName.count)")
        return placeholder
    }

    /// Normaliza un Entity cargado desde USDZ: centra, escala al targetSize y
    /// aplica la posición y rotación del torso frame.
    private static func normalizeLoaded(
        entity loaded: Entity,
        targetSize: Float,
        position: SIMD3<Float>,
        rotationEuler: SIMD3<Float>,
        organName: String
    ) -> (wrapper: Entity, primaryModel: ModelEntity) {
        // Wrapper padre para posición + rotación controladas.
        let wrapper = Entity()
        wrapper.name = organName

        // Bounding box para escalar al tamaño deseado.
        let bounds = loaded.visualBounds(relativeTo: nil)
        let extents = bounds.extents
        let maxDim = max(extents.x, max(extents.y, extents.z))
        let rawScale: Float = maxDim > 1e-4 ? targetSize / maxDim : 1.0
        // Clamp para evitar assets con bounds mal medidos que generan monstruos.
        let scaleFactor = min(max(rawScale, 0.001), 5.0)

        AnatomyLog.info(
            category: .loader,
            "[\(organName)] bounds extents=(\(String(format: "%.3f", extents.x)),\(String(format: "%.3f", extents.y)),\(String(format: "%.3f", extents.z))) maxDim=\(String(format: "%.3f", maxDim)) rawScale=\(String(format: "%.3f", rawScale)) finalScale=\(String(format: "%.3f", scaleFactor))"
        )

        // Centrar: mover el entity para que su centro quede en origin.
        let centerOffset = -bounds.center
        loaded.position = centerOffset * scaleFactor
        loaded.scale = SIMD3<Float>(repeating: scaleFactor)

        // Rotación
        if rotationEuler != .zero {
            let qx = simd_quatf(angle: rotationEuler.x, axis: SIMD3(1, 0, 0))
            let qy = simd_quatf(angle: rotationEuler.y, axis: SIMD3(0, 1, 0))
            let qz = simd_quatf(angle: rotationEuler.z, axis: SIMD3(0, 0, 1))
            wrapper.orientation = qy * qx * qz
        }

        wrapper.position = position
        wrapper.name = organName
        wrapper.addChild(loaded)

        // Primary model entity (primer ModelEntity encontrado, o el loaded casteado).
        var primaryModel: ModelEntity
        if let m = loaded as? ModelEntity {
            primaryModel = m
        } else {
            // Buscar el primer ModelEntity descendente.
            var foundModel: ModelEntity?
            loaded.visit { e in
                if foundModel == nil, let m = e as? ModelEntity {
                    foundModel = m
                }
            }
            // Si no hay, crear uno dummy para que el shader/component se pueda registrar.
            primaryModel = foundModel ?? ModelEntity(mesh: .generateSphere(radius: 0.001))
        }
        // Renombrar los ModelEntity descendentes para que XRayHologramFactory
        // los procese con los defaults del órgano target.
        loaded.visit { e in
            if let m = e as? ModelEntity, m.name.isEmpty {
                m.name = organName
            }
        }

        return (wrapper, primaryModel)
    }

    /// Esfera cyan de 30 cm centrada en el torso para debug de visibilidad.
    private static func buildGiantSphere() -> LoadedOrgans {
        let root = Entity()
        root.name = "debug_giant_sphere_root"

        let mat = SimpleMaterial(
            color: UIColor(red: 0.49, green: 0.83, blue: 0.99, alpha: 0.75),
            roughness: 0.3,
            isMetallic: false
        )
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [mat]
        )
        sphere.name = "debug_sphere"
        sphere.position = SIMD3(0, 0.05, 0.05)  // ligeramente alto y delante
        root.addChild(sphere)

        return LoadedOrgans(
            root: root,
            byName: ["debug_sphere": sphere],
            modelTorsoLength: 0.45,
            organDefaults: [:]
        )
    }

    // MARK: - Placeholder procedural

    /// Construye torso sintético con primitives para que el pipeline funcione
    /// ANTES de tener el USDZ real.
    private static func buildPlaceholder() -> LoadedOrgans {
        let root = Entity()
        root.name = "anatomy_torso_placeholder"
        var byName: [String: ModelEntity] = [:]

        // Material base por órgano — se reemplaza con XRay shader en Fase 6.
        func simpleMat(rgb: SIMD3<Float>, alpha: Float = 0.55) -> SimpleMaterial {
            let uiColor = UIColor(
                red:   CGFloat(rgb.x),
                green: CGFloat(rgb.y),
                blue:  CGFloat(rgb.z),
                alpha: CGFloat(alpha)
            )
            return SimpleMaterial(
                color: uiColor,
                roughness: 0.5,
                isMetallic: false
            )
        }

        // Definición de cada órgano: nombre, mesh, posición, scale, color.
        struct Spec {
            let name: String
            let mesh: MeshResource
            let position: SIMD3<Float>
            let scale: SIMD3<Float>
            let rgb: SIMD3<Float>
        }

        // Órganos agrandados 2x vs. versión anterior para que se vean mejor sobre
        // el pecho del sujeto a 1.5m de distancia. Colores cyan holográficos.
        // El XRaySystem (si el slider debug muestra damage) interpola a otros
        // colores, pero los defaults son todos cyan translúcidos.
        let cyan = SIMD3<Float>(0.49, 0.83, 0.99)   // #7DD3FC
        let amber = SIMD3<Float>(0.96, 0.73, 0.26)  // color más cálido para corazón
        let specs: [Spec] = [
            // Corazón: esfera pulsante, centro-izquierda.
            Spec(name: "heart",
                 mesh: .generateSphere(radius: 0.09),
                 position: SIMD3(-0.04, 0.06, 0.02),
                 scale: SIMD3(1.0, 1.2, 0.95),
                 rgb: amber),

            // Pulmón izquierdo: cápsula vertical grande.
            Spec(name: "lung_left",
                 mesh: .generateBox(size: SIMD3(0.16, 0.30, 0.12), cornerRadius: 0.055),
                 position: SIMD3(-0.14, 0.06, 0.00),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),

            // Pulmón derecho: un poco más grande (anatómicamente correcto).
            Spec(name: "lung_right",
                 mesh: .generateBox(size: SIMD3(0.17, 0.32, 0.12), cornerRadius: 0.055),
                 position: SIMD3(0.14, 0.06, 0.00),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),

            // Cerebro: esfera arriba del torso.
            Spec(name: "brain",
                 mesh: .generateSphere(radius: 0.10),
                 position: SIMD3(0.0, 0.42, 0.01),
                 scale: SIMD3(1.05, 0.95, 1.1),
                 rgb: cyan),

            // Hígado: abajo-derecha.
            Spec(name: "liver",
                 mesh: .generateBox(size: SIMD3(0.20, 0.11, 0.13), cornerRadius: 0.03),
                 position: SIMD3(0.07, -0.14, 0.0),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),

            // Riñones: dorsal bajo.
            Spec(name: "kidney_left",
                 mesh: .generateBox(size: SIMD3(0.05, 0.08, 0.035), cornerRadius: 0.02),
                 position: SIMD3(-0.06, -0.22, -0.05),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),
            Spec(name: "kidney_right",
                 mesh: .generateBox(size: SIMD3(0.05, 0.08, 0.035), cornerRadius: 0.02),
                 position: SIMD3(0.06, -0.22, -0.05),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),

            // Aorta: cilindro vertical centro.
            Spec(name: "aorta",
                 mesh: .generateBox(size: SIMD3(0.025, 0.30, 0.025), cornerRadius: 0.011),
                 position: SIMD3(0.0, 0.02, -0.01),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: amber),

            // Tráquea: cilindro delgado, arriba.
            Spec(name: "trachea",
                 mesh: .generateBox(size: SIMD3(0.025, 0.14, 0.025), cornerRadius: 0.01),
                 position: SIMD3(0.0, 0.28, 0.0),
                 scale: SIMD3(1.0, 1.0, 1.0),
                 rgb: cyan),
        ]

        for spec in specs {
            let mat = simpleMat(rgb: spec.rgb)
            let entity = ModelEntity(mesh: spec.mesh, materials: [mat])
            entity.name = spec.name
            entity.position = spec.position
            entity.scale = spec.scale
            root.addChild(entity)
            byName[spec.name] = entity
        }

        return LoadedOrgans(
            root: root,
            byName: byName,
            modelTorsoLength: 0.45,
            organDefaults: Self.defaultOrganParams
        )
    }

    // MARK: - Defaults por órgano

    static let defaultOrganParams: [String: OrganDefaults] = [
        "heart":        .init(pulseRateHz: 1.20, pulseAmp: 0.008, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "lung_left":    .init(pulseRateHz: 0.25, pulseAmp: 0.020, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "lung_right":   .init(pulseRateHz: 0.25, pulseAmp: 0.020, baseColor: SIMD3(0.49, 0.83, 0.99)),
        // Combo USDZ que engloba pulmones + corazón en una sola malla.
        "heart_lungs":  .init(pulseRateHz: 0.40, pulseAmp: 0.006, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "brain":        .init(pulseRateHz: 0.15, pulseAmp: 0.003, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "liver":        .init(pulseRateHz: 0.15, pulseAmp: 0.002, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "kidney_left":  .init(pulseRateHz: 0.15, pulseAmp: 0.002, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "kidney_right": .init(pulseRateHz: 0.15, pulseAmp: 0.002, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "aorta":        .init(pulseRateHz: 1.20, pulseAmp: 0.002, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "trachea":      .init(pulseRateHz: 0.25, pulseAmp: 0.002, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "bronchi_left": .init(pulseRateHz: 0.25, pulseAmp: 0.003, baseColor: SIMD3(0.49, 0.83, 0.99)),
        "bronchi_right":.init(pulseRateHz: 0.25, pulseAmp: 0.003, baseColor: SIMD3(0.49, 0.83, 0.99)),
    ]
}

// MARK: - Helpers

extension Entity {
    /// Recorre la jerarquía aplicando `body` a cada entidad (incluyendo self).
    func visit(_ body: (Entity) -> Void) {
        body(self)
        children.forEach { $0.visit(body) }
    }
}
