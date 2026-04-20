//
//  SavedScanViewerView.swift
//  AcessNet
//
//  Visor interactivo del USDZ guardado. Usa SceneKit con `allowsCameraControl`
//  para dar rotación orbital + pinch-zoom + pan inercial nativos.
//

import SwiftUI
import UIKit
import SceneKit

struct SavedScanViewerView: View {
    @ObservedObject var storage: BodyScanStorage
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            if storage.hasSavedScan {
                Scene3DViewer(url: storage.scanURL)
                    .ignoresSafeArea()

                VStack {
                    metadataHeader
                        .padding(.top, 110)
                    Spacer()
                    gestureHint
                    actionsBar
                        .padding(.bottom, 190)
                }
            } else {
                emptyState
            }
        }
        .preferredColorScheme(.dark)
        .alert("Eliminar escaneo", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                storage.deleteScan()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El escaneo guardado se perderá. ¿Continuar?")
        }
    }

    // MARK: - Metadata header

    private var metadataHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tu escaneo 3D")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            if let meta = storage.savedMetadata {
                HStack(spacing: 16) {
                    metaPill(icon: "calendar",
                             text: Self.dateFormatter.string(from: meta.createdAt))
                    if let v = meta.vertexCount {
                        metaPill(icon: "cube.transparent",
                                 text: "\(v.formatted()) vértices")
                    }
                    if let h = meta.estimatedHeightMeters {
                        metaPill(icon: "ruler",
                                 text: String(format: "%.2f m", h))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.08))
        )
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    // MARK: - Gesture hint

    private var gestureHint: some View {
        HStack(spacing: 18) {
            hintItem(icon: "hand.draw", text: "Arrastra: rotar")
            hintItem(icon: "arrow.up.left.and.down.right.magnifyingglass", text: "Pellizca: zoom")
            hintItem(icon: "hand.tap", text: "Dos dedos: mover")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.bottom, 14)
    }

    private func hintItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.7))
    }

    // MARK: - Actions

    private var actionsBar: some View {
        HStack(spacing: 14) {
            actionButton(icon: "square.and.arrow.up",
                         title: "Compartir",
                         color: Color(hex: "#7DD3FC")) {
                shareScan()
            }

            actionButton(icon: "trash",
                         title: "Eliminar",
                         color: Color(hex: "#F472B6")) {
                showDeleteConfirm = true
            }
        }
        .padding(.horizontal, 20)
    }

    private func actionButton(icon: String,
                              title: String,
                              color: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(color.opacity(0.25))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.6), lineWidth: 1)
                    )
            )
        }
    }

    private func shareScan() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first?.rootViewController else { return }

        let controller = UIActivityViewController(
            activityItems: [storage.scanURL],
            applicationActivities: nil
        )
        controller.popoverPresentationController?.sourceView = root.view
        root.present(controller, animated: true)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 54))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#7DD3FC"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Sin escaneo guardado")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Inicia un escaneo 3D para verlo aquí.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 32)
    }
}

// MARK: - Visor SceneKit interactivo

private struct Scene3DViewer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.autoenablesDefaultLighting = true
        scnView.rendersContinuously = true

        // Gestures nativos de SceneKit: orbit + pinch + two-finger pan.
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.defaultCameraController.maximumVerticalAngle = 90
        scnView.defaultCameraController.minimumVerticalAngle = -90

        loadScene(into: scnView)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func loadScene(into scnView: SCNView) {
        do {
            let scene = try SCNScene(url: url, options: [
                .convertToYUp: true,
                .convertUnitsToMeters: 1.0
            ])

            // Centrar el contenido visible en el origen.
            let modelContainer = SCNNode()
            for child in scene.rootNode.childNodes {
                modelContainer.addChildNode(child)
            }
            scene.rootNode.addChildNode(modelContainer)

            let (minVec, maxVec) = modelContainer.boundingBox
            let size = SCNVector3(
                maxVec.x - minVec.x,
                maxVec.y - minVec.y,
                maxVec.z - minVec.z
            )
            let center = SCNVector3(
                (maxVec.x + minVec.x) / 2,
                (maxVec.y + minVec.y) / 2,
                (maxVec.z + minVec.z) / 2
            )
            modelContainer.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

            // Normalizar escala para que siempre quepa en viewport.
            let maxDimension = max(size.x, size.y, size.z)
            let targetSize: Float = 1.0
            let scale: Float = maxDimension > 0 ? targetSize / Float(maxDimension) : 1.0
            modelContainer.scale = SCNVector3(scale, scale, scale)

            // Cámara con encuadre automático.
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 45
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 2.2)
            scene.rootNode.addChildNode(cameraNode)
            scnView.pointOfView = cameraNode

            // Iluminación adicional para acentuar relieves de la malla.
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 1200
            keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1)
            keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .directional
            fillLight.light?.intensity = 500
            fillLight.light?.color = UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1)
            fillLight.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 3, 0)
            scene.rootNode.addChildNode(fillLight)

            scnView.scene = scene
        } catch {
            print("[Scene3DViewer] Error cargando USDZ: \(error)")
        }
    }
}

#Preview {
    SavedScanViewerView(storage: .shared)
}
