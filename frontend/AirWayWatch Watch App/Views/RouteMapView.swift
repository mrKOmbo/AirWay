//
//  RouteMapView.swift
//  AirWayWatch Watch App
//
//  Vista de mapa para mostrar la ruta en Apple Watch
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.2827, longitude: -99.6525),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        ZStack {
            if let route = connectivityManager.currentRoute {
                // Mapa con la ruta
                Map(coordinateRegion: $region, annotationItems: routeAnnotations) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: .blue)
                }
                .overlay(alignment: .bottom) {
                    RouteInfoOverlay(route: route)
                        .padding(.bottom, 8)
                }
                .onAppear {
                    updateMapRegion(for: route)
                }
                .onReceive(connectivityManager.$currentRoute) { newRoute in
                    if let route = newRoute {
                        updateMapRegion(for: route)
                    }
                  }
            } else {
                // Sin ruta activa
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))

                    Text("No Active Route")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    Text("Create a route on your iPhone")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Button("Request Route") {
                            connectivityManager.requestCurrentRoute()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#4AA1B3"))

                        #if DEBUG
                        Button("Load Sample") {
                            connectivityManager.currentRoute = .sample
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .font(.caption2)
                        #endif
                    }
                }
                .padding()
            }
        }
        .airWayBackground()
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var routeAnnotations: [RouteAnnotation] {
        guard let route = connectivityManager.currentRoute else { return [] }

        var annotations: [RouteAnnotation] = []

        // Agregar punto de inicio
        if let first = route.coordinates.first {
            annotations.append(RouteAnnotation(
                id: "start",
                coordinate: first.coordinate,
                title: "Start"
            ))
        }

        // Agregar punto de destino
        if let last = route.coordinates.last {
            annotations.append(RouteAnnotation(
                id: "end",
                coordinate: last.coordinate,
                title: route.destinationName
            ))
        }

        return annotations
    }

    // MARK: - Helper Methods

    private func updateMapRegion(for route: WatchRouteData) {
        guard !route.coordinates.isEmpty else { return }

        // Calcular el centro y span basado en las coordenadas
        let lats = route.coordinates.map { $0.latitude }
        let lons = route.coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let spanLat = (maxLat - minLat) * 1.3 // Agregar padding
        let spanLon = (maxLon - minLon) * 1.3

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(spanLat, 0.01),
                longitudeDelta: max(spanLon, 0.01)
            )
        )
    }
}

// MARK: - Supporting Views

struct RouteInfoOverlay: View {
    let route: WatchRouteData

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Distancia y tiempo
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.distanceFormatted)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(route.timeFormatted)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // AQI Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: route.aqiColor))
                        .frame(width: 8, height: 8)

                    Text("AQI \(route.averageAQI)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
            }

            // Incidentes (si hay)
            if route.trafficIncidents > 0 || route.hazardIncidents > 0 {
                HStack(spacing: 8) {
                    if route.trafficIncidents > 0 {
                        Label("\(route.trafficIncidents)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if route.hazardIncidents > 0 {
                        Label("\(route.hazardIncidents)", systemImage: "exclamationmark.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .shadow(radius: 4)
        )
        .padding(.horizontal)
    }
}

// MARK: - Route Annotation Model

struct RouteAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
}

// MARK: - Preview

#Preview {
    RouteMapView()
}
