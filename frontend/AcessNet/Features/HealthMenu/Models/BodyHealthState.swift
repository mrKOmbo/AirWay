//
//  BodyHealthState.swift
//  AcessNet
//
//  Snapshot del estado de salud del cuerpo del usuario en un instante dado.
//  Por ahora se inicializa con mocks; en el futuro vendrá de un motor real
//  que consuma APIs de calidad del aire + HealthKit + hábitos registrados.
//

import Foundation

struct BodyHealthState: Equatable, Hashable, Codable {
    var lungs: OrganHealth
    var nose: OrganHealth
    var brain: OrganHealth
    var throat: OrganHealth
    var heart: OrganHealth
    var skin: OrganHealth

    enum Organ: String, CaseIterable, Identifiable {
        case lungs, nose, brain, throat, heart, skin
        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .lungs:  return String(localized: "Pulmones")
            case .nose:   return String(localized: "Nariz")
            case .brain:  return String(localized: "Cerebro")
            case .throat: return String(localized: "Garganta")
            case .heart:  return String(localized: "Corazón")
            case .skin:   return String(localized: "Piel")
            }
        }
    }

    func health(for organ: Organ) -> OrganHealth {
        switch organ {
        case .lungs:  return lungs
        case .nose:   return nose
        case .brain:  return brain
        case .throat: return throat
        case .heart:  return heart
        case .skin:   return skin
        }
    }

    /// Snapshot mock: CDMX con PM2.5 alto simulado. Reemplazar cuando se
    /// conecte el motor real de daño.
    // TODO: sustituir por motor real (APIs calidad del aire + HealthKit)
    static let cdmxHighPollutionMock = BodyHealthState(
        lungs: OrganHealth(damageLevel: 0.34, activeConditions: [.pm25Exposure, .no2Exposure]),
        nose: OrganHealth(damageLevel: 0.45, activeConditions: [.rhinitis]),
        brain: OrganHealth(damageLevel: 0.28, activeConditions: [.migraine]),
        throat: OrganHealth(damageLevel: 0.22, activeConditions: [.bronchialIrritation]),
        heart: OrganHealth(damageLevel: 0.15, activeConditions: []),
        skin: OrganHealth(damageLevel: 0.10, activeConditions: [])
    )
}
