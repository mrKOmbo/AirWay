//
//  AQIHomeView.swift
//  AcessNet
//
//  Created by BICHOTEE
//  Redesigned to match AirWay .pen spec — iOS 26 glass effects
//

import SwiftUI
import Combine
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
    @State private var animatedAQI: CGFloat = 0
    @State private var animateGauges: Bool = false
    @State private var currentNotifIndex: Int = 0
    @State private var showNotif: Bool = false
    @State private var notifExpanded: Bool = false
    @State private var notifDismissed: Bool = false

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
                // Background — dark solid
                Color(hex: "#0A0A0F")
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerView

                        // AQI Main Card
                        aqiMainCard

                        // AI Insight banner (collapsible, below AQI)
                        insightBanner

                        // Loading indicator
                        if isLoadingAQI {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading real-time data...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        // Error message
                        if let error = dataLoadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        // Environment Card (Pollutants + Weather)
                        environmentCard

                        // Bento Grid: Exposure + Forecast + AR + AI
                        bentoGrid

                        // Hourly / Weekly Forecast
                        hourlySection

                        // Today's Exposure Detail
                        todaysExposureView
                    }
                    .padding(.top, 16)
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
        .onAppear {
            triggerAnimations()
        }
        .onChange(of: airQualityData.aqi) { _ in
            triggerAnimations()
        }
    }

    // MARK: - AQI Animation

    private func triggerAnimations() {
        Task { @MainActor in
            animatedAQI = 0
            animateGauges = false

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            withAnimation(.easeOut(duration: 1.2)) {
                animateGauges = true
            }

            let target = CGFloat(airQualityData.aqi)
            let steps = 40

            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
                let progress = CGFloat(i) / CGFloat(steps)
                let eased = 1.0 - pow(1.0 - progress, 3)
                animatedAQI = target * eased
            }
            animatedAQI = target
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

        do {
            guard let analysisURL = URL(string: "\(backendURL)/air/analysis?lat=\(lat)&lon=\(lon)&mode=walk") else { return }
            let (analysisData, _) = try await URLSession.shared.data(from: analysisURL)

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
            }
        } catch {
            await MainActor.run { dataLoadError = "Error: \(error.localizedDescription)" }
        }

        // Best-time (independiente)
        do {
            guard let btURL = URL(string: "\(backendURL)/air/best-time?lat=\(lat)&lon=\(lon)&mode=bike&hours=12") else { return }
            let (btData, _) = try await URLSession.shared.data(from: btURL)
            let bestTime = try JSONDecoder().decode(BestTimeResponse.self, from: btData)
            await MainActor.run { bestTimeData = bestTime }
        } catch { }

        await MainActor.run { isLoadingAQI = false }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)

                    Text(airQualityData.location)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Text(airQualityData.city)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "sensor.tag.radiowaves.forward")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Monitor: \(String(format: "%.1f", airQualityData.distance)) km")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "globe.americas")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text("NASA TEMPO")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Button(action: { showSearchModal = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - AQI Main Card

    private var aqiMainCard: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(destination: DailyForecastView()) {
                VStack(spacing: 12) {
                    Text("Air Quality Index")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))

                    Text("\(Int(animatedAQI))")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: airQualityData.qualityLevel.color).opacity(0.6), radius: 20)

                    // "Good" badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: airQualityData.qualityLevel.color))
                            .frame(width: 8, height: 8)

                        Text(airQualityData.qualityLevel.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(Color(hex: airQualityData.qualityLevel.color))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: airQualityData.qualityLevel.color).opacity(0.15))
                    )
                    .opacity(animatedAQI > 0 ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: animatedAQI)

                    // Live indicator (pulsing)
                    LiveIndicator()

                    // Scale bar — animated
                    aqiScaleBar
                        .padding(.top, 8)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(glassCard)
            }

            // AR button — top right corner
            Button(action: { showARView = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arkit")
                        .font(.system(size: 12, weight: .semibold))
                    Text("AR")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.purple.opacity(0.15))
                        .overlay(
                            Capsule().stroke(.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(12)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - AQI Scale Bar

    private var aqiScaleBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Gradient bar
                    LinearGradient(
                        colors: [
                            Color(hex: "#4CAF50"),
                            Color(hex: "#8BC34A"),
                            Color(hex: "#FFEB3B"),
                            Color(hex: "#FF9800"),
                            Color(hex: "#F44336"),
                            Color(hex: "#9C27B0")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())

                    // Animated position indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: min(animatedAQI / 300.0 * geo.size.width, geo.size.width - 16))
                        .animation(.easeOut(duration: 1.5), value: animatedAQI)
                }
            }
            .frame(height: 10)

            HStack {
                Text("Good"); Spacer(); Text("Moderate"); Spacer(); Text("Poor"); Spacer(); Text("Hazardous")
            }
            .font(.system(size: 9))
            .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Environment Card (Pollutants + Weather unified)

    private var environmentCard: some View {
        VStack(spacing: 16) {
            // Pollutant gauges row
            HStack(spacing: 0) {
                MiniPollutantGauge(
                    value: Int(airQualityData.pm25),
                    maxValue: 75,
                    name: "PM2.5",
                    color: airQualityData.pm25 < 35 ? .green : .yellow
                )

                // Divider
                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)

                MiniPollutantGauge(
                    value: Int(airQualityData.pm10),
                    maxValue: 150,
                    name: "PM10",
                    color: airQualityData.pm10 < 50 ? .green : .yellow
                )

                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)

                MiniPollutantGauge(
                    value: 42,
                    maxValue: 100,
                    name: "O₃",
                    color: .white.opacity(0.7)
                )
            }

            // Thin separator
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                .padding(.horizontal, 8)

            // Weather stats row — inline, compact
            HStack(spacing: 0) {
                WeatherMiniStat(icon: "thermometer.medium", value: "\(Int(airQualityData.temperature))°C", label: "Temp")
                WeatherMiniStat(icon: "humidity.fill", value: "\(airQualityData.humidity)%", label: "Humidity")
                WeatherMiniStat(icon: "wind", value: "\(Int(airQualityData.windSpeed))", label: "km/h")
                WeatherMiniStat(icon: "sun.max.fill", value: "\(airQualityData.uvIndex)", label: "UV")
            }
        }
        .padding(.vertical, 14)
        .background(glassCard)
        .padding(.horizontal, 16)
    }

    // MARK: - Bento Grid

    private var bentoGrid: some View {
        VStack(spacing: 10) {
            // Row 1: Exposure + Forecast (side by side)
            HStack(alignment: .top, spacing: 10) {
                // Exposure gauge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 6)

                        Circle()
                            .trim(from: 0, to: animateGauges ? 0.25 : 0)
                            .stroke(
                                AngularGradient(
                                    colors: [.green, .yellow],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(90)
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0).delay(0.5), value: animateGauges)

                        VStack(spacing: 1) {
                            Text("Low")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                            Text("0.8 cig")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .frame(width: 72, height: 72)

                    Text("Exposure")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(glassCard)

                // Forecast — matches exposure height
                if let prediction = mlPrediction, prediction.model_available == true,
                   let preds = prediction.predictions {
                    VStack(spacing: 0) {
                        // Trend header
                        HStack(spacing: 4) {
                            Text("Forecast")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            if let trend = prediction.trend {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(trend == "subiendo" ? Color.orange : trend == "bajando" ? Color.green : Color.white.opacity(0.4))
                                        .frame(width: 5, height: 5)
                                    Text(trend == "subiendo" ? "Worsening" : trend == "bajando" ? "Improving" : "Stable")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(trend == "subiendo" ? .orange : trend == "bajando" ? .green : .white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                        // Bar chart area
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(["1h", "3h", "6h"], id: \.self) { key in
                                if let p = preds[key] {
                                    let aqiColor = aqiLevelColor(p.aqi)
                                    let barFill = max(0.15, min(CGFloat(p.aqi) / 200.0, 1.0))

                                    VStack(spacing: 0) {
                                        // AQI value
                                        Text("\(p.aqi)")
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundColor(aqiColor)
                                            .padding(.bottom, 4)

                                        // Bar
                                        GeometryReader { geo in
                                            VStack {
                                                Spacer()
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [aqiColor.opacity(0.3), aqiColor.opacity(0.7), aqiColor],
                                                            startPoint: .bottom,
                                                            endPoint: .top
                                                        )
                                                    )
                                                    .frame(height: geo.size.height * barFill)
                                                    .shadow(color: aqiColor.opacity(0.4), radius: 6, y: -2)
                                            }
                                        }

                                        // Time label
                                        Text(key)
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.35))
                                            .padding(.top, 4)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .background(glassCard)
                }
            }

            // Row 2: Best Time (full width)
            if let bestTime = bestTimeData, let best = bestTime.best_window {
                HStack(spacing: 12) {
                    // Best window
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Go out")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Text(formatTimeWindow(best.start, best.end))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("AQI \(best.avg_aqi)")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Avoid window
                    if let worst = bestTime.worst_window {
                        Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.7))
                                Text("Avoid")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Text(formatTimeWindow(worst.start, worst.end))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("AQI \(worst.avg_aqi)")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(glassCard)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Insight Notifications (auto-rotate)

    private var insightNotifications: [InsightNotif] {
        var notifs: [InsightNotif] = []

        if let analysis = aiAnalysis {
            if let summary = analysis.summary {
                let short = String(summary.prefix(60)) + (summary.count > 60 ? "…" : "")
                notifs.append(InsightNotif(icon: "sparkles", color: .purple, text: short, fullText: summary))
            }
            if let rec = analysis.health_recommendation {
                let short = String(rec.prefix(55)) + (rec.count > 55 ? "…" : "")
                notifs.append(InsightNotif(icon: "heart.fill", color: .red, text: short, fullText: rec))
            }
            if let hours = analysis.best_hours, !hours.isEmpty {
                let short = String(hours.prefix(50)) + (hours.count > 50 ? "…" : "")
                notifs.append(InsightNotif(icon: "clock.fill", color: .yellow, text: short, fullText: hours))
            }
        }

        if let prediction = mlPrediction, let trend = prediction.trend {
            let short = trend == "subiendo" ? "Air quality worsening ahead" : trend == "bajando" ? "Air quality improving" : "Air quality stable"
            notifs.append(InsightNotif(icon: "chart.line.uptrend.xyaxis", color: .cyan, text: short, fullText: short))
        }

        return notifs
    }

    private var insightBanner: some View {
        let notifs = insightNotifications

        return Group {
            if !notifs.isEmpty && showNotif && !notifDismissed {
                let notif = notifs[currentNotifIndex % notifs.count]

                VStack(alignment: .leading, spacing: 0) {
                    // Main row — tap to expand, swipe to dismiss
                    HStack(spacing: 10) {
                        Image(systemName: notif.icon)
                            .font(.system(size: 11))
                            .foregroundColor(notif.color)

                        Text(notifExpanded ? notif.fullText : notif.text)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(notifExpanded ? 5 : 1)
                            .fixedSize(horizontal: false, vertical: notifExpanded)

                        Spacer(minLength: 4)

                        if !notifExpanded {
                            // Dots + dismiss
                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    ForEach(0..<notifs.count, id: \.self) { i in
                                        Circle()
                                            .fill(i == currentNotifIndex % notifs.count ? .white.opacity(0.6) : .white.opacity(0.15))
                                            .frame(width: 4, height: 4)
                                    }
                                }

                                Button {
                                    // Dismiss solo este mensaje, avanza al siguiente
                                    let notifs = insightNotifications
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showNotif = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        currentNotifIndex += 1
                                        // Si ya recorrió todos, ocultar
                                        if currentNotifIndex >= notifs.count {
                                            notifDismissed = true
                                        } else {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                showNotif = true
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(.white.opacity(0.08)))
                                }
                            }
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    notifExpanded = false
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            notifExpanded.toggle()
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(notif.color.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(currentNotifIndex)
            }
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            let notifs = insightNotifications
            guard notifs.count > 1, !notifExpanded, !notifDismissed else { return }

            withAnimation(.easeOut(duration: 0.3)) {
                showNotif = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentNotifIndex += 1
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showNotif = true
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showNotif = true
                }
            }
        }
        .onChange(of: aiAnalysis?.summary) { _ in
            currentNotifIndex = 0
            notifDismissed = false
            notifExpanded = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showNotif = true
            }
        }
    }

    private func aqiLevelColor(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<51: return Color(hex: "#4CAF50")    // Green — Good
        case 51..<101: return Color(hex: "#FFEB3B")   // Yellow — Moderate
        case 101..<151: return Color(hex: "#FF9800")  // Orange — Unhealthy for sensitive
        case 151..<201: return Color(hex: "#F44336")  // Red — Unhealthy
        case 201..<301: return Color(hex: "#9C27B0")  // Purple — Very unhealthy
        default: return Color(hex: "#880E4F")         // Maroon — Hazardous
        }
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

    // MARK: - Hourly Section (inside single glass card)

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hourly")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 0) {
                    ForecastPill(title: "Today", isSelected: selectedForecastTab == .hourly) {
                        withAnimation(.none) { selectedForecastTab = .hourly }
                    }
                    ForecastPill(title: "Week", isSelected: selectedForecastTab == .daily) {
                        withAnimation(.none) { selectedForecastTab = .daily }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
            }
            .padding(.horizontal, 16)

            if selectedForecastTab == .hourly {
                // Hourly inline inside glass card
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        HourlyInlineItem(hour: "Now", aqi: airQualityData.aqi, icon: "cloud.fill", isNow: true)
                        HourlyInlineItem(hour: "1PM", aqi: 45, icon: "sun.max.fill")
                        HourlyInlineItem(hour: "2PM", aqi: 51, icon: "cloud.sun.fill")
                        HourlyInlineItem(hour: "3PM", aqi: 58, icon: "cloud.bolt.fill")
                        HourlyInlineItem(hour: "4PM", aqi: 48, icon: "cloud.fill")
                        HourlyInlineItem(hour: "5PM", aqi: 39, icon: "sun.max.fill")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .background(glassCard)
                .padding(.horizontal, 16)
                .transition(.identity)
            } else {
                // Weekly compact list inside glass card
                VStack(spacing: 0) {
                    ForEach(generateDailyForecasts()) { forecast in
                        NavigationLink(destination: DailyForecastView()) {
                            DailyCompactRow(forecast: forecast)
                        }
                        if forecast.id < 4 {
                            Rectangle().fill(.white.opacity(0.04)).frame(height: 1)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background(glassCard)
                .padding(.horizontal, 16)
                .transition(.identity)
            }
        }
    }

    // MARK: - Today's Exposure (compact)

    private var todaysExposureView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's exposure")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ExposureCircularChart()
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Weather Forecast (removed — merged into hourly "Week" tab)

    private func generateDailyForecasts() -> [DailyForecastData] {
        let calendar = Calendar.current
        let today = Date()

        return [
            DailyForecastData(id: 0, date: calendar.date(byAdding: .day, value: 0, to: today)!, dayName: "Today", aqi: 58, temp: 16, weatherIcon: "cloud.rain.fill", weatherDescription: "Rainy", qualityLevel: "Moderate"),
            DailyForecastData(id: 1, date: calendar.date(byAdding: .day, value: 1, to: today)!, dayName: "Tomorrow", aqi: 45, temp: 17, weatherIcon: "cloud.sun.fill", weatherDescription: "Partly Cloudy", qualityLevel: "Good"),
            DailyForecastData(id: 2, date: calendar.date(byAdding: .day, value: 2, to: today)!, dayName: "Saturday", aqi: 62, temp: 18, weatherIcon: "cloud.fill", weatherDescription: "Cloudy", qualityLevel: "Moderate"),
            DailyForecastData(id: 3, date: calendar.date(byAdding: .day, value: 3, to: today)!, dayName: "Sunday", aqi: 38, temp: 19, weatherIcon: "sun.max.fill", weatherDescription: "Sunny", qualityLevel: "Good"),
            DailyForecastData(id: 4, date: calendar.date(byAdding: .day, value: 4, to: today)!, dayName: "Monday", aqi: 71, temp: 15, weatherIcon: "cloud.drizzle.fill", weatherDescription: "Drizzle", qualityLevel: "Moderate")
        ]
    }

    // MARK: - Glass Card Background

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Insight Notification Model

struct InsightNotif {
    let icon: String
    let color: Color
    let text: String
    let fullText: String
}

// MARK: - Animated Counter (uses Animatable for smooth interpolation)

struct AnimatedCounter: View, Animatable {
    var value: CGFloat

    var animatableData: CGFloat {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value))")
    }
}

// MARK: - Live Indicator (pulsing red dot)

struct LiveIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)

                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }

            Text("Live")
                .font(.caption2.bold())
                .foregroundColor(.red.opacity(0.8))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Mini Pollutant Gauge (compact, inside unified card)

struct MiniPollutantGauge: View {
    let value: Int
    let maxValue: Int
    let name: String
    let color: Color

    @State private var animatedProgress: CGFloat = 0
    @State private var displayValue: Int = 0

    private var percentage: CGFloat {
        min(CGFloat(value) / CGFloat(maxValue), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0).delay(0.4), value: animatedProgress)

                Text("\(displayValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)

            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            animatedProgress = 0
            displayValue = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animatedProgress = percentage

                // Counter
                let steps = 20
                let interval = 1.0 / Double(steps)
                for i in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                        displayValue = Int(Double(value) * Double(i) / Double(steps))
                    }
                }
            }
        }
    }
}

