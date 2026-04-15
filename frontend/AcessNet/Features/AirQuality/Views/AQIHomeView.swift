//
//  AQIHomeView.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import SwiftUI
import CoreLocation

struct AQIHomeView: View {
    @Binding var showBusinessPulse: Bool
    @State private var airQualityData: AirQualityData = .sample
    @State private var selectedForecastTab: ForecastTab = .hourly
    @State private var showSearchModal = false
    @State private var searchText = ""
    @State private var showARView = false
    @State private var isLoadingAQI: Bool = false

    // ML Prediction data
    @State private var mlPrediction: MLPredictionResponse?
    @State private var aiAnalysis: AIAnalysisResponse?
    @State private var bestTimeData: BestTimeResponse?
    @State private var dataLoadError: String?
    @State private var hasLoadedBackend: Bool = false

    enum ForecastTab {
        case hourly
        case daily
    }

    init(showBusinessPulse: Binding<Bool>) {
        self._showBusinessPulse = showBusinessPulse
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient - Primary to Secondary
                LinearGradient(
                    colors: [
                        Color("Primary"),
                        Color("Secondary")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerView

                        // AQI Info Button (combines AQI Card + PM Indicators)
                        aqiInfoButton

                        // Loading indicator
                        if isLoadingAQI {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading real-time data...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                        }

                        // Error message
                        if let error = dataLoadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        // ML Prediction Card (NEW)
                        if let prediction = mlPrediction, prediction.model_available == true {
                            mlPredictionCard(prediction)
                        }

                        // AI Analysis Card (NEW)
                        if let analysis = aiAnalysis, analysis.summary != nil {
                            aiAnalysisCard(analysis)
                        }

                        // Best Time Card (NEW)
                        if let bestTime = bestTimeData {
                            bestTimeCard(bestTime)
                        }

                        // AR Button
                        arButton

                        // Weather Info Card
                        weatherCard

                        // Today's Exposure
                        todaysExposureView

                        // Weather Forecast
                        weatherForecast
                    }
                    .padding(.top, 20)
                    .avoidTabBar(extraPadding: 20)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showARView) {
            ARParticlesView()
        }
        .sheet(isPresented: $showSearchModal) {
            LocationSearchModal(searchText: $searchText, onLocationSelected: handleLocationSelection)
        }
        .task {
            guard !hasLoadedBackend else { return }
            await loadBackendData()
        }
    }

    // MARK: - Backend Data Loading

    private func loadBackendData() async {
        await MainActor.run {
            isLoadingAQI = true
            dataLoadError = nil
        }

        let lat = 19.4326
        let lon = -99.1332
        let backendURL = "https://airway-api.onrender.com/api/v1"

        // Llamada directa con URLSession (más confiable que el genérico)
        do {
            // 1. Fetch analysis
            guard let analysisURL = URL(string: "\(backendURL)/air/analysis?lat=\(lat)&lon=\(lon)&mode=walk") else { return }
            print("🌐 Fetching: \(analysisURL)")
            let (analysisData, _) = try await URLSession.shared.data(from: analysisURL)

            if let rawJSON = String(data: analysisData, encoding: .utf8) {
                print("📦 Analysis response (\(analysisData.count) bytes): \(String(rawJSON.prefix(300)))")
            }

            let decoder = JSONDecoder()
            let analysis = try decoder.decode(AnalysisResponse.self, from: analysisData)

            await MainActor.run {
                airQualityData = AirQualityData(
                    aqi: analysis.combined_aqi,
                    pm25: analysis.pollutants?.pm25?.value ?? 0,
                    pm10: analysis.pollutants?.pm10?.value ?? 0,
                    location: "CDMX Centro",
                    city: "Ciudad de México",
                    distance: 0,
                    temperature: 18,
                    humidity: 55,
                    windSpeed: 5,
                    uvIndex: 0,
                    weatherCondition: .cloudy,
                    lastUpdate: Date()
                )
                mlPrediction = analysis.ml_prediction
                aiAnalysis = analysis.ai_analysis
                hasLoadedBackend = true
                print("✅ Analysis loaded: AQI=\(analysis.combined_aqi), ML=\(analysis.ml_prediction != nil)")
            }
        } catch {
            print("❌ Analysis error: \(error)")
            if let decodingError = error as? DecodingError {
                print("   Decoding detail: \(decodingError)")
            }
            await MainActor.run { dataLoadError = "Error: \(error.localizedDescription)" }
        }

        // 2. Fetch best-time (independiente, no bloquea si falla)
        do {
            guard let btURL = URL(string: "\(backendURL)/air/best-time?lat=\(lat)&lon=\(lon)&mode=bike&hours=12") else { return }
            let (btData, _) = try await URLSession.shared.data(from: btURL)
            let bestTime = try JSONDecoder().decode(BestTimeResponse.self, from: btData)
            await MainActor.run {
                bestTimeData = bestTime
                print("✅ BestTime loaded: best=\(bestTime.best_window?.avg_aqi ?? 0)")
            }
        } catch {
            print("⚠️ BestTime error: \(error)")
        }

        await MainActor.run { isLoadingAQI = false }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .font(.subheadline)

                        Text(airQualityData.location)
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }

