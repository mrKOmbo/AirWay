//
//  TripBriefing.swift
//  AcessNet
//
//  Modelos del "Trip Briefing" — la card que aparece al poner un pin
//  en el mapa y se bifurca entre "🚶 A pie" y "🚗 En coche".
//
//  Vive del otro lado de CigaretteMath (modo a pie) + FuelAPIClient /
//  FuelStationsAPI / DepartureOptimizerAPI (modo coche).
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Preview Route

/// Representación ligera de una ruta tentativa para dibujar en el mapa.
/// Envuelve tanto `MKRoute` real como variantes simuladas compuestas
/// de múltiples tramos (MKRoute no tiene init público).
struct PreviewRoute: Equatable {
    let polyline: MKPolyline
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval

    static func == (lhs: PreviewRoute, rhs: PreviewRoute) -> Bool {
        lhs.distance == rhs.distance
            && lhs.expectedTravelTime == rhs.expectedTravelTime
            && lhs.polyline === rhs.polyline
    }

    init(polyline: MKPolyline, distance: CLLocationDistance, expectedTravelTime: TimeInterval) {
        self.polyline = polyline
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
    }

    init(mkRoute: MKRoute) {
        self.polyline = mkRoute.polyline
        self.distance = mkRoute.distance
        self.expectedTravelTime = mkRoute.expectedTravelTime
    }
}

// MARK: - Briefing Mode

/// Modo de viaje seleccionado en el toggle de la card del pin.
/// (Se llama `BriefingMode` para no chocar con `TripMode` del endpoint /trip.)
enum BriefingMode: String, CaseIterable, Identifiable {
    case walking
    case driving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walking: return "A pie"
        case .driving: return "En coche"
        }
    }

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        }
    }

    /// Elige el modo por defecto según la distancia al destino (metros).
    /// < 2 km → a pie, ≥ 2 km → coche.
    static func `default`(forDistanceMeters distance: CLLocationDistance) -> BriefingMode {
        distance < 2000 ? .walking : .driving
    }
}

// MARK: - Loading State wrapper

/// Estado genérico para sub-módulos que cargan independientes.
enum AsyncLoadState<Value> {
    case idle
    case loading
    case ready(Value)
    case failed(String)