// MARK: - Weather Mini Stat (compact, inside unified card)

struct WeatherMiniStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hourly Card

struct HourlyCard: View {
    let hour: String
    let aqi: Int
    let icon: String
    var isNow: Bool = false

    private var aqiColor: Color {
        switch aqi {
        case 0..<51: return .green
        case 51..<101: return .yellow
        case 101..<151: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(hour)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)

            Text("\(aqi)")
                .font(.headline.bold())
                .foregroundColor(aqiColor)
        }
        .frame(width: 60)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(isNow ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(isNow ? 0.15 : 0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Forecast Pill

struct ForecastPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? .white.opacity(0.15) : .clear)
                )
        }
    }
}

// MARK: - Hourly Inline Item (inside single glass card)

struct HourlyInlineItem: View {
    let hour: String
    let aqi: Int
    let icon: String
    var isNow: Bool = false

    private var aqiColor: Color {
        switch aqi {
        case 0..<51: return Color(hex: "#4CAF50")
        case 51..<101: return Color(hex: "#FFEB3B")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#F44336")
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(hour)
                .font(.system(size: 10, weight: isNow ? .bold : .regular))
                .foregroundColor(isNow ? .white : .white.opacity(0.4))

            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .symbolRenderingMode(.multicolor)

            Text("\(aqi)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(aqiColor)
        }
        .frame(width: 52)
        .padding(.vertical, 4)
        .background(
            isNow ?
                RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)) :
                RoundedRectangle(cornerRadius: 12).fill(.clear)
        )
    }
}