                    Text(airQualityData.city)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Text("Nearest Monitor : \(String(format: "%.2f", airQualityData.distance)) Km")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Search button
                Button(action: {
                    showSearchModal = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal)
    }

    private var aqiCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: .red, radius: 4)

                        Text("Live AQI")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    Text("\(airQualityData.aqi)")
                        .font(.system(size: 90, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Text("Air Quality is")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.95))

                    Text(airQualityData.qualityLevel.rawValue)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: airQualityData.qualityLevel.color).opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var dailyForecastButton: some View {
        NavigationLink(destination: DailyForecastView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5-Day Forecast")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("View detailed daily air quality predictions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("Secondary").opacity(0.7),
                                Color("Primary").opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal)
    }

    private var aqiInfoButton: some View {
        NavigationLink(destination: DailyForecastView()) {
            VStack(spacing: 16) {
                // AQI Card content
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red, radius: 4)

                            Text("Live AQI")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }

                        Text("\(airQualityData.aqi)")
                            .font(.system(size: 90, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Text("Air Quality is")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.95))

                        Text(airQualityData.qualityLevel.rawValue)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(hex: airQualityData.qualityLevel.color).opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // PM Indicators with daily comparison
                HStack(spacing: 20) {
                    // PM2.5
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PM2.5")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text("\(Int(airQualityData.pm25)) μg/m³")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    // PM10
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PM10")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text("\(Int(airQualityData.pm10)) μg/m³")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Daily comparison dots
                    HStack(spacing: 8) {
                        DayDot(label: "Tue", aqi: 52)
                        DayDot(label: "Wed", aqi: 58)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal)
    }

    private var arButton: some View {
        Button(action: {
            showARView = true
        }) {
            HStack(spacing: 16) {
                // AR Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.8), .indigo.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)

                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("AR Air Quality")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Visualize invisible PM2.5 particles")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.5),
                                Color.indigo.opacity(0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
            )
        }
        .padding(.horizontal)
    }

    private var pmIndicators: some View {
        HStack(spacing: 24) {
            // PM2.5 - Simplified
            HStack(spacing: 8) {
                Text("PM2.5:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(airQualityData.pm25)) μg/m³")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            // PM10 - Simplified
            HStack(spacing: 8) {
                Text("PM10:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(airQualityData.pm10)) μg/m³")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - ML Prediction Card

    private func mlPredictionCard(_ prediction: MLPredictionResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)
                Text("ML Prediction")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                if let trend = prediction.trend {
                    HStack(spacing: 4) {
                        Image(systemName: trend == "subiendo" ? "arrow.up.right" : trend == "bajando" ? "arrow.down.right" : "arrow.right")
                            .foregroundColor(trend == "subiendo" ? .orange : trend == "bajando" ? .green : .white)
                        Text(trend.capitalized)
                            .font(.caption.bold())
                            .foregroundColor(trend == "subiendo" ? .orange : trend == "bajando" ? .green : .white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(.white.opacity(0.15))
                    )
                }
            }

            if let preds = prediction.predictions {
                HStack(spacing: 0) {
                    ForEach(["1h", "3h", "6h"], id: \.self) { key in
                        if let p = preds[key] {
                            VStack(spacing: 6) {
                                Text("In \(key)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(p.aqi)")
                                    .font(.title2.bold())
                                    .foregroundColor(Color(hex: p.color ?? "#ffff00"))
                                Text((p.risk_level ?? "moderado").capitalized)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - AI Analysis Card

    private func aiAnalysisCard(_ analysis: AIAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Analysis")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }

            if let summary = analysis.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
            }

            if let rec = analysis.health_recommendation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.caption)
                        .padding(.top, 2)
                    Text(rec)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                }
            }

            if let bestHours = analysis.best_hours, !bestHours.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.yellow.opacity(0.8))
                        .font(.caption)
                        .padding(.top, 2)
                    Text(bestHours)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.indigo.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Best Time Card

    private func bestTimeCard(_ bestTime: BestTimeResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.green)
                Text("Best Time to Go Out")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }

            if let best = bestTime.best_window {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.8))
                        Text(formatTimeWindow(best.start, best.end))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("AQI \(best.avg_aqi)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let worst = bestTime.worst_window {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avoid")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                            Text(formatTimeWindow(worst.start, worst.end))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("AQI \(worst.avg_aqi)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // Mini hourly bar chart
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(bestTime.hourly.prefix(12)) { entry in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: entry.color))
                                .frame(width: 20, height: CGFloat(max(10, entry.aqi / 2)))
                            Text(entry.hourLabel)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.teal.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    private func formatTimeWindow(_ start: String, _ end: String) -> String {
        let extractHour = { (s: String) -> String in
            if let tIndex = s.firstIndex(of: "T") {
                return String(s[s.index(after: tIndex)...].prefix(5))
            }
            return s
        }
        return "\(extractHour(start)) - \(extractHour(end))"
    }

    // MARK: - Weather Card

    private var weatherCard: some View {
        VStack(spacing: 16) {
            // Weather scale bar
            AQIScaleBar(currentAQI: airQualityData.aqi)
                .padding(.horizontal)

            // Weather info card
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // Temperature
                    WeatherInfoItem(
                        icon: "cloud.fill",
                        value: "\(Int(airQualityData.temperature))°",
                        unit: "C",
                        label: airQualityData.weatherCondition.rawValue
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // Humidity
                    WeatherInfoItem(
                        icon: "drop.fill",
                        value: "\(airQualityData.humidity)",
                        unit: "%",
                        label: "Humidity"
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // Wind
                    WeatherInfoItem(
                        icon: "wind",
                        value: "\(Int(airQualityData.windSpeed))",
                        unit: "km/hr",
                        label: "Wind"
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // UV Index
                    WeatherInfoItem(
                        icon: "sun.max.fill",
                        value: "\(airQualityData.uvIndex)",
                        unit: "",
                        label: "UV Index"
                    )
                }
                .padding(.vertical, 8)

                // Last update
                Text("Last Update:  \(airQualityData.timeAgo)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
        }
    }

    private var todaysExposureView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's exposure")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            // Exposure Chart
            ExposureCircularChart()
                .frame(height: 280)
                .padding(.horizontal)
        }
    }

    private var mascotView: some View {
        HStack {
            Spacer()
            MascotCharacter()
                .frame(height: 180)
                .padding(.trailing, 40)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }

    private var weatherForecast: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Forecast")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            // Tabs
            HStack(spacing: 8) {
                ForecastTabButton(
                    title: "Hourly",
                    isSelected: selectedForecastTab == .hourly
                ) {
                    withAnimation(.none) {
                        selectedForecastTab = .hourly
                    }
                }

                ForecastTabButton(
                    title: "Daily",
                    isSelected: selectedForecastTab == .daily
                ) {
                    withAnimation(.none) {
                        selectedForecastTab = .daily
                    }
                }
            }
            .padding(.horizontal)

            // Forecast content with sample data
            if selectedForecastTab == .hourly {
                hourlyForecastView
                    .transition(.identity)
            } else {
                dailyForecastView
                    .transition(.identity)
            }
        }
    }

    private var hourlyForecastView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                HourlyForecastItem(hour: "Now", temp: 16, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "19:00", temp: 15, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "20:00", temp: 15, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "21:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "22:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "23:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "00:00", temp: 13, icon: "cloud.moon.rain.fill")
            }
            .padding(.horizontal)
        }
    }

    private var dailyForecastView: some View {
        VStack(spacing: 16) {
            // Daily forecast cards
            ForEach(generateDailyForecasts()) { forecast in
                NavigationLink(destination: DailyForecastView()) {
                    DailyForecastCard(forecast: forecast)
                }
            }
        }
        .padding(.horizontal)
    }

    private func generateDailyForecasts() -> [DailyForecastData] {
        let calendar = Calendar.current
        let today = Date()

        return [
            DailyForecastData(
                id: 0,
                date: calendar.date(byAdding: .day, value: 0, to: today)!,
                dayName: "Today",
                aqi: 58,
                temp: 16,
                weatherIcon: "cloud.rain.fill",
                weatherDescription: "Rainy",
                qualityLevel: "Moderate"
            ),
            DailyForecastData(
                id: 1,
                date: calendar.date(byAdding: .day, value: 1, to: today)!,
                dayName: "Tomorrow",
                aqi: 45,
                temp: 17,
                weatherIcon: "cloud.sun.fill",
                weatherDescription: "Partly Cloudy",
                qualityLevel: "Good"
            ),
            DailyForecastData(
                id: 2,
                date: calendar.date(byAdding: .day, value: 2, to: today)!,
                dayName: "Saturday",
                aqi: 62,
                temp: 18,
                weatherIcon: "cloud.fill",
                weatherDescription: "Cloudy",
                qualityLevel: "Moderate"
            ),
            DailyForecastData(
                id: 3,
                date: calendar.date(byAdding: .day, value: 3, to: today)!,
                dayName: "Sunday",
                aqi: 38,
                temp: 19,
                weatherIcon: "sun.max.fill",
                weatherDescription: "Sunny",
                qualityLevel: "Good"
            ),
            DailyForecastData(
                id: 4,
                date: calendar.date(byAdding: .day, value: 4, to: today)!,
                dayName: "Monday",
                aqi: 71,
                temp: 15,
                weatherIcon: "cloud.drizzle.fill",
                weatherDescription: "Drizzle",
                qualityLevel: "Moderate"
            )
        ]
    }
}

struct DailyForecastCard: View {
    let forecast: DailyForecastData

    var body: some View {
        HStack(spacing: 16) {
            // Left section - Day and Date
            VStack(alignment: .leading, spacing: 4) {
                Text(forecast.dayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(formatDate(forecast.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 85, alignment: .leading)

            // AQI Badge
            VStack(spacing: 4) {
                Text("\(forecast.aqi)")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("AQI")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(forecast.aqiColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(forecast.aqiColor, lineWidth: 2)
                    )
            )

            Spacer()

            // Weather section
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(forecast.weatherDescription)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Text("\(forecast.temp)°C")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Image(systemName: forecast.weatherIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 35)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

extension AQIHomeView {
    // MARK: - Location Selection Handler

    fileprivate func handleLocationSelection(_ locationString: String) {
        // Parse location string (e.g., "Mexico City, Mexico")
        let components = locationString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let locationName = components.first ?? locationString
        let cityName = locationString

        // Fetch AQI data for selected location
        fetchAQIData(locationName: locationName, cityName: cityName)
    }

    // MARK: - Fetch AQI Data
    fileprivate func fetchAQIData(locationName: String, cityName: String) {
        // Show loading state
        isLoadingAQI = true

        // Simulate API call - En producción, aquí se haría la llamada real a NASA TEMPO o OpenAQ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Create new air quality data with selected location
            let newAQI = Int.random(in: 50...150)
            let newPM25 = Double.random(in: 15...35)
            let newPM10 = Double.random(in: 40...80)

            self.airQualityData = AirQualityData(
                aqi: newAQI,
                pm25: newPM25,
                pm10: newPM10,
                location: locationName,
                city: cityName,
                distance: Double.random(in: 0.5...5.0),
                temperature: Double.random(in: 15...25),
                humidity: Int.random(in: 50...80),
                windSpeed: Double.random(in: 2...8),
                uvIndex: Int.random(in: 0...5),
                weatherCondition: .overcast,
                lastUpdate: Date()
            )

            // Hide loading state
            self.isLoadingAQI = false
        }
    }
}

// MARK: - Supporting Views

struct PMIndicator: View {
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(value))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct AQIScaleBar: View {
    let currentAQI: Int

    var body: some View {
        VStack(spacing: 8) {
            // Scale labels
            HStack {
                Text("Good")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Moderate")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Poor")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Unhealthy")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Severe")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Hazardous")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            // Scale bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0"),
                            Color(hex: "#F9A825"),
                            Color(hex: "#FF6F00"),
                            Color(hex: "#E53935"),
                            Color(hex: "#8E24AA"),
                            Color(hex: "#6A1B4D")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Current position indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 4)
                        .offset(x: CGFloat(currentAQI) / 301.0 * geometry.size.width - 10)
                }
            }
            .frame(height: 12)

            // Scale numbers
            HStack {
                ForEach([0, 50, 100, 150, 200, 301], id: \.self) { number in
                    Text("\(number)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    if number != 301 {
                        Spacer()
                    }
                }

                Text("301+")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct WeatherInfoItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ForecastTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? .white : .white.opacity(0.1))
                )
        }
    }
}

struct HourlyForecastItem: View {
    let hour: String
    let temp: Int
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Text(hour)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))

            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)

            Text("\(temp)°")
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Exposure Circular Chart

