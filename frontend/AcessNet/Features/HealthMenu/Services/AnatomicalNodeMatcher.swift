//
//  AnatomicalNodeMatcher.swift
//  AcessNet
//
//  Traduce el nombre de un `SCNNode` a un órgano conocido de BodyHealthState
//  usando patrones *contains* case-insensitive. Diseñado para tolerar
//  convenciones de nombres distintas entre assets USDZ (ej: "lung-L",
//  "Lungs_Right", "respiratory_system-trachea", "Brain_cerebrum").
//
//  Si un asset tiene nombres muy distintos, extiende la lista de patrones por
//  órgano. Los patrones se evalúan en orden: el primero que haga match gana.
//

import Foundation

enum AnatomicalNodeMatcher {

    /// Patrones por órgano. Cada string se busca con `contains` case-insensitive.
    private static let patterns: [(BodyHealthState.Organ, [String])] = [
        // Orden importa: patrones más específicos primero.
        (.brain,  ["brain", "cerebrum", "cerebellum", "cerebro"]),
        (.lungs,  ["lung", "pulmon", "respiratory", "bronch", "alveol"]),
        (.heart,  ["heart", "cardiac", "corazon", "coraz", "cardiovascular"]),
        (.throat, ["trachea", "larynx", "pharynx", "throat", "traquea", "laringe", "faringe"]),
        (.nose,   ["nose", "nasal", "sinus", "nariz"]),
        (.skin,   ["skin", "integumentary", "piel", "epiderm"])
    ]

    /// Devuelve el órgano asociado al nodo o `nil` si no hay match.
    static func organ(forNodeName nodeName: String) -> BodyHealthState.Organ? {
        let lower = nodeName.lowercased()
        for (organ, keywords) in patterns {
            if keywords.contains(where: { lower.contains($0) }) {
                return organ
            }
        }
        return nil
    }
}
