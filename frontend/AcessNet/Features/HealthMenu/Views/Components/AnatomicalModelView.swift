//
//  AnatomicalModelView.swift
//  AcessNet
//
//  Visor 3D anatómico nativo basado en SceneKit. Carga un USDZ del bundle,
//  ofrece rotación/zoom/pan con `allowsCameraControl`, hit-testing para
//  detectar qué órgano tocó el usuario y aplica color a los órganos
//  afectados según el BodyHealthState.
//
//  Es la alternativa sin dependencias al SDK de BioDigital. Compatible con
//  cualquier USDZ que tenga los órganos como nodos nombrados.
//
//  Assets sugeridos (ver HealthMenu/Resources/README.md):
//   · Apple AR Quick Look gallery (human body samples).
//   · Sketchfab: filtro "Downloadable" + "USDZ" + query "anatomy".
//   · Z-Anatomy (.fbx) convertido a USDZ con Reality Composer Pro.
//

import SwiftUI
import SceneKit

struct AnatomicalModelView: UIViewRepresentable {

    /// Nombre del USDZ en el bundle (sin extensión).
    /// Si el archivo no existe se usa una escena primitiva de respaldo.
    let modelName: String

    let bodyState: BodyHealthState
    var onModelReady: () -> Void
    var onLoadError: (String) -> Void
    var onOrganPicked: (BodyHealthState.Organ) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onOrganPicked: onOrganPicked,
            onModelReady: onModelReady,
            onLoadError: onLoadError
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        let scene = context.coordinator.loadScene(preferredModelName: modelName)
        scnView.scene = scene
        context.coordinator.sceneView = scnView

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        scnView.addGestureRecognizer(tap)

