//
//  BioDigitalHumanView.swift
//  AcessNet
//
//  SwiftUI wrapper alrededor del SDK BioDigital HumanKit (XCFramework nativo).
//
//  ── Activación del SDK ──────────────────────────────────────────────
//  El SDK se integra vía Swift Package Manager:
//    https://github.com/biodigital-inc/HumanKit.git   (≥ 164.3)
//
//  Hasta que el paquete esté enlazado al target, este archivo compila en
//  modo PLACEHOLDER (render SceneKit básico + mensaje "SDK no enlazado").
//  Para activar el SDK real: agregar el paquete en Xcode y añadir la flag
//  de compilación `HAS_HUMANKIT` en Build Settings → Swift Compiler → Custom
//  Flags → Active Compilation Conditions.
//

import SwiftUI
import SceneKit

#if HAS_HUMANKIT
import HumanKit
#endif

// MARK: - SwiftUI Wrapper

struct BioDigitalHumanView: UIViewControllerRepresentable {

    var bodyState: BodyHealthState
    var onModelReady: () -> Void
    var onLoadError: (String) -> Void
    var onObjectPicked: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onModelReady: onModelReady,
            onLoadError: onLoadError,
            onObjectPicked: onObjectPicked
        )
    }

    func makeUIViewController(context: Context) -> UIViewController {
        #if HAS_HUMANKIT
        return BioDigitalHumanViewControllerReal(coordinator: context.coordinator)
        #else
        return BioDigitalPlaceholderController()
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.bodyState = bodyState
        #if HAS_HUMANKIT
        (uiViewController as? BioDigitalHumanViewControllerReal)?.apply(bodyState: bodyState)
        #endif
    }

    /// Pide al SDK resetear la cámara al estado inicial. Se llama desde el
    /// botón flotante de la pantalla.
    static func resetCamera(on controller: UIViewController) {
        #if HAS_HUMANKIT
        (controller as? BioDigitalHumanViewControllerReal)?.resetCamera()
        #endif
    }
}

// MARK: - Coordinator

extension BioDigitalHumanView {

    final class Coordinator {
        let onModelReady: () -> Void
        let onLoadError: (String) -> Void
        let onObjectPicked: (String) -> Void

        /// Última versión del estado conocido. El VC real lo usa para pintar
        /// una vez que el modelo ha terminado de cargar.
        var bodyState: BodyHealthState?

        init(
            onModelReady: @escaping () -> Void,
            onLoadError: @escaping (String) -> Void,
            onObjectPicked: @escaping (String) -> Void
        ) {
            self.onModelReady = onModelReady
            self.onLoadError = onLoadError
            self.onObjectPicked = onObjectPicked
        }
    }
}

// MARK: - Implementación real (compila solo con HAS_HUMANKIT)

#if HAS_HUMANKIT

final class BioDigitalHumanViewControllerReal: UIViewController, HKHumanDelegate, HKServicesDelegate {

    private let canvasView = UIView()
    private var human: HKHuman?
    private let coordinator: BioDigitalHumanView.Coordinator

    init(coordinator: BioDigitalHumanView.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        canvasView.backgroundColor = .clear
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        guard BioDigitalConfig.isConfigured else {
            coordinator.onLoadError(
                String(localized: "Credenciales de BioDigital no configuradas.")
            )
            return
        }

        // TODO: confirmar la firma exacta del init del SDK (v164.3).
        // En v147 era `HKHuman(view: UIView)`; en v164+ puede requerir
        // canvas + apiKey en el init. Ajustar cuando se enlace el paquete.
        let human = HKHuman(view: canvasView)
        human.delegate = self
        self.human = human
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        human?.unload()
    }

    // MARK: Public API

    func apply(bodyState: BodyHealthState) {
        guard let human else { return }
        for organ in BodyHealthState.Organ.allCases {
            let health = bodyState.health(for: organ)
            let rgba = BioDigitalOrganMapper.highlightColor(for: health.damageLevel)
            let color = HKColor()
            color.tint = UIColor(
                red: CGFloat(rgba.red),
                green: CGFloat(rgba.green),
                blue: CGFloat(rgba.blue),
                alpha: 1.0
            )
            color.opacity = CGFloat(rgba.alpha)
            for objectId in BioDigitalOrganMapper.objectIds(for: organ) {
                human.scene.color(objectId: objectId, color: color)
            }
        }
    }

    func resetCamera() {
        human?.camera.reset()
    }

    // MARK: HKServicesDelegate

    func onValidSDK() { /* no-op */ }

    func onInvalidSDK() {
        coordinator.onLoadError(
            String(localized: "API key de BioDigital inválida.")
        )
    }

    // MARK: HKHumanDelegate

    func human(_ view: HKHuman, modelLoaded: String) {
        coordinator.onModelReady()
        if let state = coordinator.bodyState {
            apply(bodyState: state)
        }
    }

    func human(_ view: HKHuman, modelLoadError: String) {
        coordinator.onLoadError(modelLoadError)
    }

    func human(_ view: HKHuman, objectPicked: String, position: [Double]) {
        coordinator.onObjectPicked(objectPicked)
    }

    func human(_ view: HKHuman, initScene: String) { /* no-op */ }
    func human(_ view: HKHuman, objectColor: String, color: HKColor) { /* no-op */ }
    func human(_ view: HKHuman, chapterTransition: String) { /* no-op */ }
    func human(_ view: HKHuman, animationComplete: Bool) { /* no-op */ }
}

#endif

// MARK: - Placeholder (se usa mientras HAS_HUMANKIT está desactivado)

#if !HAS_HUMANKIT

final class BioDigitalPlaceholderController: UIViewController {

    private let sceneView = SCNView()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupScene()
        setupMessage()
    }

    private func setupScene() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.antialiasingMode = .multisampling4X
        sceneView.scene = makeScene()
        view.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        let torso = SCNCapsule(capRadius: 0.35, height: 1.6)
        torso.firstMaterial?.diffuse.contents = UIColor(white: 0.85, alpha: 0.95)
        torso.firstMaterial?.lightingModel = .physicallyBased
        let node = SCNNode(geometry: torso)
        scene.rootNode.addChildNode(node)

        let camera = SCNCamera()
        camera.fieldOfView = 40
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3.2)
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    private func setupMessage() {
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "SDK BioDigital no enlazado\nAgrega HumanKit vía SPM y activa la flag HAS_HUMANKIT"
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        messageLabel.font = .systemFont(ofSize: 11, weight: .medium)
        view.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
}

#endif
