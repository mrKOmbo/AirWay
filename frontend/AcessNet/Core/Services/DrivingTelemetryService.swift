//
//  DrivingTelemetryService.swift
//  AcessNet
//
//  Captura telemetría durante un viaje en auto sin hardware adicional.
//  Usa CoreMotion (acelerómetro) + CoreLocation + CMMotionActivityManager.
//
//  Al terminar el viaje, actualiza el driving_style del VehicleProfile activo
//  con EMA (Exponential Moving Average). Permitirá al motor físico refinar
//  estimaciones personalizadas.
//

import Foundation
import CoreMotion
import CoreLocation
import Combine
import os

@MainActor
final class DrivingTelemetryService: NSObject, ObservableObject {
    static let shared = DrivingTelemetryService()

    // MARK: - Published

    @Published private(set) var currentTrip: TripTelemetry?
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var liveStats: LiveStats = .empty
    @Published private(set) var pastTrips: [TripTelemetry] = []

    struct LiveStats {
        var speedKmh: Double
        var harshEvents: Int
        var durationMin: Double
        var distanceKm: Double

        static let empty = LiveStats(speedKmh: 0, harshEvents: 0, durationMin: 0, distanceKm: 0)
    }

    // MARK: - Private

    private let motion = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private let locationManager = CLLocationManager()

    private var lastLocation: CLLocation?
    private let harshThreshold: Double = 3.0   // m/s²
    private let idleSpeedThreshold: Double = 3.0  // km/h

    private var sampleBufferLimit = 200

    private let pastTripsKey = "airway.telemetry.pastTrips"

    // MARK: - Simulation

    /// Modo simulación: genera datos realistas sin CoreMotion ni GPS.
    /// Útil para demos en simulador y hackathon sin hardware.
    @Published var useSimulation: Bool = true
    private var simulationTimer: Timer?
    private var simStartTime: Date = Date()
    private var simCumulativeDistance: Double = 0   // km
    private var simCurrentSpeed: Double = 0         // km/h
    private var simTargetSpeed: Double = 40         // km/h objetivo cambiante
    private var simElevationGain: Double = 0        // m
    private var simElapsedSec: Double = 0

