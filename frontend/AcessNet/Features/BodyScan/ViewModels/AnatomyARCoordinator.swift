//
//  AnatomyARCoordinator.swift
//  AcessNet
//
//  Coordinator del modo Anatomy AR.
//
//  Arquitectura:
//    - ARWorldTrackingConfiguration (no BodyTracking — incompatible con person seg).
//    - VNDetectHumanBodyPose3DRequest en paralelo sobre capturedImage (iOS 17+).
//    - personSegmentationWithDepth → RealityKit ocluye automáticamente.
//    - LiDAR sceneReconstruction + sceneDepth cuando está disponible.
//
//  Thread model:
//    - ARSessionDelegate (nonisolated) recibe frames a 60 fps.
//    - Vision corre en visionQueue (utility QoS) cada N frames.
//    - Todos los updates al @Published viewModel vuelven a @MainActor.
//

import ARKit
import RealityKit
import Vision
import Combine
import UIKit
import os

@MainActor
final class AnatomyARCoordinator: NSObject {

    // MARK: - Dependencies

    weak var arView: ARView?
    let viewModel: AnatomyViewModel

    // MARK: - Vision pipeline

    private let visionQueue = DispatchQueue(
        label: "xyz.KOmbo.AirWay.anatomy.vision",
        qos: .userInitiated
    )
    /// Rate-limit atómico (nonisolated, accesible desde el delegate).
    /// Crítico para no encolar un Task @MainActor por cada frame (60/s).
    private let frameGate = OSAllocatedUnfairLock<FrameGateState>(
        initialState: FrameGateState()
    )
    private let visionEveryN = 3  // 20 fps Vision sobre 60 fps ARKit (menos carga)

    struct FrameGateState {
        var counter: Int = 0
        var busy: Bool = false
    }

    private var lastVisionTimestamp: CFTimeInterval = 0
    private var visionFrameCount = 0
    private var fpsWindowStart: CFTimeInterval = 0

    // MARK: - Tracking state

    private var consecutiveLostFrames = 0
    private let lostThresholdShort = 15   // ~0.5 s → searching
    private let lostThresholdLong = 60    // ~2 s → lost

    // MARK: - Torso frame builder (Fase 4)

    private let torsoBuilder = TorsoAnchorBuilder()

    // MARK: - Anchoring (Fase 5+)

    /// Ancla mundial que contiene el USDZ de órganos. Se actualiza cada vez
    /// que llega una observation filtrada.
    private let rootAnchor = AnchorEntity(world: .zero)

    /// Órganos cargados (USDZ real o placeholder).
    private var loadedOrgans: LoadedOrgans?

    /// Controller que suaviza la pose a 60/120 fps.
    private var organController: OrganAnchorController?

    /// Acumula exposición a contaminantes y produce damage por órgano.
    let exposureAccumulator = ExposureAccumulator()

    /// Cancellable para la suscripción damageByOrgan → shader.
    private var damageCancellable: AnyCancellable?

    /// Cancellable para el slider debug.
    private var debugAQICancellable: AnyCancellable?

    /// Último transform world del torso (para predicción / interpolación Fase 7).
    private(set) var lastTorsoWorldTransform: simd_float4x4 = matrix_identity_float4x4
    private(set) var lastTorsoTimestamp: CFTimeInterval = 0

    /// Callback que Fase 7 usa para recibir torso frames (para el OrganAnchorController).
    var onTorsoFrame: ((_ worldTransform: simd_float4x4,
                        _ frame: TorsoFrame,
                        _ timestamp: CFTimeInterval) -> Void)?

    // MARK: - Init

