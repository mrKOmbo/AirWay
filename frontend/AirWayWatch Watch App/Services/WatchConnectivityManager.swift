//
//  WatchConnectivityManager.swift
//  AirWayWatch Watch App
//
//  Gestor de conectividad entre iPhone y Apple Watch.
//  Handles route data, AQI updates, biometric data, and PPI scores.
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties
    @Published var currentRoute: WatchRouteData?
    @Published var isConnected: Bool = false
    @Published var lastMessageReceived: Date?
    @Published var lastAQIUpdate: AQIUpdateData?
    @Published var vulnerabilityProfile: VulnerabilityProfile?

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

    // MARK: - Send PPI Score to iPhone

    func sendPPIScore(_ ppiData: PPIScoreData) {
        PPILog.wc.notice(" Sending PPI score=\(ppiData.score) zone=\(ppiData.zone.rawValue) to iPhone")
        let message = WatchMessage(type: .ppiScore, ppiData: ppiData)
        sendMessage(message)
    }

    // MARK: - Send Biometric Data to iPhone

    func sendBiometrics(_ biometricData: BiometricUpdateData) {
        let message = WatchMessage(type: .biometricUpdate, biometricData: biometricData)
        sendMessage(message)
    }

    // MARK: - Send Cigarette Equivalence to iPhone

    func sendCigaretteData(_ data: CigaretteData) {
        PPILog.wc.notice(" Sending cigarettes=\(String(format: "%.2f", data.cigarettesToday)) to iPhone")
        let message = WatchMessage(type: .cigaretteUpdate, cigaretteData: data)
        sendMessage(message)
    }

    // MARK: - Request Route from iPhone

    func requestCurrentRoute() {
        guard let session = session, session.isReachable else { return }

        let message = WatchMessage(type: .requestCurrentRoute)

        do {
            let data = try JSONEncoder().encode(message)
            let dictionary: [String: Any] = ["message": data]

            session.sendMessage(dictionary, replyHandler: { reply in
                self.handleReply(reply)
            }, errorHandler: { error in
                print("PPI Watch: Error requesting route — \(error.localizedDescription)")
            })
        } catch {
            print("PPI Watch: Error encoding route request — \(error.localizedDescription)")
        }
    }

    func clearRoute() {
        DispatchQueue.main.async {
            self.currentRoute = nil
        }
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: WatchMessage) {
        guard let session = session else { return }

        do {
            let data = try JSONEncoder().encode(message)
            let dictionary: [String: Any] = ["message": data]

            if session.isReachable {
                session.sendMessage(dictionary, replyHandler: nil) { error in
                    // Fallback to application context for AQI updates
                    if message.type == .ppiScore || message.type == .biometricUpdate {
                        try? session.updateApplicationContext(dictionary)
                    }
                }
            } else {
                // Background transfer for important data
                switch message.type {
                case .ppiScore, .biometricUpdate:
                    session.transferUserInfo(dictionary)
                default:
                    try? session.updateApplicationContext(dictionary)
                }
            }
        } catch {
            print("PPI Watch: Error sending message — \(error.localizedDescription)")
        }
    }

    private func handleReply(_ reply: [String: Any]) {
        if let data = reply["route"] as? Data {
            do {
                let route = try JSONDecoder().decode(WatchRouteData.self, from: data)
                DispatchQueue.main.async {
                    self.currentRoute = route
                    self.lastMessageReceived = Date()
                }
            } catch {
                print("PPI Watch: Error decoding route reply — \(error.localizedDescription)")
            }
        }
    }

    private func handleReceivedMessage(_ message: WatchMessage) {
        DispatchQueue.main.async {
            self.lastMessageReceived = Date()

            PPILog.wc.notice(" Received message type=\(message.type.rawValue)")
            switch message.type {
            case .routeCreated, .routeUpdated:
                if let route = message.route {
                    self.currentRoute = route
                    PPILog.wc.notice(" Route received: \(route.destinationName)")
                }
            case .routeCleared:
                self.currentRoute = nil
                PPILog.wc.notice(" Route cleared")
            case .aqiUpdate:
                if let aqiData = message.aqiData {
                    self.lastAQIUpdate = aqiData
                    PPILog.wc.notice(" AQI update: aqi=\(aqiData.aqi) location=\(aqiData.location)")
                }
            case .vulnerabilitySync:
                if let profile = message.vulnerabilityProfile {
                    self.vulnerabilityProfile = profile
                    PPILog.wc.notice(" Vulnerability profile synced: multiplier=\(profile.multiplier)")
                }
            case .requestCurrentRoute, .biometricUpdate, .ppiScore, .cigaretteUpdate:
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processIncoming(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        processIncoming(message)
        replyHandler(["status": "received"])
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
                handleReceivedMessage(watchMessage)
            } catch {
                print("PPI Watch: Error decoding incoming message — \(error.localizedDescription)")
            }
        }
    }
}
