//
//  VehicleProfileService.swift
//  AcessNet
//
//  Persistencia local de perfiles de vehículo (UserDefaults).
//  Gestiona múltiples autos (familiar, personal, Uber) y el perfil activo.
//

import Foundation
import Combine
import os

@MainActor
final class VehicleProfileService: ObservableObject {
    static let shared = VehicleProfileService()

    // MARK: - Published

    @Published private(set) var savedProfiles: [VehicleProfile] = []
    @Published var activeProfile: VehicleProfile? {
        didSet {
            if let p = activeProfile {
                UserDefaults.standard.set(p.id.uuidString, forKey: activeIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeIdKey)
            }
        }
    }

    // MARK: - Private

    private let storageKey = "airway.vehicle.profiles.v1"
    private let activeIdKey = "airway.vehicle.activeId.v1"

    // MARK: - Lifecycle

    private init() {
        load()
        // Auto-carga de vehículos demo si es la primera vez
        if savedProfiles.isEmpty {
            loadDemoVehicles()
        }
    }

    // MARK: - Public API

    func save(_ profile: VehicleProfile) {
        var updated = profile
        updated.updatedAt = Date()

        let isNew = !savedProfiles.contains(where: { $0.id == profile.id })
        if let idx = savedProfiles.firstIndex(where: { $0.id == profile.id }) {
            savedProfiles[idx] = updated
        } else {
            savedProfiles.append(updated)
        }
        activeProfile = updated
        persist()
        AirWayLogger.fuel.info(
            "VehicleProfile \(isNew ? "created" : "updated", privacy: .public): \(updated.fullDisplayName, privacy: .public) km/L=\(String(format: "%.1f", updated.conueeKmPerL), privacy: .public) style=\(String(format: "%.2f", updated.drivingStyle), privacy: .public)"
        )
    }

    func delete(_ profile: VehicleProfile) {
        savedProfiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            activeProfile = savedProfiles.first
        }
        persist()
        AirWayLogger.fuel.notice("VehicleProfile deleted: \(profile.fullDisplayName, privacy: .public)")
    }

    func setActive(_ profile: VehicleProfile) {
        guard savedProfiles.contains(where: { $0.id == profile.id }) else {
            AirWayLogger.fuel.warning("VehicleProfileService.setActive: profile not in saved list")
            return
        }
        activeProfile = profile
        AirWayLogger.fuel.info("VehicleProfile active: \(profile.fullDisplayName, privacy: .public)")
    }

    /// Actualiza `drivingStyle` con EMA al terminar un viaje (Fase 6).
    func updateDrivingStyle(for profileId: UUID, newStyleMultiplier: Double, alpha: Double = 0.15) {
        guard let idx = savedProfiles.firstIndex(where: { $0.id == profileId }) else {
            AirWayLogger.fuel.warning("updateDrivingStyle: profile \(profileId, privacy: .public) not found")
            return
        }
        let current = savedProfiles[idx].drivingStyle
        let clamped = max(0.85, min(newStyleMultiplier, 1.30))
        let updated = alpha * clamped + (1 - alpha) * current
        savedProfiles[idx].drivingStyle = updated
        savedProfiles[idx].updatedAt = Date()
        if activeProfile?.id == profileId {
            activeProfile = savedProfiles[idx]
        }
        persist()
        AirWayLogger.fuel.info(
            "drivingStyle EMA \(String(format: "%.3f", current), privacy: .public) → \(String(format: "%.3f", updated), privacy: .public) (input=\(String(format: "%.3f", clamped), privacy: .public), α=\(String(format: "%.2f", alpha), privacy: .public))"
        )
    }

    /// Carga los vehículos demo asociados a cada modelo 3D. Si ya existen, no los duplica.
    func loadDemoVehicles() {
        for asset in Vehicle3DAsset.allCases {
            let demo = asset.demoProfile
            let alreadyExists = savedProfiles.contains { p in
                p.make == demo.make && p.model == demo.model && p.year == demo.year
            }
            guard !alreadyExists else { continue }
            savedProfiles.append(demo)
        }
        if activeProfile == nil {
            activeProfile = savedProfiles.first
        }
        persist()
        AirWayLogger.fuel.info("VehicleProfile demo loaded (\(self.savedProfiles.count, privacy: .public) total)")
    }

    /// Actualiza el odómetro (p.ej. detectado por Gemini Vision).
    func updateOdometer(for profileId: UUID, km: Int) {
        guard let idx = savedProfiles.firstIndex(where: { $0.id == profileId }) else { return }
        savedProfiles[idx].odometerKm = km
        savedProfiles[idx].updatedAt = Date()
        if activeProfile?.id == profileId {
            activeProfile = savedProfiles[idx]
        }
        persist()
        AirWayLogger.fuel.info("Odometer updated: \(km, privacy: .public) km")
    }

    // MARK: - Private

    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedProfiles)
            UserDefaults.standard.set(data, forKey: storageKey)
            AirWayLogger.fuel.debug("VehicleProfileService persisted \(self.savedProfiles.count) profiles (\(data.count) bytes)")
        } catch {
            AirWayLogger.fuel.error("VehicleProfileService persist error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([VehicleProfile].self, from: data)
        else {
            AirWayLogger.fuel.debug("VehicleProfileService: no saved profiles on disk")
            return
        }

        savedProfiles = list
        if let activeIdString = UserDefaults.standard.string(forKey: activeIdKey),
           let activeId = UUID(uuidString: activeIdString),
           let match = list.first(where: { $0.id == activeId }) {
            activeProfile = match
        } else {
            activeProfile = list.first
        }
        AirWayLogger.fuel.info(
            "VehicleProfileService loaded \(list.count) profiles, active=\(self.activeProfile?.fullDisplayName ?? "none", privacy: .public)"
        )
    }
}
