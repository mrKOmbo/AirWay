//
//  MainTabView.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab: Tab = .home
    @State private var showBusinessPulse = false

    enum Tab {
        case home
        case map
        case fuel
        case health
        case settings
    }

    private var activeWeather: WeatherCondition {
        appSettings.weatherOverride ?? .overcast
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Base background — prevents white flash
            Color(hex: "#0A0A0F")
                .ignoresSafeArea()

            // Content
            Group {
                switch selectedTab {
                case .home:
                    AQIHomeView(showBusinessPulse: $showBusinessPulse)
                        .id(Tab.home)
                case .map:
                    ContentView(showBusinessPulse: $showBusinessPulse)
                        .id(Tab.map)
                case .fuel:
                    GasolinaMeterHubView()
                        .id(Tab.fuel)
                case .health:
                    PPIDashboardView()
                        .id(Tab.health)
                case .settings:
                    SettingsView()
                        .id(Tab.settings)
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)

            // Enhanced Tab Bar Premium
            EnhancedTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
        .environment(\.weatherTheme, WeatherTheme(condition: activeWeather))
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