// MARK: - Daily Compact Row (inside glass card)

struct DailyCompactRow: View {
    let forecast: DailyForecastData

    var body: some View {
        HStack(spacing: 0) {
            // Day
            Text(forecast.dayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)

            // Weather icon
            Image(systemName: forecast.weatherIcon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .symbolRenderingMode(.multicolor)
                .frame(width: 30)

            Spacer()

            // AQI bar mini
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(forecast.aqiColor)
                            .frame(width: geo.size.width * min(CGFloat(forecast.aqi) / 150.0, 1.0))
                    }
                }
                .frame(height: 4)

                Text("\(forecast.aqi)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(forecast.aqiColor)
                    .frame(width: 28, alignment: .trailing)
            }
            .frame(width: 100)

            // Temp
            Text("\(forecast.temp)°")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 30, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.15))
                .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Daily Forecast Card (Redesigned)

struct DailyForecastCard: View {
    let forecast: DailyForecastData

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(forecast.dayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(formatDate(forecast.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 85, alignment: .leading)

            VStack(spacing: 4) {
                Text("\(forecast.aqi)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("AQI")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(forecast.aqiColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(forecast.aqiColor.opacity(0.5), lineWidth: 1)
                    )
            )

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(forecast.weatherDescription)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(forecast.temp)°C")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Image(systemName: forecast.weatherIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 35)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views (preserved)

struct AQIScaleBar: View {
    let currentAQI: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Good"); Spacer(); Text("Moderate"); Spacer(); Text("Poor"); Spacer(); Text("Hazardous")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.4))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Color(hex: "#4CAF50"), Color(hex: "#FFEB3B"),
                            Color(hex: "#FF9800"), Color(hex: "#F44336"),
                            Color(hex: "#9C27B0")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())

                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 4)
                        .offset(x: CGFloat(currentAQI) / 301.0 * geometry.size.width - 8)
                }
            }
            .frame(height: 10)
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
                Text(value).font(.title3.bold()).foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundColor(.white.opacity(0.6))
                }
            }
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.6))
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
                .foregroundColor(isSelected ? .black : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? .white : .white.opacity(0.08))
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
            Text(hour).font(.caption).foregroundColor(.white.opacity(0.6))
            Image(systemName: icon).font(.title2).foregroundColor(.white).symbolRenderingMode(.multicolor)
            Text("\(temp)°").font(.title3.bold()).foregroundColor(.white)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Exposure Circular Chart

