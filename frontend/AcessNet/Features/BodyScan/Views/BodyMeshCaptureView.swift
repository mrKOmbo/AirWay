//
//  BodyMeshCaptureView.swift
//  AcessNet
//
//  Captura 3D usando Apple Object Capture (WWDC23, iOS 17+).
//  Reemplaza el approach anterior de sceneReconstruction por la API moderna.
//
//  IMPORTANTE: Object Capture está diseñado para objetos estáticos. Para
//  escanear personas, deben quedarse perfectamente quietas durante la captura.
//

import SwiftUI
import RealityKit
import UIKit

struct BodyMeshCaptureView: View {

    /// El coordinator vive en el hub para que pueda reaccionar a la fase
    /// (p.ej. ocultar el menú durante la captura).
    let coordinator: ObjectCaptureCoordinator

    /// Durante captura/reconstrucción el action panel usa menos padding ya que
    /// el hub oculta el mode selector y el tab bar queda debajo.
    private var bottomPadding: CGFloat {
        coordinator.isScanningActive ? 60 : 190
    }

    private var topPadding: CGFloat {
        coordinator.isScanningActive ? 60 : 110
    }

    var body: some View {
        ZStack {
            if !ObjectCaptureCoordinator.isSupported {
                unsupportedState
            } else if let session = coordinator.session {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()

                VStack {
                    statusHeader
                        .padding(.top, topPadding)
                    Spacer()
                    actionPanel
                        .padding(.bottom, bottomPadding)
                }
                .animation(.easeInOut(duration: 0.3), value: coordinator.isScanningActive)
            } else {
                progressOverlay
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if coordinator.session == nil, !coordinator.isCompleted {
                coordinator.start()
            }
        }
    }

    // MARK: - Header de estado

    private var statusHeader: some View {
        HStack(spacing: 12) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(phaseSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
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

    @ViewBuilder
    private var statusIndicator: some View {
        let color = colorForPhase
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
            .shadow(color: color.opacity(0.6), radius: 6)
    }

    // MARK: - Botonera principal

    private var actionPanel: some View {
        VStack(spacing: 14) {
            instructions

            switch coordinator.phase {
            case .ready:
                primaryButton(title: "Detectar objeto",
                              icon: "viewfinder",
                              color: Color(hex: "#7DD3FC")) {
                    coordinator.startDetecting()
                }
            case .detecting:
                primaryButton(title: "Iniciar captura",
                              icon: "camera.aperture",
                              color: Color(hex: "#A78BFA")) {
                    coordinator.startCapturing()
                }
            case .capturing(let progress):
                captureControls(progress: progress)
            case .reconstructing(let progress):
                reconstructionProgress(fraction: progress)
            case .failed(let message):
                errorBanner(message)
            default:
                EmptyView()
            }
        }
    }

    private func primaryButton(title: String,
                               icon: String,
                               color: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(color.opacity(0.85))
                    .shadow(color: color.opacity(0.5), radius: 14, x: 0, y: 6)
            )
        }
        .padding(.horizontal, 28)
    }

    private func captureControls(progress: Double) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color(hex: "#A78BFA"))
                .padding(.horizontal, 28)

            HStack(spacing: 14) {
                Button {
                    coordinator.cancel()
                    coordinator.start()
                } label: {
                    Label("Reiniciar", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                        )
                }

                Button {
                    coordinator.finish()
                } label: {
                    Label("Finalizar", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#4ADE80").opacity(0.85))
                                .shadow(color: Color(hex: "#4ADE80").opacity(0.5),
                                        radius: 12, x: 0, y: 4)
                        )
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func reconstructionProgress(fraction: Double) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Procesando malla 3D…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Color(hex: "#7DD3FC"))
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 28)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                coordinator.cancel()
                coordinator.start()
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(hex: "#FF5B5B").opacity(0.85))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 28)
    }

    private var instructions: some View {
        Text(instructionText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.black.opacity(0.45))
                    .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
            )
    }

    // MARK: - Estados especiales

    private var progressOverlay: some View {
        Color.black.opacity(0.55).ignoresSafeArea()
            .overlay {
                if case .reconstructing(let f) = coordinator.phase {
                    reconstructionProgress(fraction: f)
                } else {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text(phaseTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
    }

    private var unsupportedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sensor.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)
            Text("Object Capture no disponible")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Requiere iPhone 12 Pro o superior con LiDAR e iOS 17+.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Phase mapping

    private var phaseTitle: String {
        switch coordinator.phase {
        case .preparing: return "Preparando…"
        case .ready: return "Coloca el objeto frente a ti"
        case .detecting: return "Bounding box detectada"
        case .capturing: return "Capturando imágenes"
        case .finishing: return "Finalizando captura"
        case .reconstructing: return "Reconstruyendo modelo 3D"
        case .completed: return "Modelo listo ✓"
        case .failed(let m): return "Error: \(m)"
        }
    }

    private var phaseSubtitle: String {
        switch coordinator.phase {
        case .preparing: return "Inicializando ObjectCaptureSession"
        case .ready: return "Mantén distancia de 30–80 cm"
        case .detecting: return "Ajusta la caja con el dial"
        case .capturing(let p): return "\(Int(p * 100))% de cobertura · rodea sin moverte rápido"
        case .finishing: return "Cerrando sesión"
        case .reconstructing(let p): return "\(Int(p * 100))% (puede tardar varios minutos)"
        case .completed: return "Guardado en almacenamiento"
        case .failed: return "Toca reintentar"
        }
    }

    private var instructionText: String {
        switch coordinator.phase {
        case .ready:
            return "Apunta a la persona quieta de cuerpo completo. Mantén buena iluminación."
        case .detecting:
            return "ARKit detectó la silueta. Toca para iniciar la captura automática."
        case .capturing:
            return "Rodea LENTAMENTE la persona. La persona debe quedarse inmóvil como estatua."
        case .reconstructing:
            return "PhotogrammetrySession está fusionando las imágenes. No cierres la app."
        default:
            return ""
        }
    }

    private var colorForPhase: Color {
        switch coordinator.phase {
        case .preparing: return Color(hex: "#F4B942")
        case .ready: return Color(hex: "#7DD3FC")
        case .detecting: return Color(hex: "#A78BFA")
        case .capturing: return Color(hex: "#4ADE80")
        case .finishing: return Color(hex: "#7DD3FC")
        case .reconstructing: return Color(hex: "#A78BFA")
        case .completed: return Color(hex: "#4ADE80")
        case .failed: return Color(hex: "#FF5B5B")
        }
    }
}

#Preview {
    BodyMeshCaptureView(coordinator: ObjectCaptureCoordinator())
}
