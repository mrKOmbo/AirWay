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
import Charts
import MapKit

struct AQIHomeView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Binding var showBusinessPulse: Bool
    @State private var airQualityData: AirQualityData = .sample
    @State private var selectedForecastTab: ForecastTab = .hourly
    @State private var showSearchModal = false
    @State private var searchText = ""
    @State private var showARView = false
    @State private var showContingencyCast = false
    @State private var isLoadingAQI: Bool = false

    // ML Prediction data
    @State private var mlPrediction: MLPredictionResponse?
    @State private var aiAnalysis: AIAnalysisResponse?
    @State private var bestTimeData: BestTimeResponse?
    @State private var dataLoadError: String?
    @State private var hasLoadedBackend: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var animatedAQI: CGFloat = 0
    @State private var animateGauges: Bool = false
    @State private var currentNotifIndex: Int = 0
    @State private var showNotif: Bool = false
    @State private var notifExpanded: Bool = false
    @State private var notifDismissed: Bool = false
    @AppStorage("aiNotificationsEnabled") private var aiNotificationsEnabled: Bool = true
    @State private var pressedPollutant: PollutantInfo?
    @State private var pressedForecast: ForecastDetailInfo?
    @State private var pressingExposure: Bool = false
    @State private var showExposure: Bool = false
    @State private var hourlyForecast: [HourlyPoint] = []
    @State private var hourlyForecastFull: [HourlyPoint] = []
    @State private var weeklyForecast: [DailyWeatherPoint] = []
    @State private var showConditionsDetail: Bool = false

    // Editable layout
    @State private var sectionOrder: [HomeSection] = HomeSection.allCases
    @State private var hiddenSections: Set<HomeSection> = []
    @State private var isEditMode: Bool = false
    @State private var sectionFrames: [HomeSection: CGRect] = [:]
    @State private var draggingSection: HomeSection? = nil
    @State private var dragStartY: CGFloat = 0
    @AppStorage("homeSectionOrder_v1") private var sectionOrderRaw: String = ""
    @AppStorage("homeHiddenSections_v1") private var hiddenSectionsRaw: String = ""

    enum ForecastTab {
        case hourly
        case daily
    }

    enum HomeSection: String, CaseIterable, Identifiable, Codable {
        case aqiCard
        case insightBanner
        case environmentCard
        case bentoGrid
        case hourly
        case todaysExposure

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .aqiCard:         return "Air Quality Index"
            case .insightBanner:   return "Insights"
            case .environmentCard: return "Environment"
            case .bentoGrid:       return "Exposure & Forecast"
            case .hourly:          return "Hourly / Weekly"
            case .todaysExposure:  return "Today's Exposure"
            }
        }

        var icon: String {
            switch self {
            case .aqiCard:         return "aqi.medium"
            case .insightBanner:   return "sparkles"
            case .environmentCard: return "leaf.fill"
            case .bentoGrid:       return "square.grid.2x2.fill"
            case .hourly:          return "clock.fill"
            case .todaysExposure:  return "chart.pie.fill"
            }
        }
    }

    init(showBusinessPulse: Binding<Bool>) {
        self._showBusinessPulse = showBusinessPulse

        // Restore persisted order
        let storedOrder = UserDefaults.standard.string(forKey: "homeSectionOrder_v1") ?? ""
        let parsed = storedOrder.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) }
        let missing = HomeSection.allCases.filter { !parsed.contains($0) }
        _sectionOrder = State(initialValue: parsed + missing)

        // Restore hidden
        let storedHidden = UserDefaults.standard.string(forKey: "homeHiddenSections_v1") ?? ""
        let hiddenSet = Set(storedHidden.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) })
        _hiddenSections = State(initialValue: hiddenSet)
    }

    private var visibleSections: [HomeSection] {
        sectionOrder.filter { !hiddenSections.contains($0) }
    }

    private func persistLayout() {
        sectionOrderRaw = sectionOrder.map(\.rawValue).joined(separator: ",")
        hiddenSectionsRaw = hiddenSections.map(\.rawValue).joined(separator: ",")
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background — dynamic weather
                WeatherBackground(condition: activeWeather)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header (fixed at top — not reorderable)
                        headerView

                        // Error message
                        if let error = dataLoadError, !hasLoadedBackend {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        // Reorderable sections
                        ForEach(visibleSections) { section in
                            sectionView(for: section)
                                .allowsHitTesting(!isEditMode)
                                .overlay(alignment: .topTrailing) {
                                    if isEditMode { editHideButton(for: section) }
                                }
                                .overlay(alignment: .topLeading) {
                                    if isEditMode { editDragHandle(for: section) }
                                }
                                .modifier(JiggleModifier(active: isEditMode, seed: section.rawValue))
                                .padding(.horizontal, isEditMode ? 6 : 0)
                                .padding(.vertical, isEditMode ? 4 : 0)
                                .background(editModeBackground(isActive: isEditMode))
                                .scaleEffect(draggingSection == section ? 1.03 : 1.0)
                                .shadow(color: .black.opacity(draggingSection == section ? 0.4 : 0), radius: 12, y: 4)
                                .zIndex(draggingSection == section ? 10 : 0)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: SectionFramePreferenceKey.self,
                                            value: [section: geo.frame(in: .named("homeScroll"))]
                                        )
                                    }
                                )
                        }

                        if isEditMode && !hiddenSections.isEmpty {
                            hiddenSectionsPanel
                        }
                    }
                    .padding(.top, 16)
                    .avoidTabBar(extraPadding: 20)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sectionOrder)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: hiddenSections)
                    .animation(.easeInOut(duration: 0.25), value: isEditMode)
                }
                .coordinateSpace(name: "homeScroll")
                .onPreferenceChange(SectionFramePreferenceKey.self) { frames in
                    sectionFrames = frames
                }

                if let info = pressedPollutant {
                    PollutantDetailOverlay(info: info)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(100)
                        .allowsHitTesting(false)
                }

                if let info = pressedForecast {
                    ForecastDetailOverlay(info: info)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(100)
                        .allowsHitTesting(false)
                }

                if showExposure {
                    ExposureMapOverlay(isPresented: $showExposure)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(100)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showARView) {
            ARParticlesView()
        }
        .sheet(isPresented: $showContingencyCast) {
            NavigationStack {
                ContingencyCastView()
            }
        }
        .sheet(isPresented: $showSearchModal) {
            LocationSearchModal(
                searchText: $searchText,
                currentCondition: activeWeather,
                onLocationSelected: handleLocationSelection
            )
        }
        .sheet(isPresented: $showConditionsDetail) {
            WeatherConditionsDetailView(
                currentCondition: activeWeather,
                hourly: hourlyForecastFull.isEmpty ? hourlyForecast : hourlyForecastFull,
                daily: weeklyForecast
            )
        }
        .environment(\.weatherTheme, theme)
        .task {
            await loadHourlyForecast()
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

    // MARK: - Section Builder (reorderable)

    @ViewBuilder
    private func sectionView(for section: HomeSection) -> some View {
        switch section {
        case .aqiCard:         aqiMainCard
        case .insightBanner:   insightBanner
        case .environmentCard: environmentCard
        case .bentoGrid:       bentoGrid
        case .hourly:          hourlySection
        case .todaysExposure:  todaysExposureView
        }
    }

    // MARK: - Edit Mode Controls

    private func editHideButton(for section: HomeSection) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                hiddenSections.insert(section)
            }
            persistLayout()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.red))
                .shadow(color: .black.opacity(0.3), radius: 4)
        }
        .offset(x: -2, y: -8)
        .transition(.scale.combined(with: .opacity))
    }

    private func editDragHandle(for section: HomeSection) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.white.opacity(0.9))
            .frame(width: 28, height: 24)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .offset(x: 8, y: -8)
            .contentShape(Rectangle())
            .gesture(reorderGesture(for: section))
            .transition(.scale.combined(with: .opacity))
    }

    private func editModeBackground(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(isActive ? 0.03 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.white.opacity(0.1) : .clear,
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
    }

    private var hiddenSectionsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("HIDDEN SECTIONS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
            }
            .foregroundColor(.white.opacity(0.55))

            VStack(spacing: 8) {
                ForEach(HomeSection.allCases.filter { hiddenSections.contains($0) }) { section in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            hiddenSections.remove(section)
                        }
                        persistLayout()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.white.opacity(0.08)))

                            Text(section.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Reorder Drag Gesture

    private func reorderGesture(for section: HomeSection) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("homeScroll"))
            .onChanged { value in
                if draggingSection == nil {
                    draggingSection = section
                    dragStartY = sectionFrames[section]?.midY ?? value.startLocation.y
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                let fingerY = dragStartY + value.translation.height
                attemptReorder(currentlyDragging: section, fingerY: fingerY)
            }
            .onEnded { _ in
                draggingSection = nil
                persistLayout()
            }
    }

    private func attemptReorder(currentlyDragging section: HomeSection, fingerY: CGFloat) {
        // Find the section whose vertical range contains fingerY
        let others = visibleSections.filter { $0 != section }
        for other in others {
            guard let frame = sectionFrames[other] else { continue }
            if fingerY >= frame.minY && fingerY <= frame.maxY,
               let from = sectionOrder.firstIndex(of: section),
               let to = sectionOrder.firstIndex(of: other) {
                let dest = to > from ? to + 1 : to
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    sectionOrder.move(fromOffsets: IndexSet(integer: from), toOffset: dest)
                }
                return
            }
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

    // MARK: - Smart Backend Loading (3-layer cache)
    //
    // Layer 1: Cache — load instantly from UserDefaults on open
    // Layer 2: Quick AQI check — fetch /air/current (fast, no Gemini)
    // Layer 3: Delta check — only call /air/analysis (with Gemini) if AQI changed ±10
    //
    // TTL: AQI data = 15 min, AI analysis = 30 min
    //

    private static let aqiTTL: TimeInterval = 15 * 60       // 15 minutes
    private static let aiAnalysisTTL: TimeInterval = 30 * 60 // 30 minutes
    private static let deltaThreshold: Int = 10              // AQI change to trigger Gemini

    private func loadBackendData() async {
        // --- Layer 1: Load cache instantly ---
        await MainActor.run {
            loadCachedData()
            dataLoadError = nil
        }

        let cachedAQI = airQualityData.aqi
        let lat = 19.4326
        let lon = -99.1332
        let backendURL = "https://airway-api.onrender.com/api/v1"

        // Check if AQI cache is still fresh
        let aqiCacheAge = Date().timeIntervalSince1970 - (UserDefaults.standard.double(forKey: "aqi_cache_timestamp"))
        let aiCacheAge = Date().timeIntervalSince1970 - (UserDefaults.standard.double(forKey: "ai_cache_timestamp"))

        let aqiStale = aqiCacheAge > Self.aqiTTL || cachedAQI == 0
        let aiStale = aiCacheAge > Self.aiAnalysisTTL

        // If nothing is stale, skip entirely
        if !aqiStale && !aiStale && hasLoadedBackend {
            print("[CACHE] AQI fresh (\(Int(aqiCacheAge))s), AI fresh (\(Int(aiCacheAge))s) — skipping fetch")
            return
        }

        await MainActor.run { withAnimation { isRefreshing = true } }

        // --- Layer 2: Quick AQI fetch (no Gemini) ---
        var freshAQI: Int = cachedAQI
        var freshAnalysis: AnalysisResponse?

        if aqiStale {
            do {
                guard let quickURL = URL(string: "\(backendURL)/air/analysis?lat=\(lat)&lon=\(lon)&mode=walk&skip_ai=true") else { return }
                let (data, _) = try await URLSession.shared.data(from: quickURL)
                let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)
                freshAQI = analysis.combined_aqi
                freshAnalysis = analysis

                await MainActor.run {
                    airQualityData = AirQualityData(
                        aqi: analysis.combined_aqi,
                        pm25: analysis.pollutants?.pm25?.value ?? 0,
                        pm10: analysis.pollutants?.pm10?.value ?? 0,
                        o3: analysis.pollutants?.o3?.value ?? 0,
                        location: "CDMX Centro",
                        city: "Ciudad de M\u{00E9}xico",
                        distance: 0,
                        temperature: 18,
                        humidity: 55,
                        windSpeed: 5,
                        uvIndex: 0,
                        weatherCondition: .cloudy,
                        lastUpdate: Date()
                    )
                    // Keep cached AI analysis if skip_ai returned nil
                    if let ml = analysis.ml_prediction { mlPrediction = ml }
                    hasLoadedBackend = true
                    cacheAQIData()
                }

                print("[CACHE] Quick AQI: \(freshAQI) (was \(cachedAQI), delta=\(abs(freshAQI - cachedAQI)))")
            } catch {
                await MainActor.run {
                    if !hasLoadedBackend { dataLoadError = "Error: \(error.localizedDescription)" }
                }
            }
        }

        // --- Layer 3: Delta check — only call Gemini if AQI changed significantly ---
        let delta = abs(freshAQI - cachedAQI)
        let needsAI = aiStale && (delta >= Self.deltaThreshold || aiAnalysis == nil)

        if needsAI {
            print("[CACHE] AI stale + delta=\(delta) >= \(Self.deltaThreshold) — calling Gemini")
            do {
                guard let fullURL = URL(string: "\(backendURL)/air/analysis?lat=\(lat)&lon=\(lon)&mode=walk") else { return }
                let (data, _) = try await URLSession.shared.data(from: fullURL)
                let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)

                await MainActor.run {
                    aiAnalysis = analysis.ai_analysis
                    if let ml = analysis.ml_prediction { mlPrediction = ml }
                    cacheAIAnalysis()
                }
                print("[CACHE] Gemini analysis updated")
            } catch {
                print("[CACHE] Gemini call failed: \(error.localizedDescription) — keeping cached AI")
            }
        } else if aiStale && delta < Self.deltaThreshold {
            print("[CACHE] AI stale but delta=\(delta) < \(Self.deltaThreshold) — reusing cached AI")
            // Just refresh the AI timestamp so we don't re-check for another 30min
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "ai_cache_timestamp")
        }

        // Best-time (independent, low cost)
        do {
            guard let btURL = URL(string: "\(backendURL)/air/best-time?lat=\(lat)&lon=\(lon)&mode=bike&hours=12") else { return }
            let (btData, _) = try await URLSession.shared.data(from: btURL)
            let bestTime = try JSONDecoder().decode(BestTimeResponse.self, from: btData)
            await MainActor.run { bestTimeData = bestTime }
        } catch { }

        await MainActor.run {
            withAnimation { isRefreshing = false }
            isLoadingAQI = false
        }
    }

    // MARK: - Cache (UserDefaults)

    private func cacheAQIData() {
        let cached: [String: Any] = [
            "aqi": airQualityData.aqi,
            "pm25": airQualityData.pm25,
            "pm10": airQualityData.pm10,
            "o3": airQualityData.o3,
            "location": airQualityData.location,
            "city": airQualityData.city,
            "temperature": airQualityData.temperature,
            "humidity": airQualityData.humidity,
            "windSpeed": airQualityData.windSpeed,
        ]
        UserDefaults.standard.set(cached, forKey: "aqi_cached_data")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "aqi_cache_timestamp")
    }

    private func cacheAIAnalysis() {
        if let ai = aiAnalysis, let data = try? JSONEncoder().encode(ai) {
            UserDefaults.standard.set(data, forKey: "ai_cached_analysis")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "ai_cache_timestamp")
        }
        if let ml = mlPrediction, let data = try? JSONEncoder().encode(ml) {
            UserDefaults.standard.set(data, forKey: "ml_cached_prediction")
        }
    }

    private func loadCachedData() {
        // Load AQI data
        if let cached = UserDefaults.standard.dictionary(forKey: "aqi_cached_data"),
           let aqi = cached["aqi"] as? Int, aqi > 0 {

            airQualityData = AirQualityData(
                aqi: aqi,
                pm25: cached["pm25"] as? Double ?? 0,
                pm10: cached["pm10"] as? Double ?? 0,
                o3: cached["o3"] as? Double ?? 0,
                location: cached["location"] as? String ?? "CDMX",
                city: cached["city"] as? String ?? "Ciudad de M\u{00E9}xico",
                distance: 0,
                temperature: cached["temperature"] as? Double ?? 18,
                humidity: cached["humidity"] as? Int ?? 55,
                windSpeed: cached["windSpeed"] as? Double ?? 5,
                uvIndex: 0,
                weatherCondition: .cloudy,
                lastUpdate: Date()
            )
            hasLoadedBackend = true
        }

        // Load cached AI analysis
        if let aiData = UserDefaults.standard.data(forKey: "ai_cached_analysis"),
           let ai = try? JSONDecoder().decode(AIAnalysisResponse.self, from: aiData) {
            aiAnalysis = ai
        }

        // Load cached ML prediction
        if let mlData = UserDefaults.standard.data(forKey: "ml_cached_prediction"),
           let ml = try? JSONDecoder().decode(MLPredictionResponse.self, from: mlData) {
            mlPrediction = ml
        }
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
                // Edit layout toggle
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isEditMode.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if !isEditMode { persistLayout() }
                } label: {
                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(isEditMode ? .green : .white.opacity(0.7))
                }

                // ContingencyCast — pronóstico probabilístico 48-72h
                Button(action: { showContingencyCast = true }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.orange.opacity(0.35), .red.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)
                        Image(systemName: "wind.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        aiNotificationsEnabled.toggle()
                        if aiNotificationsEnabled {
                            notifDismissed = false
                            currentNotifIndex = 0
                            showNotif = true
                        } else {
                            showNotif = false
                            notifExpanded = false
                        }
                    }
                }) {
                    Image(systemName: aiNotificationsEnabled ? "bell.fill" : "bell.slash")
                        .font(.title3)
                        .foregroundColor(aiNotificationsEnabled ? .white : .white.opacity(0.4))
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
                    color: pm25Status(Int(airQualityData.pm25)).1,
                    onPressChange: { pressing in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pressedPollutant = pressing ? pm25Info() : nil
                        }
                    }
                )

                // Divider
                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)

                MiniPollutantGauge(
                    value: Int(airQualityData.pm10),
                    maxValue: 150,
                    name: "PM10",
                    color: pm10Status(Int(airQualityData.pm10)).1,
                    onPressChange: { pressing in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pressedPollutant = pressing ? pm10Info() : nil
                        }
                    }
                )

                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)

                MiniPollutantGauge(
                    value: Int(airQualityData.o3),
                    maxValue: 100,
                    name: "O₃",
                    color: o3Status(Int(airQualityData.o3)).1,
                    onPressChange: { pressing in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pressedPollutant = pressing ? o3Info() : nil
                        }
                    }
                )
            }

            // Thin separator
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                .padding(.horizontal, 8)

            // Weather stats row — inline, compact
            HStack(spacing: 0) {
                AnimatedWeatherStat(kind: .temperature(airQualityData.temperature))
                AnimatedWeatherStat(kind: .humidity(airQualityData.humidity))
                AnimatedWeatherStat(kind: .wind(airQualityData.windSpeed))
                AnimatedWeatherStat(kind: .uv(airQualityData.uvIndex))
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
                // Exposure gauge (animated bento)
                ExposureBentoCard(level: "Low", cigValue: 0.8, progress: 0.25, color: .green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(glassCard)
                .scaleEffect(pressingExposure ? 1.04 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressingExposure)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30, pressing: { pressing in
                    pressingExposure = pressing
                }, perform: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showExposure = true
                    }
                })

                // Forecast — sparkline card
                if let prediction = mlPrediction, prediction.model_available == true,
                   let preds = prediction.predictions {
                    let pts: [ForecastSparklineCard.Point] = [
                        .init(label: "Now", aqi: Int(airQualityData.aqi)),
                        preds["1h"].map { .init(label: "+1h", aqi: $0.aqi) },
                        preds["3h"].map { .init(label: "+3h", aqi: $0.aqi) },
                        preds["6h"].map { .init(label: "+6h", aqi: $0.aqi) }
                    ].compactMap { $0 }

                    ForecastSparklineCard(
                        points: pts,
                        trend: prediction.trend,
                        colorForAQI: aqiLevelColor
                    )
                    .frame(maxWidth: .infinity)
                    .background(glassCard)
                    .scaleEffect(pressedForecast == nil ? 1.0 : 1.04)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressedForecast == nil)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30, pressing: { pressing in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pressedForecast = pressing
                                ? ForecastDetailInfo(points: pts, trend: prediction.trend, colorForAQI: aqiLevelColor)
                                : nil
                        }
                        if pressing {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }, perform: {})
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
                notifs.append(InsightNotif(icon: "sparkles", color: .purple, title: "AI Insight", body: summary))
            }
            if let rec = analysis.health_recommendation {
                notifs.append(InsightNotif(icon: "heart.fill", color: .pink, title: "Health Tip", body: rec))
            }
            if let hours = analysis.best_hours, !hours.isEmpty {
                notifs.append(InsightNotif(icon: "clock.fill", color: .yellow, title: "Best Hours", body: hours))
            }
        }

        if let prediction = mlPrediction, let trend = prediction.trend {
            let (title, body): (String, String) = {
                switch trend {
                case "subiendo": return ("Worsening", "Air quality is trending down")
                case "bajando":  return ("Improving", "Air quality is getting better")
                default:         return ("Stable", "Conditions holding steady")
                }
            }()
            notifs.append(InsightNotif(icon: "chart.line.uptrend.xyaxis", color: .cyan, title: title, body: body))
        }

        return notifs
    }

    private var insightBanner: some View {
        let notifs = insightNotifications

        return Group {
            if aiNotificationsEnabled && !notifs.isEmpty && showNotif && !notifDismissed {
                let notif = notifs[currentNotifIndex % notifs.count]

                Group {
                    if notifExpanded {
                        expandedCard(notif)
                    } else {
                        collapsedRow(notif)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.cardColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [notif.color.opacity(0.35), notif.color.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(currentNotifIndex)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        notifExpanded.toggle()
                    }
                }
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
                guard aiNotificationsEnabled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showNotif = true
                }
            }
        }
        .onChange(of: aiAnalysis?.summary) { _ in
            guard aiNotificationsEnabled else { return }
            currentNotifIndex = 0
            notifDismissed = false
            notifExpanded = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showNotif = true
            }
        }
    }

    // MARK: - Insight Banner — collapsed row

    private func collapsedRow(_ notif: InsightNotif) -> some View {
        let notifs = insightNotifications
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(notif.color.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: notif.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(notif.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                Text(notif.body)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 18, height: 18)
                .background(Circle().fill(.white.opacity(0.08)))

            Button {
                withAnimation(.easeOut(duration: 0.25)) { showNotif = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    currentNotifIndex += 1
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
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Insight Banner — expanded card

    private func expandedCard(_ notif: InsightNotif) -> some View {
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [notif.color.opacity(0.45), notif.color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: notif.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: notif.color.opacity(0.5), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(notif.body)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    notifExpanded = false
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
        }
        .padding(14)
    }

    // MARK: - Pollutant Info Builders

    private func pm25Info() -> PollutantInfo {
        let v = Int(airQualityData.pm25)
        let (status, statusColor) = pm25Status(v)
        return PollutantInfo(
            shortName: "PM2.5",
            fullName: "Fine Particulate Matter",
            value: v,
            unit: "µg/m³",
            maxValue: 150,
            color: statusColor,
            description: "Microscopic particles smaller than 2.5 micrometers that penetrate deep into the lungs and enter the bloodstream.",
            sources: [
                PollutantSource(icon: "car.fill", label: "Vehicles"),
                PollutantSource(icon: "flame.fill", label: "Wildfires"),
                PollutantSource(icon: "building.2.fill", label: "Industry")
            ],
            scaleStops: [
                ScaleStop(label: "Good", color: Color(hex: "#4CAF50"), limit: 12),
                ScaleStop(label: "Moderate", color: Color(hex: "#FFEB3B"), limit: 35),
                ScaleStop(label: "USG", color: Color(hex: "#FF9800"), limit: 55),
                ScaleStop(label: "Unhealthy", color: Color(hex: "#F44336"), limit: 150),
                ScaleStop(label: "Hazardous", color: Color(hex: "#9C27B0"), limit: 250)
            ],
            status: status,
            statusColor: statusColor
        )
    }

    private func pm10Info() -> PollutantInfo {
        let v = Int(airQualityData.pm10)
        let (status, statusColor) = pm10Status(v)
        return PollutantInfo(
            shortName: "PM10",
            fullName: "Coarse Particulate Matter",
            value: v,
            unit: "µg/m³",
            maxValue: 300,
            color: statusColor,
            description: "Inhalable particles up to 10 micrometers. Includes dust, pollen, and mold that irritate airways.",
            sources: [
                PollutantSource(icon: "wind", label: "Dust"),
                PollutantSource(icon: "leaf.fill", label: "Pollen"),
                PollutantSource(icon: "hammer.fill", label: "Construction")
            ],
            scaleStops: [
                ScaleStop(label: "Good", color: Color(hex: "#4CAF50"), limit: 54),
                ScaleStop(label: "Moderate", color: Color(hex: "#FFEB3B"), limit: 154),
                ScaleStop(label: "USG", color: Color(hex: "#FF9800"), limit: 254),
                ScaleStop(label: "Unhealthy", color: Color(hex: "#F44336"), limit: 354),
                ScaleStop(label: "Hazardous", color: Color(hex: "#9C27B0"), limit: 500)
            ],
            status: status,
            statusColor: statusColor
        )
    }

    private func o3Info() -> PollutantInfo {
        let v = Int(airQualityData.o3)
        let (status, statusColor) = o3Status(v)
        return PollutantInfo(
            shortName: "O₃",
            fullName: "Ground-Level Ozone",
            value: v,
            unit: "ppb",
            maxValue: 200,
            color: statusColor,
            description: "Reactive gas formed when sunlight hits vehicle and industrial emissions. Causes chest pain and coughing.",
            sources: [
                PollutantSource(icon: "sun.max.fill", label: "Sunlight"),
                PollutantSource(icon: "car.fill", label: "Traffic"),
                PollutantSource(icon: "smoke.fill", label: "Emissions")
            ],
            scaleStops: [
                ScaleStop(label: "Good", color: Color(hex: "#4CAF50"), limit: 54),
                ScaleStop(label: "Moderate", color: Color(hex: "#FFEB3B"), limit: 70),
                ScaleStop(label: "USG", color: Color(hex: "#FF9800"), limit: 85),
                ScaleStop(label: "Unhealthy", color: Color(hex: "#F44336"), limit: 105),
                ScaleStop(label: "Hazardous", color: Color(hex: "#9C27B0"), limit: 200)
            ],
            status: status,
            statusColor: statusColor
        )
    }

    private func pm25Status(_ v: Int) -> (String, Color) {
        switch v {
        case 0..<13:   return ("Good", Color(hex: "#4CAF50"))
        case 13..<36:  return ("Moderate", Color(hex: "#FFEB3B"))
        case 36..<56:  return ("Unhealthy for sensitive", Color(hex: "#FF9800"))
        case 56..<151: return ("Unhealthy", Color(hex: "#F44336"))
        default:       return ("Hazardous", Color(hex: "#9C27B0"))
        }
    }

    private func pm10Status(_ v: Int) -> (String, Color) {
        switch v {
        case 0..<55:    return ("Good", Color(hex: "#4CAF50"))
        case 55..<155:  return ("Moderate", Color(hex: "#FFEB3B"))
        case 155..<255: return ("Unhealthy for sensitive", Color(hex: "#FF9800"))
        case 255..<355: return ("Unhealthy", Color(hex: "#F44336"))
        default:        return ("Hazardous", Color(hex: "#9C27B0"))
        }
    }

    private func o3Status(_ v: Int) -> (String, Color) {
        switch v {
        case 0..<55:    return ("Good", Color(hex: "#4CAF50"))
        case 55..<71:   return ("Moderate", Color(hex: "#FFEB3B"))
        case 71..<86:   return ("Unhealthy for sensitive", Color(hex: "#FF9800"))
        case 86..<106:  return ("Unhealthy", Color(hex: "#F44336"))
        default:        return ("Hazardous", Color(hex: "#9C27B0"))
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

    // MARK: - Hourly Weather Forecast (Open-Meteo + backend AQI)

    private func loadHourlyForecast() async {
        let lat = 19.4326
        let lon = -99.1332
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&hourly=temperature_2m,apparent_temperature,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=7") else { return }

        struct OpenMeteoResponse: Decodable {
            let hourly: Hourly
            let daily: Daily
            struct Hourly: Decodable {
                let time: [String]
                let temperature_2m: [Double]
                let apparent_temperature: [Double]
                let weather_code: [Int]
                let precipitation_probability: [Int]
            }
            struct Daily: Decodable {
                let time: [String]
                let weather_code: [Int]
                let temperature_2m_max: [Double]
                let temperature_2m_min: [Double]
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let om = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm"
            df.timeZone = TimeZone.current

            let dayDf = DateFormatter()
            dayDf.dateFormat = "yyyy-MM-dd"
            dayDf.timeZone = TimeZone.current

            let hourDf = DateFormatter()
            hourDf.dateFormat = "ha"

            let now = Date()
            let calendar = Calendar.current

            // Hourly (all 7 days for conditions detail; current +24 for home strip)
            var allHourly: [HourlyPoint] = []
            for (i, timeStr) in om.hourly.time.enumerated() {
                guard let date = df.date(from: timeStr) else { continue }
                guard i < om.hourly.temperature_2m.count,
                      i < om.hourly.weather_code.count,
                      i < om.hourly.apparent_temperature.count,
                      i < om.hourly.precipitation_probability.count else { break }

                let temp = Int(om.hourly.temperature_2m[i].rounded())
                let feels = Int(om.hourly.apparent_temperature[i].rounded())
                let icon = weatherCodeToSymbol(om.hourly.weather_code[i])
                let precip = om.hourly.precipitation_probability[i]
                let aqi = aqiForTime(date)
                let isNow = calendar.isDate(date, equalTo: now, toGranularity: .hour)
                let label = isNow ? "Now" : hourDf.string(from: date).uppercased()

                allHourly.append(HourlyPoint(id: timeStr, label: label, date: date, temp: temp, feelsLike: feels, icon: icon, aqi: aqi, isNow: isNow, precipProbability: precip))
            }

            // Daily (7 days)
            var daily: [DailyWeatherPoint] = []
            for (i, dayStr) in om.daily.time.enumerated() {
                guard let date = dayDf.date(from: dayStr) else { continue }
                guard i < om.daily.temperature_2m_max.count,
                      i < om.daily.temperature_2m_min.count,
                      i < om.daily.weather_code.count else { break }
                daily.append(DailyWeatherPoint(
                    id: dayStr,
                    date: date,
                    tempMax: Int(om.daily.temperature_2m_max[i].rounded()),
                    tempMin: Int(om.daily.temperature_2m_min[i].rounded()),
                    icon: weatherCodeToSymbol(om.daily.weather_code[i])
                ))
            }

            // Home strip: current hour onwards, capped at 24
            let stripCutoff = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            let strip = allHourly.filter { $0.date >= stripCutoff }.prefix(24)

            await MainActor.run {
                hourlyForecast = Array(strip)
                weeklyForecast = daily
                hourlyForecastFull = allHourly
            }
        } catch {
            print("[HourlyForecast] Open-Meteo error: \(error.localizedDescription)")
        }
    }

    private func weatherCodeToSymbol(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    private func aqiForTime(_ date: Date) -> Int {
        guard let hourly = bestTimeData?.hourly else { return airQualityData.aqi }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = TimeZone(identifier: "UTC")

        var bestMatch: (diff: TimeInterval, aqi: Int)?
        for entry in hourly {
            if let entryDate = df.date(from: entry.time) {
                let diff = abs(entryDate.timeIntervalSince(date))
                if bestMatch == nil || diff < bestMatch!.diff {
                    bestMatch = (diff, entry.aqi)
                }
            }
        }
        if let match = bestMatch, match.diff < 3600 { return match.aqi }
        return airQualityData.aqi
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
                // Hourly inline inside glass card — horizontal scroll with 24h
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        if hourlyForecast.isEmpty {
                            HourlyInlineItem(hour: "Now", aqi: airQualityData.aqi, temp: Int(airQualityData.temperature), icon: "cloud.fill", isNow: true)
                        } else {
                            ForEach(hourlyForecast) { p in
                                HourlyInlineItem(hour: p.label, aqi: p.aqi, temp: p.temp, icon: p.icon, isNow: p.isNow)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
                }
                .background(glassCard)
                .padding(.horizontal, 16)
                .transition(.identity)
                .onTapGesture { showConditionsDetail = true }
            } else {
                // Weekly compact list inside glass card
                VStack(spacing: 0) {
                    ForEach(generateDailyForecasts()) { forecast in
                        Button(action: { showConditionsDetail = true }) {
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

            NavigationLink(destination: DailyForecastView()) {
                ExposureCircularChart()
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
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

    private var activeWeather: WeatherCondition {
        appSettings.weatherOverride ?? airQualityData.weatherCondition
    }

    private var theme: WeatherTheme {
        WeatherTheme(condition: activeWeather)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(theme.cardColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Insight Notification Model

struct InsightNotif {
    let icon: String
    let color: Color
    let title: String
    let body: String
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
    var onPressChange: ((Bool) -> Void)? = nil

    @State private var animatedProgress: CGFloat = 0
    @State private var displayValue: Int = 0
    @State private var isPressed: Bool = false

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
        .scaleEffect(isPressed ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30, pressing: { pressing in
            isPressed = pressing
            onPressChange?(pressing)
            if pressing {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }, perform: {})
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

// MARK: - Animated Weather Stat (compact, color + motion per kind)

enum WeatherStatKind {
    case temperature(Double)
    case humidity(Int)
    case wind(Double)
    case uv(Int)

    var label: String {
        switch self {
        case .temperature: return "Temp"
        case .humidity:    return "Humidity"
        case .wind:        return "km/h"
        case .uv:          return "UV"
        }
    }

    var value: String {
        switch self {
        case .temperature(let t): return "\(Int(t))°C"
        case .humidity(let h):    return "\(h)%"
        case .wind(let w):        return "\(Int(w))"
        case .uv(let u):          return "\(u)"
        }
    }

    var primaryColor: Color {
        switch self {
        case .temperature(let t):
            if t < 15      { return Color(hex: "#4FC3F7") }
            else if t < 25 { return Color(hex: "#81C784") }
            else if t < 32 { return Color(hex: "#FFB74D") }
            else           { return Color(hex: "#EF5350") }
        case .humidity:    return Color(hex: "#4FC3F7")
        case .wind:        return Color(hex: "#4DD0E1")
        case .uv(let u):
            if u < 3       { return Color(hex: "#81C784") }
            else if u < 6  { return Color(hex: "#FFD54F") }
            else if u < 8  { return Color(hex: "#FFB74D") }
            else if u < 11 { return Color(hex: "#EF5350") }
            else           { return Color(hex: "#AB47BC") }
        }
    }
}

struct AnimatedWeatherStat: View {
    let kind: WeatherStatKind

    @State private var animate: Bool = false

    var body: some View {
        VStack(spacing: 5) {
            iconView
                .frame(width: 26, height: 22)

            Text(kind.value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, kind.primaryColor.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(kind.label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .onAppear { animate = true }
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Soft glow halo
            Circle()
                .fill(kind.primaryColor.opacity(0.18))
                .frame(width: 22, height: 22)
                .blur(radius: 6)
                .scaleEffect(animate ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animate)

            switch kind {
            case .temperature:
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [kind.primaryColor, kind.primaryColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(animate ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

            case .humidity:
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [kind.primaryColor, kind.primaryColor.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: animate ? 1.5 : -1.5)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)

            case .wind:
                Image(systemName: "wind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(kind.primaryColor)
                    .offset(x: animate ? 2 : -2)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: animate)

            case .uv:
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [kind.primaryColor, kind.primaryColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: animate)
                    .shadow(color: kind.primaryColor.opacity(0.6), radius: 4)
            }
        }
    }
}

// MARK: - Pollutant Detail Overlay (press-and-hold)

struct PollutantSource: Hashable {
    let icon: String
    let label: String
}

struct ScaleStop: Hashable {
    let label: String
    let color: Color
    let limit: Int
}

struct PollutantInfo: Equatable {
    let shortName: String
    let fullName: String
    let value: Int
    let unit: String
    let maxValue: Int
    let color: Color
    let description: String
    let sources: [PollutantSource]
    let scaleStops: [ScaleStop]
    let status: String
    let statusColor: Color

    var percentage: CGFloat {
        min(CGFloat(value) / CGFloat(maxValue), 1.0)
    }

    var scalePosition: CGFloat {
        guard let last = scaleStops.last else { return 0 }
        return min(CGFloat(value) / CGFloat(last.limit), 1.0)
    }

    static func == (lhs: PollutantInfo, rhs: PollutantInfo) -> Bool {
        lhs.shortName == rhs.shortName && lhs.value == rhs.value
    }
}

struct PollutantDetailOverlay: View {
    let info: PollutantInfo

    @State private var animateRing: Bool = false
    @State private var animateValue: Int = 0

    var body: some View {
        ZStack {
            // Backdrop dimming
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.4))

            VStack(spacing: 18) {
                // Header
                VStack(spacing: 2) {
                    Text(info.shortName)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [info.color, info.color.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(info.fullName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }

                // Animated ring gauge
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: animateRing ? info.percentage : 0)
                        .stroke(info.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(animateValue)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text(info.unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: 140, height: 140)
                .shadow(color: info.color.opacity(0.5), radius: 24, y: 4)

                // Status badge
                HStack(spacing: 6) {
                    Circle().fill(info.statusColor).frame(width: 8, height: 8)
                    Text(info.status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(info.statusColor.opacity(0.18))
                        .overlay(Capsule().stroke(info.statusColor.opacity(0.4), lineWidth: 1))
                )

                // Scale bar with marker
                scaleBar
                    .padding(.horizontal, 4)

                // Description
                Text(info.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Sources row
                HStack(spacing: 20) {
                    ForEach(info.sources, id: \.self) { src in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(info.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: src.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(info.color)
                            }
                            Text(src.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }

                // Hint
                Text("Release to close")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [info.color.opacity(0.6), info.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: info.color.opacity(0.35), radius: 32, y: 8)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animateRing = true
            }
            let steps = 20
            let interval = 0.04
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        animateValue = Int(Double(info.value) * Double(i) / Double(steps))
                    }
                }
            }
        }
    }

    private var scaleBar: some View {
        GeometryReader { geo in
            let totalLimit = CGFloat(info.scaleStops.last?.limit ?? 1)
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    ForEach(info.scaleStops.indices, id: \.self) { i in
                        let stop = info.scaleStops[i]
                        let prev = i == 0 ? 0 : info.scaleStops[i - 1].limit
                        let width = CGFloat(stop.limit - prev) / totalLimit * (geo.size.width - CGFloat(info.scaleStops.count - 1) * 2)
                        Rectangle()
                            .fill(stop.color.opacity(0.7))
                            .frame(width: max(width, 4), height: 6)
                    }
                }
                .clipShape(Capsule())

                // Marker triangle
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(180))
                    .offset(x: max(0, min(geo.size.width - 9, geo.size.width * info.scalePosition - 4.5)), y: -10)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Forecast Sparkline Card (bento)

struct ForecastSparklineCard: View {
    struct Point: Identifiable {
        let id = UUID()
        let label: String
        let aqi: Int
    }

    let points: [Point]
    let trend: String?
    let colorForAQI: (Int) -> Color

    @State private var animate: Bool = false

    private var peak: Point? { points.dropFirst().max(by: { $0.aqi < $1.aqi }) }
    private var minY: Int { max(0, (points.map(\.aqi).min() ?? 0) - 8) }
    private var maxY: Int { max((points.map(\.aqi).max() ?? 80) + 8, minY + 20) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                Text("Forecast")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                if let trend = trend { trendChip(trend) }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Peak hint
            if let pk = peak {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(colorForAQI(pk.aqi))
                    Text("Peak \(pk.aqi) · \(pk.label)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            // Chart
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let n = max(points.count - 1, 1)
                let range = CGFloat(maxY - minY)
                let positions: [CGPoint] = points.enumerated().map { i, p in
                    let x = w * CGFloat(i) / CGFloat(n)
                    let ny = range > 0 ? 1 - CGFloat(p.aqi - minY) / range : 0.5
                    return CGPoint(x: x, y: 14 + ny * (h - 26))
                }
                let firstColor = colorForAQI(points.first?.aqi ?? 50)
                let lastColor = colorForAQI(points.last?.aqi ?? 50)

                ZStack {
                    // Area fill
                    Path { p in
                        guard let first = positions.first, let last = positions.last else { return }
                        p.move(to: CGPoint(x: first.x, y: h))
                        p.addLine(to: first)
                        for pt in positions.dropFirst() { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: last.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [lastColor.opacity(0.45), firstColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(animate ? 1 : 0)
                    .animation(.easeOut(duration: 0.9).delay(0.3), value: animate)

                    // Line
                    Path { p in
                        guard let first = positions.first else { return }
                        p.move(to: first)
                        for pt in positions.dropFirst() { p.addLine(to: pt) }
                    }
                    .trim(from: 0, to: animate ? 1 : 0)
                    .stroke(
                        LinearGradient(
                            colors: [firstColor, lastColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.easeOut(duration: 1.1).delay(0.1), value: animate)

                    // Markers + value labels
                    ForEach(Array(points.enumerated()), id: \.element.id) { i, p in
                        let pos = positions[i]
                        let color = colorForAQI(p.aqi)
                        let isCurrent = i == 0
                        let isPeak = p.id == peak?.id

                        ZStack {
                            if isCurrent {
                                Circle()
                                    .stroke(color.opacity(0.35), lineWidth: 6)
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(animate ? 1.1 : 0.8)
                                    .opacity(animate ? 0.0 : 0.8)
                                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: animate)
                            }
                            Circle()
                                .fill(color)
                                .frame(width: isCurrent ? 9 : 7, height: isCurrent ? 9 : 7)
                                .shadow(color: color.opacity(0.7), radius: 4)
                            Circle()
                                .stroke(.white.opacity(isCurrent ? 0.9 : 0.25), lineWidth: 1)
                                .frame(width: isCurrent ? 9 : 7, height: isCurrent ? 9 : 7)
                        }
                        .position(pos)
                        .scaleEffect(animate ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15 + Double(i) * 0.1), value: animate)

                        // AQI number
                        Text("\(p.aqi)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(isPeak ? 0.4 : 0))
                            )
                            .position(x: pos.x, y: max(10, pos.y - 12))
                            .opacity(animate ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(0.3 + Double(i) * 0.1), value: animate)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 6)

            // Hour labels
            HStack(spacing: 0) {
                ForEach(points) { p in
                    Text(p.label)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(p.label == "Now" ? .white.opacity(0.8) : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .onAppear { animate = true }
    }

    private func trendChip(_ trend: String) -> some View {
        let label: String
        let color: Color
        let icon: String
        switch trend {
        case "subiendo": label = "Worse";  color = .orange; icon = "arrow.up.right"
        case "bajando":  label = "Better"; color = .green;  icon = "arrow.down.right"
        default:         label = "Stable"; color = .gray;   icon = "arrow.right"
        }

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .heavy))
            Text(label)
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.18))
                .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
        )
    }
}

// MARK: - Forecast Detail Overlay (press-and-hold)

struct ForecastDetailInfo: Equatable {
    let points: [ForecastSparklineCard.Point]
    let trend: String?
    let colorForAQI: (Int) -> Color

    static func == (lhs: ForecastDetailInfo, rhs: ForecastDetailInfo) -> Bool {
        lhs.trend == rhs.trend &&
        lhs.points.count == rhs.points.count &&
        zip(lhs.points, rhs.points).allSatisfy { $0.aqi == $1.aqi && $0.label == $1.label }
    }
}

struct ForecastDetailOverlay: View {
    let info: ForecastDetailInfo

    @State private var animate: Bool = false

    private var currentAQI: Int { info.points.first?.aqi ?? 0 }
    private var peak: ForecastSparklineCard.Point? { info.points.dropFirst().max(by: { $0.aqi < $1.aqi }) }
    private var minValue: Int { max(0, (hourlyPoints.map(\.aqi).min() ?? 0) - 15) }
    private var maxValue: Int { max((hourlyPoints.map(\.aqi).max() ?? 80) + 15, minValue + 25) }
    private var delta: Int { (info.points.last?.aqi ?? 0) - currentAQI }

    // Parsed anchor hours from labels ("Now", "+1h", "+3h", "+6h")
    private var anchorHours: [(hour: Int, aqi: Int)] {
        info.points.compactMap { p in
            if p.label == "Now" { return (0, p.aqi) }
            if p.label.hasPrefix("+"), let h = Int(p.label.dropFirst().dropLast()) {
                return (h, p.aqi)
            }
            return nil
        }.sorted { $0.hour < $1.hour }
    }

    // Dense hourly series (0...maxHour) with linear interpolation
    private var hourlyPoints: [ForecastSparklineCard.Point] {
        let anchors = anchorHours
        guard let maxH = anchors.last?.hour, maxH > 0 else { return info.points }
        var result: [ForecastSparklineCard.Point] = []
        for h in 0...maxH {
            if let exact = anchors.first(where: { $0.hour == h }) {
                result.append(.init(label: h == 0 ? "Now" : "+\(h)h", aqi: exact.aqi))
            } else if let before = anchors.last(where: { $0.hour < h }),
                      let after = anchors.first(where: { $0.hour > h }) {
                let t = Double(h - before.hour) / Double(after.hour - before.hour)
                let aqi = Int(round(Double(before.aqi) + t * Double(after.aqi - before.aqi)))
                result.append(.init(label: "+\(h)h", aqi: aqi))
            }
        }
        return result
    }

    private func isAnchor(_ p: ForecastSparklineCard.Point) -> Bool {
        info.points.contains(where: { $0.label == p.label })
    }

    private var trendLabel: (String, Color, String) {
        switch info.trend {
        case "subiendo": return ("Worsening", .orange, "arrow.up.right")
        case "bajando":  return ("Improving", .green, "arrow.down.right")
        default:         return ("Stable", .gray, "arrow.right")
        }
    }

    private var recommendation: String {
        guard let pk = peak else { return "Conditions holding steady. Normal activity is fine." }
        if pk.aqi >= 151 {
            return "Limit outdoor activity around \(pk.label). Sensitive groups should stay indoors."
        } else if pk.aqi >= 101 {
            return "Reduce intense outdoor exercise near \(pk.label)."
        } else if delta < -10 {
            return "Air quality improving — great window for outdoor plans later."
        } else {
            return "Conditions remain acceptable throughout the next 6 hours."
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.6))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.4))

            VStack(spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Forecast")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.3)
                        Text("Next 6 Hours")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: trendLabel.2)
                            .font(.system(size: 9, weight: .heavy))
                        Text(trendLabel.0)
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(trendLabel.1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(trendLabel.1.opacity(0.2))
                            .overlay(Capsule().stroke(trendLabel.1.opacity(0.4), lineWidth: 0.8))
                    )
                }

                // Big chart
                chartView
                    .frame(height: 150)

                // Stats grid
                HStack(spacing: 8) {
                    statBox(
                        label: "Now",
                        value: "\(currentAQI)",
                        sub: levelName(currentAQI),
                        color: info.colorForAQI(currentAQI)
                    )
                    if let pk = peak {
                        statBox(
                            label: "Peak",
                            value: "\(pk.aqi)",
                            sub: pk.label,
                            color: info.colorForAQI(pk.aqi)
                        )
                    }
                    statBox(
                        label: "Δ 6h",
                        value: (delta >= 0 ? "+" : "") + "\(delta)",
                        sub: delta > 0 ? "Rising" : delta < 0 ? "Falling" : "Flat",
                        color: delta > 0 ? .orange : delta < 0 ? .green : .gray
                    )
                }

                // Recommendation
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.purple.opacity(0.18)))
                    Text(recommendation)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.05))
                )

                Text("Release to close")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [trendLabel.1.opacity(0.6), trendLabel.1.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: trendLabel.1.opacity(0.3), radius: 32, y: 8)
            )
            .padding(.horizontal, 24)
        }
        .onAppear { animate = true }
    }

    private func statBox(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(sub)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.25), lineWidth: 0.8)
                )
        )
    }

    private var chartView: some View {
        let series = hourlyPoints

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(series.count - 1, 1)
            let range = CGFloat(maxValue - minValue)
            let positions: [CGPoint] = series.enumerated().map { i, p in
                let x = w * CGFloat(i) / CGFloat(n)
                let ny = range > 0 ? 1 - CGFloat(p.aqi - minValue) / range : 0.5
                return CGPoint(x: x, y: 22 + ny * (h - 56))
            }
            let firstColor = info.colorForAQI(series.first?.aqi ?? 50)
            let lastColor = info.colorForAQI(series.last?.aqi ?? 50)

            ZStack {
                // Horizontal grid lines
                ForEach(0..<4) { i in
                    let y = 22 + CGFloat(i) * (h - 56) / 3
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(.white.opacity(0.05), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }

                // Area fill
                Path { p in
                    guard let first = positions.first, let last = positions.last else { return }
                    p.move(to: CGPoint(x: first.x, y: h - 22))
                    p.addLine(to: first)
                    for pt in positions.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: h - 22))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [lastColor.opacity(0.55), firstColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.9).delay(0.2), value: animate)

                // Line
                Path { p in
                    guard let first = positions.first else { return }
                    p.move(to: first)
                    for pt in positions.dropFirst() { p.addLine(to: pt) }
                }
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(
                    LinearGradient(
                        colors: [firstColor, lastColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .animation(.easeOut(duration: 1.1), value: animate)

                // Points
                ForEach(Array(series.enumerated()), id: \.element.id) { i, p in
                    let pos = positions[i]
                    let color = info.colorForAQI(p.aqi)
                    let isCurrent = i == 0
                    let isAnchorPt = isAnchor(p)
                    let isPeak = isAnchorPt && p.aqi == peak?.aqi && p.label == peak?.label

                    ZStack {
                        if isCurrent {
                            Circle()
                                .stroke(color.opacity(0.35), lineWidth: 8)
                                .frame(width: 24, height: 24)
                                .scaleEffect(animate ? 1.2 : 0.8)
                                .opacity(animate ? 0.0 : 0.8)
                                .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: animate)
                        }
                        Circle()
                            .fill(color)
                            .frame(
                                width: isCurrent ? 14 : (isAnchorPt ? 11 : 5),
                                height: isCurrent ? 14 : (isAnchorPt ? 11 : 5)
                            )
                            .shadow(color: color.opacity(isAnchorPt ? 0.8 : 0.4), radius: isAnchorPt ? 6 : 2)
                        if isAnchorPt {
                            Circle()
                                .stroke(.white.opacity(isCurrent ? 0.95 : 0.3), lineWidth: 1.5)
                                .frame(width: isCurrent ? 14 : 11, height: isCurrent ? 14 : 11)
                        }
                    }
                    .position(pos)
                    .scaleEffect(animate ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2 + Double(i) * 0.05), value: animate)

                    // Value bubble — only for anchors
                    if isAnchorPt {
                        Text("\(p.aqi)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(color.opacity(0.95))
                                    .shadow(color: color.opacity(0.5), radius: 4)
                            )
                            .position(x: pos.x, y: max(14, pos.y - 16))
                            .opacity(animate ? 1 : 0)
                            .scaleEffect(animate ? 1 : 0.6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.35 + Double(i) * 0.05), value: animate)
                    }

                    if isPeak {
                        Text("PEAK")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(color)
                            .tracking(0.8)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(color.opacity(0.18)))
                            .position(x: pos.x, y: max(4, pos.y - 34))
                            .opacity(animate ? 1 : 0)
                    }

                    // Time label — only for anchors (avoid clutter)
                    if isAnchorPt {
                        Text(p.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(isCurrent ? .white.opacity(0.9) : .white.opacity(0.45))
                            .position(x: pos.x, y: h - 8)
                            .opacity(animate ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.5 + Double(i) * 0.03), value: animate)
                    }
                }
            }
        }
    }

    private func levelName(_ aqi: Int) -> String {
        switch aqi {
        case 0..<51:    return "Good"
        case 51..<101:  return "Moderate"
        case 101..<151: return "USG"
        case 151..<201: return "Unhealthy"
        case 201..<301: return "V.Unhealthy"
        default:        return "Hazardous"
        }
    }
}

// MARK: - Reorderable Layout Support

struct SectionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [AQIHomeView.HomeSection: CGRect] = [:]
    static func reduce(value: inout [AQIHomeView.HomeSection: CGRect],
                       nextValue: () -> [AQIHomeView.HomeSection: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Subtle iOS-widget-like jiggle. Stagger via seed so sections desync.
struct JiggleModifier: ViewModifier {
    let active: Bool
    let seed: String

    @State private var jiggle: Bool = false

    private var phase: Double {
        Double(abs(seed.hashValue) % 100) / 100.0
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (jiggle ? 0.6 : -0.6) : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true).delay(phase * 0.08)
                    : .default,
                value: jiggle
            )
            .onChange(of: active) { newValue in
                if newValue {
                    jiggle = true
                } else {
                    jiggle = false
                }
            }
            .onAppear {
                if active { jiggle = true }
            }
    }
}

// MARK: - Exposure Bento Card (animated)

struct ExposureBentoCard: View {
    let level: String
    let cigValue: Double
    let progress: CGFloat       // 0...1 ring fill
    let color: Color

    @State private var animateRing: Bool = false
    @State private var animateContent: Bool = false
    @State private var pulseHalo: Bool = false
    @State private var displayValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Pulsing halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 44
                        )
                    )
                    .frame(width: 82, height: 82)
                    .scaleEffect(pulseHalo ? 1.1 : 0.85)
                    .opacity(pulseHalo ? 0.6 : 0.25)
                    .blur(radius: 6)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseHalo)

                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)

                // Progress ring (angular gradient)
                Circle()
                    .trim(from: 0, to: animateRing ? progress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.6), .yellow.opacity(progress > 0.3 ? 0.8 : 0.4)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.6), radius: animateRing ? 8 : 0)
                    .animation(.easeOut(duration: 1.1).delay(0.3), value: animateRing)

                // Inner content
                VStack(spacing: 1) {
                    Text(level)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                    Text("\(formattedValue) cig")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .contentTransition(.numericText())
                }
                .opacity(animateContent ? 1 : 0)
                .scaleEffect(animateContent ? 1 : 0.6)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: animateContent)
            }
            .frame(width: 72, height: 72)

            Text("Exposure")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 4)
                .animation(.easeOut(duration: 0.4).delay(0.75), value: animateContent)
        }
        .onAppear {
            animateRing = true
            animateContent = true
            pulseHalo = true
            // Count-up for cig value
            let steps = 20
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.04) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        displayValue = cigValue * Double(i) / Double(steps)
                    }
                }
            }
        }
    }

    private var formattedValue: String {
        String(format: "%.1f", displayValue)
    }
}

