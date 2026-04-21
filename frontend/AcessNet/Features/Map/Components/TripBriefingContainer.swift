//
//  TripBriefingContainer.swift
//  AcessNet
//
//  Container del flujo de briefing en 2 pasos:
//   1. ModeChoicePopup — elegir caminar o coche.
//   2. RouteOptionsPanel — elegir variante de ruta y confirmar.
//
//  El container es dueño del @StateObject del VM; los pasos son
//  sub-vistas stateless que comparten el mismo VM.
//

import SwiftUI
import CoreLocation
import MapKit

/// Payload que pasa el briefing al caller cuando el usuario presiona
/// "Ir ahora" — incluye toda la info para trazar la ruta final.
struct TripStartContext {
    let mode: BriefingMode
    let priority: TripPriority
    let preference: RoutePreference
    let transportType: MKDirectionsTransportType
    let destination: CLLocationCoordinate2D
    let destinationTitle: String
}

struct TripBriefingContainer: View {
    // MARK: - Inputs
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let destinationTitle: String
    let zones: [AirQualityZone]
    let vehicle: VehicleProfile?
    let gridManager: AirQualityGridManager?

    let onDismiss: () -> Void
    let onStartRoute: (TripStartContext) -> Void
    let onPreviewRouteChanged: (PreviewRoute?, BriefingMode) -> Void

    // MARK: - VM
    @StateObject private var viewModel: TripBriefingViewModel

    // MARK: - Pasos del flujo
    enum Step: Equatable {
        case modeChoice
        case routeOptions
    }

    @State private var step: Step = .modeChoice

    // MARK: - Init

    init(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        destinationTitle: String,
        zones: [AirQualityZone],
        vehicle: VehicleProfile?,
        gridManager: AirQualityGridManager? = nil,
        onDismiss: @escaping () -> Void,
        onStartRoute: @escaping (TripStartContext) -> Void,
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

    // MARK: - Body

    var body: some View {
        Group {
            switch step {
            case .modeChoice:
                ModeChoicePopup(
                    destinationTitle: destinationTitle,
                    onSelectMode: { mode in
                        // Cambiar modo en VM y pasar al paso 2.
                        viewModel.mode = mode
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            step = .routeOptions
                        }
                    },
                    onDismiss: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -4)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))

            case .routeOptions:
                RouteOptionsPanel(
                    viewModel: viewModel,
                    onBack: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            step = .modeChoice
                        }
                    },
                    onGo: fireStartRoute,
                    onDismiss: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 6)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            }
        }
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            onPreviewRouteChanged(nil, viewModel.mode)
        }
        // UN SOLO trigger para propagar preview al mapa. La firma combina
        // mode + priority + distancia redondeada del previewRoute activo.
        // Antes había 4 .onChange independientes (walkingRoute, drivingRoute,
        // mode, priority) que disparaban 4 llamadas consecutivas a
        // updateZonesAlongRoutes al cambiar variante — cada una limpiaba
        // zones=[] antes de recalcular, haciendo "parpadear" los círculos.
        .onChange(of: previewSignature) { _, _ in
            onPreviewRouteChanged(viewModel.previewRoute, viewModel.mode)
        }
    }

    /// Firma que representa el estado del preview activo. Cambia exactamente
    /// cuando el mapa debe refrescar los círculos: nuevo modo, nueva
    /// prioridad, o nueva distancia (carga inicial de MKDirections).
    private var previewSignature: String {
        let mode = viewModel.mode
        let priority = viewModel.routePriority
        let dist = Int((viewModel.previewRoute?.distance ?? 0).rounded())
        return "\(mode)_\(priority)_\(dist)"
    }

    // MARK: - Go

    private func fireStartRoute() {
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
    }
}