    var value: Value? {
        if case .ready(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Walking Briefing

/// Snapshot del briefing del modo "A pie".
/// Se calcula 100% local a partir de AQI promedio en ruta + duración.
/// `pm25RouteAvg` / `aqiRouteAvg` son **opcionales**: `nil` = no hay
/// suficientes datos de calidad del aire para el trayecto.
struct WalkingBriefing: Equatable {
    let distanceMeters: CLLocationDistance
    let durationSeconds: TimeInterval
    let pm25RouteAvg: Double?         // µg/m³ a lo largo del trayecto (nil = sin datos)
    let aqiRouteAvg: Double?
    let activity: WalkActivityLevel

    /// `true` si tenemos datos de calidad del aire para esta ruta.
    var hasAirData: Bool { pm25RouteAvg != nil }

    /// Cálculo puro encapsulado (struct de valor).
    /// Si no hay datos de aire, usa 0 → cigarros = 0 pero `verdict`
    /// será `.unknown` (no `.goForIt`).
    var math: CigaretteMath {
        CigaretteMath(
            pm25Avg: pm25RouteAvg ?? 0,
            durationSeconds: durationSeconds,
            activity: activity
        )
    }

    // MARK: Derived (para UI)

    /// Cigarros equivalentes. `nil` si no hay datos de aire.
    var cigarettes: Double? {
        hasAirData ? math.cigarettesEquivalent : nil
    }

    /// Dosis en µg. `nil` si no hay datos.
    var dosedMicrograms: Double? {
        hasAirData ? math.dosedMicrograms : nil
    }

    var kcalBurned: Double { math.kcalBurned }

    var verdict: WalkVerdict {
        guard hasAirData else { return .unknown }
        return math.verdict
    }

    var distanceKm: Double { distanceMeters / 1000.0 }
    var durationMinutes: Int { Int((durationSeconds / 60.0).rounded()) }

    var distanceLabel: String {
        distanceKm < 1
            ? String(format: "%.0f m", distanceMeters)
            : String(format: "%.1f km", distanceKm)
    }

    var durationLabel: String {
        durationMinutes < 60
            ? "\(durationMinutes) min"
            : String(format: "%dh %dm", durationMinutes / 60, durationMinutes % 60)
    }

    /// Cambia la actividad (sin perder los demás parámetros).
    /// Recalcula duración según velocidad del nuevo ritmo.
    func withActivity(_ new: WalkActivityLevel) -> WalkingBriefing {
        let oldSpeed = activity.speedMps
        let newSpeed = new.speedMps
        let newDuration: TimeInterval
        if newSpeed > 0 && oldSpeed > 0 {
            newDuration = durationSeconds * (oldSpeed / newSpeed)
        } else {
            newDuration = durationSeconds
        }
        return WalkingBriefing(
            distanceMeters: distanceMeters,
            durationSeconds: newDuration,
            pm25RouteAvg: pm25RouteAvg,
            aqiRouteAvg: aqiRouteAvg,
            activity: new
        )
    }
}

// MARK: - Hotspot

/// Segmento de la ruta con AQI peligroso.
struct WalkingHotspot: Equatable, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let aqi: Double
    let durationInZoneSec: TimeInterval

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, aqi: Double, durationInZoneSec: TimeInterval) {
        self.id = id
        self.coordinate = coordinate
        self.aqi = aqi
        self.durationInZoneSec = durationInZoneSec
    }

    static func == (lhs: WalkingHotspot, rhs: WalkingHotspot) -> Bool {
        lhs.id == rhs.id
            && lhs.aqi == rhs.aqi
            && lhs.durationInZoneSec == rhs.durationInZoneSec
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    var minutesInZone: Int { Int((durationInZoneSec / 60.0).rounded()) }
}

// MARK: - Driving Briefing

/// Snapshot del modo "En coche" — compone varios endpoints.
/// NO es `Equatable` porque algunos payloads del backend
/// (`OptimalDepartureResponse`) no conforman a `Equatable`.
struct DrivingBriefing {
    let distanceMeters: CLLocationDistance
    let durationSeconds: TimeInterval
    let pm25RouteAvg: Double?    // nil = sin datos suficientes
    let aqiRouteAvg: Double?

    // Sub-fetches (cada uno carga independiente).
    var fuel: AsyncLoadState<FuelEstimate> = .idle
    var stations: AsyncLoadState<[FuelStation]> = .idle
    var departure: AsyncLoadState<OptimalDepartureResponse> = .idle

    var hasAirData: Bool { pm25RouteAvg != nil }

    var distanceKm: Double { distanceMeters / 1000.0 }
    var durationMinutes: Int { Int((durationSeconds / 60.0).rounded()) }

    var distanceLabel: String {
        distanceKm < 1
            ? String(format: "%.0f m", distanceMeters)
            : String(format: "%.1f km", distanceKm)
    }

    var durationLabel: String {
        durationMinutes < 60
            ? "\(durationMinutes) min"
            : String(format: "%dh %dm", durationMinutes / 60, durationMinutes % 60)
    }

    /// "Cigarros de cabina" — PM2.5 infiltrado al interior del auto.
    /// `nil` si no hay datos de aire.
    var cabinCigarettes: Double? {
        guard let pm25 = pm25RouteAvg else { return nil }
        return CigaretteMath.cabinCigarettes(
            pm25RouteAvg: pm25,
            durationSeconds: durationSeconds,
            filtration: .standard
        )
    }

    /// Mejor estación por precio (si hay).
    var bestStation: FuelStation? {
        stations.value?.min(by: { $0.price < $1.price })
    }

    /// Ahorro vs promedio si cargas en la mejor.
    var bestStationSavings: Double? {
        bestStation?.savingsPerLiter
    }

    /// kg CO2 → # árboles/día que absorberían esa cantidad.
    /// Heurística: 1 árbol maduro ≈ 0.06 kg CO2/día.
    var treesPerDayToOffset: Int? {
        guard let kg = fuel.value?.co2Kg else { return nil }
        return Int((kg / 0.06).rounded())
    }
}