    init(arView: ARView, viewModel: AnatomyViewModel) {
        self.arView = arView
        self.viewModel = viewModel
        super.init()

        AnatomyLog.info("[1/7] AnatomyARCoordinator.init — start")

        // Fix preventivo #3: device no soportado → no intentamos AR.
        guard ARWorldTrackingConfiguration.isSupported else {
            AnatomyLog.error("[1/7] ARWorldTrackingConfiguration NOT supported (simulator?). Aborting setup.")
            viewModel.state = .lost
            return
        }

        // Registrar ECS (idempotente).
        XRayOrganComponent.registerComponent()
        XRaySystem.registerSystem()
        AnatomyLog.info("[2/7] ECS registered (XRayOrganComponent + XRaySystem)")

        configureSession()
        arView.scene.addAnchor(rootAnchor)
        AnatomyLog.info("[3/7] rootAnchor added to scene")

        // Cargar asset de órganos (o placeholder) en background.
        Task { @MainActor [weak self] in
            guard let self else { return }
            AnatomyLog.info("[4/7] Loading organs asset…")
            let organs = await AnatomyEntityLoader.load()
            self.loadedOrgans = organs
            self.rootAnchor.addChild(organs.root)
            AnatomyLog.info("[4/7] Organs loaded: \(organs.byName.count) entities, modelTorsoLength=\(organs.modelTorsoLength)")

            // Aplicar shader X-Ray a todos los órganos.
            AnatomyLog.info("[5/7] Applying XRay shader…")
            XRayHologramFactory.applyRecursive(
                to: organs.root,
                defaults: organs.organDefaults
            )
            AnatomyLog.info("[5/7] XRay shader applied")

            // Controller de interpolación 60 fps.
            self.organController = OrganAnchorController(
                rootAnchor: self.rootAnchor,
                modelTorsoLength: organs.modelTorsoLength
            )
            AnatomyLog.info("[6/7] OrganAnchorController ready")

            // Conectar Vision → controller.
            self.onTorsoFrame = { [weak self] worldT, frame, ts in
                self?.organController?.updateFromVision(
                    worldTransform: worldT,
                    frame: frame,
                    timestamp: ts
                )
            }

            // Suscripción damageByOrgan → shader (Fase 8).
            self.damageCancellable = self.exposureAccumulator.$damageByOrgan
                .receive(on: DispatchQueue.main)
                .sink { [weak self] byOrgan in
                    guard let self else { return }
                    for (targetOrgan, damage) in byOrgan {
                        for usdzName in targetOrgan.usdzNames {
                            self.setDamage(Float(damage), forOrgan: usdzName)
                        }
                    }
                    self.exposureAccumulator.apply(to: self.viewModel)
                }

            // Suscripción debug AQI → exposureAccumulator.
            self.debugAQICancellable = self.viewModel.$debugAQI
                .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
                .sink { [weak self] aqi in
                    guard let self, aqi > 0 else { return }
                    self.exposureAccumulator.ingestAQI(aqi)
                }
            AnatomyLog.info("[7/7] AnatomyARCoordinator.init — complete")
        }
    }

    // MARK: - Damage control (Fase 8 lo conecta con AQI/PPI)

    /// Actualiza el damageLevel target de un órgano. XRaySystem interpola.
    func setDamage(_ damage: Float, forOrgan name: String) {
        guard let entity = loadedOrgans?.byName[name] else { return }
        if var xray = entity.components[XRayOrganComponent.self] as XRayOrganComponent? {
            xray.damageLevel = max(0, min(1, damage))
            entity.components.set(xray)
        }
    }

    /// Conveniencia: aplicar el mismo damage a todos los órganos (debug slider).
    func setDamageAll(_ damage: Float) {
        guard let organs = loadedOrgans else { return }
        for (name, _) in organs.byName {
            setDamage(damage, forOrgan: name)
        }
    }

    // MARK: - AR session

    private func configureSession() {
        guard let arView else {
            AnatomyLog.error("configureSession: arView is nil")
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none      // no texturing → menos pipeline
        config.isAutoFocusEnabled = true

        // ❌ NO personSegmentation: para X-Ray vision NO queremos que el cuerpo
        // del sujeto tape los órganos. Los órganos están DENTRO del torso,
        // con personSegWithDepth la persona los ocluye completamente (no se ven).
        // Visual XRay: los órganos se dibujan encima del feed de cámara.
        let personSegActive = "disabled (for X-Ray visibility)"

        // ❌ NO activamos sceneDepth ni sceneReconstruction:
        // el shader interno `fsSurfaceMeshShadowCasterProgrammableBlending`
        // crashea cuando el mesh LiDAR participa en el pipeline de shadow
        // casting sobre un CustomMaterial con blending .transparent.
        // Los órganos siguen al sujeto, no al entorno — no necesitamos el mesh.

        // Render options — todo lo que pueda invocar el shadow caster:
        arView.renderOptions.remove(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableGroundingShadows)
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableFaceMesh)
        arView.renderOptions.insert(.disableHDR)
        arView.renderOptions.insert(.disableAREnvironmentLighting)

        // Nada en sceneUnderstanding — no queremos mesh participando.
        arView.environment.sceneUnderstanding.options = []

        AnatomyLog.info("configureSession: personSeg=\(personSegActive) sceneDepth=disabled reconstruction=disabled")

        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        AnatomyLog.info("configureSession: session.run called")
    }

