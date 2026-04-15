//
//  PPIHapticManager.swift
//  AirWayWatch Watch App
//
//  Manages haptic feedback for PPI zone transitions.
//  Different haptic patterns for worsening vs improving air quality impact.
//

import WatchKit

class PPIHapticManager {
    static let shared = PPIHapticManager()
    private let device = WKInterfaceDevice.current()
    private var lastAlertedZone: PPIZone = .green

    private init() {}

    func checkZoneTransition(from oldZone: PPIZone, to newZone: PPIZone) {
        guard oldZone != newZone else { return }
        lastAlertedZone = newZone

        if isWorsening(from: oldZone, to: newZone) {
            PPILog.haptic.notice(" WORSENING: \(oldZone.rawValue) -> \(newZone.rawValue)")
            playWorseningHaptic(zone: newZone)
        } else {
            PPILog.haptic.notice(" IMPROVING: \(oldZone.rawValue) -> \(newZone.rawValue)")
            playImprovingHaptic()
        }
    }

    private func isWorsening(from old: PPIZone, to new: PPIZone) -> Bool {
        let order: [PPIZone] = [.green, .yellow, .orange, .red]
        let oldIndex = order.firstIndex(of: old) ?? 0
        let newIndex = order.firstIndex(of: new) ?? 0
        return newIndex > oldIndex
    }

    private func playWorseningHaptic(zone: PPIZone) {
        switch zone {
        case .yellow:
            device.play(.notification)
        case .orange:
            device.play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.device.play(.directionDown)
            }
        case .red:
            device.play(.failure)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.device.play(.failure)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.device.play(.directionDown)
            }
        case .green:
            break
        }
    }

    private func playImprovingHaptic() {
        device.play(.success)
    }
}
