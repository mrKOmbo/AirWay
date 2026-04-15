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

    // Computed property para verificar si hay ruta activa
    private var hasActiveRoute: Bool {
        routeManager.currentRoute != nil || routeManager.isCalculating || isInNavigationMode
    }

    // Computed property para verificar si hay ruta activa para navegación
    private var hasActiveRouteForNav: Bool {
        routeManager.currentScoredRoute != nil && !isInNavigationMode
    }

    // MARK: - Proximity Filtering (2km Radius)

    /// Zonas de calidad del aire dentro del rango de visibilidad (2km)
    /// NOTA: Cuando hay rutas activas, deshabilita el filtro para mostrar TODAS las zonas de las rutas
    private var visibleAirQualityZones: [AirQualityZone] {
        guard let userLocation = locationManager.userLocation else {
            return airQualityGridManager.zones
        }

        // Si hay rutas activas, deshabilitar filtro para mostrar TODAS las zonas de las rutas
        if hasActiveRoute {
            print("🛣️ Proximity Filtering DISABLED (active route) - Showing all \(airQualityGridManager.zones.count) zones")
            return airQualityGridManager.zones
        }

        // Filtro normal cuando NO hay rutas
        guard appSettings.enableProximityFiltering else {
            print("📍 Proximity Filtering DISABLED - Showing all \(airQualityGridManager.zones.count) zones")
            return airQualityGridManager.zones
        }

        let filtered = ProximityFilter.filterZones(
            airQualityGridManager.zones,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )

        // Debug logging
        let stats = ProximityFilter.calculateStatistics(
            total: airQualityGridManager.zones,
            visible: filtered,
            radius: appSettings.proximityRadiusMeters
        )
        ProximityFilter.logFilterStatistics(stats, elementType: "Air Quality Zones")

        return filtered
    }

    /// Alerts dentro del rango de visibilidad (2km)
    private var visibleAnnotations: [CustomAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return annotations
        }

        guard appSettings.enableProximityFiltering else {
            return annotations
        }

        let filtered = ProximityFilter.filterAnnotations(
            annotations,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )

        // Debug logging
        if !annotations.isEmpty {
            let stats = ProximityFilter.calculateStatistics(
                total: annotations,
                visible: filtered,
                radius: appSettings.proximityRadiusMeters
            )
            ProximityFilter.logFilterStatistics(stats, elementType: "Alert Annotations")
        }

        return filtered
    }

    /// Route arrows dentro del rango de visibilidad (2km)
    private var visibleRouteArrows: [RouteArrowAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return routeArrows
        }

        guard appSettings.enableProximityFiltering else {
            return routeArrows
        }

        let filtered = ProximityFilter.filterRouteArrows(
            routeArrows,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )

        // Debug logging
        if !routeArrows.isEmpty {
            let stats = ProximityFilter.calculateStatistics(
                total: routeArrows,
                visible: filtered,
                radius: appSettings.proximityRadiusMeters
            )
            ProximityFilter.logFilterStatistics(stats, elementType: "Route Arrows")
        }

        return filtered
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
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)

                        Text(routeToastMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
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
                            if isInNavigationMode {
                                stopNavigation()
                            } else {
                                clearRoute()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.9))
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                )
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

            // Route Preference Selector (sheet modal)
            if showRoutePreferences {
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
                VStack {
                    Spacer()

                    LocationInfoCard(
                        locationInfo: locationInfo,
                        onCalculateRoute: {
                            // Calcular ruta desde ubicación actual al punto seleccionado
                            guard let userLocation = locationManager.userLocation else { return }

                            // Ocultar location info card
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showLocationInfo = false
                            }

                            // Limpiar rutas anteriores ANTES de calcular nuevas
                            routeManager.clearRoute()

                            // Actualizar datos en el RouteManager
                            routeManager.updateActiveIncidents(annotations)
                            routeManager.updateAirQualityZones(airQualityGridManager.zones)

                            // Aplicar preferencias
                            applyRoutePreferences()

                            // Calcular ruta considerando todos los factores
                            routeManager.calculateRoute(from: userLocation, to: locationInfo.coordinate, destinationName: locationInfo.title)

                            // Hacer zoom para mostrar toda la ruta después de calcularla
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                zoomToRoute()
                            }

                            // Mostrar toast
                            showRouteToast(to: locationInfo.title)
                        },
                        onViewAirQuality: {
                            // Activar capa de calidad del aire centrada en el destino
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()

                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAirQualityLayer = true
                                showLocationInfo = false  // Cerrar card para mejor visualización
                            }

                            // Centrar cámara en el destino con zoom apropiado para ver grid de calidad del aire
                            // Grid 3x3 con 800m spacing = ~2.4km diámetro, usar 3500m para ver todo
                            centerCamera(on: locationInfo.coordinate, distance: 3500)

                            print("🌫️ Capa de calidad del aire activada y centrada en destino")
                        },
                        onCancel: {
                            // Limpiar destino y ocultar card
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

            // Route Info Card o Calculating Indicator
            if !isSearchFocused && !showLocationInfo {
                VStack {
                    Spacer()

                    // Contenido de ruta
                    VStack(spacing: 12) {
                        // DEBUG: Logging de estado
                        let _ = print("🐛 DEBUG - allScoredRoutes count: \(routeManager.allScoredRoutes.count)")
                        let _ = print("🐛 DEBUG - currentRoute exists: \(routeManager.currentRoute != nil)")
                        let _ = print("🐛 DEBUG - isInNavigationMode: \(isInNavigationMode)")
                        let _ = print("🐛 DEBUG - isCalculating: \(routeManager.isCalculating)")

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
        }
        .onChange(of: showAirQualityLayer) { _, newValue in
            if newValue {
                // Activar capa de calidad del aire
                if let userLocation = locationManager.userLocation {
                    airQualityGridManager.startAutoUpdate(center: userLocation)
                }
            } else {
                // Desactivar capa
                airQualityGridManager.stopAutoUpdate()
            }
        }
        .onReceive(locationManager.$userLocation) { newLocation in
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
            if newRoute != nil {
                // Calcular flechas direccionales
                routeArrows = routeManager.calculateDirectionalArrows()

                // Inicializar animación de marching ants (simplificada)
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    dashPhase = 22
                }

                print("✅ Animación de ruta iniciada!")
                print("   - Flechas direccionales: \(routeArrows.count)")

            } else {
                // Limpiar ruta
                routeArrows = []
                dashPhase = 0
            }
        }
        .onReceive(routeManager.$allScoredRoutes) { routes in
            // Cuando se calculan rutas nuevas, generar círculos grandes que cubran el área de TODAS las rutas
            guard !routes.isEmpty, showAirQualityLayer else { return }

            // Obtener todos los polylines de todas las rutas
            let allPolylines = routes.map { $0.routeInfo.route.polyline }

            // Generar círculos de calidad del aire SOLO a lo largo de las rutas con espaciado dinámico
            airQualityGridManager.updateZonesAlongRoutes(polylines: allPolylines)

            print("🗺️ Rutas calculadas: generando círculos de calidad del aire a lo largo de \(routes.count) rutas")
        }
        .onReceive(airQualityGridManager.$zones) { zones in
            // Cuando las zonas se actualizan, re-analizar rutas si es necesario
            guard !zones.isEmpty, routeManager.needsAirQualityReanalysis else { return }

            print("🔄 Zonas de aire actualizadas (\(zones.count)) - Re-analizando rutas...")
            routeManager.reanalyzeWithAirQuality(zones: zones)
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

                // 🌍 AIR QUALITY ZONES OVERLAY - Optimized (Proximity Filtered + Static)
                if showAirQualityLayer {
                    ForEach(Array(visibleAirQualityZones.enumerated()), id: \.element.id) { index, zone in
                        // MapCircle estático para mostrar área de cobertura (500m radius)
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(zone.fillColor)
                            .stroke(zone.strokeColor, lineWidth: 0.5)

                        // Annotation estático con icono central (sin animaciones)
                        Annotation("", coordinate: zone.coordinate) {
                            EnhancedAirQualityOverlay(
                                zone: zone,
                                isVisible: showAirQualityLayer,
                                index: index,
                                settingsKey: "\(appSettings.enableAirQualityRotation)"
                            )
                            .environmentObject(appSettings)
                            .onTapGesture {
                                handleZoneTap(zone)
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(mapStyle.style)
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

        // Obtener datos de calidad del aire del GENERADOR SIMULADO (consistente con círculos)
        print("\n👆 ===== LONG PRESS EN MAPA =====")
        print("📍 Coordenadas: \(coordinate.latitude), \(coordinate.longitude)")

        // Usar generador simulado (mismo que círculos del mapa)
        let airQuality = AirQualityDataGenerator.shared.generateAirQuality(
            for: coordinate,
            includeExtendedMetrics: false
        )

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

                    // Fallback a datos simulados
                    let airQuality = AirQualityDataGenerator.shared.generateAirQuality(
                        for: coordinate,
                        includeExtendedMetrics: true
                    )

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

                        print("⚠️ LocationInfo mostrado con DATOS SIMULADOS (fallback)")
                        print("   AQI: \(Int(airQuality.aqi)) - \(airQuality.level.rawValue)")
                        print("   Fuente: AirQualityDataGenerator (local)")
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

    var style: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
        case .hybrid:
            return .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
        case .imagery:
            return .imagery(elevation: .realistic)
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


// MARK: - Floating Action Button (Modernizado)

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    var size: CGFloat = 50
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: isPrimary ? .medium : .light)
            impact.impactOccurred()

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
                // Glow effect para botón primario
                if isPrimary {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(glowIntensity),
                                    color.opacity(glowIntensity * 0.5),
                                    .clear
                                ],
                                center: .center,
                                startRadius: size * 0.3,
                                endRadius: size * 0.9
                            )
                        )
                        .frame(width: size * 1.3, height: size * 1.3)
                        .blur(radius: 8)
                }

                // Fondo del botón
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .fill(
                                isPrimary ?
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.95),
                                        color.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.9),
                                        .white.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: isPrimary ?
                                    [.white.opacity(0.6), .white.opacity(0.2)] :
                                    [.black.opacity(0.1), .black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isPrimary ? 2 : 1.5
                            )
                    )
                    .shadow(
                        color: isPrimary ? color.opacity(0.4) : .black.opacity(0.15),
                        radius: isPressed ? 8 : 12,
                        x: 0,
                        y: isPressed ? 3 : 6
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 3,
                        x: 0,
                        y: 2
                    )

                // Icono
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 28 : 22, weight: .semibold))
                    .foregroundStyle(
                        isPrimary ?
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [color, color.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: isPrimary ? .black.opacity(0.3) : .clear,
                        radius: 1,
                        x: 0,
                        y: 1
                    )
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
        .onAppear {
            if isPrimary {
                // Animación de glow pulsante
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    glowIntensity = 0.5
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