// MARK: - Exposure Activity Rings (Apple-style)

struct ExposureCircularChart: View {
    @State private var animate = false

    let homeHours: CGFloat = 6
    let workHours: CGFloat = 4
    let outdoorHours: CGFloat = 3

    var totalHours: CGFloat { homeHours + workHours + outdoorHours }

    private let ringSize: CGFloat = 140
    private let strokeWidth: CGFloat = 12

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            // Rings
            ZStack {
                // Outdoor — outer ring
                ExposureRing(
                    progress: animate ? outdoorHours / 12 : 0,
                    color: Color(hex: "#FFA726"),
                    size: ringSize,
                    strokeWidth: strokeWidth
                )

                // Work — middle ring
                ExposureRing(
                    progress: animate ? workHours / 12 : 0,
                    color: Color(hex: "#81C784"),
                    size: ringSize - (strokeWidth * 2 + 6),
                    strokeWidth: strokeWidth
                )

                // Home — inner ring
                ExposureRing(
                    progress: animate ? homeHours / 12 : 0,
                    color: Color(hex: "#FFD54F"),
                    size: ringSize - (strokeWidth * 4 + 12),
                    strokeWidth: strokeWidth
                )

                // Center total
                VStack(spacing: 1) {
                    Text("\(Int(totalHours))h")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Total")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: ringSize, height: ringSize)

            Spacer(minLength: 16)

            // Legend
            VStack(alignment: .leading, spacing: 12) {
                ExposureLegendItem(color: Color(hex: "#FFA726"), label: "Outdoor", hours: outdoorHours, total: 12)
                ExposureLegendItem(color: Color(hex: "#81C784"), label: "Work", hours: workHours, total: 12)
                ExposureLegendItem(color: Color(hex: "#FFD54F"), label: "Home", hours: homeHours, total: 12)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                animate = true
            }
        }
    }
}