// MARK: - Exposure Map Overlay (press-and-hold on Exposure bento)

struct ExposureSegment: Identifiable {
    let id = UUID()
    let coords: [CLLocationCoordinate2D]
    let aqi: Int
    let label: String           // e.g. "Commute · 8:05 AM"
    let durationMin: Int
}

struct ExposureStop: Identifiable {
    let id = UUID()
    let coord: CLLocationCoordinate2D
    let icon: String
    let title: String
    let time: String
    let color: Color
}

struct ExposureHotspot: Identifiable {
    let id = UUID()
    let coord: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let aqi: Int
}

struct ExposureMapOverlay: View {
    @Binding var isPresented: Bool
    @State private var camera: MapCameraPosition
    @State private var animate: Bool = false

    private let segments: [ExposureSegment]
    private let stops: [ExposureStop]
    private let hotspots: [ExposureHotspot]
    private let totalDistanceKm: Double
    private let cigEquivalent: Double
    private let peakAQI: Int
    private let peakLocation: String
    private let peakTime: String
    private let minutesByLevel: [(label: String, color: Color, minutes: Int)]

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        // Sample realistic daily trip: Home → Work → Lunch → Home (CDMX style)
        let home   = CLLocationCoordinate2D(latitude: 19.3450, longitude: -99.1650)
        let ins1   = CLLocationCoordinate2D(latitude: 19.3650, longitude: -99.1680)
        let ins2   = CLLocationCoordinate2D(latitude: 19.3900, longitude: -99.1710)
        let work   = CLLocationCoordinate2D(latitude: 19.4250, longitude: -99.1700)
        let lunch  = CLLocationCoordinate2D(latitude: 19.4300, longitude: -99.1900)
        let per1   = CLLocationCoordinate2D(latitude: 19.4100, longitude: -99.1850)
        let per2   = CLLocationCoordinate2D(latitude: 19.3800, longitude: -99.1770)

