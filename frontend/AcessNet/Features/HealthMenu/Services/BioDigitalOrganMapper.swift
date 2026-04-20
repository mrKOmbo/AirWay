//
//  BioDigitalOrganMapper.swift
//  AcessNet
//
//  Traduce entre el modelo de dominio (BodyHealthState.Organ) y los object IDs
//  concretos del modelo 3D de BioDigital. También decide el color de highlight
//  según el damageLevel.
//
//  Los IDs reales se descubren tocando objetos en el SDK (se reciben vía
//  HKHumanDelegate.objectPicked). Por ahora usamos slugs placeholder; cuando
//  cargues el modelo la primera vez, loguea los object IDs reales y pégalos
//  aquí.
//

import SwiftUI

enum BioDigitalOrganMapper {

    /// Object IDs candidatos por órgano. Se intentará pintar TODOS (el SDK
    /// ignora silenciosamente los que no existen en el modelo cargado).
    // TODO: reemplazar por IDs reales del modelo flu.json una vez validados
    //       con el callback objectPicked.
    static func objectIds(for organ: BodyHealthState.Organ) -> [String] {
        switch organ {
        case .lungs:
            return [
                "lung-L", "lung-R",
                "lungs_left", "lungs_right",
                "respiratory_system-lungs"
            ]
        case .nose:
            return [
                "nose", "nasal_cavity",
                "respiratory_system-nose",
                "sinus-frontal", "sinus-maxillary"
            ]
        case .brain:
            return [
                "brain",
                "nervous_system-brain",
                "cerebrum", "cerebellum"
            ]
        case .throat:
            return [
                "trachea", "larynx", "pharynx",
                "respiratory_system-trachea"
            ]
        case .heart:
            return [
                "heart",
                "cardiovascular_system-heart"
            ]
        case .skin:
            return [
                "skin",
                "integumentary_system-skin"
            ]
        }
    }

    /// Mapeo inverso: dado un object ID recibido del SDK (vía objectPicked)
    /// devuelve el órgano asociado si lo reconocemos. Útil para abrir el sheet
    /// de detalle.
    static func organ(forObjectId objectId: String) -> BodyHealthState.Organ? {
        let lowered = objectId.lowercased()
        for organ in BodyHealthState.Organ.allCases {
            if objectIds(for: organ).contains(where: { lowered.contains($0.lowercased()) }) {
                return organ
            }
        }
        return nil
    }

    /// Color RGBA para pintar un órgano según su nivel de daño. Se traduce al
    /// tipo `HKColor` del SDK dentro del wrapper.
    static func highlightColor(for damageLevel: Double) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        let severity = OrganHealth(damageLevel: damageLevel).severity
        let color = severity.tint
        let components = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        let r = Double(components.count > 0 ? components[0] : 0)
        let g = Double(components.count > 1 ? components[1] : 0)
        let b = Double(components.count > 2 ? components[2] : 0)
        let a = Double(components.count > 3 ? components[3] : 0.65)
        return (r, g, b, a)
    }
}
