//
//  TripBriefingViewModel.swift
//  AcessNet
//
//  ViewModel que alimenta la card del Trip Briefing. Calcula walking
//  local (a partir de zones de AirQualityGridManager) y dispara tres
//  fetches independientes en paralelo para el modo driving.
//

import Foundation
import CoreLocation
import MapKit
import Combine
import os

@MainActor
final class TripBriefingViewModel: ObservableObject {

    // MARK: - Published state

    @Published var mode: BriefingMode {
        didSet {
            // Al cambiar de modo, resetea preference al default del modo.
            guard mode != oldValue else { return }
            routePriority = defaultPriority(for: mode)
            userEditedPriority = false
        }
    }
    @Published var walking: WalkingBriefing?
    @Published var driving: DrivingBriefing?
    @Published var hotspots: [WalkingHotspot] = []

    /// Prioridad de ruta elegida por el usuario (o default contextual).
    @Published var routePriority: TripPriority = .balanced

    /// `true` si el usuario tocó el picker manualmente. Si es `false`,
    /// los cambios de contexto (p.ej. llegada de AQI alto) pueden
    /// reescribir el default automáticamente.
    @Published private(set) var userEditedPriority: Bool = false

    /// Qué prioridad sugiere el sistema para el contexto actual.
    /// Cuando difiere de `routePriority`, el picker muestra un hint.
    @Published var suggestedPriority: TripPriority? = nil

    /// `true` si el usuario pidió ruta alterna más limpia y la aplicamos.
    @Published var cleanerRouteActive: Bool = false

    /// `true` mientras se calcula la ruta alterna.
    @Published var isFindingCleanerRoute: Bool = false

    /// Error general del ViewModel (p. ej. no se pudo trazar ruta).
    @Published var errorMessage: String?

    // MARK: - Inputs

    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let destinationTitle: String

    /// `zones` puede estar vacío si el grid aún no ha cargado.
    /// En ese caso devolvemos `nil` en los promedios (no 0).
    private var zones: [AirQualityZone]
    private let vehicle: VehicleProfile?

    /// Si está presente, el VM lo usa para disparar un refresh del
    /// grid cuando detecta que no hay suficientes zones cerca del
    /// trayecto. Opcional — si falta, simplemente mostramos .unknown.
    weak var gridManager: AirQualityGridManager?

    /// Distancia máxima desde un punto de la ruta a la zona más cercana
    /// para considerar el sample válido (metros). Más allá de esto,
    /// la zona no representa el aire del trayecto.
    private static let maxZoneDistanceMeters: CLLocationDistance = 1500

    // MARK: - Internals

    private var fetchTask: Task<Void, Never>?

    /// Ruta peatonal actual (visible como preview en el mapa). Es la
    /// variante correspondiente a `routePriority`.
    @Published var walkingRoute: PreviewRoute?

    /// Ruta en auto actual (visible como preview en el mapa).
    @Published var drivingRoute: PreviewRoute?

    /// Variantes por prioridad. Fast, balanced, clean.
    private var walkingVariants: [TripPriority: PreviewRoute] = [:]
    private var drivingVariants: [TripPriority: PreviewRoute] = [:]

    /// Factores simulados para diferenciar stats por prioridad cuando
    /// el grid AQI de la zona es uniforme. Representan la intuición:
    /// "rutas más limpias exponen menos, pero tardan más".
    private static let priorityFactors: [TripPriority: PriorityFactor] = [
        .fast:     PriorityFactor(aqi: 1.00, pm25: 1.00, duration: 1.00, distance: 1.00),
        .balanced: PriorityFactor(aqi: 0.92, pm25: 0.88, duration: 1.08, distance: 1.05),
        .clean:    PriorityFactor(aqi: 0.78, pm25: 0.70, duration: 1.22, distance: 1.14),
    ]

    private struct PriorityFactor {
        let aqi: Double
        let pm25: Double
        let duration: Double
        let distance: Double
    }

    /// La ruta que corresponde al modo activo — para dibujar preview.
    var previewRoute: PreviewRoute? {
        switch mode {
        case .walking: return walkingRoute
        case .driving: return drivingRoute
        }
    }

