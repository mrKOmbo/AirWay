//
//  EnvironmentalCondition.swift
//  AcessNet
//
//  Condiciones ambientales / hábitos que impactan un órgano concreto.
//  El motor real de daño se conectará en iteración futura (ver TODOs).
//

import Foundation

enum EnvironmentalCondition: String, Equatable, Hashable, CaseIterable, Codable, Identifiable {
    case pm25Exposure
    case smokingDamage
    case no2Exposure
    case o3Exposure
    case migraine
    case rhinitis
    case bronchialIrritation

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .pm25Exposure:         return String(localized: "Exposición a PM2.5")
        case .smokingDamage:        return String(localized: "Daño por tabaquismo")
        case .no2Exposure:          return String(localized: "Exposición a NO₂")
        case .o3Exposure:           return String(localized: "Exposición a O₃")
        case .migraine:             return String(localized: "Migraña")
        case .rhinitis:             return String(localized: "Rinitis alérgica")
        case .bronchialIrritation:  return String(localized: "Irritación bronquial")
        }
    }

    var iconSystemName: String {
        switch self {
        case .pm25Exposure:         return "aqi.medium"
        case .smokingDamage:        return "smoke.fill"
        case .no2Exposure:          return "car.fill"
        case .o3Exposure:           return "sun.max.trianglebadge.exclamationmark"
        case .migraine:             return "brain.head.profile"
        case .rhinitis:             return "nose"
        case .bronchialIrritation:  return "lungs.fill"
        }
    }
}
