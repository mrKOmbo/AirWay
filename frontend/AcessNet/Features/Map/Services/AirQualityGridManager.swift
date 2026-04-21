//
//  AirQualityGridManager.swift
//  AcessNet
//
//  Generador y gestor de grid dinámico de zonas de calidad del aire
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import MapKit

// MARK: - Air Quality Grid Manager

/// Gestor del grid de zonas de calidad del aire que se actualiza dinámicamente
class AirQualityGridManager: ObservableObject {

    // MARK: - Published Properties

    /// Zonas actuales de calidad del aire
    @Published private(set) var zones: [AirQualityZone] = []

    /// Indica si está calculando el grid
    @Published private(set) var isCalculating: Bool = false

    /// Centro actual del grid
    @Published private(set) var currentCenter: CLLocationCoordinate2D?

    // MARK: - Private Properties

    /// Configuración del grid
    private var config: AirQualityGridConfig

    /// URL del backend real
    private let backendURL = "https://airway-api.onrender.com/api/v1"

    /// Cache de datos del backend
    private var cachedHeatmapData: [HeatmapPoint]?
    private var cachedAnalysisAQI: Int?

    /// Timestamp del último cálculo
    private var lastCalculation: Date?

    /// Timer para actualizaciones periódicas
    private var updateTimer: Timer?

    /// Queue para cálculos en background
    private let calculationQueue = DispatchQueue(label: "com.acessnet.airqualitygrid", qos: .userInitiated)

    /// Distancia mínima para recalcular (en metros).
    /// Subido de 500m → 1000m: un fetch al backend cuesta ~12s (timeout) + rebuild
    /// de 40+ annotations en SwiftUI. A 500m se disparaba cada ~30s en coche urbano;
    /// a 1000m baja a ~1 min y aprovecha mejor el cache de 2 min.
    private let minimumDistanceForUpdate: CLLocationDistance = 1000

    // MARK: - Initialization

    init(config: AirQualityGridConfig = .default) {
        self.config = config
    }

    deinit {
        stopAutoUpdate()
    }

    // MARK: - Public Methods