    func stopSession() {
        arView?.session.pause()
    }

    // MARK: - Vision processing state

    private var didLogFirstFrame = false

    // MARK: - Main-actor update

    private func apply(observation: VNHumanBodyPose3DObservation,
                       cameraTransform: simd_float4x4) {
        let ts = CACurrentMediaTime()

        // Fase 4: construir marco torso filtrado (en frame de cámara).
        guard let torsoFrame = torsoBuilder.build(from: observation, timestamp: ts) else {
            handleTrackingLost()
            return
        }

        // Confidence muy baja → tratar como lost.
        if torsoFrame.confidence < 0.3 {
            handleTrackingLost()
            return
        }

        consecutiveLostFrames = 0
        viewModel.state = .tracking
        viewModel.bodyHeight = torsoFrame.height
        viewModel.trackingConfidence = torsoFrame.confidence
        updateVisionFps()

        // Vision y ARKit usan frames de cámara DISTINTOS. Compongámoslos así:
        //   - **X/Y de pantalla**: ray-through-hip-2D-point del sujeto (Vision)
        //   - **Distancia (Z)**: fija a ~1.2 m (funciona con sujeto sentado/parado)
        //   - **Orientación**: yaw-only (ejes horizontales alineados con cámara,
        //     Y = world up). Elimina roll/pitch que distorsionan los offsets.
        let anchorDistance: Float = 1.2

        // 1) Posición: ray a través del punto 2D del hip del sujeto.
        let anchorPos: SIMD3<Float>
        if let arView = self.arView,
           let rootImage = try? observation.pointInImage(.root) {
            let viewSize = arView.bounds.size
            // pointInImage devuelve (x, y) en [0..1] donde y es bottom-up.
            // UIKit usa top-left origin, por eso flip Y.
            let uiPoint = CGPoint(
                x: rootImage.x * viewSize.width,
                y: (1.0 - rootImage.y) * viewSize.height
            )
            if let ray = arView.ray(through: uiPoint) {
                anchorPos = ray.origin + ray.direction * anchorDistance
            } else {
                anchorPos = Self.fallbackAnchorPos(
                    cameraTransform: cameraTransform,
                    distance: anchorDistance
                )
            }
        } else {
            anchorPos = Self.fallbackAnchorPos(
                cameraTransform: cameraTransform,
                distance: anchorDistance
            )
        }

        // 2) Orientación yaw-only: Y = world up, forward = proyección del forward
        //    de la cámara en el plano horizontal, right = cross(up, forward).
        let worldUp = SIMD3<Float>(0, 1, 0)
        let rawForward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        var horizForward = SIMD3<Float>(rawForward.x, 0, rawForward.z)
        let mag = simd_length(horizForward)
        if mag > 1e-3 {
            horizForward /= mag
        } else {
            horizForward = SIMD3<Float>(0, 0, -1)  // mirando al horizonte
        }
        let horizRight = simd_normalize(simd_cross(worldUp, horizForward))

        let torsoWorld = simd_float4x4(
            SIMD4(horizRight, 0),
            SIMD4(worldUp, 0),
            SIMD4(-horizForward, 0),   // Z en RealityKit es opuesto al forward
            SIMD4(anchorPos, 1)
        )

        // Fase 7: notificar a OrganAnchorController (interpolación 60 fps).
        //         Mientras tanto, actualizamos el rootAnchor directo.
        lastTorsoWorldTransform = torsoWorld
        lastTorsoTimestamp = ts

        // Escala dinámica: torsoLength real / modelTorsoLength.
        let modelTorsoLen = loadedOrgans?.modelTorsoLength ?? 0.45
        let targetScale = max(0.5, min(2.0, torsoFrame.torsoLength / modelTorsoLen))

        if let onTorsoFrame {
            onTorsoFrame(torsoWorld, torsoFrame, ts)
        } else {
            // Fallback sin controller: aplicar directo (saltará entre frames de Vision).
            rootAnchor.setTransformMatrix(torsoWorld, relativeTo: nil)
            rootAnchor.scale = SIMD3(repeating: targetScale)
        }

        #if DEBUG
        if ts - lastDebugLog > 1.0 {
            lastDebugLog = ts
            let p = torsoWorld.columns.3
            AnatomyLog.info("h=\(String(format: "%.2f", torsoFrame.height))m conf=\(String(format: "%.2f", torsoFrame.confidence)) vFps=\(String(format: "%.1f", viewModel.visionFps)) torsoWorld=(\(String(format: "%.2f", p.x)),\(String(format: "%.2f", p.y)),\(String(format: "%.2f", p.z))) scale=\(String(format: "%.2f", targetScale))")
        }
        #endif
    }

