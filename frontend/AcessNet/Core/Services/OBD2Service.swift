//
//  OBD2Service.swift
//  AcessNet
//
//  Cliente BLE para dongles ELM327 (Vgate iCar Pro, OBDLink MX+, Kiwi 3...).
//  Expone datos en tiempo real (RPM, velocidad, MAF, fuel rate) vía CoreBluetooth.
//
//  Protocolo ELM327: comandos AT + PIDs estándar SAE J1979.
//  Referencia: https://en.wikipedia.org/wiki/OBD-II_PIDs
//

import Foundation
import CoreBluetooth
import Combine
import os

@MainActor
final class OBD2Service: NSObject, ObservableObject {
    static let shared = OBD2Service()

    // MARK: - Published

    @Published private(set) var state: OBD2ConnectionState = .disconnected
    @Published private(set) var liveData: OBD2LiveData = OBD2LiveData()
    @Published private(set) var recentResponses: [String] = []

    // MARK: - Private

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var responseBuffer: String = ""

    private var pollTimer: Timer?
    private let pollPIDs: [OBD2PID] = [.rpm, .speed, .throttle, .maf, .engineTemp, .fuelRate, .engineLoad]
    private var pidIndex = 0

    // ELM327 usa UUID 0xFFE0 en muchos dongles; otros usan 0xFFF0 (OBDLink).
    private let candidateServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFE0"),
        CBUUID(string: "FFF0"),
        CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"),  // OBDLink MX+
    ]

    // MARK: - Simulation

    /// Modo simulación para demos/hackathon sin dongle físico.
    @Published var useSimulation: Bool = true
    private var simulationTimer: Timer?
    private var simElapsed: Double = 0
    private var simCurrentSpeed: Double = 0
    private var simTargetSpeed: Double = 35
    private var simRPM: Double = 800
    private var simThrottle: Double = 0
    private var simFuelLevel: Double = 68

    // MARK: - Init

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }

    // MARK: - Public API

    func scan() {
        if useSimulation {
            startSimulation()
            return
        }
        guard central.state == .poweredOn else {
            AirWayLogger.obd.warning("scan() attempted but BLE not powered on (state=\(String(describing: self.central.state), privacy: .public))")
            state = .failed(reason: "Bluetooth apagado")
            return
        }
        AirWayLogger.obd.notice("Starting BLE scan for OBD dongles")
        state = .scanning
        // Peripheral scan sin filter (muchos dongles no publican los service UUIDs)
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func disconnect() {
        AirWayLogger.obd.notice("disconnect() called")
        stopSimulation()
        stopPolling()
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        peripheral = nil
        writeChar = nil
        notifyChar = nil
        state = .disconnected
    }

    // MARK: - Simulation

    private func startSimulation() {
        AirWayLogger.obd.notice("OBD-II starting SIMULATION (Vgate iCar Pro demo)")
        state = .scanning
        // Simula descubrimiento después de 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.state = .connecting(peripheralName: "Vgate iCar Pro BLE [SIM]")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.state = .connected(peripheralName: "Vgate iCar Pro BLE [SIM]")
                self.recentResponses.append("ELM327 v1.5")
                self.recentResponses.append("ATZ → OK")
                self.recentResponses.append("ATSP0 → AUTO: ISO 15765-4 CAN (11/500)")
                self.startSimulationTicker()
            }
        }
    }

    private func startSimulationTicker() {
        simElapsed = 0
        simCurrentSpeed = 0
        simTargetSpeed = 40
        simRPM = 800

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.simulationTick() }
        }
        RunLoop.main.add(simulationTimer!, forMode: .common)
    }

    private func simulationTick() {
        simElapsed += 0.3

        // Cambiar target cada 6s (simula semáforos + tráfico CDMX)
        if Int(simElapsed * 10) % 60 == 0 {
            let rand = Double.random(in: 0...1)
            if rand < 0.15 {
                simTargetSpeed = 0                              // rojo
            } else if rand < 0.55 {
                simTargetSpeed = Double.random(in: 25...45)     // ciudad
            } else {
                simTargetSpeed = Double.random(in: 50...75)     // avenida
            }
        }

        // Suavizado
        simCurrentSpeed = max(0, simCurrentSpeed + (simTargetSpeed - simCurrentSpeed) * 0.12)

        // RPM: en ralentí 800, escala con speed y acceleration
        let speedRatio = simCurrentSpeed / 80.0
        let accel = simTargetSpeed - simCurrentSpeed
        simRPM = 800 + speedRatio * 1800 + max(0, accel) * 40
        simRPM = max(700, min(simRPM, 4500))

        // Throttle: en aceleración alta
        if accel > 5 {
            simThrottle = min(100, simThrottle + 8)
        } else if accel < -5 {
            simThrottle = max(0, simThrottle - 12)
        } else {
            simThrottle = max(8, simThrottle - 1.5)    // ralentí ~8-15%
        }

        // Consumo combustible va bajando gradualmente
        if Int(simElapsed) % 20 == 0 && simCurrentSpeed > 10 {
            simFuelLevel = max(5, simFuelLevel - 0.05)
        }

        // MAF estimado (g/s): proporcional a RPM y throttle
        let maf = (simRPM / 1000.0) * (simThrottle / 100.0 + 0.3) * 4.5

        // Fuel rate directo L/hr = (MAF_g_s * 3600) / (14.7 * 740)
        let fuelRate = (maf * 3600) / (14.7 * 740)

        // Temp motor: calienta al arrancar y estabiliza ~92°C
        let targetTemp = 92.0
        let temp = 40.0 + min(simElapsed / 2.5, 1.0) * (targetTemp - 40.0)
        let intakeTemp = 28.0 + sin(simElapsed / 10) * 3

        // Engine load estimado
        let load = (simRPM - 800) / 3700 * 100

        liveData = OBD2LiveData(
            timestamp: Date(),
            rpm: Int(simRPM),
            speedKmh: Int(simCurrentSpeed),
            throttlePct: simThrottle,
            mafGs: maf,
            fuelRateLh: fuelRate,
            engineTempC: Int(temp),
            intakeTempC: Int(intakeTemp),
            baroPressureKpa: 77,  // CDMX ~2240m
            fuelLevelPct: simFuelLevel,
            engineLoadPct: max(10, min(load, 95))
        )

        // Log trace con los PIDs simulados
        if Int(simElapsed * 10) % 10 == 0 {
            recentResponses.append("41 0C \(String(format: "%02X %02X", Int(simRPM * 4) / 256, Int(simRPM * 4) % 256)) → \(Int(simRPM)) RPM")
            if recentResponses.count > 20 {
                recentResponses.removeFirst(recentResponses.count - 20)
            }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        if useSimulation {
            AirWayLogger.obd.info("OBD-II simulation stopped")
        }
    }

    // MARK: - Private commands

    private func sendATInit() {
        AirWayLogger.obd.info("Sending ATZ/ATE0/ATL0/ATH0/ATS0/ATSP0 init sequence")
        // Secuencia de reset e inicialización ELM327
        send("ATZ\r")              // reset
        send("ATE0\r")             // echo off
        send("ATL0\r")             // linefeeds off
        send("ATH0\r")             // headers off
        send("ATS0\r")             // spaces off
        send("ATSP0\r")            // auto-protocol
    }

    private func send(_ command: String) {
        guard let p = peripheral, let c = writeChar,
              let data = command.data(using: .ascii) else {
            AirWayLogger.obd.warning("send() \(command.trimmingCharacters(in: .whitespacesAndNewlines), privacy: .public) dropped: no peripheral/char")
            return
        }
        AirWayLogger.obd.trace("TX: \(command.trimmingCharacters(in: .whitespacesAndNewlines), privacy: .public)")
        p.writeValue(data, for: c, type: .withResponse)
    }

    private func startPolling() {
        stopPolling()
        // Cada 300ms un PID → 7 PIDs ≈ 2.1s ciclo completo
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.requestNextPID() }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func requestNextPID() {
        let pid = pollPIDs[pidIndex % pollPIDs.count]
        send(pid.command)
        pidIndex += 1
    }

    // MARK: - Response parsing

    private func handleIncomingData(_ data: Data) {
        guard let str = String(data: data, encoding: .ascii) else { return }
        responseBuffer.append(str)

        // ELM327 termina con '>' prompt
        while let range = responseBuffer.range(of: ">") {
            let response = String(responseBuffer[..<range.lowerBound])
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            responseBuffer.removeSubrange(..<range.upperBound)

            if !response.isEmpty {
                recentResponses.append(response)
                if recentResponses.count > 20 {
                    recentResponses.removeFirst(recentResponses.count - 20)
                }
                AirWayLogger.obd.trace("RX: \(response, privacy: .public)")
                parseResponse(response)
            }
        }
    }

    private func parseResponse(_ response: String) {
        // Ejemplo respuesta: "41 0C 1A F8" → RPM = ((1A*256) + F8) / 4
        let tokens = response.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard tokens.count >= 3, tokens[0] == "41" else { return }
        let pid = tokens[1]
        let bytes = Array(tokens.dropFirst(2)).compactMap { UInt8($0, radix: 16) }
        guard !bytes.isEmpty else { return }

        var updated = liveData
        updated.timestamp = Date()

        switch pid {
        case "0C":  // RPM
            guard bytes.count >= 2 else { return }
            updated.rpm = (Int(bytes[0]) * 256 + Int(bytes[1])) / 4
        case "0D":  // Speed km/h
            updated.speedKmh = Int(bytes[0])
        case "11":  // Throttle %
            updated.throttlePct = Double(bytes[0]) * 100.0 / 255.0
        case "10":  // MAF g/s
            guard bytes.count >= 2 else { return }
            updated.mafGs = Double(Int(bytes[0]) * 256 + Int(bytes[1])) / 100.0
        case "5E":  // Fuel rate L/hr
            guard bytes.count >= 2 else { return }
            updated.fuelRateLh = Double(Int(bytes[0]) * 256 + Int(bytes[1])) * 0.05
        case "05":  // Engine temp °C
            updated.engineTempC = Int(bytes[0]) - 40
        case "0F":  // Intake temp °C
            updated.intakeTempC = Int(bytes[0]) - 40
        case "33":  // Baro kPa
            updated.baroPressureKpa = Int(bytes[0])
        case "2F":  // Fuel level %
            updated.fuelLevelPct = Double(bytes[0]) * 100.0 / 255.0
        case "04":  // Engine load %
            updated.engineLoadPct = Double(bytes[0]) * 100.0 / 255.0
        default:
            return
        }

        liveData = updated
    }
}

