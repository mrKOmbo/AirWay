//
//  RouteData.swift
//  AirWayWatch Watch App
//
//  Modelos de datos compartidos para comunicación iPhone ↔ Watch
//

import Foundation
import CoreLocation

// MARK: - Route Models

struct WatchRouteData: Codable, Identifiable {
    let id: String
    let distanceFormatted: String
    let timeFormatted: String
    let coordinates: [WatchCoordinate]
    let averageAQI: Int
    let qualityLevel: String
    let destinationName: String
    let trafficIncidents: Int
    let hazardIncidents: Int
    let safetyScore: Double

    init(
        id: String = UUID().uuidString,
        distanceFormatted: String,
        timeFormatted: String,
        coordinates: [WatchCoordinate],
        averageAQI: Int,
        qualityLevel: String,
        destinationName: String,
        trafficIncidents: Int = 0,
        hazardIncidents: Int = 0,
        safetyScore: Double = 100.0
    ) {
        self.id = id
        self.distanceFormatted = distanceFormatted
        self.timeFormatted = timeFormatted
        self.coordinates = coordinates
        self.averageAQI = averageAQI
        self.qualityLevel = qualityLevel
        self.destinationName = destinationName
        self.trafficIncidents = trafficIncidents
        self.hazardIncidents = hazardIncidents
        self.safetyScore = safetyScore
    }

    var aqiColor: String {
        switch averageAQI {
        case 0..<51: return "#E0E0E0"
        case 51..<101: return "#FDD835"
        case 101..<151: return "#FF9800"
        default: return "#E53935"
        }
    }

    var riskLevel: String {
        switch safetyScore {
        case 80...100: return "Low Risk"
        case 60..<80: return "Medium Risk"
        case 40..<60: return "High Risk"
        default: return "Critical Risk"
        }
    }
}

struct WatchCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - AQI Update (iPhone → Watch)

struct AQIUpdateData: Codable {
    let aqi: Int
    let pm25: Double
    let pm10: Double
    let no2: Double?
    let o3: Double?
    let dominantPollutant: String?
    let location: String
    let qualityLevel: String
    let confidence: Double
    let timestamp: Date
}

// MARK: - Biometric Update (Watch → iPhone)

struct BiometricUpdateData: Codable {
    let heartRate: Double?
    let heartRateDate: Date?
    let hrv: Double?
    let hrvDate: Date?
    let spO2: Double?
    let spO2Date: Date?
    let respiratoryRate: Double?
    let respiratoryRateDate: Date?
    let timestamp: Date
}

// MARK: - PPI Score Data

struct PPIScoreData: Codable {
    let score: Int
    let zone: PPIZone
    let components: PPIComponents
    let activityState: String
    let availableMetrics: Int
    let baselineCalibrated: Bool
    let timestamp: Date
}

struct PPIComponents: Codable {
    let spO2Score: Double?
    let hrvScore: Double?
    let hrScore: Double?
    let respScore: Double?
    let spO2Deviation: Double?
    let hrvDeviation: Double?
    let hrDeviation: Double?
    let respDeviation: Double?
}

enum PPIZone: String, Codable, CaseIterable {
    case green = "green"
    case yellow = "yellow"
    case orange = "orange"
    case red = "red"

    var label: String {
        switch self {
        case .green: return "No effects"
        case .yellow: return "Mild effects"
        case .orange: return "Moderate impact"
        case .red: return "Significant stress"
        }
    }

    var labelES: String {
        switch self {
        case .green: return "Sin efectos"
        case .yellow: return "Efectos leves"
        case .orange: return "Impacto moderado"
        case .red: return "Estrés significativo"
        }
    }

    static func from(score: Int) -> PPIZone {
        switch score {
        case 0..<25: return .green
        case 25..<50: return .yellow
        case 50..<75: return .orange
        default: return .red
        }
    }
}

// MARK: - Vulnerability Profile

struct VulnerabilityProfile: Codable {
    var hasAsthma: Bool = false
    var hasCOPD: Bool = false
    var hasCVD: Bool = false
    var hasDiabetes: Bool = false
    var isElderly: Bool = false
    var isChild: Bool = false

    var multiplier: Double {
        var m = 1.0
        if hasAsthma { m += 0.5 }
        if hasCOPD { m += 0.8 }
        if hasCVD { m += 0.5 }
        if hasDiabetes { m += 0.4 }
        if isElderly { m += 0.3 }
        if isChild { m += 0.2 }
        return m
    }

    var riskFactors: [String] {
        var factors: [String] = []
        if hasAsthma { factors.append("Asthma") }
        if hasCOPD { factors.append("COPD") }
        if hasCVD { factors.append("Cardiovascular") }
        if hasDiabetes { factors.append("Diabetes") }
        if isElderly { factors.append("65+") }
        if isChild { factors.append("Child") }
        return factors
    }
}

// MARK: - Watch Message Protocol

struct WatchMessage: Codable {
    enum MessageType: String, Codable {
        case routeCreated
        case routeUpdated
        case routeCleared
        case requestCurrentRoute
        case aqiUpdate
        case biometricUpdate
        case ppiScore
        case vulnerabilitySync
        case cigaretteUpdate
    }

    let type: MessageType
    let route: WatchRouteData?
    let aqiData: AQIUpdateData?
    let biometricData: BiometricUpdateData?
    let ppiData: PPIScoreData?
    let vulnerabilityProfile: VulnerabilityProfile?
    let cigaretteData: CigaretteData?
    let timestamp: Date

    init(type: MessageType,
         route: WatchRouteData? = nil,
         aqiData: AQIUpdateData? = nil,
         biometricData: BiometricUpdateData? = nil,
         ppiData: PPIScoreData? = nil,
         vulnerabilityProfile: VulnerabilityProfile? = nil,
         cigaretteData: CigaretteData? = nil) {
        self.type = type
        self.route = route
        self.aqiData = aqiData
        self.biometricData = biometricData
        self.ppiData = ppiData
        self.vulnerabilityProfile = vulnerabilityProfile
        self.cigaretteData = cigaretteData
        self.timestamp = Date()
    }
}

// MARK: - Sample Data

extension WatchRouteData {
    static var sample: WatchRouteData {
        WatchRouteData(
            distanceFormatted: "5.2 km",
            timeFormatted: "12 min",
            coordinates: [
                WatchCoordinate(latitude: 19.2827, longitude: -99.6525),
                WatchCoordinate(latitude: 19.2900, longitude: -99.6400),
                WatchCoordinate(latitude: 19.2950, longitude: -99.6350),
                WatchCoordinate(latitude: 19.3000, longitude: -99.6300)
            ],
            averageAQI: 65,
            qualityLevel: "Moderate",
            destinationName: "Starbucks Centro",
            trafficIncidents: 2,
            hazardIncidents: 1,
            safetyScore: 75.0
        )
    }
}