    // MARK: - Lifecycle

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .automotiveNavigation
        loadPastTrips()
    }

    // MARK: - Authorization

    func requestAuthorizationsIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        // CoreMotion: no requiere autorización explícita en iOS >= 11
    }

    // MARK: - Public API

    /// Inicia captura manual (el usuario toca "Iniciar viaje").
    func startTrip(vehicleId: UUID? = nil) {
        guard !isRecording else {
            AirWayLogger.telemetry.warning("startTrip called but already recording")
            return
        }

        currentTrip = TripTelemetry(vehicleProfileId: vehicleId)
        liveStats = .empty
        lastLocation = nil
        isRecording = true

        if useSimulation {
            startSimulation()
            return
        }

        requestAuthorizationsIfNeeded()

        AirWayLogger.telemetry.notice(
            "startTrip vehicleId=\(vehicleId?.uuidString ?? "nil", privacy: .public) accelAvailable=\(self.motion.isAccelerometerAvailable, privacy: .public) activityAvailable=\(CMMotionActivityManager.isActivityAvailable(), privacy: .public)"
        )

        // Acelerómetro 5 Hz suficiente para detectar aceleraciones bruscas
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.2
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let d = data, self.isRecording else { return }
                self.processAccel(d)
            }
        }

        // Activity detection para auto-detectar "automotive"
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let a = activity, a.automotive == false, self?.isRecording == true else { return }
                // Si el usuario dejó el auto (walking, stationary) por >5min: auto-end
                AirWayLogger.telemetry.debug(
                    "activity changed auto=\(a.automotive, privacy: .public) stationary=\(a.stationary, privacy: .public)"
                )
            }
        }

        // Location
        locationManager.startUpdatingLocation()
    }

    // MARK: - Simulation

    /// Inicia un viaje simulado realista (Zócalo → Polanco 8 km aprox).
    private func startSimulation() {
        simStartTime = Date()
        simCumulativeDistance = 0
        simCurrentSpeed = 0
        simTargetSpeed = 35
        simElevationGain = 0
        simElapsedSec = 0

        AirWayLogger.telemetry.notice("startTrip [SIMULATION] — generando datos realistas")

        // Tick cada 500ms simulando ~2 Hz de GPS
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.simulationTick() }
        }
        RunLoop.main.add(simulationTimer!, forMode: .common)
    }

    private func simulationTick() {
        guard isRecording, var trip = currentTrip else { return }

        simElapsedSec += 0.5

        // Cambiar velocidad objetivo cada 8s (simula tráfico + semáforos)
        if Int(simElapsedSec) % 8 == 0 {
            let rand = Double.random(in: 0...1)
            if rand < 0.15 {
                simTargetSpeed = Double.random(in: 0...8)       // stop / semáforo
            } else if rand < 0.55 {
                simTargetSpeed = Double.random(in: 20...45)     // ciudad
            } else {
                simTargetSpeed = Double.random(in: 45...70)     // avenida
            }
        }

        // Suavizado hacia target
        let prevSpeed = simCurrentSpeed
        let delta = simTargetSpeed - simCurrentSpeed
        simCurrentSpeed = max(0, simCurrentSpeed + delta * 0.15)

        // Detectar harsh accel/brake (|Δspeed| > 6 km/h en 0.5s ≈ 3.3 m/s²)
        let speedDelta = simCurrentSpeed - prevSpeed
        if abs(speedDelta) > 6 {
            if speedDelta > 0 {
                trip.harshAccels += 1
                AirWayLogger.telemetry.debug("SIM harsh ACCEL Δ=\(String(format: "%.1f", speedDelta), privacy: .public) km/h")
            } else {
                trip.harshBrakes += 1
                AirWayLogger.telemetry.debug("SIM harsh BRAKE Δ=\(String(format: "%.1f", speedDelta), privacy: .public) km/h")
            }
        }

        // Idle detection
        if simCurrentSpeed < 3 {
            trip.idleSeconds += 1   // ~0.5s pero contamos como 1 para ser generoso
        }

        // Distancia acumulada
        let distKmThisTick = simCurrentSpeed * (0.5 / 3600)
        simCumulativeDistance += distKmThisTick
        trip.totalDistanceKm = simCumulativeDistance
        trip.maxSpeedKmh = max(trip.maxSpeedKmh, simCurrentSpeed)

        // Elevación ligera oscilante
        let elevDelta = sin(simElapsedSec / 15) * 0.3
        if elevDelta > 0 {
            simElevationGain += elevDelta
            trip.elevationGainM = simElevationGain
        }

        currentTrip = trip
        liveStats = LiveStats(
            speedKmh: simCurrentSpeed,
            harshEvents: trip.harshAccels + trip.harshBrakes,
            durationMin: trip.durationMinutes,
            distanceKm: trip.totalDistanceKm
        )
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    /// Finaliza el viaje y retorna el TripTelemetry final.
    @discardableResult
    func endTrip() -> TripTelemetry? {
        guard isRecording else {
            AirWayLogger.telemetry.warning("endTrip called but not recording")
            return nil
        }
        isRecording = false

        stopSimulation()
        motion.stopAccelerometerUpdates()
        activityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()

        guard var trip = currentTrip else { return nil }
        trip.endedAt = Date()

        // Calcular velocidad promedio final
        if trip.totalDistanceKm > 0 && trip.durationSeconds > 0 {
            trip.avgSpeedKmh = trip.totalDistanceKm / (trip.durationSeconds / 3600)
        }

        currentTrip = trip
        pastTrips.insert(trip, at: 0)
        savePastTrips()

        AirWayLogger.telemetry.notice(
            "endTrip distance=\(String(format: "%.2f", trip.totalDistanceKm), privacy: .public)km dur=\(Int(trip.durationMinutes), privacy: .public)min maxSpeed=\(Int(trip.maxSpeedKmh), privacy: .public)km/h harshAccel=\(trip.harshAccels, privacy: .public) harshBrake=\(trip.harshBrakes, privacy: .public) idle=\(trip.idleSeconds, privacy: .public)s style=\(String(format: "%.3f", trip.computedStyleMultiplier), privacy: .public)"
        )

        // Actualizar driving style del vehicle activo con EMA
        applyDrivingStyleUpdate(for: trip)

        return trip
    }

    /// Descarta el viaje en curso sin guardar.
    func cancelTrip() {
        AirWayLogger.telemetry.notice("cancelTrip")
        isRecording = false
        stopSimulation()
        motion.stopAccelerometerUpdates()
        activityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()
        currentTrip = nil
        liveStats = .empty
    }

    // MARK: - Processing

    private func processAccel(_ data: CMAccelerometerData) {
        // magnitud en g, restamos 1g de gravedad
        let mag = sqrt(
            data.acceleration.x * data.acceleration.x +
            data.acceleration.y * data.acceleration.y +
            data.acceleration.z * data.acceleration.z
        )
        let net = abs(mag - 1.0) * 9.81  // m/s²

        if net > harshThreshold {
            // Clasificar como accel o brake por la velocidad
            if let speed = lastLocation?.speed, speed > 5 {
                // acelerando
                currentTrip?.harshAccels += 1
                AirWayLogger.telemetry.debug(
                    "harsh ACCEL net=\(String(format: "%.2f", net), privacy: .public)m/s² at speed=\(String(format: "%.1f", speed * 3.6), privacy: .public)km/h"
                )
            } else {
                // frenando (velocidad baja tras evento)
                currentTrip?.harshBrakes += 1
                AirWayLogger.telemetry.debug(
                    "harsh BRAKE net=\(String(format: "%.2f", net), privacy: .public)m/s²"
                )
            }
            liveStats.harshEvents = (currentTrip?.harshAccels ?? 0) + (currentTrip?.harshBrakes ?? 0)
        }
    }

    // MARK: - Persistence

    private func savePastTrips() {
        do {
            // Limitar a últimos 100 trips
            let trimmed = Array(pastTrips.prefix(100))
            let data = try JSONEncoder().encode(trimmed)
            UserDefaults.standard.set(data, forKey: pastTripsKey)
            AirWayLogger.telemetry.debug("savePastTrips stored \(trimmed.count) trips (\(data.count) bytes)")
        } catch {
            AirWayLogger.telemetry.error("savePastTrips failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadPastTrips() {
        guard let data = UserDefaults.standard.data(forKey: pastTripsKey),
              let list = try? JSONDecoder().decode([TripTelemetry].self, from: data) else {
            AirWayLogger.telemetry.debug("loadPastTrips no trips on disk")
            return
        }
        pastTrips = list
        AirWayLogger.telemetry.info("loadPastTrips \(list.count) trips loaded")
    }

    private func applyDrivingStyleUpdate(for trip: TripTelemetry) {
        let newMultiplier = trip.computedStyleMultiplier
        guard let profileId = trip.vehicleProfileId ?? VehicleProfileService.shared.activeProfile?.id else {
            return
        }
        VehicleProfileService.shared.updateDrivingStyle(
            for: profileId,
            newStyleMultiplier: newMultiplier,
            alpha: 0.15
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension DrivingTelemetryService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            guard var trip = self.currentTrip, self.isRecording else { return }

            let speedKmh = max(0, last.speed) * 3.6
            if speedKmh < self.idleSpeedThreshold {
                trip.idleSeconds += 1
            }
            trip.maxSpeedKmh = max(trip.maxSpeedKmh, speedKmh)

            // Distancia acumulada
            if let prev = self.lastLocation {
                let deltaM = last.distance(from: prev)
                trip.totalDistanceKm += deltaM / 1000.0

                let deltaAlt = last.altitude - prev.altitude
                if deltaAlt > 0 {
                    trip.elevationGainM += deltaAlt
                }
            }
            self.lastLocation = last

            // Sample si hay espacio
            if trip.samples.count < self.sampleBufferLimit {
                trip.samples.append(TelemetrySample(
                    t: Date(),
                    lat: last.coordinate.latitude,
                    lon: last.coordinate.longitude,
                    speedKmh: speedKmh,
                    altitude: last.altitude,
                    accelMagnitude: 0
                ))
            }

            self.currentTrip = trip
            self.liveStats.speedKmh = speedKmh
            self.liveStats.distanceKm = trip.totalDistanceKm
            self.liveStats.durationMin = trip.durationMinutes
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AirWayLogger.telemetry.error("location error: \(error.localizedDescription, privacy: .public)")
    }
}
