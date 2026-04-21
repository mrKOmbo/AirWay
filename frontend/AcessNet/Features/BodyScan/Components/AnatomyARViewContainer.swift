//
//  AnatomyARViewContainer.swift
//  AcessNet
//
//  Puente SwiftUI ↔ UIKit para el ARView del modo Anatomy.
//
//  Crea el ARView, instancia el AnatomyARCoordinator y le inyecta el viewModel
//  para que pueda publicar estado hacia SwiftUI. Fase 3 implementa el coordinator.
//

import SwiftUI
import ARKit
import RealityKit

struct AnatomyARViewContainer: UIViewRepresentable {

    @ObservedObject var viewModel: AnatomyViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )

        // El coordinator se retiene en el Coordinator de SwiftUI para que no
        // muera con cada recomposición.
        context.coordinator.attach(arView: arView, viewModel: viewModel)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // El coordinator lee el viewModel por referencia, nada que hacer aquí.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // Wrapper que retiene el AnatomyARCoordinator (el de ARKit).
    final class Coordinator {
        private var arCoordinator: AnatomyARCoordinator?

        func attach(arView: ARView, viewModel: AnatomyViewModel) {
            guard arCoordinator == nil else { return }
            arCoordinator = AnatomyARCoordinator(arView: arView, viewModel: viewModel)
        }
    }
}
