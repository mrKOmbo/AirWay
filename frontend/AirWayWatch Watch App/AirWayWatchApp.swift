//
//  AirWayWatchApp.swift
//  AirWayWatch Watch App
//
//  Entry point for the AirWay watchOS app.
//  Initializes HealthKit authorization on launch.
//

import SwiftUI

@main
struct AirWayWatch_Watch_AppApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    healthKitManager.requestAuthorization()
                }
        }
    }
}
