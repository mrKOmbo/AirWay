//
//  EnhancedTabBar.swift
//  AcessNet
//
//  Tab bar compacto tipo píldora transparente con iconos animados
//

import SwiftUI

// MARK: - Tab Theme

enum TabTheme {
    case home
    case map
    case fuel
    case health
    case body
    case settings

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "map.fill"
        case .fuel: return "fuelpump.fill"
        case .health: return "heart.text.clipboard.fill"
        case .body: return "figure.arms.open"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .map: return "Map"
        case .fuel: return "Fuel"
        case .health: return "Health"
        case .body: return "Body"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Enhanced Tab Bar

struct EnhancedTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(\.weatherTheme) private var theme
    @Namespace private var namespace
    @State private var showLabel = false

    let tabs: [MainTabView.Tab] = [.home, .map, .fuel, .health, .body, .settings]

    // MARK: - Colores adaptativos (AirWay light vs. temas de clima oscuros)
    private var iconActiveColor: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D") : .white
    }
    private var iconInactiveColor: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D").opacity(0.45) : .white.opacity(0.4)
    }
    private var pillFill: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D").opacity(0.08) : .white.opacity(0.12)
    }
    private var pillStroke: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D").opacity(0.12) : .white.opacity(0.1)
    }
    private var barFill: Color {
        theme.isAirWay ? .white.opacity(0.7) : .black.opacity(0.5)
    }
    private var barStroke: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D").opacity(0.08) : .white.opacity(0.08)
    }
    private var barShadow: Color {
        theme.isAirWay ? Color(hex: "#0A1D4D").opacity(0.12) : .black.opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                let theme = themeForTab(tab)
                let isSelected = selectedTab == tab

                Button {
                    guard selectedTab != tab else { return }
                    HapticFeedback.light()

                    // 1. Cambiar tab + mostrar label
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                        showLabel = true
                    }

                    // 2. Después de 0.8s, ocultar label y volver a icono
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showLabel = false
                        }
                    }
                } label: {
                    ZStack {
                        if isSelected && showLabel {
                            // Mostrar solo el nombre
                            Text(theme.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(iconActiveColor)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else {
                            // Mostrar solo el icono
                            Image(systemName: theme.icon)
                                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? iconActiveColor : iconInactiveColor)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .frame(width: isSelected && showLabel ? 60 : 40, height: 36)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(pillFill)
                                .overlay(
                                    Capsule()
                                        .stroke(pillStroke, lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "pill", in: namespace)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(theme.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(barFill)
                .overlay(
                    Capsule()
                        .stroke(barStroke, lineWidth: 1)
                )
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .shadow(color: barShadow, radius: 16, x: 0, y: 8)
    }

    private func themeForTab(_ tab: MainTabView.Tab) -> TabTheme {
        switch tab {
        case .home: return .home
        case .map: return .map
        case .fuel: return .fuel
        case .health: return .health
        case .body: return .body
        case .settings: return .settings
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Tab Bar") {
    struct PreviewWrapper: View {
        @State private var selectedTab: MainTabView.Tab = .home

        var body: some View {
            ZStack {
                Color(hex: "#0A0A0F").ignoresSafeArea()

                VStack {
                    Spacer()
                    EnhancedTabBar(selectedTab: $selectedTab)
                }
            }
        }
    }

    return PreviewWrapper()
}
