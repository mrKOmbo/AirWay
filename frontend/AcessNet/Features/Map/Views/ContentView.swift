//
//  ContentView.swift
//  AcessNet
//
//  Vista principal mejorada con mapa estilo Waze
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Custom Annotation Model

struct CustomAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let alertType: AlertType
    let timestamp: Date = Date()

    init(coordinate: CLLocationCoordinate2D, title: String) {
        self.coordinate = coordinate
        self.title = title
        // Convertir el title a AlertType
        self.alertType = AlertType.allCases.first { $0.rawValue == title } ?? .hazard
    }

    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(timestamp) / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        return "\(hours) hr ago"
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @Binding var showBusinessPulse: Bool
    @StateObject private var locationManager = LocationManager()

    init(showBusinessPulse: Binding<Bool>) {
        self._showBusinessPulse = showBusinessPulse
    }

    var body: some View {
        EnhancedMapView(
            locationManager: locationManager,
            showPulse: $showBusinessPulse
        )
        .ignoresSafeArea()
    }
}

// MARK: - Air Quality Reference Point

/// Punto de referencia para el grid de calidad del aire
enum AirQualityReferencePoint {
    case userLocation
    case destination(CLLocationCoordinate2D)

    var coordinate: CLLocationCoordinate2D? {
        switch self {
        case .userLocation:
            return nil
        case .destination(let coord):
            return coord
        }
    }

    var displayName: String {
        switch self {
        case .userLocation:
            return "Your Location"
        case .destination:
            return "Destination (Point B)"
        }
    }

    var icon: String {
        switch self {
        case .userLocation:
            return "location.fill"
        case .destination:
            return "mappin.circle.fill"
        }
    }
}

// MARK: - Enhanced Map View

