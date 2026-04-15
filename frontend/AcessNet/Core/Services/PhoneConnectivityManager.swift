//
//  PhoneConnectivityManager.swift
//  AcessNet
//
//  Gestor de conectividad para comunicación bidireccional iPhone ↔ Apple Watch.
//  Envía: rutas, AQI updates, vulnerability profiles.
//  Recibe: biometric updates, PPI scores.
//

import Foundation
import WatchConnectivity
import Combine
import CoreLocation
import MapKit

class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    // MARK: - Published Properties
    @Published var isWatchConnected: Bool = false
    @Published var lastMessageSent: Date?

    // PPI data received from Watch
    @Published var latestPPIScore: PPIScoreData?
    @Published var latestBiometrics: BiometricUpdateData?
    @Published var latestCigaretteData: CigaretteData?

    // MARK: - Private Properties
    private var session: WCSession?

    // MARK: - Initialization
    private override init() {
        super.init()
        setupWatchConnectivity()
    }

    // MARK: - Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Route to Watch (existing functionality)

    func sendRouteToWatch(from scoredRoute: ScoredRoute, destinationName: String) {
        guard let session = session else { return }

        let coordinates = scoredRoute.routeInfo.route.polyline.coordinates()
        let watchCoordinates = coordinates.map { WatchCoordinate(from: $0) }

        let watchRoute = WatchRouteData(
            distanceFormatted: scoredRoute.routeInfo.distanceFormatted,
            timeFormatted: scoredRoute.routeInfo.timeFormatted,
            coordinates: watchCoordinates,
            averageAQI: Int(scoredRoute.averageAQI),
            qualityLevel: scoredRoute.averageAQILevel.rawValue,
            destinationName: destinationName,
            trafficIncidents: scoredRoute.incidentAnalysis?.trafficCount ?? 0,
            hazardIncidents: scoredRoute.incidentAnalysis?.hazardCount ?? 0,
            safetyScore: scoredRoute.incidentAnalysis?.safetyScore ?? 100.0
        )

        sendRoute(watchRoute, messageType: .routeCreated)
    }

    func clearRouteOnWatch() {
        let message = WatchMessage(type: .routeCleared)
        sendWatchMessage(message)
    }

    // MARK: - Send AQI Update to Watch

    func sendAQIUpdate(aqi: Int, pm25: Double, pm10: Double, no2: Double? = nil,
                       o3: Double? = nil, dominantPollutant: String? = nil,
                       location: String, qualityLevel: String, confidence: Double = 0) {
        let aqiData = AQIUpdateData(
            aqi: aqi,
            pm25: pm25,
            pm10: pm10,
            no2: no2,
            o3: o3,
            dominantPollutant: dominantPollutant,
            location: location,
            qualityLevel: qualityLevel,
            confidence: confidence,
            timestamp: Date()
        )

        let message = WatchMessage(type: .aqiUpdate, aqiData: aqiData)
        sendWatchMessage(message)
    }

    // MARK: - Send Vulnerability Profile to Watch

    func sendVulnerabilityProfile(_ profile: VulnerabilityProfile) {
        let message = WatchMessage(type: .vulnerabilitySync, vulnerabilityProfile: profile)
        sendWatchMessage(message)
    }

    // MARK: - Private Sending Methods

    private func sendRoute(_ route: WatchRouteData, messageType: WatchMessage.MessageType) {
        let message = WatchMessage(type: messageType, route: route)
        sendWatchMessage(message)
    }

    // MARK: - Send PPI Score to Watch (for background transfer)

    private func sendWatchMessage(_ message: WatchMessage) {
        guard let session = session else { return }

        do {
            let data = try JSONEncoder().encode(message)
            let dictionary: [String: Any] = ["message": data]

            if session.isReachable {
                session.sendMessage(dictionary, replyHandler: { reply in
                    // Success
                }, errorHandler: { [weak self] error in
                    print("PPI Phone: sendMessage failed — \(error.localizedDescription)")
                    // Fallback for AQI updates
                    if message.type == .aqiUpdate || message.type == .vulnerabilitySync {
                        self?.transferBackground(dictionary)
                    }
                })
            } else {
                transferBackground(dictionary)
            }

            DispatchQueue.main.async {
                self.lastMessageSent = Date()
            }
        } catch {
            print("PPI Phone: Error encoding message — \(error.localizedDescription)")
        }
    }

    private func transferBackground(_ dictionary: [String: Any]) {
        guard let session = session else { return }
        do {
            try session.updateApplicationContext(dictionary)
        } catch {
            session.transferUserInfo(dictionary)
        }
    }

    // MARK: - Handle Incoming from Watch

    private func handleWatchMessage(_ message: WatchMessage) {
        DispatchQueue.main.async {
            switch message.type {
            case .requestCurrentRoute:
                // Watch requested current route — respond via existing logic
                break
            case .biometricUpdate:
                if let bio = message.biometricData {
                    self.latestBiometrics = bio
                }
            case .ppiScore:
                if let ppi = message.ppiData {
                    self.latestPPIScore = ppi
                }
            case .cigaretteUpdate:
                if let cig = message.cigaretteData {
                    self.latestCigaretteData = cig
                }
            case .routeCreated, .routeUpdated, .routeCleared, .aqiUpdate, .vulnerabilitySync:
                break
            }
        }
    }

    private func handleWatchRequest(_ message: WatchMessage, replyHandler: @escaping ([String: Any]) -> Void) {
        switch message.type {
        case .requestCurrentRoute:
            replyHandler(["status": "no_route"])
        default:
            handleWatchMessage(message)
            replyHandler(["status": "received"])
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated && session.isPaired && session.isWatchAppInstalled)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processIncoming(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let data = message["message"] as? Data {
            do {
                let watchMessage = try JSONDecoder().decode(WatchMessage.self, from: data)
                handleWatchRequest(watchMessage, replyHandler: replyHandler)
            } catch {
                replyHandler(["status": "error"])
            }
        } else {
            replyHandler(["status": "unknown"])
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        processIncoming(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        processIncoming(userInfo)
    }

    private func processIncoming(_ dictionary: [String: Any]) {
        if let data = dictionary["message"] as? Data {
            do {
                let watchMessage = try JSONDecoder().decode(WatchMessage.self, from: data)
                handleWatchMessage(watchMessage)
            } catch {
                print("PPI Phone: Error decoding Watch message — \(error.localizedDescription)")
            }
        }
    }
}