    /// Actualiza el grid con un nuevo centro
    /// - Parameter center: Coordenada central del grid
    func updateGrid(center: CLLocationCoordinate2D) {
        // Verificar si es necesario actualizar
        guard shouldUpdate(for: center) else {
            return
        }

        // Limpiar zonas inmediatamente para evitar superposición
        DispatchQueue.main.async {
            self.zones = []
            self.isCalculating = true
        }

        // Calcular grid en background
        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            let newZones = self.calculateGrid(center: center)

            // Actualizar en main thread
            DispatchQueue.main.async {
                self.zones = newZones
                self.currentCenter = center
                self.lastCalculation = Date()
                self.isCalculating = false

                print("🌍 Grid actualizado: \(newZones.count) zonas generadas")
                self.logGridStatistics()
            }
        }
    }

    /// Limpia todas las zonas
    func clearGrid() {
        DispatchQueue.main.async {
            self.zones = []
            self.currentCenter = nil
            self.lastCalculation = nil
        }
    }

    /// Obtiene la zona de calidad del aire en una coordenada específica
    /// - Parameter coordinate: Coordenada a buscar
    /// - Returns: Zona más cercana a la coordenada, o nil si no hay zonas
    func getZoneAtCoordinate(_ coordinate: CLLocationCoordinate2D) -> AirQualityZone? {
        guard !zones.isEmpty else { return nil }

        // Buscar zona más cercana
        return zones.min { zone1, zone2 in
            let dist1 = coordinate.distance(to: zone1.coordinate)
            let dist2 = coordinate.distance(to: zone2.coordinate)
            return dist1 < dist2
        }
    }

    /// Obtiene la zona de calidad del aire en una coordenada, pero solo si está dentro del radio
    /// - Parameters:
    ///   - coordinate: Coordenada a buscar
    ///   - maxDistance: Distancia máxima para considerar (por defecto: radio de zona)
    /// - Returns: Zona si está dentro del radio, nil si no
    func getZoneContaining(_ coordinate: CLLocationCoordinate2D, maxDistance: CLLocationDistance? = nil) -> AirQualityZone? {
        guard !zones.isEmpty else { return nil }

        for zone in zones {
            let distance = coordinate.distance(to: zone.coordinate)
            let threshold = maxDistance ?? zone.radius

            if distance <= threshold {
                return zone
            }
        }

        return nil
    }

    /// Actualiza las zonas de calidad del aire a lo largo de las rutas con espaciado dinámico
    /// - Parameter polylines: Array de polylines de todas las rutas
    func updateZonesAlongRoutes(polylines: [MKPolyline]) {
        // Limpiar zonas inmediatamente
        DispatchQueue.main.async {
            self.zones = []
            self.isCalculating = true
        }

        // Calcular zonas en background
        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Calcular longitud total de todas las rutas
            var totalDistance: CLLocationDistance = 0
            for polyline in polylines {
                totalDistance += polyline.totalLength()
            }

            let totalDistanceKm = totalDistance / 1000.0

            // 2. Calcular espaciado y radio dinámicos
            let spacing = self.calculateDynamicSpacing(totalDistanceKm: totalDistanceKm)
            let radius = self.calculateDynamicRadius(spacing: spacing)

            print("📏 Distancia total: \(String(format: "%.1f", totalDistanceKm))km")
            print("   → Espaciado: \(Int(spacing))m (\(String(format: "%.1f", spacing/1000))km entre círculos)")
            print("   → Radio: \(Int(radius))m (\(String(format: "%.1f", radius/1000))km de área promediada)")

            // 3. Samplear puntos a lo largo de cada ruta
            var allSampledPoints: [CLLocationCoordinate2D] = []

            for polyline in polylines {
                let sampledPoints = self.samplePolylineCoordinates(polyline, interval: spacing)
                allSampledPoints.append(contentsOf: sampledPoints)
            }

            print("   → Puntos sampleados: \(allSampledPoints.count) (de \(polylines.count) rutas)")

            // 4. Eliminar puntos duplicados muy cercanos
            // Usar 40% del spacing como distancia mínima para evitar superposición entre rutas
            let minDistance = spacing * 0.4
            let beforeDedup = allSampledPoints.count
            allSampledPoints = self.removeDuplicatePoints(allSampledPoints, minDistance: minDistance)
            print("   → Después de dedup: \(allSampledPoints.count) círculos (removidos: \(beforeDedup - allSampledPoints.count))")

            // 5. Generar zonas con promedio de área
            var newZones: [AirQualityZone] = []

            for point in allSampledPoints {
                // Calcular promedio de calidad del aire del área
                let avgAirQuality = self.calculateAreaAverage(center: point, radius: radius)

                let zone = AirQualityZone(
                    coordinate: point,
                    radius: radius,
                    airQuality: avgAirQuality
                )
                newZones.append(zone)
            }

            // 6. Actualizar en main thread
            DispatchQueue.main.async {
                self.zones = newZones
                self.currentCenter = nil
                self.lastCalculation = Date()
                self.isCalculating = false

                print("🛣️ Zonas a lo largo de rutas: \(newZones.count) círculos (espaciado: \(Int(spacing))m)")

                // Log de rango de AQI generado
                let aqiValues = newZones.map { $0.airQuality.aqi }
                let minAQI = aqiValues.min() ?? 0
                let maxAQI = aqiValues.max() ?? 0
                let avgAQI = aqiValues.isEmpty ? 0 : aqiValues.reduce(0, +) / Double(aqiValues.count)
                print("   💨 AQI range: \(String(format: "%.1f", minAQI)) - \(String(format: "%.1f", maxAQI)) (avg: \(String(format: "%.1f", avgAQI)))")

                self.logGridStatistics()
            }
        }
    }

    /// Inicia actualizaciones automáticas cada X segundos
    /// - Parameter interval: Intervalo en segundos (por defecto usa config.cacheTime)
    func startAutoUpdate(center: CLLocationCoordinate2D, interval: TimeInterval? = nil) {
        stopAutoUpdate()

        let updateInterval = interval ?? config.cacheTime

        // Actualizar inmediatamente
        updateGrid(center: center)

        // Configurar timer para actualizaciones periódicas
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let currentCenter = self.currentCenter else { return }
            self.updateGrid(center: currentCenter)
        }

        print("⏰ Auto-update iniciado (cada \(Int(updateInterval))s)")
    }

    /// Detiene las actualizaciones automáticas
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Obtiene la zona más cercana a una coordenada
    /// - Parameter coordinate: Coordenada a buscar
    /// - Returns: Zona más cercana o nil
    func nearestZone(to coordinate: CLLocationCoordinate2D) -> AirQualityZone? {
        guard !zones.isEmpty else { return nil }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return zones.min { zone1, zone2 in
            let loc1 = CLLocation(latitude: zone1.coordinate.latitude, longitude: zone1.coordinate.longitude)
            let loc2 = CLLocation(latitude: zone2.coordinate.latitude, longitude: zone2.coordinate.longitude)

            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }

    /// Filtra zonas por nivel de calidad
    /// - Parameter level: Nivel de AQI a filtrar
    /// - Returns: Zonas con ese nivel
    func zones(withLevel level: AQILevel) -> [AirQualityZone] {
        return zones.filter { $0.level == level }
    }

    /// Actualiza la configuración del grid
    /// - Parameter newConfig: Nueva configuración
    func updateConfiguration(_ newConfig: AirQualityGridConfig) {
        self.config = newConfig

        // Recalcular grid si hay un centro
        if let center = currentCenter {
            updateGrid(center: center)
        }
    }

    // MARK: - Private Methods

    /// Determina si se debe actualizar el grid
    private func shouldUpdate(for center: CLLocationCoordinate2D) -> Bool {
        // Si no hay centro previo, actualizar
        guard let previousCenter = currentCenter else {
            return true
        }

        // Verificar distancia desde último centro
        let previousLocation = CLLocation(latitude: previousCenter.latitude, longitude: previousCenter.longitude)
        let newLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distance = previousLocation.distance(from: newLocation)

        if distance >= minimumDistanceForUpdate {
            print("📍 Movimiento detectado: \(Int(distance))m (mín: \(Int(minimumDistanceForUpdate))m)")
            return true
        }

        // Verificar tiempo desde último cálculo
        if let lastCalc = lastCalculation {
            let timeSinceLastCalc = Date().timeIntervalSince(lastCalc)
            if timeSinceLastCalc >= config.cacheTime {
                print("⏱️ Cache expirado: \(Int(timeSinceLastCalc))s (max: \(Int(config.cacheTime))s)")
                return true
            }
        }

        return false
    }

    /// Samplea puntos a lo largo de un polyline
    /// - Parameters:
    ///   - polyline: Polyline a samplear
    ///   - interval: Distancia entre puntos en metros
    /// - Returns: Array de coordenadas sampleadas
    private func samplePolylineCoordinates(_ polyline: MKPolyline, interval: CLLocationDistance) -> [CLLocationCoordinate2D] {
        let allCoordinates = polyline.coordinates()
        guard allCoordinates.count >= 2 else { return allCoordinates }

        var sampledCoordinates: [CLLocationCoordinate2D] = []
        var accumulatedDistance: CLLocationDistance = 0
        var nextSampleDistance: CLLocationDistance = 0

        // Siempre incluir primer punto
        sampledCoordinates.append(allCoordinates[0])

        for i in 0..<allCoordinates.count - 1 {
            let coord1 = allCoordinates[i]
            let coord2 = allCoordinates[i + 1]
            let segmentDistance = coord1.distance(to: coord2)

            accumulatedDistance += segmentDistance

            // Si pasamos el siguiente punto de muestreo
            while accumulatedDistance >= nextSampleDistance + interval {
                nextSampleDistance += interval

                // Interpolar punto en el segmento
                let distanceIntoSegment = nextSampleDistance - (accumulatedDistance - segmentDistance)
                let fraction = distanceIntoSegment / segmentDistance

                if fraction >= 0 && fraction <= 1 {
                    let sampledPoint = coord1.interpolate(to: coord2, fraction: fraction)
                    sampledCoordinates.append(sampledPoint)
                }
            }
        }

        // Siempre incluir último punto
        if let last = allCoordinates.last {
            // Verificar si el último punto ya está incluido
            let lastSampled = sampledCoordinates.last
            let shouldAddLast = lastSampled == nil ||
                abs(lastSampled!.latitude - last.latitude) > 0.0001 ||
                abs(lastSampled!.longitude - last.longitude) > 0.0001

            if shouldAddLast {
                sampledCoordinates.append(last)
            }
        }

        return sampledCoordinates
    }

    /// Calcula el grid de zonas usando datos REALES del backend
    /// - Parameter center: Centro del grid
    /// - Returns: Array de zonas
    private func calculateGrid(center: CLLocationCoordinate2D) -> [AirQualityZone] {
        // Llamar al backend de forma síncrona (ya estamos en background queue)
        let radiusKm = Double(config.gridSize) * config.spacing / 1000.0
        let resolution = config.gridSize * 2 + 1 // e.g. gridSize=1 → 3x3, gridSize=2 → 5x5

        let urlString = "\(backendURL)/air/heatmap?lat=\(center.latitude)&lon=\(center.longitude)&radius_km=\(radiusKm)&resolution=\(resolution)"

        guard let url = URL(string: urlString) else {
            print("❌ Grid: URL inválida")
            return fallbackGrid(center: center)
        }

        print("🌐 Grid: fetching from backend: \(urlString)")

        let semaphore = DispatchSemaphore(value: 0)
        var resultZones: [AirQualityZone] = []

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { semaphore.signal() }

            guard let self = self, let data = data, error == nil else {
                print("❌ Grid backend error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            do {
                let heatmap = try JSONDecoder().decode(HeatmapResponse.self, from: data)
                self.cachedHeatmapData = heatmap.grid

                print("✅ Grid: \(heatmap.grid_points) points from backend (trend: \(heatmap.trend_factor))")

                for point in heatmap.grid {
                    let coordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
                    let airQuality = AirQualityPoint(
                        coordinate: coordinate,
                        aqi: Double(point.aqi),
                        pm25: Double(point.aqi) * 0.3, // Estimate PM2.5 from AQI
                        pm10: Double(point.aqi) * 0.5,
                        timestamp: Date()
                    )
                    let zone = AirQualityZone(
                        coordinate: coordinate,
                        radius: self.config.zoneRadius,
                        airQuality: airQuality
                    )
                    resultZones.append(zone)
                }
            } catch {
                print("❌ Grid decode error: \(error)")
            }
        }.resume()

        // Esperar máximo 12 segundos
        let waitResult = semaphore.wait(timeout: .now() + 12)
        if waitResult == .timedOut {
            print("⏰ Grid: backend timeout, using fallback")
            return fallbackGrid(center: center)
        }

        if resultZones.isEmpty {
            return fallbackGrid(center: center)
        }

        return resultZones
    }

    /// Fallback cuando el backend no responde — usa un solo punto del análisis
    private func fallbackGrid(center: CLLocationCoordinate2D) -> [AirQualityZone] {
        print("⚠️ Grid: using single-point fallback")

        let urlString = "\(backendURL)/air/analysis?lat=\(center.latitude)&lon=\(center.longitude)&mode=walk"
        guard let url = URL(string: urlString) else { return [] }

        let semaphore = DispatchSemaphore(value: 0)
        var zones: [AirQualityZone] = []

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else { return }

            do {
                let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)
                let aqi = Double(analysis.combined_aqi)
                let pm25 = analysis.pollutants?.pm25?.value ?? aqi * 0.3

                let airQuality = AirQualityPoint(
                    coordinate: center,
                    aqi: aqi,
                    pm25: pm25,
                    pm10: analysis.pollutants?.pm10?.value,
                    no2: analysis.pollutants?.no2?.value,
                    o3: analysis.pollutants?.o3?.value,
                    timestamp: Date()
                )
                let zone = AirQualityZone(
                    coordinate: center,
                    radius: 800,
                    airQuality: airQuality
                )
                zones.append(zone)
                print("✅ Fallback: AQI=\(analysis.combined_aqi) from analysis endpoint")
            } catch {
                print("❌ Fallback decode error: \(error)")
            }
        }.resume()

        _ = semaphore.wait(timeout: .now() + 10)
        return zones
    }

    /// Registra estadísticas del grid en consola
    private func logGridStatistics() {
        let goodCount = zones.filter { $0.level == .good }.count
        let moderateCount = zones.filter { $0.level == .moderate }.count
        let poorCount = zones.filter { $0.level == .poor }.count
        let unhealthyCount = zones.filter { $0.level == .unhealthy }.count

        let avgAQI = zones.map { $0.airQuality.aqi }.reduce(0, +) / Double(max(zones.count, 1))

        print("""
        📊 Estadísticas del Grid:
           - Total zonas: \(zones.count)
           - AQI promedio: \(Int(avgAQI))
           - 🟢 Good: \(goodCount)
           - 🟡 Moderate: \(moderateCount)
           - 🟠 Poor: \(poorCount)
           - 🔴 Unhealthy: \(unhealthyCount)
        """)
    }

    /// Calcula el espaciado dinámico basado en la distancia total de las rutas
    private func calculateDynamicSpacing(totalDistanceKm: Double) -> CLLocationDistance {
        switch totalDistanceKm {
        case 0..<1:
            return 400   // Ruta muy corta: 1 círculo cada 400m
        case 1..<3:
            return 800   // Ruta corta: 1 círculo cada 800m
        case 3..<7:
            return 1500  // Ruta media: 1 círculo cada 1.5km
        case 7..<15:
            return 2500  // Ruta larga: 1 círculo cada 2.5km
        default:
            return 3500  // Ruta muy larga: 1 círculo cada 3.5km
        }
    }

    /// Calcula el radio dinámico basado en el espaciado
    private func calculateDynamicRadius(spacing: CLLocationDistance) -> CLLocationDistance {
        return spacing * 0.5  // 50% del espaciado para evitar superposición
    }

    /// Elimina puntos duplicados muy cercanos
    private func removeDuplicatePoints(_ points: [CLLocationCoordinate2D], minDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
        var uniquePoints: [CLLocationCoordinate2D] = []

        for point in points {
            var isDuplicate = false
            for existing in uniquePoints {
                if point.distance(to: existing) < minDistance {
                    isDuplicate = true
                    break
                }
            }
            if !isDuplicate {
                uniquePoints.append(point)
            }
        }

        return uniquePoints
    }

    /// Calcula el promedio de calidad del aire de un área circular
    private func calculateAreaAverage(center: CLLocationCoordinate2D, radius: CLLocationDistance) -> AirQualityPoint {
        // Buscar en cache del heatmap datos cercanos
        if let cached = cachedHeatmapData {
            let nearby = cached.filter { point in
                let dist = sqrt(pow(point.lat - center.latitude, 2) + pow(point.lon - center.longitude, 2)) * 111000
                return dist < radius * 1.5
            }
            if !nearby.isEmpty {
                let avgAQI = Double(nearby.map { $0.aqi }.reduce(0, +)) / Double(nearby.count)
                return AirQualityPoint(
                    coordinate: center,
                    aqi: avgAQI,
                    pm25: avgAQI * 0.3,
                    pm10: avgAQI * 0.5,
                    timestamp: Date()
                )
            }
        }

        // Fallback: usar AQI promedio conocido
        let fallbackAQI = Double(cachedAnalysisAQI ?? 50)
        return AirQualityPoint(
            coordinate: center,
            aqi: fallbackAQI,
            pm25: fallbackAQI * 0.3,
            pm10: fallbackAQI * 0.5,
            timestamp: Date()
        )
    }
}

