//
//  Treatment.swift
//  AcessNet
//
//  Recomendación accionable tipo "Cure Menu" de MGS3. Cada tratamiento está
//  ligado a un órgano y al condición ambiental que ataca.
//

import Foundation

struct Treatment: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let iconSystemName: String
    let priority: Int

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        iconSystemName: String,
        priority: Int
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.priority = priority
    }

    /// Recomendaciones mock para CDMX con PM2.5 alto. Se reemplazan cuando
    /// se enchufe el motor de recomendaciones real.
    // TODO: generar dinámicamente desde el motor de recomendaciones
    static let cdmxHighPollutionMocks: [Treatment] = [
        Treatment(
            title: String(localized: "Usa cubrebocas N95"),
            subtitle: String(localized: "Reduce exposición PM2.5 al 95%"),
            iconSystemName: "facemask.fill",
            priority: 1
        ),
        Treatment(
            title: String(localized: "Evita ejercicio al aire libre"),
            subtitle: String(localized: "Hasta las 19:00 hrs"),
            iconSystemName: "figure.run.circle.fill",
            priority: 2
        ),
        Treatment(
            title: String(localized: "Hidrátate (2L hoy)"),
            subtitle: String(localized: "Ayuda a filtrar toxinas"),
            iconSystemName: "drop.fill",
            priority: 3
        )
    ]
}
