//
//  EnhancedTabBar.swift
//  AcessNet
//
//  Tab bar premium con glassmorphism, pill indicator animado y micro-interacciones
//

import SwiftUI

// MARK: - Tab Theme

enum TabTheme {
    case home
    case map
    case health
    case settings

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "map.fill"
        case .health: return "heart.text.clipboard.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .map: return "Map"
        case .health: return "PPI"
        case .settings: return "Settings"
        }
    }

    var iconColor: LinearGradient {
        // Iconos negros cuando seleccionados
        return LinearGradient(
            colors: [.black.opacity(0.9), .black.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var iconColorInactive: LinearGradient {
        // Iconos negros semi-transparentes cuando no seleccionados
        return LinearGradient(
            colors: [.black.opacity(0.5), .black.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var glowColor: Color {
        // Todos los tabs usan azul para el glow
        return .blue
    }

    var pillGradient: LinearGradient {
        // Pill indicator con azul más intenso para mejor contraste
        return LinearGradient(
            colors: [
                Color.blue.opacity(0.4),  // Aumentado de 0.3
                Color.cyan.opacity(0.3)   // Aumentado de 0.2
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Enhanced Tab Bar

struct EnhancedTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Namespace private var namespace

    let tabs: [MainTabView.Tab] = [.home, .map, .health, .settings]

    var currentTheme: TabTheme {
        switch selectedTab {
        case .home: return .home
        case .map: return .map
        case .health: return .health
        case .settings: return .settings
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.self) { tab in
                EnhancedTabButton(
                    theme: themeForTab(tab),
                    isSelected: selectedTab == tab,
                    namespace: namespace
                ) {
                    selectTab(tab)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(liquidGlassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // Sombras multicapa para efecto flotante líquido
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -10)      // Principal difusa
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -4)        // Media para profundidad
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)        // Sutil cercana
        .shadow(color: .white.opacity(0.05), radius: 1, x: 0, y: -1)        // Glow superior
    }

    private var liquidGlassBackground: some View {
        ZStack {
            // CAPA 1: Gradiente radial azul a blanco
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.6),
                            Color.white.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )

            // CAPA 2: Material secundario para profundidad de vidrio
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.6)

            // CAPA 3: Gradiente de refracción azul
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.blue.opacity(0.15),
                            Color.white.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )

            // CAPA 4: Shimmer overlay
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 150
                    )
                )

            // CAPA 5: Glass overlay mejorado
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.2),
                            .white.opacity(0.08),
                            .white.opacity(0.15)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0),
                        endPoint: UnitPoint(x: 1, y: 1)
                    )
                )

            // CAPA 6: Inner glow
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .white.opacity(0.4),
                            .white.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .blur(radius: 1)

            // CAPA 7: Glossy border brillante
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.9),
                            .white.opacity(0.3),
                            .white.opacity(0.6),
                            .white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .compositingGroup()  // Optimización SwiftUI nativa
        .drawingGroup()      // Mejor performance para múltiples capas
    }

    private func themeForTab(_ tab: MainTabView.Tab) -> TabTheme {
        switch tab {
        case .home: return .home
        case .map: return .map
        case .health: return .health
        case .settings: return .settings
        }
    }

    private func selectTab(_ tab: MainTabView.Tab) {
        guard selectedTab != tab else { return }

        // Haptic feedback
        HapticFeedback.light()

        // Animate tab change
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedTab = tab
        }
    }
}

// MARK: - Enhanced Tab Button

struct EnhancedTabButton: View {
    let theme: TabTheme
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Press animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            ZStack {
                // Pill indicator (background) - mejorado para mejor contraste
                if isSelected {
                    Capsule()
                        .fill(theme.pillGradient)
                        .matchedGeometryEffect(id: "pill", in: namespace)
                        .frame(height: 56)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    theme.glowColor.opacity(0.5),  // Aumentado de 0.3 a 0.5
                                    lineWidth: 1.5                 // Aumentado de 1 a 1.5
                                )
                        )
                        .shadow(color: theme.glowColor.opacity(0.5), radius: 12, x: 0, y: 6)  // Más intenso
                }

                // Icon - ahora con colores negros
                VStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ?
                            theme.iconColor :        // Negro cuando seleccionado
                            theme.iconColorInactive  // Negro semi-transparente cuando no
                        )
                        .scaleEffect(isPressed ? 0.9 : (isSelected ? 1.15 : 1.0))
                        .rotationEffect(.degrees(isPressed ? 3 : 0))
                        .shadow(
                            color: isSelected ? .black.opacity(0.3) : .black.opacity(0.15),
                            radius: isSelected ? 3 : 2,
                            x: 0,
                            y: 1
                        )

                    // Optional title - también negro
                    if isSelected {
                        Text(theme.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.iconColor)  // Negro en lugar de gradient azul
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(theme.title)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("Enhanced Tab Bar") {
    struct PreviewWrapper: View {
        @State private var selectedTab: MainTabView.Tab = .home

        var body: some View {
            ZStack {
                // Background gradient simulado
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    Text("Selected: \(String(describing: selectedTab))")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    EnhancedTabBar(selectedTab: $selectedTab)
                }
            }
        }
    }

    return PreviewWrapper()
}
