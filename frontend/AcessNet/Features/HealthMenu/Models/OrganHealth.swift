//
//  OrganHealth.swift
//  AcessNet
//
//  Estado de salud de un órgano concreto. `damageLevel` va de 0.0 (sano)
//  a 1.0 (daño máximo). Se usa para colorear el modelo 3D de BioDigital
//  y para renderizar las barras de progreso en el detalle.
//

import Foundation
import SwiftUI

struct OrganHealth: Equatable, Hashable, Codable {
    var damageLevel: Double
    var activeConditions: [EnvironmentalCondition]

    init(damageLevel: Double, activeConditions: [EnvironmentalCondition] = []) {
        self.damageLevel = min(max(damageLevel, 0.0), 1.0)
        self.activeConditions = activeConditions
    }

    var severity: Severity {
        switch damageLevel {
        case ..<0.20:  return .healthy
        case ..<0.40:  return .mild
        case ..<0.65:  return .moderate
        default:       return .severe
        }
    }

    enum Severity: Equatable, Hashable {
        case healthy
        case mild
        case moderate
        case severe

        var label: String {
            switch self {
            case .healthy:  return String(localized: "Sano")
            case .mild:     return String(localized: "Leve")
            case .moderate: return String(localized: "Moderado")
            case .severe:   return String(localized: "Crítico")
            }
        }

        /// Paleta verde → amarillo → naranja → rojo.
        var tint: Color {
            switch self {
            case .healthy:  return Color(hex: "#4ADE80")
            case .mild:     return Color(hex: "#F4B942")
            case .moderate: return Color(hex: "#FF8A3D")
            case .severe:   return Color(hex: "#FF5B5B")
            }
        }
    }
}