        DispatchQueue.main.async {
            context.coordinator.applyHealthState(bodyState)
        }
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.applyHealthState(bodyState)
    }

    /// Resetea la cámara al transform inicial. Se llama desde el botón flotante.
    static func resetCamera(on view: SCNView) {
        guard let initial = view.scene?.rootNode.value(forKey: "initialCameraTransform") as? NSValue else {
            view.defaultCameraController.pointOfView?.transform = SCNMatrix4Identity
            return
        }
        let transform = initial.scnMatrix4Value
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.45
        view.pointOfView?.transform = transform
        SCNTransaction.commit()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        weak var sceneView: SCNView?
        private let onOrganPicked: (BodyHealthState.Organ) -> Void
        private let onModelReady: () -> Void
        private let onLoadError: (String) -> Void

        /// Cache: nodo → órgano mapeado. Evita recalcular en cada tap.
        private var organByNode: [ObjectIdentifier: BodyHealthState.Organ] = [:]
        /// Material original por nodo, para poder restaurar cuando baja el damageLevel.
        private var originalMaterials: [ObjectIdentifier: SCNMaterial] = [:]
        private var didReportReady = false

        init(
            onOrganPicked: @escaping (BodyHealthState.Organ) -> Void,
            onModelReady: @escaping () -> Void,
            onLoadError: @escaping (String) -> Void
        ) {
            self.onOrganPicked = onOrganPicked
            self.onModelReady = onModelReady
            self.onLoadError = onLoadError
        }

        // MARK: Scene loading

        func loadScene(preferredModelName: String) -> SCNScene {
            if let scene = tryLoadScene(named: preferredModelName) {
                indexAnatomyNodes(scene)
                addAmbientLighting(scene)
                snapshotInitialCamera(scene)
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.didReportReady else { return }
                    self.didReportReady = true
                    self.onModelReady()
                }
                return scene
            }
            // Fallback: escena primitiva con "órganos" sintéticos agrupados por nombre.
            // Permite probar el flujo completo sin asset externo.
            let fallback = makeFallbackScene()
            indexAnatomyNodes(fallback)
            snapshotInitialCamera(fallback)
            DispatchQueue.main.async { [weak self] in
                self?.onLoadError(
                    String(localized: "Asset anatómico no encontrado. Usando modelo de respaldo.")
                )
            }
            return fallback
        }

        private func tryLoadScene(named: String) -> SCNScene? {
            for ext in ["usdz", "usd", "usda", "scn", "dae"] {
                if let url = Bundle.main.url(forResource: named, withExtension: ext),
                   let scene = try? SCNScene(url: url, options: [
                    .checkConsistency: true,
                    .flattenScene: false,
                    .preserveOriginalTopology: true
                   ]) {
                    return scene
                }
            }
            return nil
        }

        private func addAmbientLighting(_ scene: SCNScene) {
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 600
            ambient.light?.color = UIColor(white: 1.0, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 900
            key.light?.castsShadow = false
            key.position = SCNVector3(2, 3, 4)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)
        }

        private func snapshotInitialCamera(_ scene: SCNScene) {
            guard let pov = scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
            scene.rootNode.setValue(NSValue(scnMatrix4: pov.transform),
                                    forKey: "initialCameraTransform")
        }

        // MARK: Node indexing

        /// Recorre la escena e indexa qué órgano representa cada nodo basado en
        /// el nombre del nodo.
        private func indexAnatomyNodes(_ scene: SCNScene) {
            organByNode.removeAll()
            originalMaterials.removeAll()

            scene.rootNode.enumerateHierarchy { [weak self] node, _ in
                guard let self else { return }
                guard let name = node.name, !name.isEmpty else { return }
                guard let organ = AnatomicalNodeMatcher.organ(forNodeName: name) else { return }
                self.organByNode[ObjectIdentifier(node)] = organ
                if let material = node.geometry?.firstMaterial?.copy() as? SCNMaterial {
                    self.originalMaterials[ObjectIdentifier(node)] = material
                }
            }
        }

        // MARK: Health state application

        func applyHealthState(_ state: BodyHealthState) {
            guard let scene = sceneView?.scene else { return }
            scene.rootNode.enumerateHierarchy { [weak self] node, _ in
                guard let self else { return }
                guard let organ = self.organByNode[ObjectIdentifier(node)] else { return }
                let health = state.health(for: organ)
                applyTint(to: node, organ: organ, damage: health.damageLevel)
            }
        }

        private func applyTint(to node: SCNNode, organ: BodyHealthState.Organ, damage: Double) {
            guard let geometry = node.geometry else { return }
            let severity = OrganHealth(damageLevel: damage).severity
            let baseMaterial = originalMaterials[ObjectIdentifier(node)]?.copy() as? SCNMaterial
                ?? SCNMaterial()

            let tinted = baseMaterial
            tinted.lightingModel = .physicallyBased
            tinted.diffuse.contents = UIColor(severity.tint).withAlphaComponent(0.92)
            tinted.emission.contents = UIColor(severity.tint).withAlphaComponent(CGFloat(damage * 0.45))
            tinted.roughness.contents = NSNumber(value: 0.35)
            tinted.metalness.contents = NSNumber(value: 0.0)
            tinted.transparency = CGFloat(0.85 + damage * 0.15)

            geometry.firstMaterial = tinted
        }

        // MARK: Hit testing

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = sceneView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            guard let hit = hits.first else { return }
            if let organ = organ(from: hit.node) {
                onOrganPicked(organ)
            } else if let name = hit.node.name {
                print("🩺 anatomical tap (no mapeado): \(name)")
            }
        }

        /// Sube por la jerarquía hasta encontrar un nodo conocido.
        private func organ(from node: SCNNode) -> BodyHealthState.Organ? {
            var cursor: SCNNode? = node
            while let current = cursor {
                if let organ = organByNode[ObjectIdentifier(current)] {
                    return organ
                }
                cursor = current.parent
            }
            if let name = node.name {
                return AnatomicalNodeMatcher.organ(forNodeName: name)
            }
            return nil
        }

        // MARK: Fallback scene

        /// Escena primitiva: torso + 6 esferas etiquetadas como órganos.
        /// Se usa solo cuando no se encuentra USDZ. Cada "órgano" es un
        /// `SCNNode` con nombre reconocible por `AnatomicalNodeMatcher`.
        private func makeFallbackScene() -> SCNScene {
            let scene = SCNScene()

            let torso = SCNCapsule(capRadius: 0.36, height: 1.7)
            torso.firstMaterial?.lightingModel = .physicallyBased
            torso.firstMaterial?.diffuse.contents = UIColor(white: 0.92, alpha: 0.28)
            torso.firstMaterial?.transparency = 0.35
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.name = "torso_silhouette"
            scene.rootNode.addChildNode(torsoNode)

            func organSphere(name: String, radius: CGFloat, position: SCNVector3) -> SCNNode {
                let sphere = SCNSphere(radius: radius)
                sphere.firstMaterial?.lightingModel = .physicallyBased
                sphere.firstMaterial?.diffuse.contents = UIColor(white: 0.75, alpha: 1)
                let node = SCNNode(geometry: sphere)
                node.name = name
                node.position = position
                return node
            }

            scene.rootNode.addChildNode(organSphere(name: "brain", radius: 0.14, position: SCNVector3(0, 1.0, 0)))
            scene.rootNode.addChildNode(organSphere(name: "nose", radius: 0.04, position: SCNVector3(0, 0.85, 0.28)))
            scene.rootNode.addChildNode(organSphere(name: "throat", radius: 0.05, position: SCNVector3(0, 0.62, 0.1)))
            scene.rootNode.addChildNode(organSphere(name: "lung_left", radius: 0.13, position: SCNVector3(-0.16, 0.35, 0.02)))
            scene.rootNode.addChildNode(organSphere(name: "lung_right", radius: 0.13, position: SCNVector3(0.16, 0.35, 0.02)))
            scene.rootNode.addChildNode(organSphere(name: "heart", radius: 0.08, position: SCNVector3(-0.04, 0.28, 0.15)))

            let skinShell = SCNSphere(radius: 0.55)
            skinShell.firstMaterial?.lightingModel = .constant
            skinShell.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.04)
            skinShell.firstMaterial?.transparency = 0.12
            let skinNode = SCNNode(geometry: skinShell)
            skinNode.name = "skin_shell"
            skinNode.position = SCNVector3(0, 0.4, 0)
            scene.rootNode.addChildNode(skinNode)

            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.automaticallyAdjustsZRange = true
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.4, 3.2)
            scene.rootNode.addChildNode(cameraNode)

            return scene
        }
    }
}