struct EnhancedMapView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showPulse: Bool

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var annotations: [CustomAnnotation] = []
    @State private var mostrarSheet = false
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAnnotation: CustomAnnotation?
    @State private var mapStyle: MapStyleType = .hybrid

    // MARK: - Routing State
    @StateObject private var routeManager = RouteManager()
    @StateObject private var routePreferences = RoutePreferencesModel()
    @StateObject private var routeAnimations = RouteAnimationController()
    @State private var routingMode: Bool = false
    @State private var destination: DestinationPoint?
    @State private var showRoutePreferences: Bool = false
    @State private var selectedRouteIndex: Int? = nil

    // MARK: - Navigation State
    @StateObject private var navigationManager = NavigationManager()
    @State private var isInNavigationMode: Bool = false

    // MARK: - Location Info State
    @State private var showLocationInfo: Bool = false
    @State private var selectedLocationInfo: LocationInfo?

    // MARK: - Trip Briefing State
    /// Ruta tentativa (walking o driving) que el briefing calcula con
    /// MKDirections. Se dibuja en el mapa detrás del sheet como preview.
    /// El container la provee vía `onPreviewRouteChanged`.
    @State private var briefingPreviewRoute: PreviewRoute?
    /// Modo activo del briefing — gobierna el color del preview.
    @State private var briefingPreviewMode: BriefingMode = .walking

    // MARK: - Search State
    @StateObject private var searchManager = LocationSearchManager()
    @FocusState private var isSearchFocused: Bool
    @State private var showRouteToast = false
    @State private var routeToastMessage = ""

    // MARK: - Route Arrows State
    @State private var routeArrows: [RouteArrowAnnotation] = []

    // MARK: - Route Animation State (Optimizado)
    @State private var dashPhase: CGFloat = 0  // Marching ants

    // MARK: - Air Quality Overlay State
    @StateObject private var airQualityGridManager = AirQualityGridManager()
    @State private var showAirQualityLayer: Bool = false
    @State private var showAirQualityLegend: Bool = false
    @State private var selectedZone: AirQualityZone?
    @State private var showZoneDetail: Bool = false
    @State private var airQualityReferencePoint: AirQualityReferencePoint = .userLocation

    // MARK: - App Settings (Performance Controls)
    @StateObject private var appSettings = AppSettings.shared

    // Enhanced tab bar height - usando constante global
    private let tabBarHeight: CGFloat = AppConstants.enhancedTabBarTotalHeight

    // Computed property para verificar si hay ruta activa.
    // Incluye `allScoredRoutes` (las 3 variantes Cleanest/Balanced/Fastest)
    // — sin esto, el ProximityFilter de 2 km oculta los círculos AQI en
    // el RouteCardsSelector. También considera `currentScoredRoute` que
    // vive independiente de `currentRoute` cuando viene del Trip Briefing.
    private var hasActiveRoute: Bool {
        routeManager.currentRoute != nil
            || routeManager.currentScoredRoute != nil
            || routeManager.isCalculating
            || isInNavigationMode
            || !routeManager.allScoredRoutes.isEmpty
    }

    /// Color del preview del Trip Briefing según modo activo.
    private var briefingPreviewColor: Color {
        switch briefingPreviewMode {
        case .walking: return Color(hex: "#7ED957")
        case .driving: return Color(hex: "#3AA3FF")
        }
    }

    // Computed property para verificar si hay ruta activa para navegación
    private var hasActiveRouteForNav: Bool {
        routeManager.currentScoredRoute != nil && !isInNavigationMode
    }

    // MARK: - Proximity Filtering (2km Radius)

    /// Snapshot cacheado de zonas visibles — actualizado por eventos, no por render.
    /// Leer desde el body es O(1) sin recomputar Haversine cada frame.
    @State private var visibleAirQualityZones: [AirQualityZone] = []

    /// Hard cap del número de círculos AQI visibles simultáneamente.
    /// Cada círculo = 1 MapCircle + 1 Annotation → costo lineal con MapKit.
    /// 20 es el punto donde FPS ≥ 50 en iPhone 13+ según pruebas empíricas.
    private static let maxVisibleZones = 20

    /// Recalcula el snapshot de zonas visibles. Debe llamarse desde handlers de evento
    /// (onChange/onReceive), no desde el body, para mantener el costo fuera del hot path.
    private func recomputeVisibleAirQualityZones() {
        let all = airQualityGridManager.zones

        // Sin ubicación del usuario → top N por AQI peor primero.
        guard let userLocation = locationManager.userLocation else {
            visibleAirQualityZones = Self.prioritize(zones: all, userLocation: nil)
            return
        }

        // Con ruta activa o preview del briefing → mostrar top N
        // priorizando cercanía al usuario + AQI peor. NO aplicar
        // ProximityFilter: las zones están distribuidas a lo largo de
        // la ruta y la mayoría caería fuera del radio.
        if hasActiveRoute || briefingPreviewRoute != nil {
            visibleAirQualityZones = Self.prioritize(zones: all, userLocation: userLocation)
            return
        }

        // Filtro desactivado en settings → top N sin límite de radio.
        guard appSettings.enableProximityFiltering else {
            visibleAirQualityZones = Self.prioritize(zones: all, userLocation: userLocation)
            return
        }

        let filtered = ProximityFilter.filterZones(
            all,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
        visibleAirQualityZones = Self.prioritize(zones: filtered, userLocation: userLocation)
    }

    /// Ordena zonas por relevancia y corta al cap máximo.
    /// Prioridad: 60% cercanía al usuario + 40% severidad AQI.
    private static func prioritize(zones: [AirQualityZone],
                                    userLocation: CLLocationCoordinate2D?) -> [AirQualityZone] {
        guard zones.count > maxVisibleZones else { return zones }

        let scored = zones.map { zone -> (AirQualityZone, Double) in
            // Score inverso: menor = mejor prioridad.
            var score: Double = 0

            if let user = userLocation {
                let distMeters = user.distance(to: zone.coordinate)
                // Normalizar distancia (10km ≈ 1.0). Peso 60%.
                score += (distMeters / 10_000) * 0.6
            }

            // AQI más bajo = menos prioritario (multiplicar por -1 para que "peor AQI"
            // sea menor score = más prioritario). Peso 40%. AQI normalizado a 500 max.
            let aqiInverse = 1.0 - (zone.airQuality.aqi / 500.0)
            score += aqiInverse * 0.4

            return (zone, score)
        }

        return scored
            .sorted { $0.1 < $1.1 }
            .prefix(maxVisibleZones)
            .map { $0.0 }
    }

    /// Alerts dentro del rango de visibilidad (2km). Sin side-effects.
    private var visibleAnnotations: [CustomAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return annotations
        }

        guard appSettings.enableProximityFiltering else {
            return annotations
        }

        return ProximityFilter.filterAnnotations(
            annotations,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
    }

    /// Route arrows dentro del rango de visibilidad (2km). Sin side-effects.
    private var visibleRouteArrows: [RouteArrowAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return routeArrows
        }

        guard appSettings.enableProximityFiltering else {
            return routeArrows
        }

        return ProximityFilter.filterRouteArrows(
            routeArrows,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Mapa principal mejorado
            enhancedMapView

            // Dimmer de fondo cuando búsqueda está activa
            if isSearchFocused {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFocused = false
                            searchManager.clearSearch()
                        }
                    }
                    .transition(.opacity)
            }

            // Route Toast Notification
            if showRouteToast {
                VStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#3B82F6").opacity(0.2))
                                .frame(width: 26, height: 26)
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }
                        Text(routeToastMessage)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.7))
                            .background(Capsule().fill(.ultraThinMaterial))
                    )
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
                    .padding(.top, 60)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Speed Indicator (top left) - ocultar cuando hay ruta activa
            if !hasActiveRoute {
                VStack {
                    HStack {
                        if locationManager.isMoving && !isSearchFocused {
                            CompactSpeedIndicator(speed: locationManager.speedKmh)
                                .padding(.leading)
                                .fadeIn(delay: 0.2)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.opacity)
            }

            // ML Prediction Banner — solo cuando el mapa está "limpio" (sin cards, zonas, rutas)
            if !hasActiveRoute && !isSearchFocused && !showLocationInfo && !showAirQualityLayer && !showZoneDetail && selectedZone == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AQIPredictionBanner()
                        Spacer()
                    }
                    .padding(.bottom, tabBarHeight + 20)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            // Botón X para cancelar navegación o limpiar ruta (top left)
            if isInNavigationMode || hasActiveRoute {
                VStack {
                    HStack {
                        Button(action: {
                            HapticFeedback.warning()
                            if isInNavigationMode {
                                stopNavigation()
                            } else {
                                clearRoute()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#EF4444"), Color(hex: "#B91C1C")],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    Circle().stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: "#EF4444").opacity(0.5), radius: 10, y: 4)
                        }
                        .padding(.leading, 16)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.scale.combined(with: .opacity))
            }

            // Controles superiores: barra de búsqueda (ocultar cuando hay ruta activa)
            if !hasActiveRoute {
                VStack(alignment: .leading, spacing: 0) {
                    SearchBarView(
                        searchText: $searchManager.searchQuery,
                        isFocused: $isSearchFocused,
                        placeholder: "Where to?",
                        onSubmit: {
                            // Opcional: submit search
                        },
                        onClear: {
                            searchManager.clearSearch()
                        }
                    )
                    .layoutPriority(1)
                    .fadeIn(delay: 0.1)
                    .padding(.horizontal)
                    .padding(.top, AppConstants.safeAreaTop + 12)

                    if !searchManager.searchResults.isEmpty || searchManager.isSearching {
                        SearchResultsView(
                            results: searchManager.searchResults,
                            isSearching: searchManager.isSearching,
                            userLocation: locationManager.userLocation,
                            onSelect: handleSearchResultSelection
                        )
                        .padding(.horizontal)
                        .padding(.top, -10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Route Preference Selector (sheet modal, legacy).
            // Se oculta cuando el Trip Briefing está activo: el briefing
            // absorbió la elección de preferencia vía RoutePriorityPicker.
            if showRoutePreferences && !appSettings.useTripBriefing {
                RoutePreferenceSelector(
                    isPresented: $showRoutePreferences,
                    preferences: routePreferences,
                    onApply: {
                        // Aplicar nuevas preferencias
                        applyRoutePreferences()

                        // Recalcular rutas con nuevas preferencias
                        if let destination = destination {
                            guard let userLocation = locationManager.userLocation else { return }

                            // Limpiar rutas anteriores ANTES de recalcular
                            routeManager.clearRoute()

                            // Actualizar zonas de calidad del aire en RouteManager
                            routeManager.updateAirQualityZones(airQualityGridManager.zones)

                            // Recalcular
                            routeManager.calculateRoute(from: userLocation, to: destination.coordinate, destinationName: destination.title)
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }

            // Location Info Card (cuando se hace long press)
            if !isSearchFocused && showLocationInfo, let locationInfo = selectedLocationInfo {
                if appSettings.useTripBriefing, let userLocation = locationManager.userLocation {
                    // NUEVO: Trip Briefing como panel deplegable arriba,
                    // debajo del search bar. Compacto por default;
                    // se expande con el chevron. No tapa el mapa.
                    VStack(spacing: 0) {
                        // Espaciador para dejar paso al search bar.
                        Color.clear
                            .frame(height: AppConstants.safeAreaTop + 78)
                            .allowsHitTesting(false)

                        TripBriefingContainer(
                            origin: userLocation,
                            destination: locationInfo.coordinate,
                            destinationTitle: locationInfo.title,
                            zones: airQualityGridManager.zones,
                            vehicle: VehicleProfileService.shared.activeProfile,
                            gridManager: airQualityGridManager,
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showLocationInfo = false
                                    selectedLocationInfo = nil
                                    destination = nil
                                    briefingPreviewRoute = nil
                                }
                            },
                            onStartRoute: { context in
                                // Capturar la polyline del preview ANTES de que el
                                // sheet desaparezca (onDisappear la pone a nil).
                                let previewPolyline = briefingPreviewRoute?.polyline

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showLocationInfo = false
                                }
                                // CRÍTICO: setear destination para que aparezca el pin
                                // en el mapa y el flujo de ruta dispare todos sus triggers.
                                destination = DestinationPoint(
                                    coordinate: context.destination,
                                    title: context.destinationTitle
                                )
                                routeManager.clearRoute()
                                routeManager.updateActiveIncidents(annotations)
                                routeManager.updateAirQualityZones(airQualityGridManager.zones)
                                // Preferencia elegida en el briefing (reemplaza applyRoutePreferences).
                                routeManager.setPreference(context.preference)
                                routeManager.calculateRoute(
                                    from: userLocation,
                                    to: context.destination,
                                    destinationName: context.destinationTitle,
                                    transportType: context.transportType
                                )

                                // Disparar círculos AQI INMEDIATAMENTE con la
                                // polyline del preview (sin esperar MKDirections
                                // oficial, que tarda 1-3s). Cuando llegue la ruta
                                // oficial, se refinará con las 3 variantes.
                                if let polyline = previewPolyline {
                                    airQualityGridManager.updateZonesAlongRoutes(polylines: [polyline])
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    zoomToRoute()
                                    recomputeVisibleAirQualityZones()
                                }
                                showRouteToast(to: context.destinationTitle)
                            },
                            onOpenStations: {
                                // El sheet guía al usuario al tab Fuel → estaciones cercanas.
                                HapticFeedback.light()
                            },
                            onOpenDeparture: {
                                HapticFeedback.light()
                            },
                            onAddVehicle: {
                                HapticFeedback.light()
                            },
                            onPreviewRouteChanged: { route, mode in
                                briefingPreviewRoute = route
                                briefingPreviewMode = mode
                                if let r = route {
                                    zoomToBriefingPreview(r)
                                    // Generar círculos AQI a lo largo
                                    // del preview para que el usuario
                                    // vea la contaminación de la ruta
                                    // propuesta ANTES de aceptarla.
                                    airQualityGridManager.updateZonesAlongRoutes(polylines: [r.polyline])
                                }
                                recomputeVisibleAirQualityZones()
                            }
                        )
                        .id("\(locationInfo.coordinate.latitude)_\(locationInfo.coordinate.longitude)")
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))

                        Spacer()
                    }
                } else {
                    // LEGACY: LocationInfoCard clásica.
                    VStack {
                        Spacer()

                        LocationInfoCard(
                            locationInfo: locationInfo,
                            onCalculateRoute: {
                                guard let userLocation = locationManager.userLocation else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showLocationInfo = false
                                }
                                routeManager.clearRoute()
                                routeManager.updateActiveIncidents(annotations)
                                routeManager.updateAirQualityZones(airQualityGridManager.zones)
                                applyRoutePreferences()
                                routeManager.calculateRoute(from: userLocation, to: locationInfo.coordinate, destinationName: locationInfo.title)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    zoomToRoute()
                                }
                                showRouteToast(to: locationInfo.title)
                            },
                            onViewAirQuality: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showAirQualityLayer = true
                                    showLocationInfo = false
                                }
                                centerCamera(on: locationInfo.coordinate, distance: 3500)
                            },
                            onCancel: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showLocationInfo = false
                                    selectedLocationInfo = nil
                                    destination = nil
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal)
                        .padding(.bottom, tabBarHeight + 12)
                    }
                }
            }

            // Route Info Card o Calculating Indicator
            if !isSearchFocused && !showLocationInfo {
                VStack {
                    Spacer()

                    // Contenido de ruta
                    VStack(spacing: 12) {
                        // Selector de rutas múltiples
                        if !routeManager.allScoredRoutes.isEmpty {
                            RouteCardsSelector(
                                routes: routeManager.allScoredRoutes,
                                selectedIndex: $selectedRouteIndex,
                                onSelectRoute: { index in
                                    routeManager.selectRoute(at: index)

                                    // Haptic feedback
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if isInNavigationMode {
                            // Panel de navegación activa
                            NavigationPanel(
                                navigationState: navigationManager.state,
                                currentZone: navigationManager.currentZone,
                                distanceToManeuver: navigationManager.distanceToNextManeuver,
                                onEndNavigation: stopNavigation
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if routeManager.isCalculating {
                            CalculatingRouteView()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let routeInfo = routeManager.currentRoute {
                            RouteInfoCard(
                                routeInfo: routeInfo,
                                scoredRoute: routeManager.currentScoredRoute,
                                isCalculating: routeManager.isCalculating,
                                onClear: clearRoute,
                                onStartNavigation: startNavigation,
                                onViewAirQuality: {
                                    // Activar capa de calidad del aire centrada en la ruta
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showAirQualityLayer = true
                                    }

                                    // Hacer zoom para mostrar toda la ruta con el grid de calidad del aire
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        zoomToRoute()
                                    }

                                    print("🌫️ Capa de calidad del aire activada y zoom a ruta")
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let errorMessage = routeManager.errorMessage {
                            RouteErrorView(message: errorMessage, onDismiss: {
                                routeManager.clearRoute()
                            })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, tabBarHeight + 12)
                }
            }

            // Enhanced Air Quality Dashboard (superior derecha)
            if showAirQualityLayer && !isSearchFocused && !showLocationInfo {
                VStack {
                    HStack {
                        Spacer()

                        // Enhanced Dashboard con gráficos y breathability integrado
                        airQualityDashboard
                        .frame(maxWidth: 320)
                        .padding(.trailing)
                    }
                    .padding(.top, AppConstants.safeAreaTop + 80)

                    Spacer()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Hero Air Quality Card (cuando se toca una zona)
            if showZoneDetail, let zone = selectedZone, !isSearchFocused {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showZoneDetail = false
                            selectedZone = nil
                        }
                    }

                VStack {
                    Spacer()

                    HeroAirQualityCard(zone: zone) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showZoneDetail = false
                            selectedZone = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.bottom, tabBarHeight + 12)

                    Spacer()
                        .frame(height: 40)
                }
            }

            // Botones flotantes (ocultar cuando búsqueda está activa o se muestra location info)
            if !isSearchFocused && !showLocationInfo {
                if hasActiveRoute {
                    airQualityToggleButton
                        .padding(.top, AppConstants.safeAreaTop + 20)
                } else {
                    floatingButtons
                        .padding(.bottom, tabBarHeight + 20)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Actualizar región de búsqueda inicial
            if let location = locationManager.userLocation {
                searchManager.updateSearchRegion(center: location)
            }
            // Inicializar cache de zonas visibles.
            recomputeVisibleAirQualityZones()
        }
        .onChange(of: showAirQualityLayer) { _, newValue in
            if newValue {
                // Activar capa de calidad del aire.
                // Si las zones están vacías o contienen restos de una
                // ruta anterior (currentCenter=nil tras updateZonesAlongRoutes),
                // forzamos clearGrid + updateGrid para asegurar grid fresco
                // centrado en el usuario.
                if let userLocation = locationManager.userLocation {
                    if airQualityGridManager.zones.isEmpty
                        || airQualityGridManager.currentCenter == nil {
                        airQualityGridManager.clearGrid()
                        airQualityGridManager.updateGrid(center: userLocation)
                    }
                    airQualityGridManager.startAutoUpdate(center: userLocation)
                }
            } else {
                // Desactivar capa
                airQualityGridManager.stopAutoUpdate()
            }
            recomputeVisibleAirQualityZones()
        }
        .onReceive(locationManager.$userLocation) { newLocation in
            // Recompute cache de zonas visibles (user movement changes distance filtering).
            recomputeVisibleAirQualityZones()

            // Actualizar región de búsqueda cuando cambie ubicación del usuario
            if let location = newLocation {
                searchManager.updateSearchRegion(center: location)

                // Actualizar navegación si está activa
                if isInNavigationMode {
                    navigationManager.updateUserLocation(location, speed: locationManager.speed)

                    // Actualizar cámara para seguir al usuario en navegación (modo 2D con heading)
                    withAnimation(.easeOut(duration: 0.5)) {
                        camera = .camera(
                            MapCamera(
                                centerCoordinate: location,
                                distance: 1000,
                                heading: locationManager.heading,  // Sigue la dirección del celular
                                pitch: 0  // Modo 2D sin inclinación
                            )
                        )
                    }
                }

                // Actualizar grid de calidad del aire si está activo
                if showAirQualityLayer && !isInNavigationMode {
                    // Solo actualizar grid si NO está navegando (en navegación los círculos son fijos)
                    // Determinar centro del grid según punto de referencia
                    let gridCenter: CLLocationCoordinate2D

                    switch airQualityReferencePoint {
                    case .userLocation:
                        // Centrar en ubicación del usuario
                        gridCenter = location
                    case .destination(let destinationCoord):
                        // Center on destination (Point B)
                        gridCenter = destinationCoord
                        print("📍 Grid centered on Point B: (\(String(format: "%.4f", destinationCoord.latitude)), \(String(format: "%.4f", destinationCoord.longitude)))")
                    }

                    airQualityGridManager.updateGrid(center: gridCenter)
                }
            }
        }
        .onChange(of: destination) { oldDestination, newDestination in
            // Actualizar punto de referencia del grid cuando cambie el destino
            if let dest = newDestination {
                // User set a destination → change to Point B
                airQualityReferencePoint = .destination(dest.coordinate)

                // Clear search automatically
                searchManager.clearSearch()
                isSearchFocused = false

                print("🎯 Reference point changed to: Destination (Point B)")

                // Solo actualizar grid si NO hay ruta activa (las rutas usan su propio grid)
                if showAirQualityLayer && !hasActiveRoute {
                    airQualityGridManager.updateGrid(center: dest.coordinate)
                }
            } else {
                // Usuario eliminó el destino → volver a ubicación del usuario
                airQualityReferencePoint = .userLocation
                print("📍 Punto de referencia cambiado a: Tu Ubicación")

                // Actualizar grid inmediatamente si la capa está activa
                if showAirQualityLayer, let userLocation = locationManager.userLocation {
                    airQualityGridManager.updateGrid(center: userLocation)
                }
            }
        }
        .onReceive(routeManager.$currentRoute) { newRoute in
            if let newRoute {
                // Calcular flechas direccionales
                routeArrows = routeManager.calculateDirectionalArrows()

                // Marching ants solo si NO hay capa AQI activa — la animación
                // .repeatForever dispara re-render del body constantemente y
                // recomputa los 40+ círculos AQI en cada frame interpolado.
                startOrStopMarchingAnts()

                // Generar zones a lo largo del trayecto para ver
                // contaminación sobre la ruta elegida.
                airQualityGridManager.updateZonesAlongRoutes(polylines: [newRoute.polyline])

                print("✅ Animación de ruta iniciada!")
                print("   - Flechas direccionales: \(routeArrows.count)")

            } else {
                // Limpiar ruta
                routeArrows = []
                dashPhase = 0
            }
        }
        // Al togglear la capa AQI, encender/apagar marching ants según contexto.
        .onChange(of: showAirQualityLayer) { _, _ in
            startOrStopMarchingAnts()
        }
        .onReceive(routeManager.$allScoredRoutes) { routes in
            // Recomputa visibles (hasActiveRoute ahora depende de esta prop).
            recomputeVisibleAirQualityZones()

            // Cuando se calculan rutas nuevas, generar círculos a lo largo
            // de TODAS las rutas. No requerimos `showAirQualityLayer` porque
            // el overlay ya se muestra cuando hay ruta activa.
            guard !routes.isEmpty else { return }

            // Obtener todos los polylines de todas las rutas.
            let allPolylines = routes.map { $0.routeInfo.route.polyline }

            // Generar círculos de calidad del aire SOLO a lo largo de las rutas
            // con espaciado dinámico.
            airQualityGridManager.updateZonesAlongRoutes(polylines: allPolylines)

            print("🗺️ Rutas calculadas: generando círculos de calidad del aire a lo largo de \(routes.count) rutas")
        }
        .onReceive(airQualityGridManager.$zones) { zones in
            // Cache del snapshot visible — evita recomputar Haversine en cada render.
            recomputeVisibleAirQualityZones()

            // Cuando las zonas se actualizan, re-analizar rutas si es necesario.
            guard !zones.isEmpty, routeManager.needsAirQualityReanalysis else { return }

            print("🔄 Zonas de aire actualizadas (\(zones.count)) - Re-analizando rutas...")
            routeManager.reanalyzeWithAirQuality(zones: zones)
        }
        // Recompute cache cuando cambian los otros inputs del filtro de proximidad.
        .onChange(of: appSettings.enableProximityFiltering) { _, _ in
            recomputeVisibleAirQualityZones()
        }
        .onChange(of: appSettings.proximityRadiusMeters) { _, _ in
            recomputeVisibleAirQualityZones()
        }
        .onReceive(routeManager.$currentRoute) { _ in
            recomputeVisibleAirQualityZones()
        }
        .onReceive(routeManager.$isCalculating) { _ in
            recomputeVisibleAirQualityZones()
        }
        // Cuando cambia el preview del briefing, hacer zoom
        // y actualizar grid AQI a lo largo del trayecto. Si el preview
        // se pone a nil (sheet cerrado sin iniciar ruta) y NO hay ruta
        // oficial, regenerar grid centrado en el usuario para no dejar
        // el overlay vacío en modo AQI explícito.
        .onChange(of: briefingPreviewRoute?.distance) { _, _ in
            if let r = briefingPreviewRoute {
                zoomToBriefingPreview(r)
                airQualityGridManager.updateZonesAlongRoutes(polylines: [r.polyline])
            } else if !hasActiveRoute,
                      showAirQualityLayer,
                      let userLoc = locationManager.userLocation {
                airQualityGridManager.updateGrid(center: userLoc)
            }
            recomputeVisibleAirQualityZones()
        }
        // Cuando se cancela / limpia una ruta, restaurar grid centrado
        // en el usuario si el modo AQI sigue activo.
        .onChange(of: routeManager.currentRoute == nil && routeManager.allScoredRoutes.isEmpty) { _, noRoute in
            if noRoute,
               briefingPreviewRoute == nil,
               showAirQualityLayer,
               let userLoc = locationManager.userLocation {
                airQualityGridManager.updateGrid(center: userLoc)
            }
            recomputeVisibleAirQualityZones()
        }
        .onChange(of: isInNavigationMode) { _, _ in
            recomputeVisibleAirQualityZones()
        }
    }

    // MARK: - Map View Components

    private var enhancedMapView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "2b4c9c"),
                    Color(hex: "65c2c8")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            MapReader { proxy in
                Map(position: $camera) {
                // User location annotation
                if let location = locationManager.userLocation {
                    Annotation("My Location", coordinate: location) {
                        AnimatedCarIcon(
                            heading: locationManager.heading,
                            isMoving: locationManager.isMoving,
                            showPulse: showPulse
                        )
                    }
                }

                // Alert annotations (filtradas por proximidad)
                ForEach(visibleAnnotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        AlertAnnotationView(
                            alertType: annotation.alertType,
                            showPulse: true
                        )
                        .onTapGesture {
                            selectedAnnotation = annotation
                        }
                    }
                }

                // Destination annotation (Point B)
                if let dest = destination {
                    Annotation(dest.title, coordinate: dest.coordinate) {
                        DestinationAnnotationView()
                            .onTapGesture {
                                // Opcional: mostrar detalles del destino
                            }
                    }
                }

                // 🎨 MÚLTIPLES RUTAS OPTIMIZADAS
                if !routeManager.allScoredRoutes.isEmpty {
                    MultiRouteOverlay(
                        scoredRoutes: routeManager.allScoredRoutes,
                        selectedIndex: selectedRouteIndex,
                        animationPhase: dashPhase
                    )
                } else if let routeInfo = routeManager.currentRoute {
                    // Fallback: ruta única (modo legacy)
                    // CAPA 1: Base de ruta con gradiente suave
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.cyan.opacity(0.7),
                                    Color.blue.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )

                    // CAPA 2: Línea animada con marching ants elegante
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [10, 12],
                                dashPhase: dashPhase
                            )
                        )

                    // CAPA 3: Borde exterior sutil para profundidad
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            Color.blue.opacity(0.3),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                        )
                }

                // Trip Briefing preview: ruta tentativa mientras el
                // usuario decide en el sheet. Se oculta en cuanto hay
                // currentRoute "oficial" (ya se presionó "Ir").
                if showLocationInfo,
                   routeManager.currentRoute == nil,
                   let preview = briefingPreviewRoute {
                    // Halo suave detrás
                    MapPolyline(preview.polyline)
                        .stroke(
                            briefingPreviewColor.opacity(0.35),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                        )
                    // Dash central
                    MapPolyline(preview.polyline)
                        .stroke(
                            briefingPreviewColor.opacity(0.95),
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [12, 8],
                                dashPhase: dashPhase
                            )
                        )
                }

                // Directional arrows along route (filtradas por proximidad)
                ForEach(Array(visibleRouteArrows.enumerated()), id: \.element.id) { index, arrow in
                    Annotation("", coordinate: arrow.coordinate) {
                        DirectionalArrowView(
                            heading: arrow.heading,
                            isNext: false, // Sin animación - todas las flechas estáticas
                            size: 30
                        )
                    }
                    .annotationTitles(.hidden)
                }

                // Temporary tap marker
                if let coordinate = tappedCoordinate, !routingMode {
                    Annotation("New Report", coordinate: coordinate) {
                        CustomMapPin(color: .red, icon: "plus.circle.fill")
                            .pulseEffect(color: .red, duration: 1.0)
                    }
                }

                // 🌍 AIR QUALITY ZONES OVERLAY — MapCircle + Annotation.
                // Mantiene los fixes de performance (#1-#9):
                // - Cache @State de visibleZones (Fix #2)
                // - Sin .id() ni @EnvironmentObject (Fix #3)
                // - Sin .ultraThinMaterial (Fix #4)
                // - Overlay condicional por AQI level (Fix #5)
                // - Hard cap 20 zonas (Fix #9)
                //
                // También visible cuando hay ruta activa o preview del
                // briefing: el usuario debe ver la contaminación a lo
                // largo del trayecto propuesto.
                if showAirQualityLayer || hasActiveRoute || briefingPreviewRoute != nil {
                    ForEach(visibleAirQualityZones) { zone in
                        // Halo geográfico que colorea el área (radio 500m real).
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(zone.fillColor)
                            .stroke(zone.strokeColor, lineWidth: 0.5)

                        // Icono identificador encima (solo visible en zonas contaminadas).
                        Annotation("", coordinate: zone.coordinate) {
                            EnhancedAirQualityOverlay(
                                zone: zone,
                                enableRotation: appSettings.enableAirQualityRotation
                            )
                            .onTapGesture {
                                handleZoneTap(zone)
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(mapStyle.style(performanceMode: showAirQualityLayer))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                handleLongPress(at: location, with: proxy)
                            }
                        default:
                            break
                        }
                    }
            )
            .onTapGesture(coordinateSpace: .local) { screenPoint in
                handleMapTap(at: screenPoint, with: proxy)
            }
            }
        }
    }

    private var floatingButtons: some View {
        HStack {
            VStack(spacing: 15) {
                // Location button
                FloatingActionButton(
                    icon: "location.fill",
                    color: .blue,
                    size: 50
                ) {
                    centerOnUser()
                }

                // Map style button
                FloatingActionButton(
                    icon: mapStyle.icon,
                    color: .blue,
                    size: 50
                ) {
                    cycleMapStyle()
                }

                // Air Quality Layer button
                FloatingActionButton(
                    icon: "aqi.medium",
                    color: showAirQualityLayer ? .mint : .gray,
                    size: 50,
                    isPrimary: showAirQualityLayer
                ) {
                    toggleAirQualityLayer()
                }

                // Route Preferences button (solo si hay ruta activa)
                if routeManager.currentRoute != nil {
                    FloatingActionButton(
                        icon: "slider.horizontal.3",
                        color: .orange,
                        size: 50
                    ) {
                        showRoutePreferences = true
                    }
                }
            }
            .padding(.leading, 20)

            Spacer()
        }
    }

    private var airQualityToggleButton: some View {
        VStack {
            HStack {
                Spacer()

                FloatingActionButton(
                    icon: "aqi.medium",
                    color: showAirQualityLayer ? .mint : .gray,
                    size: 50,
                    isPrimary: showAirQualityLayer
                ) {
                    toggleAirQualityLayer()
                }
                .shadow(color: Color.mint.opacity(0.3), radius: 10, x: 0, y: 6)
                .padding(.trailing, 20)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var airQualityDashboard: some View {
        let navAction: (() -> Void)? = hasActiveRouteForNav ? { self.startNavigation() } : nil
        EnhancedAirQualityDashboard(
            isExpanded: $showAirQualityLegend,
            statistics: airQualityGridManager.getStatistics(),
            referencePoint: airQualityReferencePoint,
            activeRoute: routeManager.currentScoredRoute,
            onStartNavigation: navAction
        )
    }

    // MARK: - Helper Methods

    private func handleMapTap(at screenPoint: CGPoint, with proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }

        if routingMode {
            // Modo ruteo: establecer destino y calcular ruta
            setDestination(at: coordinate)
        }
        // Removido: modo de agregar alertas manualmente
    }

    private func handleLongPress(at screenPoint: CGPoint, with proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }

        // Haptic feedback fuerte para indicar long press detectado
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Centrar cámara en el punto seleccionado
        centerCamera(on: coordinate, distance: 800)

        // Obtener datos de calidad del aire del BACKEND REAL
        print("\n👆 ===== LONG PRESS EN MAPA =====")
        print("📍 Coordenadas: \(coordinate.latitude), \(coordinate.longitude)")

        // Usar datos reales: buscar zona más cercana del grid, o fallback a valor por defecto
        let airQuality: AirQualityPoint
        if let nearestZone = airQualityGridManager.getZoneAtCoordinate(coordinate) {
            airQuality = nearestZone.airQuality
            print("✅ AQI from grid zone: \(Int(nearestZone.airQuality.aqi))")
        } else {
            airQuality = AirQualityPoint(
                coordinate: coordinate,
                aqi: 50, pm25: 15, pm10: 25, timestamp: Date()
            )
            print("⚠️ No grid zone nearby, using default AQI=50")
        }

        // Obtener información del lugar con reverse geocoding
        searchManager.reverseGeocode(coordinate: coordinate) { address in
            DispatchQueue.main.async {
                            // Calcular distancia desde el usuario
                            let distanceText: String
                            if let userLocation = locationManager.userLocation {
                                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                let selectedCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                let distance = userCLLocation.distance(from: selectedCLLocation)

                                if distance < 1000 {
                                    distanceText = String(format: "%.0f m de tu ubicación", distance)
                                } else {
                                    distanceText = String(format: "%.1f km de tu ubicación", distance / 1000.0)
                                }
                            } else {
                                distanceText = "Ubicación desconocida"
                            }

                // Dividir dirección para obtener nombre y detalles
                let parsedAddress = splitAddress(address)

                // Crear LocationInfo con datos SIMULADOS (consistente con círculos)
                let locationInfo = LocationInfo(
                    coordinate: coordinate,
                    title: parsedAddress.title,
                    subtitle: parsedAddress.subtitle,
                    distanceFromUser: distanceText,
                    airQuality: airQuality
                )

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedLocationInfo = locationInfo
                    showLocationInfo = true
                }

                // Actualizar destino para mostrar etiqueta adecuada en el mapa
                destination = DestinationPoint(
                    coordinate: coordinate,
                    title: parsedAddress.title,
                    subtitle: parsedAddress.subtitle
                )

                print("✅ LocationInfo mostrado con DATOS SIMULADOS")
                print("   Lugar: \(parsedAddress.title)")
                print("   AQI: \(Int(airQuality.aqi)) - \(airQuality.level.rawValue)")
                print("   PM2.5: \(String(format: "%.1f", airQuality.pm25)) μg/m³")
                print("   Health Risk: \(airQuality.healthRisk.rawValue)")
                print("===== END LONG PRESS =====\n")
            }
        }
    }

    /// Divide la dirección recibida en un título principal y detalles opcionales
    private func splitAddress(_ address: String?) -> (title: String, subtitle: String?) {
        guard let rawAddress = address?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawAddress.isEmpty else {
            return ("Ubicación Seleccionada", nil)
        }

        let components = rawAddress
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let firstComponent = components.first else {
            return (rawAddress, nil)
        }

        let remaining = components.dropFirst().joined(separator: ", ")
        return (String(firstComponent), remaining.isEmpty ? nil : remaining)
    }

    private func centerOnUser() {
        guard let location = locationManager.userLocation else { return }

        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1000,
                    heading: locationManager.heading,
                    pitch: 60
                )
            )
        }
    }

    private func cycleMapStyle() {
        withAnimation {
            mapStyle = mapStyle.next()
        }
    }

    private func addAlertAtUserLocation() {
        tappedCoordinate = locationManager.userLocation
        mostrarSheet = true
    }

    // MARK: - Routing Methods

    private func toggleRoutingMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            routingMode.toggle()
        }

        if !routingMode {
            // Si se desactiva el modo ruteo, limpiar todo
            clearRoute()
        }
    }

    private func setDestination(at coordinate: CLLocationCoordinate2D, title: String = "Destination", subtitle: String? = nil, calculateRoute: Bool = true) {
        // Establecer destino con nombre
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            destination = DestinationPoint(
                coordinate: coordinate,
                title: title,
                subtitle: subtitle
            )
        }

        // Limpiar búsqueda automáticamente
        searchManager.clearSearch()
        isSearchFocused = false

        // Solo calcular ruta si se solicita
        if calculateRoute {
            guard let origin = locationManager.userLocation else {
                print("⚠️ No se puede calcular ruta sin ubicación del usuario")
                return
            }

            // Limpiar rutas anteriores ANTES de calcular nuevas
            routeManager.clearRoute()

            // Actualizar datos en el RouteManager
            routeManager.updateActiveIncidents(annotations)
            routeManager.updateAirQualityZones(airQualityGridManager.zones)

            // Aplicar preferencias
            applyRoutePreferences()

            // Calcular ruta considerando todos los factores
            routeManager.calculateRoute(from: origin, to: coordinate, destinationName: title)

            // Hacer zoom para mostrar toda la ruta después de calcularla con delay mayor
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                zoomToRoute()
            }
        }
    }

    private func clearRoute() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            // Si está en navegación, detenerla primero
            if isInNavigationMode {
                stopNavigation()
            }

            destination = nil
            routeManager.clearRoute()
            selectedRouteIndex = nil

            // Volver a grid centrado en ubicación del usuario
            if showAirQualityLayer, let userLocation = locationManager.userLocation {
                airQualityGridManager.updateGrid(center: userLocation)
                print("🔄 Restaurando grid de calidad del aire centrado en ubicación del usuario")
            }

            // Alejar la cámara a vista normal
            if let userLocation = locationManager.userLocation {
                camera = .camera(
                    MapCamera(
                        centerCoordinate: userLocation,
                        distance: 1000,  // Vista normal alejada
                        heading: locationManager.heading,
                        pitch: 60
                    )
                )
                print("📷 Cámara restaurada a vista normal")
            }
        }
    }

    // MARK: - Navigation Methods

    private func startNavigation() {
        guard let scoredRoute = routeManager.currentScoredRoute ?? routeManager.allScoredRoutes.first else {
            print("❌ No hay ruta para iniciar navegación")
            return
        }

        print("🧭 Iniciando navegación con ruta seleccionada...")

        // Iniciar navegación con NavigationManager
        navigationManager.startNavigation(route: scoredRoute, gridManager: airQualityGridManager)

        // Limpiar rutas alternativas - solo mostrar la ruta seleccionada
        routeManager.alternateScoredRoutes = []
        routeManager.allScoredRoutes = [scoredRoute]

        // Activar modo navegación
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isInNavigationMode = true
            routeManager.isInNavigationMode = true
        }

        // Asegurar que la capa de calidad del aire esté activa
        if !showAirQualityLayer {
            showAirQualityLayer = true
        }

        // Configurar cámara en modo 2D centrada en usuario con heading
        if let userLocation = locationManager.userLocation {
            withAnimation(.easeInOut(duration: 1.0)) {
                camera = .camera(
                    MapCamera(
                        centerCoordinate: userLocation,
                        distance: 1000,
                        heading: locationManager.heading,
                        pitch: 0  // Modo 2D sin inclinación
                    )
                )
            }
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        print("✅ Navegación iniciada - Modo 2D activado con heading del dispositivo")
    }

    private func stopNavigation() {
        print("🛑 Deteniendo navegación...")

        navigationManager.stopNavigation()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isInNavigationMode = false
            routeManager.isInNavigationMode = false
        }

        // Volver a vista normal del mapa
        if let userLocation = locationManager.userLocation {
            withAnimation(.easeInOut(duration: 1.0)) {
                camera = .camera(
                    MapCamera(
                        centerCoordinate: userLocation,
                        distance: 2000,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        }

        print("✅ Navegación detenida - Vista normal restaurada")
    }

    private func applyRoutePreferences() {
        // Determinar la preferencia basada en los pesos
        let preference: RoutePreference

        if routePreferences.speedWeight > 0.6 {
            preference = .fastest
        } else if routePreferences.safetyWeight > 0.5 {
            preference = .safest
        } else if routePreferences.airQualityWeight > 0.5 {
            preference = .cleanestAir
        } else if routePreferences.safetyWeight > 0.3 && routePreferences.airQualityWeight > 0.3 {
            preference = .balancedSafety
        } else {
            preference = .balanced
        }

        routeManager.setPreference(preference)
    }

    private func zoomToRoute() {
        guard let mapRect = routeManager.getRouteBounds() else { return }

        // Convertir MKMapRect a región para la cámara con mayor espacio visual
        var region = MKCoordinateRegion(mapRect)

        // Expandir región 100% para ver toda la ruta con más contexto (más alejado)
        region.span.latitudeDelta *= 2.0
        region.span.longitudeDelta *= 2.0

        withAnimation(.easeInOut(duration: 1.5)) {
            camera = .region(region)
        }
    }

    /// Zoom al preview del Trip Briefing — ajusta la cámara para que
    /// se vea toda la ruta tentativa en la mitad superior de la pantalla
    /// (la mitad inferior la ocupa el sheet).
    private func zoomToBriefingPreview(_ route: PreviewRoute) {
        var region = MKCoordinateRegion(route.polyline.boundingMapRect)
        // Un poco de padding horizontal y bastante vertical hacia abajo
        // para que quepa el sheet por abajo.
        region.span.latitudeDelta *= 3.0
        region.span.longitudeDelta *= 1.6
        // Empuja centro hacia arriba para dejar espacio al sheet.
        region.center.latitude -= region.span.latitudeDelta * 0.18

        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .region(region)
        }
    }

    // MARK: - Search Methods

    private func handleSearchResultSelection(_ result: SearchResult) {
        // Obtener coordenadas del resultado
        searchManager.selectResult(result) { coordinate in
            guard let coordinate = coordinate else {
                print("⚠️ No se pudo obtener coordenadas del resultado")
                return
            }

            // Cerrar teclado
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchFocused = false
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Centrar cámara en el punto seleccionado
            centerCamera(on: coordinate, distance: 800)

            // Calcular distancia desde el usuario
            let distanceText: String
            if let userLocation = locationManager.userLocation {
                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                let selectedCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = userCLLocation.distance(from: selectedCLLocation)

                if distance < 1000 {
                    distanceText = String(format: "%.0f m de tu ubicación", distance)
                } else {
                    distanceText = String(format: "%.1f km de tu ubicación", distance / 1000.0)
                }
            } else {
                distanceText = "Ubicación desconocida"
            }

            // Obtener datos de calidad del aire del BACKEND REAL
            Task {
                do {
                    print("\n🔍 ===== BÚSQUEDA DE CIUDAD =====")
                    print("📍 Ciudad seleccionada: \(result.title)")
                    print("   Subtítulo: \(result.subtitle)")
                    print("   Coordenadas: \(coordinate.latitude), \(coordinate.longitude)")
                    print("   Distancia: \(distanceText)")

                    // Consultar backend real
                    let airQuality = try await AirQualityAPIService.shared.getCurrentAQI(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )

                    // Crear LocationInfo con datos reales
                    await MainActor.run {
                        let locationInfo = LocationInfo(
                            coordinate: coordinate,
                            title: result.title,
                            subtitle: result.subtitle,
                            distanceFromUser: distanceText,
                            airQuality: airQuality
                        )

                        // Mostrar LocationInfoCard
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedLocationInfo = locationInfo
                            showLocationInfo = true
                        }

                        // Establecer destino (sin calcular ruta todavía)
                        destination = DestinationPoint(
                            coordinate: coordinate,
                            title: result.title,
                            subtitle: result.subtitle
                        )

                        print("✅ LocationInfo mostrado con DATOS REALES")
                        print("   AQI: \(Int(airQuality.aqi)) - \(airQuality.level.rawValue)")
                        print("   PM2.5: \(String(format: "%.1f", airQuality.pm25)) μg/m³")
                        print("   Health Risk: \(airQuality.healthRisk.rawValue)")
                        print("===== END BÚSQUEDA =====\n")
                    }

                } catch {
                    print("\n⚠️ ===== ERROR EN BACKEND =====")
                    print("❌ Error: \(error.localizedDescription)")
                    print("   Tipo: \(type(of: error))")
                    print("🔄 Activando fallback a datos simulados...")

                    // Fallback a datos del grid o valor por defecto
                    let airQuality: AirQualityPoint
                    if let nearestZone = airQualityGridManager.getZoneAtCoordinate(coordinate) {
                        airQuality = nearestZone.airQuality
                    } else {
                        airQuality = AirQualityPoint(
                            coordinate: coordinate,
                            aqi: 50, pm25: 15, pm10: 25, timestamp: Date()
                        )
                    }

                    await MainActor.run {
                        let locationInfo = LocationInfo(
                            coordinate: coordinate,
                            title: result.title,
                            subtitle: result.subtitle,
                            distanceFromUser: distanceText,
                            airQuality: airQuality
                        )

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedLocationInfo = locationInfo
                            showLocationInfo = true
                        }

                        destination = DestinationPoint(
                            coordinate: coordinate,
                            title: result.title,
                            subtitle: result.subtitle
                        )

                        print("⚠️ LocationInfo mostrado con fallback")
                        print("   AQI: \(Int(airQuality.aqi)) - \(airQuality.level.rawValue)")
                        print("   Fuente: Grid zone o default")
                        print("===== END BÚSQUEDA (FALLBACK) =====\n")
                    }
                }
            }
        }
    }

    private func centerCamera(on coordinate: CLLocationCoordinate2D, distance: Double = 1000) {
        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: distance,
                    heading: 0,
                    pitch: 45
                )
            )
        }
    }

    private func showRouteToast(to placeName: String) {
        routeToastMessage = "Calculando ruta a \(placeName)"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showRouteToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showRouteToast = false
            }
        }
    }

    // MARK: - Air Quality Methods

    /// Controla la animación marching ants de la ruta según contexto.
    /// Apaga la animación cuando la capa AQI está activa para evitar re-render
    /// del body a ~60 fps (la animación dispara recomposición del Map content).
    private func startOrStopMarchingAnts() {
        // Sin ruta activa → nada que animar.
        guard routeManager.currentRoute != nil else {
            dashPhase = 0
            return
        }

        if showAirQualityLayer {
            // Congelar animación para liberar el body.
            dashPhase = 0
        } else {
            // Reanudar animación solo si la ruta existe y no hay AQI.
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                dashPhase = 22
            }
        }
    }

    private func toggleAirQualityLayer() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showAirQualityLayer.toggle()

            // Expandir leyenda automáticamente la primera vez
            if showAirQualityLayer && !showAirQualityLegend {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAirQualityLegend = true
                    }
                }
            }
        }

        // Si se activa, inicializar grid
        if showAirQualityLayer, let userLocation = locationManager.userLocation {
            airQualityGridManager.startAutoUpdate(center: userLocation)
        }
    }

    private func handleZoneTap(_ zone: AirQualityZone) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Mostrar detalle de la zona
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedZone = zone
            showZoneDetail = true
        }
    }

}

