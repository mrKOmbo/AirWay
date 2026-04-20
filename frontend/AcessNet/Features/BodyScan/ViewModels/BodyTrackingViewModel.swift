//
//  BodyTrackingViewModel.swift
//  AcessNet
//
//  Tracking continuo del esqueleto humano usando ARBodyTrackingConfiguration.
//  Expone los 34 joints en espacio 3D (mundo) y 2D (pantalla) para overlay.
//

import Foundation
import ARKit
import RealityKit
import Combine
import simd

@MainActor
final class BodyTrackingViewModel: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isTracking: Bool = false
    @Published var isDeviceSupported: Bool = ARBodyTrackingConfiguration.isSupported
    @Published var trackedJointsScreen: [BodyJoint: CGPoint] = [:]
    @Published var trackedJointsWorld: [BodyJoint: SIMD3<Float>] = [:]
    @Published var estimatedHeight: Float? = nil
    @Published var poseQuality: PoseQuality = .searching

    // MARK: - AR references

    weak var arView: ARView?
    private var viewBounds: CGSize = .zero

    // MARK: - Lifecycle

    func startSession(on arView: ARView) {
        self.arView = arView
        arView.session.delegate = self

        // Diferir para evitar "Publishing changes from within view updates".
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard ARBodyTrackingConfiguration.isSupported else {
                self.isDeviceSupported = false
                return
            }

            let configuration = ARBodyTrackingConfiguration()
            configuration.automaticSkeletonScaleEstimationEnabled = true
            configuration.frameSemantics.insert(.bodyDetection)
            if ARBodyTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }

            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    func stopSession() {
        arView?.session.pause()
        isTracking = false
        trackedJointsScreen = [:]
        trackedJointsWorld = [:]
    }

    func updateViewBounds(_ size: CGSize) {
        viewBounds = size
    }

    // MARK: - Helpers

    enum PoseQuality {
        case searching
        case partial
        case good

        var label: String {
            switch self {
            case .searching: return "Buscando cuerpo…"
            case .partial: return "Pose parcial"
            case .good: return "Tracking óptimo"
            }
        }

        var color: String {
            switch self {
            case .searching: return "#F4B942"
            case .partial: return "#FF8A3D"
            case .good: return "#4ADE80"
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension BodyTrackingViewModel: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let bodyAnchor = frame.anchors.compactMap { $0 as? ARBodyAnchor }.first

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let bodyAnchor else {
                self.isTracking = false
                self.poseQuality = .searching
                self.trackedJointsScreen = [:]
                self.trackedJointsWorld = [:]
                return
            }

            self.isTracking = true
            self.processBodyAnchor(bodyAnchor, frame: frame)
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors where anchor is ARBodyAnchor {
            Task { @MainActor [weak self] in
                self?.isTracking = true
            }
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors where anchor is ARBodyAnchor {
            Task { @MainActor [weak self] in
                self?.isTracking = false
                self?.trackedJointsScreen = [:]
                self?.trackedJointsWorld = [:]
                self?.poseQuality = .searching
            }
        }
    }
}

// MARK: - Frame processing

private extension BodyTrackingViewModel {

    func processBodyAnchor(_ bodyAnchor: ARBodyAnchor, frame: ARFrame) {
        let skeleton = bodyAnchor.skeleton
        let rootTransform = bodyAnchor.transform

        var screenPoints: [BodyJoint: CGPoint] = [:]
        var worldPoints: [BodyJoint: SIMD3<Float>] = [:]

        guard let arView else { return }
        let cameraTransform = frame.camera.transform
        let interfaceOrientation: UIInterfaceOrientation = {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first {
                return scene.interfaceOrientation
            }
            return .portrait
        }()

        let viewSize = arView.bounds.size
        viewBounds = viewSize

        for joint in BodyJoint.allCases {
            let jointName = ARSkeleton.JointName(rawValue: joint.arJointName)
            let localTransform = skeleton.modelTransform(for: jointName)

            guard let localTransform else { continue }

            let worldTransform = simd_mul(rootTransform, localTransform)
            let worldPos = SIMD3<Float>(worldTransform.columns.3.x,
                                        worldTransform.columns.3.y,
                                        worldTransform.columns.3.z)
            worldPoints[joint] = worldPos

            let projected = frame.camera.projectPoint(
                worldPos,
                orientation: interfaceOrientation,
                viewportSize: viewSize
            )

            if projected.x.isFinite && projected.y.isFinite {
                screenPoints[joint] = projected
            }
        }

        let headPos = worldPoints[.head]
        let footPos = worldPoints[.leftFoot] ?? worldPoints[.rightFoot]
        if let h = headPos, let f = footPos {
            estimatedHeight = abs(h.y - f.y) + 0.18 // +offset estimado de cabeza
        }

        trackedJointsScreen = screenPoints
        trackedJointsWorld = worldPoints

        let totalJoints = BodyJoint.allCases.count
        let ratio = Double(screenPoints.count) / Double(totalJoints)
        poseQuality = ratio > 0.85 ? .good : (ratio > 0.5 ? .partial : .searching)

        _ = cameraTransform // silencia warning si no se usa
    }
}