// MARK: - CBCentralManagerDelegate

extension OBD2Service: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOff:
                self.state = .failed(reason: "Bluetooth apagado")
            case .unauthorized:
                self.state = .failed(reason: "Permiso BLE denegado")
            case .unsupported:
                self.state = .failed(reason: "BLE no soportado")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String : Any],
                                    rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        // Filtrar por nombre típico dongles ELM327
        let lowered = name.lowercased()
        let isOBD = lowered.contains("obd") || lowered.contains("elm") || lowered.contains("vgate")
                   || lowered.contains("obdlink") || lowered.contains("kiwi")
                   || lowered.contains("vlinker")
        guard isOBD else { return }

        AirWayLogger.obd.notice("Found OBD peripheral: \(name, privacy: .public) RSSI=\(RSSI.intValue, privacy: .public)")
        Task { @MainActor in
            self.central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            self.state = .connecting(peripheralName: peripheral.name)
            self.central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        AirWayLogger.obd.info("Connected peripheral=\(peripheral.name ?? "?", privacy: .public); discovering services")
        Task { @MainActor in
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        AirWayLogger.obd.error("Connection failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        Task { @MainActor in
            self.state = .failed(reason: error?.localizedDescription ?? "Conexión fallida")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        AirWayLogger.obd.notice("Disconnected peripheral=\(peripheral.name ?? "?", privacy: .public) error=\(error?.localizedDescription ?? "none", privacy: .public)")
        Task { @MainActor in
            self.stopPolling()
            self.state = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OBD2Service: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for svc in services {
            peripheral.discoverCharacteristics(nil, for: svc)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        guard let chars = service.characteristics else { return }
        var foundWrite: CBCharacteristic?
        var foundNotify: CBCharacteristic?
        for c in chars {
            if c.properties.contains(.writeWithoutResponse) || c.properties.contains(.write) {
                foundWrite = c
            }
            if c.properties.contains(.notify) {
                foundNotify = c
            }
        }
        Task { @MainActor in
            self.writeChar = foundWrite
            self.notifyChar = foundNotify
            if let n = foundNotify {
                peripheral.setNotifyValue(true, for: n)
            }
            AirWayLogger.obd.info(
                "Characteristics found writeChar=\(foundWrite != nil, privacy: .public) notifyChar=\(foundNotify != nil, privacy: .public)"
            )
            if foundWrite != nil {
                self.state = .connected(peripheralName: peripheral.name ?? "ELM327")
                self.sendATInit()
                // Dar tiempo a ATZ reset antes de polling
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    AirWayLogger.obd.info("Starting PID polling every 300ms")
                    self.startPolling()
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            self.handleIncomingData(data)
        }
    }
}