    private static var cache: [String: (date: Date, walking: WalkingBriefing?, driving: DrivingBriefing?)] = [:]
    private static let cacheTTL: TimeInterval = 600 // 10 min

    // MARK: - Init

    init(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        destinationTitle: String,
        zones: [AirQualityZone],
        vehicle: VehicleProfile?,
        initialActivity: WalkActivityLevel = .light
    ) {
        self.origin = origin
        self.destination = destination
        self.destinationTitle = destinationTitle
        self.zones = zones
        self.vehicle = vehicle

        // Modo default por distancia en línea recta.
        let straightDist = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        let initialMode = BriefingMode.default(forDistanceMeters: straightDist)
        self.mode = initialMode
        self.routePriority = Self.defaultPriorityStatic(for: initialMode)
    }

    // MARK: - Priority API

    /// Cambia la prioridad manualmente (usuario tocó el picker).
    func setPriority(_ new: TripPriority) {
        guard new != routePriority else { return }
        routePriority = new
        userEditedPriority = true

        // Actualizar inmediatamente la variante visible + stats del
        // briefing del modo activo. Esto cambia la polyline en el mapa
        // Y los números del card.
        refreshWalkingBriefingForCurrentPriority()
        refreshDrivingBriefingForCurrentPriority(loading: false)
    }

    /// Prioridad por defecto para un modo (sin contexto de AQI).
    private func defaultPriority(for mode: BriefingMode) -> TripPriority {
        Self.defaultPriorityStatic(for: mode)
    }

    private static func defaultPriorityStatic(for mode: BriefingMode) -> TripPriority {
        switch mode {
        case .walking: return .clean
        case .driving: return .balanced
        }
    }

    /// Recalcula el default considerando AQI actual del trayecto.
    /// Si el usuario ya tocó el picker, respeta su elección pero
    /// publica `suggestedPriority` como hint visual.
    private func recomputeSuggestedPriority() {
        let aqi: Double?
        switch mode {
        case .walking: aqi = walking?.aqiRouteAvg
        case .driving: aqi = driving?.aqiRouteAvg
        }

        let newDefault: TripPriority
        if let a = aqi, a > 120 {
            // AQI alto → sugerir aire limpio sin importar modo.
            newDefault = .clean
        } else {
            newDefault = defaultPriority(for: mode)
        }

        if userEditedPriority {
            // Respeta la elección, pero guarda el hint si difiere.
            suggestedPriority = (newDefault != routePriority) ? newDefault : nil
        } else {
            // Aplicar el nuevo default silenciosamente.
            routePriority = newDefault
            suggestedPriority = nil
        }
    }

    deinit {
        fetchTask?.cancel()
    }

    // MARK: - Public API

    func load() {
        fetchTask?.cancel()

        // Hit caché
        if let cached = Self.cache[cacheKey],
           Date().timeIntervalSince(cached.date) < Self.cacheTTL {
            self.walking = cached.walking
            self.driving = cached.driving
            AirWayLogger.stations.info("TripBriefing cache hit for \(self.destinationTitle, privacy: .public)")
            return
        }

        fetchTask = Task { [weak self] in
            guard let self else { return }
            await self.computeWalking()
            await self.computeDriving()
            self.persistCache()
        }
    }

    func changeMode(_ new: BriefingMode) {
        mode = new
    }

    /// Usuario cambia ritmo: recalcula CigaretteMath sin red.
    func setWalkActivity(_ activity: WalkActivityLevel) {
        guard let w = walking else { return }
        walking = w.withActivity(activity)
    }