// MARK: - Grid Statistics

extension AirQualityGridManager {
    /// Estadísticas del grid actual
    struct GridStatistics {
        let totalZones: Int
        let averageAQI: Double
        let goodCount: Int
        let moderateCount: Int
        let poorCount: Int
        let unhealthyCount: Int
        let severeCount: Int
        let hazardousCount: Int

        var dominantLevel: AQILevel {
            let counts = [
                (AQILevel.good, goodCount),
                (AQILevel.moderate, moderateCount),
                (AQILevel.poor, poorCount),
                (AQILevel.unhealthy, unhealthyCount),
                (AQILevel.severe, severeCount),
                (AQILevel.hazardous, hazardousCount)
            ]

            return counts.max { $0.1 < $1.1 }?.0 ?? .good
        }
    }

    /// Calcula estadísticas del grid actual
    func getStatistics() -> GridStatistics {
        return GridStatistics(
            totalZones: zones.count,
            averageAQI: zones.isEmpty ? 0 : zones.map { $0.airQuality.aqi }.reduce(0, +) / Double(zones.count),
            goodCount: zones.filter { $0.level == .good }.count,
            moderateCount: zones.filter { $0.level == .moderate }.count,
            poorCount: zones.filter { $0.level == .poor }.count,
            unhealthyCount: zones.filter { $0.level == .unhealthy }.count,
            severeCount: zones.filter { $0.level == .severe }.count,
            hazardousCount: zones.filter { $0.level == .hazardous }.count
        )
    }
}
