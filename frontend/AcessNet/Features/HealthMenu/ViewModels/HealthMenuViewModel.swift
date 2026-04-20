//
//  HealthMenuViewModel.swift
//  AcessNet
//
//  VM del menú tipo Cure (MGS3). Mantiene el estado de salud del cuerpo,
//  la lista de tratamientos recomendados y el estado de carga del SDK.
//
//  Se usa la macro `@Observable` (iOS 17+) para alinearse con el resto
//  de coordinators modernos del proyecto (ObjectCaptureCoordinator).
//

import SwiftUI
import Observation

@MainActor
@Observable
final class HealthMenuViewModel {

    // MARK: - State

    var bodyState: BodyHealthState = .cdmxHighPollutionMock
    var treatments: [Treatment] = Treatment.cdmxHighPollutionMocks
    var isModelReady: Bool = false
    var loadError: String?

    /// Órgano actualmente seleccionado (para abrir el sheet de detalle).
    var selectedOrgan: BodyHealthState.Organ?

    // MARK: - AQI mock header

    // TODO: conectar con API real de calidad del aire (IQAir / SEDEMA / OpenWeather)
    let currentAQIBadge = AQIBadge(
        location: "CDMX",
        pollutant: "PM2.5",
        level: "ALTO",
        aqi: 168
    )

    struct AQIBadge: Equatable {
        let location: String
        let pollutant: String
        let level: String
        let aqi: Int

        var tint: Color {
            switch aqi {
            case ..<51:   return Color(hex: "#4ADE80")
            case ..<101:  return Color(hex: "#F4B942")
            case ..<151:  return Color(hex: "#FF8A3D")
            case ..<201:  return Color(hex: "#FF5B5B")
            default:      return Color(hex: "#8B5CF6")
            }
        }
    }

    // MARK: - SDK callbacks

    func handleModelReady() {
        isModelReady = true
        loadError = nil
    }

    /// Error duro: el modelo no puede renderizar. `isModelReady` queda en false
    /// y la UI muestra el estado de error bloqueante.
    func handleLoadError(_ message: String) {
        isModelReady = false
        loadError = message
    }

    /// Warning informativo: el USDZ preferido no se encontró pero un modelo
    /// de respaldo sí está renderizando. No bloquea la UI.
    func handleFallbackNotice(_ message: String) {
        isModelReady = true
        loadError = message
    }

    func didSelectOrgan(_ organ: BodyHealthState.Organ) {
        HapticFeedback.light()
        selectedOrgan = organ
    }

    /// El SDK reporta un object ID crudo cuando el usuario toca el modelo.
    /// Lo traducimos al órgano conocido (si hay match) y abrimos el sheet.
    func didPickObject(_ objectId: String) {
        guard let organ = BioDigitalOrganMapper.organ(forObjectId: objectId) else {
            // Objeto no mapeado: log + ignorar. Útil para descubrir IDs reales.
            print("🩺 BioDigital objectPicked (no mapeado): \(objectId)")
            return
        }
        didSelectOrgan(organ)
    }

    func didTapTreatment(_ treatment: Treatment) {
        // TODO: integrar notificaciones push / deep link a detalle del tratamiento
        print("🩺 tapped treatment: \(treatment.title)")
    }

    func dismissOrganDetail() {
        selectedOrgan = nil
    }

    // MARK: - Retry

    func retryLoad() {
        loadError = nil
        isModelReady = false
    }
}