        let commuteOut: [CLLocationCoordinate2D] = [
            home,
            .init(latitude: 19.3550, longitude: -99.1665),
            ins1,
            .init(latitude: 19.3770, longitude: -99.1695),
            ins2,
            .init(latitude: 19.4060, longitude: -99.1720),
            work
        ]

        let lunchTrip: [CLLocationCoordinate2D] = [
            work,
            .init(latitude: 19.4270, longitude: -99.1790),
            lunch
        ]

        let lunchReturn: [CLLocationCoordinate2D] = [
            lunch,
            .init(latitude: 19.4270, longitude: -99.1790),
            work
        ]

        let commuteHome: [CLLocationCoordinate2D] = [
            work,
            .init(latitude: 19.4200, longitude: -99.1780),
            per1,
            .init(latitude: 19.3970, longitude: -99.1810),
            per2,
            .init(latitude: 19.3620, longitude: -99.1720),
            home
        ]

        self.segments = [
            ExposureSegment(coords: commuteOut,  aqi: 148, label: "Morning Commute · 7:45 AM", durationMin: 38),
            ExposureSegment(coords: lunchTrip,   aqi: 92,  label: "Lunch Out · 1:10 PM",       durationMin: 12),
            ExposureSegment(coords: lunchReturn, aqi: 88,  label: "Back to Work · 1:55 PM",    durationMin: 12),
            ExposureSegment(coords: commuteHome, aqi: 118, label: "Evening Commute · 6:40 PM", durationMin: 45)
        ]

