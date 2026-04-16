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
        case .health: return "Health"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Enhanced Tab Bar

struct EnhancedTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Namespace private var namespace
    @State private var showLabel = false

    let tabs: [MainTabView.Tab] = [.home, .map, .health, .settings]

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
                                .foregroundColor(.white)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else {
                            // Mostrar solo el icono
                            Image(systemName: theme.icon)
                                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .frame(width: isSelected && showLabel ? 60 : 40, height: 36)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(.white.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
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
                .fill(.black.opacity(0.5))
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
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    private func themeForTab(_ tab: MainTabView.Tab) -> TabTheme {
        switch tab {
        case .home: return .home
        case .map: return .map
        case .health: return .health
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
