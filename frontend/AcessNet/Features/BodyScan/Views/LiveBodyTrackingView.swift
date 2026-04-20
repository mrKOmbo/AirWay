//
//  LiveBodyTrackingView.swift
//  AcessNet
//
//  Tracking continuo del cuerpo con overlay stick-figure de 34 joints.
//

import SwiftUI
import ARKit
import RealityKit

struct LiveBodyTrackingView: View {
    @StateObject private var viewModel = BodyTrackingViewModel()
    @State private var viewSize: CGSize = .zero

    var body: some View {
        ZStack {
            if viewModel.isDeviceSupported {
                BodyARContainer(viewModel: viewModel)
                    .ignoresSafeArea()

                SkeletonOverlay(joints: viewModel.trackedJointsScreen)
                    .ignoresSafeArea()

                VStack {
                    topBar
                    Spacer()
                    if viewModel.isTracking {
                        bottomPanel
                            .padding(.bottom, 190)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        searchingHint
                            .padding(.bottom, 190)
                    }
                }
            } else {
                unsupportedState
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in viewSize = newSize }
            }
        )
        .preferredColorScheme(.dark)
        .onDisappear { viewModel.stopSession() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: viewModel.poseQuality.color))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )

            Text(viewModel.poseQuality.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(viewModel.trackedJointsScreen.count) / 34")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.35))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 110)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                metricCell(icon: "figure",
                           title: "Altura est.",
                           value: heightText)
                Divider()
                    .frame(height: 34)
                    .overlay(Color.white.opacity(0.1))
                metricCell(icon: "waveform.path.ecg",
                           title: "Pose",
                           value: viewModel.poseQuality.label)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )

            Text("Mantén el cuerpo completo visible en cámara para mejor tracking")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.4))
                )
        }
        .padding(.horizontal, 20)
    }

    private func metricCell(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#7DD3FC"))
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(Color(hex: "#7DD3FC").opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
        }
    }

    private var heightText: String {
        guard let h = viewModel.estimatedHeight else { return "—" }
        return String(format: "%.2f m", h)
    }

    // MARK: - Searching / Unsupported

    private var searchingHint: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text("Apunta la cámara a una persona")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text("Se requiere cuerpo completo en el encuadre")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 40)
    }

    private var unsupportedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)
            Text("Dispositivo no compatible")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Body tracking requiere iPhone/iPad con chip A12 Bionic o superior.")
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
}

// MARK: - AR Container

private struct BodyARContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BodyTrackingViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        viewModel.startSession(on: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        viewModel.updateViewBounds(uiView.bounds.size)
    }
}

#Preview {
    LiveBodyTrackingView()
}