struct ExposureRing: View {
    let progress: CGFloat
    let color: Color
    let size: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 4)
        }
    }
}

struct ExposureLegendItem: View {
    let color: Color
    let label: String
    let hours: CGFloat
    let total: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 4) {
                    Text("\(Int(hours))h")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("/ \(Int(total))h")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }
}

struct PMIndicator: View {
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(value))").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                Text(unit).font(.caption).foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        )
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
            Color(hex: "#0A0A0F").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .padding(.top, 10)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))

                    TextField("Search location...", text: $searchText)
                        .font(.body)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                ScrollView {
                    if searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Quick Navigation")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            VStack(spacing: 12) {
                                ForEach(quickLocations, id: \.0) { location in
                                    Button(action: {
                                        onLocationSelected(location.0)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: location.1)
                                                .font(.title2).foregroundColor(.white).frame(width: 40)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(location.0).font(.body.bold()).foregroundColor(.white)
                                                Text("View air quality").font(.caption).foregroundColor(.white.opacity(0.5))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.white.opacity(0.08))
                                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
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
                                        Image(systemName: "mappin.circle.fill").font(.title2).foregroundColor(.white).frame(width: 40)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(location).font(.body.bold()).foregroundColor(.white)
                                            Text("Tap to view air quality").font(.caption).foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.white.opacity(0.08))
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
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
            "Mexico City, Mexico", "New York, USA", "Los Angeles, USA",
            "London, UK", "Tokyo, Japan", "Paris, France",
            "Berlin, Germany", "Madrid, Spain"
        ]
        if searchText.isEmpty { return sampleLocations }
        return sampleLocations.filter { $0.lowercased().contains(searchText.lowercased()) }
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
            Circle().fill(dotColor).frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.6))
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
        case 0..<51: return Color(hex: "#4CAF50")
        case 51..<101: return Color(hex: "#FDD835")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
}

extension AQIHomeView {
    fileprivate func handleLocationSelection(_ locationString: String) {
        let components = locationString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let locationName = components.first ?? locationString
        let cityName = locationString
        fetchAQIData(locationName: locationName, cityName: cityName)
    }

    fileprivate func fetchAQIData(locationName: String, cityName: String) {
        isLoadingAQI = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
            self.isLoadingAQI = false
        }
    }
}

#Preview {
    AQIHomeView(showBusinessPulse: .constant(false))
}