// MARK: - Map Style Type

enum MapStyleType {
    case standard
    case hybrid
    case imagery

    /// Estilo default (rica en detalle) para uso normal.
    var style: MapStyle {
        style(performanceMode: false)
    }

    /// Estilo parametrizado — cuando `performanceMode == true` degrada elevation a `.flat`
    /// y apaga traffic para liberar GPU ante overlays pesados (ej. capa AQI activa).
    func style(performanceMode: Bool) -> MapStyle {
        let elevation: MapStyle.Elevation = performanceMode ? .flat : .realistic
        let showTraffic = !performanceMode

        switch self {
        case .standard:
            return .standard(elevation: elevation, pointsOfInterest: .all, showsTraffic: showTraffic)
        case .hybrid:
            return .hybrid(elevation: elevation, pointsOfInterest: .all, showsTraffic: showTraffic)
        case .imagery:
            return .imagery(elevation: elevation)
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe.americas.fill"
        }
    }

    func next() -> MapStyleType {
        switch self {
        case .standard: return .hybrid
        case .hybrid: return .imagery
        case .imagery: return .standard
        }
    }
}


// MARK: - Floating Action Button (AirWay premium glass)

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    var size: CGFloat = 50
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    isPressed = false
                }
            }
            action()
        }) {
            ZStack {
                // Glow radial para primary
                if isPrimary {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.55), color.opacity(0.2), .clear],
                                center: .center,
                                startRadius: size * 0.3,
                                endRadius: size * 0.9
                            )
                        )
                        .frame(width: size * 1.55, height: size * 1.55)
                        .scaleEffect(glowPulse)
                        .blur(radius: 10)
                }

                // Fondo black glass
                Circle()
                    .fill(.black.opacity(0.75))
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: isPrimary
                                        ? [color.opacity(0.8), color.opacity(0.2)]
                                        : [.white.opacity(0.18), .white.opacity(0.04)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: isPrimary ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isPrimary ? color.opacity(0.5) : .black.opacity(0.4),
                        radius: isPressed ? 6 : 12,
                        y: isPressed ? 2 : 6
                    )

                // Icono
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundColor(isPrimary ? .white : color)
                    .shadow(color: isPrimary ? color.opacity(0.7) : .clear, radius: 4)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
        .onAppear {
            if isPrimary {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    glowPulse = 1.25
                }
            }
        }
    }
}

// MARK: - Enhanced Alert Sheet

struct EnhancedAlertSheet: View {
    @Environment(\.dismiss) var dismiss
    var addAnnotation: (String) -> Void

    let alertTypes: [AlertType] = AlertType.allCases

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Report an incident")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Alert type grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(alertTypes, id: \.self) { type in
                    AlertTypeButton(alertType: type) {
                        addAnnotation(type.rawValue)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct AlertTypeButton: View {
    let alertType: AlertType
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback mejorado
            HapticAction.alertAdded.trigger()

            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Glow effect sutil
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    alertType.color.opacity(0.3),
                                    alertType.color.opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 6)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    alertType.gradientColors[0],
                                    alertType.gradientColors[1]
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 62, height: 62)

                    Image(systemName: alertType.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .shadow(color: alertType.color.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                Text(alertType.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
    }
}

// MARK: - Preview

#Preview {
    ContentView(showBusinessPulse: .constant(false))
}
