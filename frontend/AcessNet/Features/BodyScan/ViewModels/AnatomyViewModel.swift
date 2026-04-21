//
//  AnatomyViewModel.swift
//  AcessNet
//
//  ViewModel del modo Anatomy AR.
//
//  Publica al SwiftUI view el estado del tracking, la altura del sujeto y los
//  damage levels por órgano. El coordinator (ARSessionDelegate + Vision) mantiene
//  este objeto actualizado desde el main thread.
//

import Foundation
import Combine

@MainActor
final class AnatomyViewModel: ObservableObject {

    // MARK: - Tracking state

    enum State {
        case searching
        case tracking
        case lost

        var label: String {
            switch self {
            case .searching: return "Buscando cuerpo…"
            case .tracking:  return "Tracking óptimo"
            case .lost:      return "Perdido"
            }
        }

        var indicatorColor: String {
            switch self {
            case .searching: return "#F4B942"
            case .tracking:  return "#4ADE80"
            case .lost:      return "#FF5B5B"
            }
        }
    }

    @Published var state: State = .searching
    @Published var bodyHeight: Float = 1.70
    @Published var trackingConfidence: Float = 0
    @Published var visionFps: Double = 0

    // MARK: - Damage levels (0..1)

    @Published var lungDamage: Float = 0
    @Published var heartDamage: Float = 0
    @Published var brainDamage: Float = 0
    @Published var liverDamage: Float = 0
    @Published var kidneyDamage: Float = 0

    // MARK: - Debug

    /// Slider debug (AQI) que el coordinator alimenta al ExposureAccumulator.
    @Published var debugAQI: Double = 0

    /// Mostrar / ocultar slider debug en la UI.
    @Published var showDebugControls: Bool = true
}
