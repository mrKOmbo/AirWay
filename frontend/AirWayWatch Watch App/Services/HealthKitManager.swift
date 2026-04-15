//
//  HealthKitManager.swift
//  AirWayWatch Watch App
//
//  Gestión de permisos y autorización de HealthKit.
//  Punto de entrada para toda la interacción con datos de salud.
//

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // Types we need to read for PPI Score
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .restingHeartRate,
        ]
        for id in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        return types
    }()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.authorizationError = "HealthKit not available on this device"
            }
            return
        }

        PPILog.health.notice("Requesting authorization for \(self.readTypes.count) types...")
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if let error = error {
                    self.authorizationError = error.localizedDescription
                    PPILog.health.notice(" Authorization error: \(error.localizedDescription)")
                } else {
                    PPILog.health.notice(" Authorization dialog shown. success=\(success)")
                }
            }
        }
    }

    // MARK: - Availability Checks

    var isHeartRateAvailable: Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return false }
        return healthStore.authorizationStatus(for: type) != .notDetermined
    }

    var isHRVAvailable: Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return false }
        return healthStore.authorizationStatus(for: type) != .notDetermined
    }

    var isSpO2Available: Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return false }
        return healthStore.authorizationStatus(for: type) != .notDetermined
    }

    var isRespiratoryRateAvailable: Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return false }
        return healthStore.authorizationStatus(for: type) != .notDetermined
    }
}
