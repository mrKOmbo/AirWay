//
//  BodyScanHubView.swift
//  AcessNet
//
//  Vista principal de la tab BodyScan. Alterna entre 3 modos:
//   1. Tracking en vivo del esqueleto (34 joints)
//   2. Captura 3D con Object Capture (WWDC23)
//   3. Visor del escaneo guardado
//

import SwiftUI

struct BodyScanHubView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var storage = BodyScanStorage.shared
    @State private var scanCoordinator = ObjectCaptureCoordinator()
    @State private var selectedMode: Mode = .live
    @State private var showHealthMenu: Bool = false

    enum Mode: String, CaseIterable, Identifiable {
        case live, scan, saved
        var id: String { rawValue }

        var title: String {
            switch self {
            case .live: return "Live"
            case .scan: return "Escanear"
            case .saved: return "Modelo"
            }
        }

        var icon: String {
            switch self {
            case .live: return "figure.walk.motion"
            case .scan: return "cube.transparent"
            case .saved: return "arkit"
            }
        }
    }

    /// El chrome (header + mode selector) se oculta durante la captura/reconstrucción
    /// para que el usuario se enfoque en el viewfinder.
    private var hideChrome: Bool {
        selectedMode == .scan && scanCoordinator.isScanningActive
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            Group {
                switch selectedMode {
                case .live:
                    LiveBodyTrackingView()
                case .scan:
                    BodyMeshCaptureView(coordinator: scanCoordinator)
                case .saved:
                    SavedScanViewerView(storage: storage)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: selectedMode)

            VStack {
                if !hideChrome {
                    header
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if !hideChrome {
                    if selectedMode == .saved && storage.hasSavedScan {
                        healthMenuCTA
                            .padding(.horizontal, 28)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    modeSelector
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hideChrome)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedMode)
        }
        .fullScreenCover(isPresented: $showHealthMenu) {
            HealthMenuView()
        }
        .task(id: scanCoordinator.isCompleted) {
            // Navegar al modelo guardado cuando completa. Usamos `task(id:)`
            // en vez de `onChange(of: phase)` para evitar "tried to update
            // multiple times per frame" causado por los updates de progreso.
            if scanCoordinator.isCompleted && selectedMode == .scan {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedMode = .saved
                }
            }
        }
        .onDisappear {
            scanCoordinator.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body Scan")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "#7DD3FC")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("LiDAR · 34 joints · USDZ")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            Spacer()

            if storage.hasSavedScan {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green, .white.opacity(0.2))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 56)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0A0A0F"), Color(hex: "#0A0A0F").opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        )
    }

    // MARK: - Health menu CTA (solo modo .saved cuando hay escaneo)

    private var healthMenuCTA: some View {
        Button {
            HapticFeedback.light()
            showHealthMenu = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 16, weight: .semibold))
                Text("Ver estado de tu cuerpo")
                    .font(.system(size: 14, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.75)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF5B5B"), Color(hex: "#FF8A3D")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#FF5B5B").opacity(0.5),
                            radius: 16, x: 0, y: 8)
            )
        }
        .accessibilityLabel("Ver estado de tu cuerpo")
        .accessibilityHint("Abre el diagnóstico de salud ambiental sobre tu modelo")
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.black.opacity(0.45))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(Capsule())
        .padding(.horizontal, 40)
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private func modeButton(_ mode: Mode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            guard selectedMode != mode else { return }
            HapticFeedback.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .semibold))
                if isSelected {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .transition(.opacity)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(.white.opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BodyScanHubView()
        .environmentObject(AppSettings.shared)
}