        self.stops = [
            ExposureStop(coord: home,  icon: "house.fill",     title: "Home",  time: "7:45 AM", color: Color(hex: "#4CAF50")),
            ExposureStop(coord: work,  icon: "briefcase.fill", title: "Work",  time: "8:23 AM", color: Color(hex: "#4FC3F7")),
            ExposureStop(coord: lunch, icon: "fork.knife",     title: "Lunch", time: "1:10 PM", color: Color(hex: "#FFB74D"))
        ]

        self.hotspots = [
            ExposureHotspot(coord: ins2, radius: 700, aqi: 158),
            ExposureHotspot(coord: per1, radius: 600, aqi: 128)
        ]

        self.totalDistanceKm = 24.6
        self.cigEquivalent = 0.8
        self.peakAQI = 158
        self.peakLocation = "Av. Insurgentes"
        self.peakTime = "8:11 AM"
        self.minutesByLevel = [
            ("Good",       Color(hex: "#4CAF50"), 520),
            ("Moderate",   Color(hex: "#FFEB3B"),  78),
            ("USG",        Color(hex: "#FF9800"),  42),
            ("Unhealthy",  Color(hex: "#F44336"),  27)
        ]

        // Center camera between home and work
        let midLat = (home.latitude + work.latitude) / 2
        let midLon = (home.longitude + work.longitude) / 2
        self._camera = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
        )))
    }

    private static func colorForAQI(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<51:    return Color(hex: "#4CAF50")
        case 51..<101:  return Color(hex: "#FFEB3B")
        case 101..<151: return Color(hex: "#FF9800")
        case 151..<201: return Color(hex: "#F44336")
        case 201..<301: return Color(hex: "#9C27B0")
        default:        return Color(hex: "#880E4F")
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.7))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))
                .contentShape(Rectangle())
                .onTapGesture { close() }

            VStack(spacing: 14) {
                header

                // MAP — interactive
                mapView
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        mapLegend.padding(10)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        recenterButton.padding(10)
                    }

                // Level breakdown bar
                levelBreakdown

                // Peak exposure row
                peakRow
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.5), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .green.opacity(0.25), radius: 40, y: 10)
            )
            .padding(.horizontal, 16)
        }
        .onAppear { animate = true }
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
        }
    }

    private var recenterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.6)) {
                let home = stops.first?.coord ?? CLLocationCoordinate2D(latitude: 19.385, longitude: -99.175)
                let work = stops.count > 1 ? stops[1].coord : home
                let midLat = (home.latitude + work.latitude) / 2
                let midLon = (home.longitude + work.longitude) / 2
                camera = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                    span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
                ))
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.black.opacity(0.7)))
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Exposure")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.3)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", cigEquivalent))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("cig equiv.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 9))
                    Text(String(format: "%.1f km", totalDistanceKm))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.8))
                Text("\(segments.count) trips")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    private var mapView: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            // Pollution hotspots
            ForEach(hotspots) { hs in
                MapCircle(center: hs.coord, radius: hs.radius)
                    .foregroundStyle(Self.colorForAQI(hs.aqi).opacity(0.22))
                    .stroke(Self.colorForAQI(hs.aqi).opacity(0.55), lineWidth: 1)
            }

            // Route segments
            ForEach(segments) { seg in
                MapPolyline(coordinates: seg.coords)
                    .stroke(
                        Self.colorForAQI(seg.aqi),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }

            // Stops (Home, Work, Lunch)
            ForEach(stops) { stop in
                Annotation(stop.title, coordinate: stop.coord) {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(stop.color)
                                .frame(width: 28, height: 28)
                                .shadow(color: stop.color.opacity(0.6), radius: 6)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                            Image(systemName: stop.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(stop.title)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.black.opacity(0.65)))
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .tint(.white)
    }

    private var mapLegend: some View {
        HStack(spacing: 8) {
            ForEach(["Good", "Moderate", "USG", "Unhealthy"], id: \.self) { label in
                let color: Color = {
                    switch label {
                    case "Good":      return Color(hex: "#4CAF50")
                    case "Moderate":  return Color(hex: "#FFEB3B")
                    case "USG":       return Color(hex: "#FF9800")
                    case "Unhealthy": return Color(hex: "#F44336")
                    default:          return .white
                    }
                }()
                HStack(spacing: 3) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.5)))
    }

    private var levelBreakdown: some View {
        let total = max(minutesByLevel.reduce(0) { $0 + $1.minutes }, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Exposure Breakdown")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                Text("\(total) min total")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(minutesByLevel.indices, id: \.self) { i in
                        let item = minutesByLevel[i]
                        let fraction = CGFloat(item.minutes) / CGFloat(total)
                        let w = fraction * (geo.size.width - CGFloat(minutesByLevel.count - 1) * 2)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(item.color)
                            .frame(width: max(4, w), height: 10)
                            .scaleEffect(x: animate ? 1 : 0, anchor: .leading)
                            .animation(.easeOut(duration: 0.7).delay(0.2 + Double(i) * 0.07), value: animate)
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 10) {
                ForEach(minutesByLevel.indices, id: \.self) { i in
                    let item = minutesByLevel[i]
                    HStack(spacing: 4) {
                        Circle().fill(item.color).frame(width: 6, height: 6)
                        Text("\(item.minutes)m")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(item.label)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var peakRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Self.colorForAQI(peakAQI).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Self.colorForAQI(peakAQI))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Peak \(peakAQI) AQI")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Self.colorForAQI(peakAQI))
                Text("\(peakLocation) · \(peakTime)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Self.colorForAQI(peakAQI).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Self.colorForAQI(peakAQI).opacity(0.3), lineWidth: 0.8)
                )
        )
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
    let temp: Int
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

            Text("\(temp)°")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Text("\(aqi)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(aqiColor)
        }
        .frame(width: 58)
        .padding(.vertical, 4)
        .background(
            isNow ?
                RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)) :
                RoundedRectangle(cornerRadius: 12).fill(.clear)
        )
    }
}

