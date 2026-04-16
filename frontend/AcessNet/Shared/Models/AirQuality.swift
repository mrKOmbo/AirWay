//
//  AirQuality.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import Foundation
import CoreLocation

// MARK: - Air Quality Models

struct AirQualityData: Identifiable {
    let id = UUID()
    let aqi: Int
    let pm25: Double
    let pm10: Double
    let location: String
    let city: String
    let distance: Double
    let temperature: Double
    let humidity: Int
    let windSpeed: Double
    let uvIndex: Int
    let weatherCondition: WeatherCondition
    let lastUpdate: Date

    var qualityLevel: AQILevel {
        AQILevel.from(aqi: aqi)
    }

    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(lastUpdate) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) minutes ago" }
        let hours = minutes / 60
        return "\(hours) hours ago"
    }
}

enum AQILevel: String, CaseIterable {
    case good = "Good"
    case moderate = "Moderate"
    case poor = "Poor"
    case unhealthy = "Unhealthy"
    case severe = "Severe"
    case hazardous = "Hazardous"

    static func from(aqi: Int) -> AQILevel {
        switch aqi {
        case 0..<51: return .good
        case 51..<101: return .moderate
        case 101..<151: return .poor
        case 151..<201: return .unhealthy
        case 201..<301: return .severe
        default: return .hazardous
        }
    }

    var color: String {
        switch self {
        case .good: return "#E0E0E0"
        case .moderate: return "#FDD835" // Amarillo - Estándar AQI para Moderate (51-100)
        case .poor: return "#FF6F00"
        case .unhealthy: return "#E53935"
        case .severe: return "#8E24AA"
        case .hazardous: return "#6A1B4D"
        }
    }

    var backgroundColor: String {
        switch self {
        case .good: return "#B8E986"
        case .moderate: return "#FFD54F" // Amarillo claro - background original
        case .poor: return "#FFB74D"
        case .unhealthy: return "#EF5350"
        case .severe: return "#AB47BC"
        case .hazardous: return "#880E4F"
        }
    }
}

enum WeatherCondition: String {
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case overcast = "Overcast"
    case rainy = "Rainy"
    case stormy = "Stormy"

    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .overcast: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        }
    }
}

// MARK: - Sample Data

extension AirQualityData {
    static let sample = AirQualityData(
        aqi: 75,
        pm25: 22.0,
        pm10: 66.0,
        location: "Atmosphere Science Center",
        city: "Mexico City, Mexico",
        distance: 3.24,
        temperature: 18.0,
        humidity: 68,
        windSpeed: 4.0,
        uvIndex: 0,
        weatherCondition: .sunny,
        lastUpdate: Date().addingTimeInterval(-360)
    )
}

// MARK: - Backend Analysis Response Models

struct AnalysisResponse: Codable {
    let location: LocationData?
    let timestamp: String?
    let combined_aqi: Int
    let aqi_range: AQIRange?
    let category: String?
    let color: String?
    let confidence: Double?
    let dominant_pollutant: String?
    let station_count: Int?
    let pollutants: PollutantsData?
    let ml_prediction: MLPredictionResponse?
    let ai_analysis: AIAnalysisResponse?

    // Ignore fields we don't need (sources, stations, forecast, weather)
    enum CodingKeys: String, CodingKey {
        case location, timestamp, combined_aqi, aqi_range, category, color
        case confidence, dominant_pollutant, station_count, pollutants
        case ml_prediction, ai_analysis
    }
}

struct LocationData: Codable {
    let lat: Double
    let lon: Double
    let elevation_m: Double?
}

struct AQIRange: Codable {
    let low: Int
    let high: Int
    let spread: Int
}

struct PollutantsData: Codable {
    let pm25: PollutantEntry?
    let pm10: PollutantEntry?
    let no2: PollutantEntry?
    let o3: PollutantEntry?
    let so2: PollutantEntry?
    let co: PollutantEntry?
}

struct PollutantEntry: Codable {
    let value: Double?
    let unit: String?
    let sources_reporting: Int?
}

// MARK: - ML Prediction Models

struct MLPredictionResponse: Codable {
    let predictions: [String: HorizonPrediction]?
    let trend: String?
    let current_pm25: Double?
    let current_aqi: Int?
    let model_available: Bool?
}

struct HorizonPrediction: Codable {
    let pm25: Double?
    let aqi: Int
    let risk_level: String?
    let confidence_interval: ConfidenceInterval?
    let category: String?
    let color: String?
}

struct ConfidenceInterval: Codable {
    let lower_pm25: Double?
    let upper_pm25: Double?
    let lower_aqi: Int?
    let upper_aqi: Int?
}

// MARK: - AI Analysis Models

struct AIAnalysisResponse: Codable {
    let summary: String?
    let health_recommendation: String?
    let source_agreement: String?
    let alerts: [String]?
    let best_hours: String?
    let risk_level: String?
}

// MARK: - Best Time Response

struct BestTimeResponse: Codable {
    let location: LocationCoord
    let mode: String
    let hours_analyzed: Int
    let best_window: TimeWindow?
    let worst_window: TimeWindow?
    let summary: String
    let hourly: [HourlyEntry]
}

struct LocationCoord: Codable {
    let lat: Double
    let lon: Double
}

struct TimeWindow: Codable {
    let start: String
    let end: String
    let avg_aqi: Int
    let risk_level: String
}

struct HourlyEntry: Codable, Identifiable {
    var id: String { time }
    let time: String
    let aqi: Int
    let category: String
    let color: String
    let recommendation: String

    var hourLabel: String {
        if let tIndex = time.firstIndex(of: "T") {
            let hourStr = time[time.index(after: tIndex)...]
            return String(hourStr.prefix(5))
        }
        return time
    }
}

// MARK: - Heatmap Response

struct HeatmapResponse: Codable {
    let center: LocationCoord
    let radius_km: Double
    let grid_points: Int
    let trend_factor: Double
    let grid: [HeatmapPoint]
}

struct HeatmapPoint: Codable, Identifiable {
    var id: String { "\(lat),\(lon)" }
    let lat: Double
    let lon: Double
    let aqi: Int
    let predicted_1h: Int
    let color: String
}
