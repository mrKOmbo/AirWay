//
//  AppConfig.swift
//  AcessNet
//
//  Configuración global compartida (base URL backend, flags).
//

import Foundation

enum AppConfig {
    /// URL base del backend AirWay (sin trailing slash, sin /api/v1).
    /// Sobrescribible con env var AIRWAY_API_BASE_URL.
    ///
    /// Coincide con el resto de services (AirQualityAPIService, ContingencyService, etc.)
    /// que apuntan a Render en https://airway-api.onrender.com
    static var backendBaseURL: URL {
        if let env = ProcessInfo.processInfo.environment["AIRWAY_API_BASE_URL"],
           let u = URL(string: env) {
            return u
        }
        // Production Render — mismo backend que los demás services del app
        return URL(string: "https://airway-api.onrender.com")!
    }
}