// MARK: - Hourly Point Model

struct HourlyPoint: Identifiable {
    let id: String
    let label: String
    let date: Date
    let temp: Int
    let feelsLike: Int
    let icon: String
    let aqi: Int
    let isNow: Bool
    let precipProbability: Int
}

struct DailyWeatherPoint: Identifiable {
    let id: String
    let date: Date
    let tempMax: Int
    let tempMin: Int
    let icon: String
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
    @Environment(\.weatherTheme) private var theme
    @State private var animateOuter = false
    @State private var animateMiddle = false
    @State private var animateInner = false
    @State private var animateCenter = false
    @State private var animateLegend = false
    @State private var pulseHalo = false
    @State private var displayTotal: Int = 0

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
                // Pulsing background halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#FFA726").opacity(0.25), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: ringSize + 30, height: ringSize + 30)
                    .scaleEffect(pulseHalo ? 1.08 : 0.92)
                    .opacity(pulseHalo ? 0.7 : 0.35)
                    .blur(radius: 8)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulseHalo)

                // Outdoor — outer ring
                ExposureRing(
                    progress: animateOuter ? outdoorHours / 12 : 0,
                    color: Color(hex: "#FFA726"),
                    size: ringSize,
                    strokeWidth: strokeWidth
                )
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animateOuter)

                // Work — middle ring
                ExposureRing(
                    progress: animateMiddle ? workHours / 12 : 0,
                    color: Color(hex: "#81C784"),
                    size: ringSize - (strokeWidth * 2 + 6),
                    strokeWidth: strokeWidth
                )
                .animation(.easeOut(duration: 1.0).delay(0.45), value: animateMiddle)

                // Home — inner ring
                ExposureRing(
                    progress: animateInner ? homeHours / 12 : 0,
                    color: Color(hex: "#FFD54F"),
                    size: ringSize - (strokeWidth * 4 + 12),
                    strokeWidth: strokeWidth
                )
                .animation(.easeOut(duration: 1.0).delay(0.7), value: animateInner)

                // Center total
                VStack(spacing: 1) {
                    Text("\(displayTotal)h")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("Total")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.4))
                }
                .opacity(animateCenter ? 1 : 0)
                .scaleEffect(animateCenter ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.95), value: animateCenter)
            }
            .frame(width: ringSize, height: ringSize)

            Spacer(minLength: 16)

            // Legend
            VStack(alignment: .leading, spacing: 12) {
                legendItem(delay: 1.05, color: Color(hex: "#FFA726"), label: "Outdoor", hours: outdoorHours)
                legendItem(delay: 1.20, color: Color(hex: "#81C784"), label: "Work",    hours: workHours)
                legendItem(delay: 1.35, color: Color(hex: "#FFD54F"), label: "Home",    hours: homeHours)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardColor.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
        .onAppear {
            pulseHalo = true
            animateOuter = true
            animateMiddle = true
            animateInner = true
            animateCenter = true
            animateLegend = true

            // Count-up total
            let steps = 18
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.95 + Double(i) * 0.04) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        displayTotal = Int(round(totalHours * CGFloat(i) / CGFloat(steps)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func legendItem(delay: Double, color: Color, label: String, hours: CGFloat) -> some View {
        ExposureLegendItem(color: color, label: label, hours: hours, total: 12)
            .opacity(animateLegend ? 1 : 0)
            .offset(x: animateLegend ? 0 : 8)
            .animation(.easeOut(duration: 0.45).delay(delay), value: animateLegend)
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
    let currentCondition: WeatherCondition
    var onLocationSelected: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) var dismiss
    @StateObject private var searchManager = LocationSearchManager()
    @State private var selectedLocation: SelectedLocation?
    @State private var locationAQI: LocationAQISnapshot?
    @State private var isLoadingAQI: Bool = false
    @State private var loadError: String?
    @FocusState private var searchFieldFocused: Bool

    struct SelectedLocation: Equatable {
        let title: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
        }
    }

    struct LocationAQISnapshot {
        let aqi: Int
        let pm25: Double
        let pm10: Double
        let o3: Double
        let dominant: String?
    }

    private let quickLocations: [(title: String, subtitle: String, lat: Double, lon: Double, icon: String)] = [
        ("Mexico City", "Mexico", 19.4326, -99.1332, "building.2.crop.circle.fill"),
        ("New York", "USA", 40.7128, -74.0060, "building.2.fill"),
        ("Tokyo", "Japan", 35.6762, 139.6503, "building.fill"),
        ("London", "UK", 51.5074, -0.1278, "building.columns.fill"),
        ("Paris", "France", 48.8566, 2.3522, "sparkles"),
        ("Los Angeles", "USA", 34.0522, -118.2437, "sun.max.fill"),
        ("Berlin", "Germany", 52.5200, 13.4050, "building.2.fill"),
        ("Madrid", "Spain", 40.4168, -3.7038, "building.columns.fill")
    ]

    private var theme: WeatherTheme { WeatherTheme(condition: currentCondition) }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(theme.cardColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20).stroke(theme.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    var body: some View {
        ZStack {
            WeatherBackground(condition: currentCondition)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                searchField

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let selected = selectedLocation {
                            detailView(for: selected)
                        } else if !searchText.isEmpty {
                            liveResultsList
                        } else {
                            quickLocationsList
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .environment(\.weatherTheme, theme)
        .onChange(of: searchText) { newValue in
            if selectedLocation != nil && !newValue.isEmpty {
                selectedLocation = nil
                locationAQI = nil
                loadError = nil
            }
            searchManager.searchQuery = newValue
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Explore")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Search a city to view its air quality")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))

            TextField("Search city, place, address...", text: $searchText)
                .font(.body)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .focused($searchFieldFocused)

            if searchManager.isSearching {
                ProgressView().tint(.white.opacity(0.7)).scaleEffect(0.8)
            } else if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    selectedLocation = nil
                    locationAQI = nil
                    loadError = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3).foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(glassCard)
        .padding(.horizontal, 16)
    }

    // MARK: - Quick locations

    private var quickLocationsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Navigation")
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(quickLocations, id: \.title) { loc in
                    Button(action: {
                        let sel = SelectedLocation(
                            title: loc.title,
                            subtitle: loc.subtitle,
                            coordinate: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lon)
                        )
                        selectLocation(sel)
                    }) {
                        locationRow(icon: loc.icon, title: loc.title, subtitle: loc.subtitle)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Live results

    private var liveResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if let err = searchManager.errorMessage {
                    Text(err).font(.caption).foregroundColor(.red.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)

            if searchManager.searchResults.isEmpty && !searchManager.isSearching {
                emptyResults
            } else {
                VStack(spacing: 10) {
                    ForEach(searchManager.searchResults) { result in
                        Button(action: { selectResult(result) }) {
                            locationRow(
                                icon: result.placeType.icon,
                                title: result.title,
                                subtitle: result.subtitle.isEmpty ? "Tap to view air quality" : result.subtitle
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash.circle")
                .font(.title).foregroundColor(.white.opacity(0.3))
            Text("No results")
                .font(.subheadline).foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Detail view

    @ViewBuilder
    private func detailView(for location: SelectedLocation) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption).foregroundColor(.white.opacity(0.7))
                        Text(location.title)
                            .font(.headline).foregroundColor(.white)
                    }
                    if !location.subtitle.isEmpty {
                        Text(location.subtitle)
                            .font(.subheadline).foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(action: {
                    selectedLocation = nil
                    locationAQI = nil
                    loadError = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Change")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)

            if isLoadingAQI {
                loadingCard
            } else if let err = loadError {
                errorCard(err, location: location)
            } else if let snap = locationAQI {
                aqiDetailCard(for: snap, location: location)
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white).scaleEffect(1.2)
            Text("Fetching air quality...")
                .font(.caption).foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(glassCard)
        .padding(.horizontal, 16)
    }

    private func errorCard(_ message: String, location: SelectedLocation) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2).foregroundColor(.orange)
            Text("Couldn't load air quality")
                .font(.subheadline.bold()).foregroundColor(.white)
            Text(message)
                .font(.caption).foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button(action: { Task { await fetchAQI(for: location) } }) {
                Text("Retry")
                    .font(.caption.bold()).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30).padding(.horizontal, 20)
        .background(glassCard)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func aqiDetailCard(for snap: LocationAQISnapshot, location: SelectedLocation) -> some View {
        let level = AQILevel.from(aqi: snap.aqi)

        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("Air Quality Index")
                    .font(.subheadline).foregroundColor(.white.opacity(0.5))

                Text("\(snap.aqi)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: level.color).opacity(0.6), radius: 20)

                HStack(spacing: 6) {
                    Circle().fill(Color(hex: level.color)).frame(width: 8, height: 8)
                    Text(level.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: level.color))
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: level.color).opacity(0.15)))

                if let dom = snap.dominant, !dom.isEmpty {
                    Text("Dominant: \(dom.uppercased())")
                        .font(.caption2).foregroundColor(.white.opacity(0.5))
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(glassCard)
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                MiniPollutantGauge(
                    value: Int(snap.pm25), maxValue: 75, name: "PM2.5",
                    color: Color(hex: level.color)
                )
                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)
                MiniPollutantGauge(
                    value: Int(snap.pm10), maxValue: 150, name: "PM10",
                    color: Color(hex: level.color)
                )
                Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 50)
                MiniPollutantGauge(
                    value: Int(snap.o3), maxValue: 100, name: "O₃",
                    color: Color(hex: level.color)
                )
            }
            .padding(.vertical, 14)
            .background(glassCard)
            .padding(.horizontal, 16)

            Button(action: {
                let fullName = location.subtitle.isEmpty
                    ? location.title
                    : "\(location.title), \(location.subtitle)"
                onLocationSelected(fullName, location.coordinate)
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                    Text("View on Home")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color(hex: level.color).opacity(0.25))
                        .overlay(Capsule().stroke(Color(hex: level.color).opacity(0.5), lineWidth: 1))
                )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Row

    private func locationRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.bold()).foregroundColor(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption).foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(glassCard)
    }

    // MARK: - Actions

    private func selectLocation(_ loc: SelectedLocation) {
        selectedLocation = loc
        locationAQI = nil
        loadError = nil
        searchFieldFocused = false
        Task { await fetchAQI(for: loc) }
    }

    private func selectResult(_ result: SearchResult) {
        if let coord = result.coordinate {
            selectLocation(SelectedLocation(title: result.title, subtitle: result.subtitle, coordinate: coord))
            return
        }
        searchManager.selectResult(result) { coord in
            DispatchQueue.main.async {
                if let coord = coord {
                    selectLocation(SelectedLocation(title: result.title, subtitle: result.subtitle, coordinate: coord))
                } else {
                    loadError = "Could not resolve coordinates"
                }
            }
        }
    }

    private func fetchAQI(for location: SelectedLocation) async {
        await MainActor.run {
            isLoadingAQI = true
            loadError = nil
        }
        let backend = "https://airway-api.onrender.com/api/v1"
        guard let url = URL(string: "\(backend)/air/analysis?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&mode=walk&skip_ai=true") else {
            await MainActor.run {
                isLoadingAQI = false
                loadError = "Invalid URL"
            }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)
            let snap = LocationAQISnapshot(
                aqi: analysis.combined_aqi,
                pm25: analysis.pollutants?.pm25?.value ?? 0,
                pm10: analysis.pollutants?.pm10?.value ?? 0,
                o3: analysis.pollutants?.o3?.value ?? 0,
                dominant: analysis.dominant_pollutant
            )
            await MainActor.run {
                locationAQI = snap
                isLoadingAQI = false
            }
        } catch {
            await MainActor.run {
                isLoadingAQI = false
                loadError = error.localizedDescription
            }
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
    fileprivate func handleLocationSelection(_ locationString: String, coordinate: CLLocationCoordinate2D) {
        let components = locationString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let locationName = components.first ?? locationString
        let cityName = locationString
        Task { await fetchAQIDataFromBackend(locationName: locationName, cityName: cityName, coordinate: coordinate) }
    }

    fileprivate func fetchAQIDataFromBackend(locationName: String, cityName: String, coordinate: CLLocationCoordinate2D) async {
        await MainActor.run { isLoadingAQI = true }

        let backendURL = "https://airway-api.onrender.com/api/v1"
        guard let url = URL(string: "\(backendURL)/air/analysis?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&mode=walk&skip_ai=true") else {
            await MainActor.run { isLoadingAQI = false }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)
            await MainActor.run {
                airQualityData = AirQualityData(
                    aqi: analysis.combined_aqi,
                    pm25: analysis.pollutants?.pm25?.value ?? 0,
                    pm10: analysis.pollutants?.pm10?.value ?? 0,
                    o3: analysis.pollutants?.o3?.value ?? 0,
                    location: locationName,
                    city: cityName,
                    distance: 0,
                    temperature: airQualityData.temperature,
                    humidity: airQualityData.humidity,
                    windSpeed: airQualityData.windSpeed,
                    uvIndex: airQualityData.uvIndex,
                    weatherCondition: airQualityData.weatherCondition,
                    lastUpdate: Date()
                )
                if let ml = analysis.ml_prediction { mlPrediction = ml }
                cacheAQIData()
                isLoadingAQI = false
            }
        } catch {
            await MainActor.run {
                dataLoadError = "Error: \(error.localizedDescription)"
                isLoadingAQI = false
            }
        }
    }
}

// MARK: - Weather Conditions Detail View

struct WeatherConditionsDetailView: View {
    let currentCondition: WeatherCondition
    let hourly: [HourlyPoint]
    let daily: [DailyWeatherPoint]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDayIndex: Int = 0
    @State private var tempMode: TempMode = .actual

    enum TempMode: String, CaseIterable { case actual = "Actual", feelsLike = "Feels Like" }

    private var theme: WeatherTheme { WeatherTheme(condition: currentCondition) }

    private var selectedDate: Date {
        if selectedDayIndex < daily.count { return daily[selectedDayIndex].date }
        return Date()
    }

    private var hoursForSelectedDay: [HourlyPoint] {
        let cal = Calendar.current
        return hourly.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ZStack {
            WeatherBackground(condition: currentCondition).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    weekStrip
                    selectedDateTitle
                    currentSummary
                    hourlyIconsStrip
                    temperatureChartCard
                    precipitationCard
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .environment(\.weatherTheme, theme)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                Text("Conditions")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
        }
        .overlay(alignment: .leading) { Spacer().frame(width: 34) }
        .padding(.horizontal, 20)
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(daily.enumerated()), id: \.offset) { (idx, day) in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedDayIndex = idx
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(dayLetter(day.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            ZStack {
                                if selectedDayIndex == idx {
                                    Circle().fill(Color(hex: "#4AB8FF"))
                                        .frame(width: 38, height: 38)
                                }
                                Text("\(dayNumber(day.date))")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(selectedDayIndex == idx ? .white : .white.opacity(0.9))
                            }
                            .frame(width: 38, height: 38)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var selectedDateTitle: some View {
        Text(fullDateString(selectedDate))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, -8)
    }

    // MARK: - Current summary

    private var currentSummary: some View {
        let day = daily[safe: selectedDayIndex]
        let currentTemp: Int = {
            if let first = hoursForSelectedDay.first(where: { $0.isNow }) { return first.temp }
            if let first = hoursForSelectedDay.first { return first.temp }
            return day?.tempMax ?? 0
        }()
        let icon = hoursForSelectedDay.first?.icon ?? day?.icon ?? "cloud.fill"

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("\(currentTemp)°")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.multicolor)
                }
                if let d = day {
                    Text("H:\(d.tempMax)°  L:\(d.tempMin)°")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Hourly icons strip

    private var hourlyIconsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(hoursForSelectedDay) { p in
                    Image(systemName: p.icon)
                        .font(.system(size: 18))
                        .foregroundColor(p.isNow ? .white : .white.opacity(0.5))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 30)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Temperature chart

    private var temperatureChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            tempChart
            toggleRow
            Text(tempMode == .actual ? "The actual temperature." : "What the temperature feels like.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
        }
        .padding(.top, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardColor.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.borderColor, lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var tempChart: some View {
        let points = hoursForSelectedDay
        if points.isEmpty {
            Text("No data available")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            let values: [(hour: Int, value: Int)] = points.map {
                let h = Calendar.current.component(.hour, from: $0.date)
                return (h, tempMode == .actual ? $0.temp : $0.feelsLike)
            }
            let maxVal = values.map(\.value).max() ?? 0
            let minVal = values.map(\.value).min() ?? 0

            Chart {
                ForEach(values, id: \.hour) { point in
                    LineMark(
                        x: .value("Hour", point.hour),
                        y: .value("Temp", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FFCB6B"), Color(hex: "#FF9800")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [4, 4]))

                    AreaMark(
                        x: .value("Hour", point.hour),
                        y: .value("Temp", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FFCB6B").opacity(0.35), Color(hex: "#4AB8FF").opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }

                if let hi = values.first(where: { $0.value == maxVal }) {
                    PointMark(x: .value("H", hi.hour), y: .value("Temp", hi.value))
                        .foregroundStyle(.white)
                        .symbolSize(60)
                        .annotation(position: .top) {
                            Text("H").font(.caption2.bold()).foregroundColor(.white.opacity(0.7))
                        }
                }
                if let lo = values.first(where: { $0.value == minVal }) {
                    PointMark(x: .value("L", lo.hour), y: .value("Temp", lo.value))
                        .foregroundStyle(.white)
                        .symbolSize(60)
                        .annotation(position: .bottom) {
                            Text("L").font(.caption2.bold()).foregroundColor(.white.opacity(0.7))
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { v in
                    AxisValueLabel().foregroundStyle(.white.opacity(0.4))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(.white.opacity(0.1))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.08))
                }
            }
            .chartXScale(domain: 0...23)
            .frame(height: 220)
            .padding(.horizontal, 16)
        }
    }

    private var toggleRow: some View {
        HStack(spacing: 0) {
            ForEach(TempMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        tempMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(tempMode == mode ? Color.white.opacity(0.18) : .clear)
                        )
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .padding(.horizontal, 20)
    }

    // MARK: - Precipitation

    private var precipitationCard: some View {
        let values = hoursForSelectedDay.map { (hour: Calendar.current.component(.hour, from: $0.date), value: $0.precipProbability) }
        let todayChance = values.map(\.value).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Chance of Precipitation")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            Text("Today's chance: \(todayChance)%")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 20)

            if !values.isEmpty {
                Chart {
                    ForEach(values, id: \.hour) { point in
                        BarMark(
                            x: .value("Hour", point.hour),
                            y: .value("Chance", point.value),
                            width: .fixed(10)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#4AB8FF"), Color(hex: "#4AB8FF").opacity(0.4)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .cornerRadius(3)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { _ in
                        AxisValueLabel().foregroundStyle(.white.opacity(0.4))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                            .foregroundStyle(.white.opacity(0.08))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 20, 40, 60, 80, 100]) { _ in
                        AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.08))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: 0...23)
                .frame(height: 200)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardColor.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.borderColor, lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func dayLetter(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "E"
        return String(df.string(from: date).prefix(1))
    }

    private func dayNumber(_ date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }

    private func fullDateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMMM yyyy"
        return df.string(from: date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    AQIHomeView(showBusinessPulse: .constant(false))
}