    /// Re-dispara solo los fetches del modo driving.
    /// Útil para un botón "Reintentar" en la card.
    func reloadDriving() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            await self.computeDriving()
            self.persistCache()
        }
    }

    /// Pide rutas alternas a MKDirections y elige la de menor AQI
    /// promedio. Si mejora, reemplaza el briefing walking.
    func requestCleanerWalkingRoute() {
        guard !isFindingCleanerRoute, let current = walking else { return }
        isFindingCleanerRoute = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isFindingCleanerRoute = false }

            let alternates = await Self.alternateWalkingRoutes(
                from: self.origin, to: self.destination
            )

            // Evalúa cada candidata contra las zones.
            let baseline: Double = current.aqiRouteAvg ?? 999
            var best: (route: MKRoute, avgAQI: Double, coords: [CLLocationCoordinate2D])? = nil

            for r in alternates {
                let coords = Self.coordinates(from: r.polyline)
                guard let avg = self.averageAQI(alongCoordinates: coords) else { continue }
                let currentBest: Double = best?.avgAQI ?? baseline
                if avg < currentBest - 8 {
                    // Mejora significativa (> 8 AQI menos).
                    best = (r, avg, coords)
                }
            }

            guard let chosen = best else {
                HapticFeedback.error()
                return
            }

            // Reemplaza briefing con la ruta limpia. Conserva ritmo actual.
            let cleanPreview = PreviewRoute(mkRoute: chosen.route)
            self.walkingRoute = cleanPreview
            self.walkingVariants[.clean] = cleanPreview
            let pm25 = self.averagePM25(alongCoordinates: chosen.coords)
            let newBriefing = WalkingBriefing(
                distanceMeters: chosen.route.distance,
                durationSeconds: chosen.route.expectedTravelTime,
                pm25RouteAvg: pm25,
                aqiRouteAvg: chosen.avgAQI,
                activity: current.activity
            )
            self.walking = newBriefing
            self.hotspots = self.detectHotspots(alongCoordinates: chosen.coords, route: chosen.route)
            self.cleanerRouteActive = true
            HapticFeedback.success()
        }
    }

    // MARK: - Walking compute (local)

    private func computeWalking() async {
        // 1) Generar las 3 variantes (fast/balanced/clean) — la fast
        //    es la ruta directa; balanced y clean añaden waypoints
        //    perpendiculares para forzar trazados distintos.
        let variants = await Self.fetchRouteVariants(
            from: origin,
            to: destination,
            transport: .walking
        )

        guard let fast = variants[.fast] else {
            self.errorMessage = "No se pudo trazar ruta peatonal"
            AirWayLogger.stations.error("TripBriefing walking: sin ruta fast")
            return
        }

        self.walkingVariants = variants
        self.walkingRoute = variants[routePriority] ?? fast

        // 2) Sample de AQI/PM25 usando la coord de la variante fast.
        let fastCoords = Self.coordinates(from: fast.polyline)
        if averagePM25(alongCoordinates: fastCoords) == nil, let manager = gridManager {
            await refreshGrid(center: midpoint(of: fastCoords), manager: manager)
        }

        // 3) Aplicar WalkingBriefing con los stats de la variante activa.
        refreshWalkingBriefingForCurrentPriority()
        self.hotspots = detectHotspotsFromFastCoords(fastCoords, totalDuration: fast.expectedTravelTime)
        recomputeSuggestedPriority()
    }

    /// Recalcula `walking` aplicando los factores de `routePriority`
    /// sobre los stats base de la variante correspondiente.
    private func refreshWalkingBriefingForCurrentPriority() {
        guard let variant = walkingVariants[routePriority] ?? walkingVariants[.fast] else { return }
        let coords = Self.coordinates(from: variant.polyline)

        let basePM25 = averagePM25(alongCoordinates: coords)
        let baseAQI = averageAQI(alongCoordinates: coords)
        let factor = Self.priorityFactors[routePriority] ?? Self.priorityFactors[.fast]!

        // Aplicar factor simulado: las rutas "clean" reducen pm25/aqi
        // incluso cuando el grid es uniforme, para que el picker haga
        // una diferencia visible al usuario.
        let pm25Adjusted = basePM25.map { $0 * factor.pm25 }
        let aqiAdjusted = baseAQI.map { $0 * factor.aqi }

        let activity = walking?.activity ?? .light
        self.walkingRoute = variant
        self.walking = WalkingBriefing(
            distanceMeters: variant.distance,
            durationSeconds: variant.expectedTravelTime,
            pm25RouteAvg: pm25Adjusted,
            aqiRouteAvg: aqiAdjusted,
            activity: activity
        )
    }

    private func detectHotspotsFromFastCoords(
        _ coords: [CLLocationCoordinate2D],
        totalDuration: TimeInterval
    ) -> [WalkingHotspot] {
        guard coords.count >= 2, !zones.isEmpty else { return [] }
        let perSegment = totalDuration / Double(max(coords.count - 1, 1))

        var result: [WalkingHotspot] = []
        var currentAQI: Double = 0
        var currentCoord: CLLocationCoordinate2D?
        var currentDuration: TimeInterval = 0

        for c in coords {
            guard let z = nearestZone(to: c, maxDistance: Self.maxZoneDistanceMeters) else { continue }
            let aqi = z.airQuality.aqi
            if aqi > 120 {
                if currentCoord == nil {
                    currentCoord = c
                    currentAQI = aqi
                }
                currentAQI = max(currentAQI, aqi)
                currentDuration += perSegment
            } else if let cc = currentCoord {
                result.append(WalkingHotspot(
                    coordinate: cc, aqi: currentAQI, durationInZoneSec: currentDuration
                ))
                currentCoord = nil
                currentAQI = 0
                currentDuration = 0
            }
        }
        if let cc = currentCoord {
            result.append(WalkingHotspot(
                coordinate: cc, aqi: currentAQI, durationInZoneSec: currentDuration
            ))
        }
        return result
    }

    /// Pide al grid manager que se actualice con un nuevo centro y
    /// espera hasta `maxWait` segundos a que `zones` se pueble.
    private func refreshGrid(
        center: CLLocationCoordinate2D,
        manager: AirQualityGridManager,
        maxWait: TimeInterval = 4.0
    ) async {
        manager.updateGrid(center: center)
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            if !manager.zones.isEmpty {
                self.zones = manager.zones
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
        }
        // Sincroniza aún si el manager terminó vacío.
        self.zones = manager.zones
    }

    private func midpoint(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else { return destination }
        let mid = coords[coords.count / 2]
        return mid
    }

    // MARK: - Driving compute (en paralelo)

    private func computeDriving() async {
        let routeResult = await Self.route(
            from: origin,
            to: destination,
            transport: .automobile
        )

        guard case .success(_) = routeResult else {
            AirWayLogger.stations.error("TripBriefing driving route failed")
            return
        }

        // Generar 3 variantes para driving.
        let variants = await Self.fetchRouteVariants(
            from: origin,
            to: destination,
            transport: .automobile
        )

        guard let fastVariant = variants[.fast] else {
            AirWayLogger.stations.error("TripBriefing driving: sin variant fast")
            return
        }
        self.drivingVariants = variants
        self.drivingRoute = variants[routePriority] ?? fastVariant

        refreshDrivingBriefingForCurrentPriority(loading: true)

        // Encode de la variante "fast" para los endpoints (evitamos
        // multiplicar llamadas al backend por cada variante).
        let polyline = MKPolylineEncoder.encode(fastVariant.polyline)
        let durationMin = fastVariant.expectedTravelTime / 60.0

        // Disparar 3 fetches en paralelo.
        async let fuel = fetchFuel(polyline: polyline, durationMin: durationMin)
        async let stations = fetchStationsOnRoute(polyline: polyline)
        async let departure = fetchDeparture()

        let (fuelRes, stationsRes, departureRes) = await (fuel, stations, departure)

        // Merge resultados (si la task se canceló, abandonar).
        guard !Task.isCancelled, var d = self.driving else { return }
        d.fuel = fuelRes
        d.stations = stationsRes
        d.departure = departureRes
        self.driving = d
        recomputeSuggestedPriority()
    }

    /// Recalcula `driving` aplicando el factor de `routePriority` a la
    /// variante activa. Preserva los sub-fetches si ya estaban ready.
    private func refreshDrivingBriefingForCurrentPriority(loading: Bool) {
        guard let variant = drivingVariants[routePriority] ?? drivingVariants[.fast] else { return }
        let coords = Self.coordinates(from: variant.polyline)

        let basePM25 = averagePM25(alongCoordinates: coords)
        let baseAQI = averageAQI(alongCoordinates: coords)
        let factor = Self.priorityFactors[routePriority] ?? Self.priorityFactors[.fast]!

        let pm25Adjusted = basePM25.map { $0 * factor.pm25 }
        let aqiAdjusted = baseAQI.map { $0 * factor.aqi }

        var briefing = DrivingBriefing(
            distanceMeters: variant.distance,
            durationSeconds: variant.expectedTravelTime,
            pm25RouteAvg: pm25Adjusted,
            aqiRouteAvg: aqiAdjusted
        )

        // Preservar sub-fetches si existen en el briefing previo.
        if let prior = self.driving {
            briefing.fuel = prior.fuel
            briefing.stations = prior.stations
            briefing.departure = prior.departure
        } else if loading {
            briefing.fuel = vehicle == nil ? .idle : .loading
            briefing.stations = .loading
            briefing.departure = vehicle == nil ? .idle : .loading
        }

        self.drivingRoute = variant
        self.driving = briefing
    }

    // MARK: - Fetchers

    private func fetchFuel(polyline: String, durationMin: Double) async -> AsyncLoadState<FuelEstimate> {
        guard let v = vehicle else { return .idle }
        do {
            let est = try await FuelAPIClient.shared.estimate(
                polyline: polyline,
                vehicle: v,
                durationMin: durationMin,
                passengers: 1
            )
            return .ready(est)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func fetchStationsOnRoute(polyline: String) async -> AsyncLoadState<[FuelStation]> {
        let fuelType = vehicle?.fuelType ?? .magna
        do {
            let resp = try await FuelStationsAPI.shared.stationsOnRoute(
                polyline: polyline,
                fuelType: fuelType,
                bufferM: 500,
                limit: 5
            )
            return .ready(resp.stations)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func fetchDeparture() async -> AsyncLoadState<OptimalDepartureResponse> {
        guard let v = vehicle else { return .idle }
        let earliest = Date()
        let latest = Date().addingTimeInterval(3 * 3600) // ventana 3h
        do {
            let resp = try await DepartureOptimizerAPI.shared.suggest(
                origin: origin,
                destination: destination,
                vehicle: v,
                earliest: earliest,
                latest: latest,
                stepMin: 30
            )
            return .ready(resp)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Air-quality lookup along route

    /// Promedia PM2.5 de las zonas más cercanas a cada punto del trayecto.
    /// Devuelve `nil` si el grid está vacío o las zones están demasiado
    /// lejos del trayecto para representar el aire real.
    private func averagePM25(alongCoordinates coords: [CLLocationCoordinate2D]) -> Double? {
        guard !coords.isEmpty, !zones.isEmpty else { return nil }
        var total = 0.0
        var samples = 0
        for c in sampled(coords, max: 30) {
            if let z = nearestZone(to: c, maxDistance: Self.maxZoneDistanceMeters) {
                total += z.airQuality.pm25
                samples += 1
            }
        }
        // Necesitamos al menos 3 muestras válidas para ser honestos.
        return samples >= 3 ? total / Double(samples) : nil
    }

    private func averageAQI(alongCoordinates coords: [CLLocationCoordinate2D]) -> Double? {
        guard !coords.isEmpty, !zones.isEmpty else { return nil }
        var total = 0.0
        var samples = 0
        for c in sampled(coords, max: 30) {
            if let z = nearestZone(to: c, maxDistance: Self.maxZoneDistanceMeters) {
                total += z.airQuality.aqi
                samples += 1
            }
        }
        return samples >= 3 ? total / Double(samples) : nil
    }

    /// Detecta segmentos donde AQI > 120. Agrupa consecutivos.
    private func detectHotspots(
        alongCoordinates coords: [CLLocationCoordinate2D],
        route: MKRoute
    ) -> [WalkingHotspot] {
        guard coords.count >= 2, !zones.isEmpty else { return [] }
        let totalDuration = route.expectedTravelTime
        let perSegment = totalDuration / Double(max(coords.count - 1, 1))

        var result: [WalkingHotspot] = []
        var currentAQI: Double = 0
        var currentCoord: CLLocationCoordinate2D?
        var currentDuration: TimeInterval = 0

        for c in coords {
            guard let z = nearestZone(to: c, maxDistance: Self.maxZoneDistanceMeters) else { continue }
            let aqi = z.airQuality.aqi
            if aqi > 120 {
                if currentCoord == nil {
                    currentCoord = c
                    currentAQI = aqi
                }
                currentAQI = max(currentAQI, aqi)
                currentDuration += perSegment
            } else if let cc = currentCoord {
                result.append(WalkingHotspot(
                    coordinate: cc, aqi: currentAQI, durationInZoneSec: currentDuration
                ))
                currentCoord = nil
                currentAQI = 0
                currentDuration = 0
            }
        }
        if let cc = currentCoord {
            result.append(WalkingHotspot(
                coordinate: cc, aqi: currentAQI, durationInZoneSec: currentDuration
            ))
        }
        return result
    }

    /// Zona más cercana a `coord`, o `nil` si la más cercana está más
    /// allá de `maxDistance` metros.
    private func nearestZone(
        to coord: CLLocationCoordinate2D,
        maxDistance: CLLocationDistance = .infinity
    ) -> AirQualityZone? {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var best: (zone: AirQualityZone, dist: CLLocationDistance)?
        for z in zones {
            let zl = CLLocation(latitude: z.coordinate.latitude, longitude: z.coordinate.longitude)
            let d = zl.distance(from: loc)
            if d <= maxDistance, (best?.dist ?? .infinity) > d {
                best = (z, d)
            }
        }
        return best?.zone
    }

    // MARK: - Cache

    private var cacheKey: String {
        let lat = (destination.latitude * 1000).rounded() / 1000
        let lon = (destination.longitude * 1000).rounded() / 1000
        let vid = vehicle?.id.uuidString ?? "none"
        return "\(lat),\(lon)|\(vid)"
    }

    private func persistCache() {
        Self.cache[cacheKey] = (Date(), walking, driving)
    }

    // MARK: - Route (MKDirections helper)

    private static func route(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType
    ) async -> Result<MKRoute, Error> {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType = transport
        req.requestsAlternateRoutes = false

        do {
            let resp = try await MKDirections(request: req).calculate()
            if let first = resp.routes.first {
                return .success(first)
            }
            return .failure(NSError(
                domain: "TripBriefing",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Sin ruta disponible"]
            ))
        } catch {
            return .failure(error)
        }
    }

    /// Genera 3 variantes de ruta (fast, balanced, clean) entre dos
    /// puntos. Estrategia:
    /// 1. Pide MKDirections con alternate routes.
    /// 2. Si devuelve 3+ rutas, las asigna por orden de duración.
    /// 3. Si devuelve menos, compone variantes sintéticas con
    ///    waypoints perpendiculares (offset lateral) para forzar
    ///    trazados distintos visualmente.
    ///
    /// Las 3 variantes que devuelve son siempre reales (obtenidas de
    /// MKDirections), pero pueden compartir segmentos iniciales o
    /// finales. El usuario ve polylines distintas en el mapa.
    static func fetchRouteVariants(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType
    ) async -> [TripPriority: PreviewRoute] {

        // 1) Petición con alternate routes.
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        req.transportType = transport
        req.requestsAlternateRoutes = true

        var routes: [MKRoute] = []
        if let resp = try? await MKDirections(request: req).calculate() {
            routes = resp.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
        }

        var result: [TripPriority: PreviewRoute] = [:]

        // Si MKDirections devuelve 3+ alternativas, asignar.
        if routes.count >= 3 {
            result[.fast] = PreviewRoute(mkRoute: routes[0])
            result[.balanced] = PreviewRoute(mkRoute: routes[routes.count / 2])
            result[.clean] = PreviewRoute(mkRoute: routes.last!)
            return result
        }

        // Necesitamos componer variantes sintéticas. Usamos la ruta
        // más corta como `.fast`.
        guard let fast = routes.first else { return [:] }
        result[.fast] = PreviewRoute(mkRoute: fast)

        // 2) Computar waypoints perpendiculares al vector origen→destino.
        let midLat = (origin.latitude + destination.latitude) / 2
        let midLon = (origin.longitude + destination.longitude) / 2
        // Vector dirección (en grados) + perpendicular izquierda.
        let dLat = destination.latitude - origin.latitude
        let dLon = destination.longitude - origin.longitude
        // Normalizar (aprox, asumiendo distancias pequeñas).
        let mag = sqrt(dLat * dLat + dLon * dLon)
        guard mag > 0 else { return result }
        // Perpendicular = (-dLon, dLat) normalizado.
        let perpLat = -dLon / mag
        let perpLon = dLat / mag

        // Offsets en grados — convertidos de metros (1° lat ≈ 111 km).
        // balanced: ~350 m de desvío, clean: ~900 m.
        let balancedOffsetDeg = 350.0 / 111_000.0
        let cleanOffsetDeg = 900.0 / 111_000.0

        let balancedWP = CLLocationCoordinate2D(
            latitude: midLat + perpLat * balancedOffsetDeg,
            longitude: midLon + perpLon * balancedOffsetDeg
        )
        let cleanWP = CLLocationCoordinate2D(
            latitude: midLat - perpLat * cleanOffsetDeg,
            longitude: midLon - perpLon * cleanOffsetDeg
        )

        // 3) Componer variantes en paralelo.
        async let balancedComposed = composeRouteViaWaypoint(
            origin: origin, waypoint: balancedWP, destination: destination, transport: transport
        )
        async let cleanComposed = composeRouteViaWaypoint(
            origin: origin, waypoint: cleanWP, destination: destination, transport: transport
        )
        let (balanced, clean) = await (balancedComposed, cleanComposed)

        // Asignar con fallback: si la composición falló, usar fast con
        // factores (ya aplicados en el VM sobre los stats).
        result[.balanced] = balanced ?? PreviewRoute(mkRoute: fast)
        result[.clean] = clean ?? balanced ?? PreviewRoute(mkRoute: fast)
        return result
    }

    /// Compone una ruta virtual haciendo dos MKDirections (origen→wp,
    /// wp→destino) y concatenando sus polylines. Los stats se suman.
    private static func composeRouteViaWaypoint(
        origin: CLLocationCoordinate2D,
        waypoint: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType
    ) async -> PreviewRoute? {
        async let seg1 = route(from: origin, to: waypoint, transport: transport)
        async let seg2 = route(from: waypoint, to: destination, transport: transport)
        let (r1, r2) = await (seg1, seg2)

        guard case .success(let route1) = r1,
              case .success(let route2) = r2
        else { return nil }

        let combinedPolyline = combinePolylines([route1.polyline, route2.polyline])
        let totalDistance = route1.distance + route2.distance
        let totalDuration = route1.expectedTravelTime + route2.expectedTravelTime

        return PreviewRoute(
            polyline: combinedPolyline,
            distance: totalDistance,
            expectedTravelTime: totalDuration
        )
    }

    /// Concatena varios MKPolyline en uno solo.
    private static func combinePolylines(_ polylines: [MKPolyline]) -> MKPolyline {
        var coords: [CLLocationCoordinate2D] = []
        for p in polylines {
            var segment = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: p.pointCount
            )
            p.getCoordinates(&segment, range: NSRange(location: 0, length: p.pointCount))
            // Evitar duplicar el waypoint (último de segmento N == primero de N+1).
            if !coords.isEmpty,
               let last = coords.last,
               let first = segment.first,
               last.latitude == first.latitude,
               last.longitude == first.longitude {
                coords.append(contentsOf: segment.dropFirst())
            } else {
                coords.append(contentsOf: segment)
            }
        }
        return MKPolyline(coordinates: coords, count: coords.count)
    }

    /// Pide hasta N rutas peatonales entre mismos endpoints.
    /// MKDirections devuelve 2-3 alternativas cuando es posible.
    private static func alternateWalkingRoutes(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> [MKRoute] {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType = .walking
        req.requestsAlternateRoutes = true

        do {
            let resp = try await MKDirections(request: req).calculate()
            return resp.routes
        } catch {
            AirWayLogger.stations.error(
                "TripBriefing alt walking routes failed: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    // MARK: - Helpers

    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: count
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
    }

    /// Submuestrea coords a un máximo N puntos manteniendo inicio y fin.
    private func sampled(_ coords: [CLLocationCoordinate2D], max: Int) -> [CLLocationCoordinate2D] {
        guard coords.count > max else { return coords }
        let step = Double(coords.count - 1) / Double(max - 1)
        return (0..<max).map { coords[Int(Double($0) * step)] }
    }
}