    private var lastDebugLog: CFTimeInterval = 0

    private func handleTrackingLost() {
        consecutiveLostFrames += 1
        if consecutiveLostFrames > lostThresholdLong {
            viewModel.state = .lost
        } else if consecutiveLostFrames > lostThresholdShort {
            viewModel.state = .searching
        }
    }

    private func updateVisionFps() {
        visionFrameCount += 1
        let now = CACurrentMediaTime()
        if fpsWindowStart == 0 { fpsWindowStart = now }
        let elapsed = now - fpsWindowStart
        if elapsed >= 1.0 {
            viewModel.visionFps = Double(visionFrameCount) / elapsed
            visionFrameCount = 0
            fpsWindowStart = now
        }
    }

    // MARK: - Helpers

    private static func fallbackAnchorPos(cameraTransform: simd_float4x4, distance: Float) -> SIMD3<Float> {
        let cameraPos = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        return cameraPos + cameraForward * distance
    }

    static func cgImageOrientation(for deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portrait:             return .right
        case .portraitUpsideDown:   return .left
        case .landscapeLeft:        return .up
        case .landscapeRight:       return .down
        default:                    return .right
        }
    }
}

// MARK: - ARSessionDelegate

extension AnatomyARCoordinator: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Rate-limit ATÓMICO antes de cualquier otra cosa, para no encolar un
        // Task @MainActor por cada frame (60/s). La advertencia "ARSession is
        // retaining N ARFrames" aparece si dejamos que los Tasks se acumulen.
        let shouldProcess = frameGate.withLock { state -> Bool in
            state.counter &+= 1
            guard state.counter % visionEveryN == 0 else { return false }
            guard !state.busy else { return false }
            state.busy = true
            return true
        }
        guard shouldProcess else { return }

        // Fix #1: extraer value types DENTRO del scope del delegate.
        // ARFrame es clase con lifetime gestionado por un pool interno;
        // retenerla en un Task diferido causa use-after-free.
        let pixelBuffer = frame.capturedImage
        let cameraTransform = frame.camera.transform
        let orientation: CGImagePropertyOrientation = .right

        // Directamente a la visionQueue — NO pasamos por main actor solo para
        // decidir. El resultado sí se dispatcha a main.
        visionQueue.async { [weak self] in
            guard let self else { return }
            self.runVision(
                pixelBuffer: pixelBuffer,
                cameraTransform: cameraTransform,
                orientation: orientation
            )
        }
    }

    /// Ejecutado en visionQueue (background). Libera `busy` al terminar.
    nonisolated private func runVision(pixelBuffer: CVPixelBuffer,
                                       cameraTransform: simd_float4x4,
                                       orientation: CGImagePropertyOrientation) {
        defer {
            frameGate.withLock { $0.busy = false }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        let request = VNDetectHumanBodyPose3DRequest()

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                Task { @MainActor [weak self] in self?.handleTrackingLost() }
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.didLogFirstFrame {
                    self.didLogFirstFrame = true
                    AnatomyLog.info("Vision: first frame processed ✓ (h=\(observation.bodyHeight)m)")
                }
                self.apply(observation: observation, cameraTransform: cameraTransform)
            }
        } catch {
            let msg = error.localizedDescription
            Task { @MainActor [weak self] in
                AnatomyLog.error("Vision perform failed: \(msg)")
                self?.handleTrackingLost()
            }
        }
    }

    nonisolated func session(_ session: ARSession,
                             cameraDidChangeTrackingState camera: ARCamera) {
        let description: String = {
            switch camera.trackingState {
            case .normal:                return "normal"
            case .notAvailable:          return "notAvailable"
            case .limited(let reason):   return "limited(\(reason))"
            }
        }()
        AnatomyLog.info("ARCamera tracking state: \(description)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch camera.trackingState {
            case .normal:
                break
            case .notAvailable, .limited:
                self.handleTrackingLost()
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let msg = error.localizedDescription
        AnatomyLog.error("ARSession failed: \(msg)")
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        AnatomyLog.warn("ARSession interrupted")
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        AnatomyLog.info("ARSession interruption ended")
    }
}