struct ExposureCircularChart: View {
    @State private var selectedCategory = "All"
    let categories = ["All", "Home", "Work", "Outdoor"]

    // Sample data: hours spent in each environment (today's data)
    let homeHours: CGFloat = 6
    let workHours: CGFloat = 4
    let outdoorHours: CGFloat = 3

    var totalHours: CGFloat {
        homeHours + workHours + outdoorHours
    }

    var showHome: Bool {
        selectedCategory == "All" || selectedCategory == "Home"
    }

    var showWork: Bool {
        selectedCategory == "All" || selectedCategory == "Work"
    }

    var showOutdoor: Bool {
        selectedCategory == "All" || selectedCategory == "Outdoor"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Category tabs
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    ExposureCategoryTabHome(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }

            // Circular clock-style chart
            ZStack {
                // Hour markers and labels
                ForEach(0..<24) { hour in
                    HourMarker(hour: hour, totalHours: totalHours)
                }

                // Colored segments - conditional display with animations
                ZStack {
                    // Home segment (Yellow)
                    if showHome {
                        SegmentArc(
                            startHour: 0,
                            endHour: homeHours,
                            color: Color(hex: "#FFD54F"),
                            label: "HOME",
                            hours: homeHours
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Work segment (Green)
                    if showWork {
                        SegmentArc(
                            startHour: homeHours,
                            endHour: homeHours + workHours,
                            color: Color(hex: "#81C784"),
                            label: "WORK",
                            hours: workHours
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Outdoor segment (Orange)
                    if showOutdoor {
                        SegmentArc(
                            startHour: homeHours + workHours,
                            endHour: homeHours + workHours + outdoorHours,
                            color: Color(hex: "#FFA726"),
                            label: "OUTDOOR",
                            hours: outdoorHours
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Center content
                VStack(spacing: 8) {
                    if selectedCategory == "All" {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))

                        Text("\(Int(totalHours))h")
                            .font(.title3.bold())
                            .foregroundColor(.white.opacity(0.6))

                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        let hours = selectedCategory == "Home" ? homeHours :
                                   selectedCategory == "Work" ? workHours : outdoorHours

                        Text("\(Int(hours))h")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundColor(.white)

                        Text(selectedCategory.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(height: 240)
        }
    }
}

struct ExposureCategoryTabHome: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var categoryColor: Color {
        switch title {
        case "Home": return Color(hex: "#FFD54F")
        case "Work": return Color(hex: "#81C784")
        case "Outdoor": return Color(hex: "#FFA726")
        default: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? categoryColor.opacity(0.3) : Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? categoryColor : .clear, lineWidth: 2)
                        )
                )
        }
    }
}

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.2))
                )
        }
    }
}

