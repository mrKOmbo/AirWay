//
//  BioDigitalConfig.swift
//  AcessNet
//
//  Lectura segura de credenciales del SDK BioDigital HumanKit.
//  La API key se inyecta desde Secrets.xcconfig → Info.plist.
//
//  Flujo de setup (una vez, manual):
//    1. Obtener key en https://developer.biodigital.com
//    2. Copiar Secrets.example.xcconfig a Secrets.xcconfig
//    3. Rellenar BIODIGITAL_API_KEY / BIODIGITAL_API_SECRET
//    4. En Xcode → Project → Info → Configurations, enlazar el xcconfig
//    5. Añadir al Info.plist las llaves:
//         BIODIGITAL_API_KEY  = $(BIODIGITAL_API_KEY)
//         BIODIGITAL_API_SECRET = $(BIODIGITAL_API_SECRET)
//

import Foundation

enum BioDigitalConfig {

    enum ConfigError: Error, LocalizedError {
        case missingAPIKey
        case missingAPISecret

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Falta BIODIGITAL_API_KEY en Info.plist. Revisa Secrets.xcconfig."
            case .missingAPISecret:
                return "Falta BIODIGITAL_API_SECRET en Info.plist. Revisa Secrets.xcconfig."
            }
        }
    }

    /// API key del SDK. En DEBUG hace crash para detectar el problema temprano;
    /// en RELEASE devuelve `nil` para que la UI muestre estado de error sin
    /// tumbar la app.
    static var apiKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BIODIGITAL_API_KEY") as? String,
              !raw.isEmpty,
              raw != "your_key_here" else {
            #if DEBUG
            assertionFailure(ConfigError.missingAPIKey.localizedDescription)
            #endif
            return nil
        }
        return raw
    }

    static var apiSecret: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BIODIGITAL_API_SECRET") as? String,
              !raw.isEmpty,
              raw != "your_secret_here" else {
            #if DEBUG
            assertionFailure(ConfigError.missingAPISecret.localizedDescription)
            #endif
            return nil
        }
        return raw
    }

    /// `true` cuando ambas credenciales están disponibles y el SDK puede inicializarse.
    static var isConfigured: Bool {
        apiKey != nil && apiSecret != nil
    }

    /// Modelo por defecto a cargar. Flu carga el sistema respiratorio, ideal
    /// para contexto de calidad del aire.
    // TODO: permitir override por usuario / por estado de salud
    static let defaultModelId = "production/maleAdult/flu.json"
}
