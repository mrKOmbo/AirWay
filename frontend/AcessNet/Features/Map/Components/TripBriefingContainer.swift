//
//  TripBriefingContainer.swift
//  AcessNet
//
//  Container que instancia TripBriefingViewModel como @StateObject
//  para que ContentView no tenga que gestionar su ciclo de vida.
//  Se re-crea vía `.id()` al cambiar el destino.
//

import SwiftUI
import CoreLocation
import MapKit

/// Payload que pasa el briefing al caller cuando el usuario presiona
/// "Ir ahora" o "Empezar caminata". Incluye toda la información que
/// RouteManager necesita para trazar la ruta correcta.
struct TripStartContext {
    let mode: BriefingMode
    let priority: TripPriority
    let preference: RoutePreference
    let transportType: MKDirectionsTransportType
    let destination: CLLocationCoordinate2D
    let destinationTitle: String
}

struct TripBriefingContainer: View {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let destinationTitle: String
    let zones: [AirQualityZone]
    let vehicle: VehicleProfile?
    let gridManager: AirQualityGridManager?

    let onDismiss: () -> Void
    let onStartRoute: (TripStartContext) -> Void
    let onOpenStations: () -> Void
    let onOpenDeparture: () -> Void
    let onAddVehicle: () -> Void
    /// Notifica al caller cuando cambia la ruta preview (al calcular
    /// walking/driving o al cambiar modo o prioridad). El caller la
    /// usa para dibujarla en el mapa detrás del sheet. Segundo
    /// parámetro es el modo activo para colorear la polyline.
    let onPreviewRouteChanged: (PreviewRoute?, BriefingMode) -> Void

    @StateObject private var viewModel: TripBriefingViewModel

    init(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        destinationTitle: String,
        zones: [AirQualityZone],
        vehicle: VehicleProfile?,
        gridManager: AirQualityGridManager? = nil,
        onDismiss: @escaping () -> Void,
        onStartRoute: @escaping (TripStartContext) -> Void,
        onOpenStations: @escaping () -> Void,
        onOpenDeparture: @escaping () -> Void,
        onAddVehicle: @escaping () -> Void,
        onPreviewRouteChanged: @escaping (PreviewRoute?, BriefingMode) -> Void = { _, _ in }
    ) {
        self.origin = origin
        self.destination = destination
        self.destinationTitle = destinationTitle
        self.zones = zones
        self.vehicle = vehicle
        self.gridManager = gridManager
        self.onDismiss = onDismiss
        self.onStartRoute = onStartRoute
        self.onOpenStations = onOpenStations
        self.onOpenDeparture = onOpenDeparture
        self.onAddVehicle = onAddVehicle
        self.onPreviewRouteChanged = onPreviewRouteChanged

        let vm = TripBriefingViewModel(
            origin: origin,
            destination: destination,
            destinationTitle: destinationTitle,
            zones: zones,
            vehicle: vehicle
        )
        vm.gridManager = gridManager
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        TripBriefingTopPanel(
            viewModel: viewModel,
            onDismiss: onDismiss,
            onGo: {
                HapticFeedback.medium()
                let context = TripStartContext(
                    mode: viewModel.mode,
                    priority: viewModel.routePriority,
                    preference: viewModel.routePriority.routePreference,
                    transportType: viewModel.mode == .walking ? .walking : .automobile,
                    destination: destination,
                    destinationTitle: destinationTitle
                )
                onStartRoute(context)
            },
            onOpenStations: onOpenStations,
            onOpenDeparture: onOpenDeparture,
            onAddVehicle: onAddVehicle
        )
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            onPreviewRouteChanged(nil, viewModel.mode)
        }
        // El container observa el VM (es @StateObject) y propaga
        // cambios de preview al caller via closure.
        .onChange(of: viewModel.walkingRoute?.distance) { _, _ in
            if viewModel.mode == .walking {
                onPreviewRouteChanged(viewModel.walkingRoute, viewModel.mode)
            }
        }
        .onChange(of: viewModel.drivingRoute?.distance) { _, _ in
            if viewModel.mode == .driving {
                onPreviewRouteChanged(viewModel.drivingRoute, viewModel.mode)
            }
        }
        .onChange(of: viewModel.mode) { _, newMode in
            onPreviewRouteChanged(viewModel.previewRoute, newMode)
        }
        // Cambio de prioridad → puede cambiar la variante visible.
        .onChange(of: viewModel.routePriority) { _, _ in
            onPreviewRouteChanged(viewModel.previewRoute, viewModel.mode)
        }
    }
}