struct HourMarker: View {
    let hour: Int
    let totalHours: CGFloat

    var body: some View {
        VStack {
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: hour % 3 == 0 ? 2 : 1, height: hour % 3 == 0 ? 12 : 6)

            Spacer()

            if hour % 3 == 0 {
                Text("\(hour)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .offset(y: -10)
            }
        }
        .frame(width: 100, height: 100)
        .rotationEffect(.degrees(Double(hour) * 15))
    }
}

struct SegmentArc: View {
    let startHour: CGFloat
    let endHour: CGFloat
    let color: Color
    let label: String
    let hours: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: startHour / 24, to: endHour / 24)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 35
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 0)
        }
    }
}

// MARK: - Location Search Modal

struct LocationSearchModal: View {
    @Binding var searchText: String
    @Environment(\.dismiss) var dismiss
    @State private var searchResults: [String] = []
    var onLocationSelected: (String) -> Void

    let quickLocations = [
        ("Mexico City, Mexico", "mappin.circle.fill"),
        ("New York, USA", "building.2.fill"),
        ("Tokyo, Japan", "building.fill"),
        ("London, UK", "building.columns.fill"),
        ("Paris, France", "sparkles")
    ]

    var body: some View {
        ZStack {
            // Background gradient - Using app colors
            LinearGradient(
                colors: [
                    Color("Secondary"),
                    Color("Primary"),
                    Color("Secondary")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .padding(.top, 10)

                // Enhanced Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))

                    TextField("Search location...", text: $searchText)
                        .font(.body)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Results or Quick Navigation
                ScrollView {
                    if searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            // Quick Navigation Header
                            Text("Quick Navigation")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // Quick location buttons
                            VStack(spacing: 12) {
                                ForEach(quickLocations, id: \.0) { location in
                                    Button(action: {
                                        onLocationSelected(location.0)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: location.1)
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .frame(width: 40)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(location.0)
                                                    .font(.body.bold())
                                                    .foregroundColor(.white)

                                                Text("View air quality")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.white.opacity(0.15))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredLocations, id: \.self) { location in
                                Button(action: {
                                    onLocationSelected(location)
                                    dismiss()
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 40)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(location)
                                                .font(.body.bold())
                                                .foregroundColor(.white)

                                            Text("Tap to view air quality")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.white.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
    }

    var filteredLocations: [String] {
        let sampleLocations = [
            "Mexico City, Mexico",
            "New York, USA",
            "Los Angeles, USA",
            "London, UK",
            "Tokyo, Japan",
            "Paris, France",
            "Berlin, Germany",
            "Madrid, Spain"
        ]

        if searchText.isEmpty {
            return sampleLocations
        } else {
            return sampleLocations.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
    }
}


// MARK: - Day Comparison Dot

struct DayDot: View {
    let label: String
    let aqi: Int

    var dotColor: Color {
        switch aqi {
        case 0..<51: return Color(hex: "#E0E0E0")
        case 51..<101: return Color(hex: "#FDD835")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(dotColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Daily Forecast Data Model

struct DailyForecastData: Identifiable {
    let id: Int
    let date: Date
    let dayName: String
    let aqi: Int
    let temp: Int
    let weatherIcon: String
    let weatherDescription: String
    let qualityLevel: String

    var aqiColor: Color {
        switch aqi {
        case 0..<51: return Color(hex: "#E0E0E0")
        case 51..<101: return Color(hex: "#FDD835")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
}

#Preview {
    AQIHomeView(showBusinessPulse: .constant(false))
}

