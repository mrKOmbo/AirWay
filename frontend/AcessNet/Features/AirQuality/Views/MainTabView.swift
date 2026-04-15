//
//  MainTabView.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showBusinessPulse = false

    enum Tab {
        case home
        case map
        case health
        case settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content con transiciones fluidas
            Group {
                switch selectedTab {
                case .home:
                    AQIHomeView(showBusinessPulse: $showBusinessPulse)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(Tab.home)
                case .map:
                    ContentView(showBusinessPulse: $showBusinessPulse)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(Tab.map)
                case .health:
                    PPIDashboardView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(Tab.health)
                case .settings:
                    SettingsView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(Tab.settings)
                }
            }
            .ignoresSafeArea()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)

            // Enhanced Tab Bar Premium
            EnhancedTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
