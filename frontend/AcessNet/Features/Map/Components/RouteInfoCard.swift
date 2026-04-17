//
//  RouteInfoCard.swift
//  AcessNet
//
//  Card que muestra información de la ruta calculada
//

import SwiftUI
import MapKit

// MARK: - Route Info Card

struct RouteInfoCard: View {
    let routeInfo: RouteInfo
    let scoredRoute: ScoredRoute?  // Opcional para mostrar datos avanzados
    let isCalculating: Bool
    let onClear: () -> Void
    let onStartNavigation: (() -> Void)?
    let onViewAirQuality: (() -> Void)?

    @State private var isExpanded = false
    @State private var showAlternates = false

    var body: some View {
        VStack(spacing: 0) {
            mainInfoView
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.78))
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 7)
        }
    }

    private var mainInfoView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "#3B82F6").opacity(0.5), radius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ruta activa")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#34D399")).frame(width: 5, height: 5)
                            .shadow(color: Color(hex: "#34D399"), radius: 3)
                        Text("Lista para navegar")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Button(action: {
                    HapticFeedback.light()
                    onClear()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.1)))
                        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Información de distancia y tiempo
            HStack(spacing: 12) {
                EnhancedInfoBadge(
                    icon: "arrow.left.and.right",
                    value: routeInfo.distanceFormatted,
                    label: "Distancia",
                    color: Color(hex: "#60A5FA")
                )

                Rectangle().fill(.white.opacity(0.08))
                    .frame(width: 1, height: 32)

                EnhancedInfoBadge(
                    icon: "clock.fill",
                    value: routeInfo.timeFormatted,
                    label: "Duración",
                    color: Color(hex: "#34D399")
                )
            }
            .padding(.vertical, 4)

            // Air Quality prediction
            if let scored = scoredRoute, scored.averageAQI > 0 {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                HStack(spacing: 12) {
                    EnhancedInfoBadge(
                        icon: "aqi.medium",
                        value: "\(Int(scored.averageAQI))",
                        label: "AQI ahora",
                        color: aqiColor(scored.averageAQI)
                    )

                    Rectangle().fill(.white.opacity(0.08))
                        .frame(width: 1, height: 32)

                    EnhancedInfoBadge(
                        icon: "brain.head.profile",
                        value: "\(Int(scored.predictedArrivalAQI ?? scored.averageAQI))",
                        label: "AQI llegada",
                        color: aqiColor(scored.predictedArrivalAQI ?? scored.averageAQI)
                    )
                }
                .padding(.vertical, 4)
            }

            // Información de seguridad
            if let scored = scoredRoute, let incidentAnalysis = scored.incidentAnalysis {
                VStack(spacing: 10) {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

                    HStack(spacing: 12) {
                        EnhancedInfoBadge(
                            icon: incidentAnalysis.riskIcon,
                            value: "\(Int(incidentAnalysis.safetyScore))%",
                            label: "Seguridad",
                            color: riskLevelColor(incidentAnalysis.riskLevel)
                        )

                        if incidentAnalysis.totalIncidents > 0 {
                            Rectangle().fill(.white.opacity(0.08))
                                .frame(width: 1, height: 32)

                            EnhancedInfoBadge(
                                icon: "exclamationmark.triangle.fill",
                                value: "\(incidentAnalysis.totalIncidents)",
                                label: "Incidentes",
                                color: Color(hex: "#FB923C")
                            )
                        }
                    }

                    if incidentAnalysis.totalIncidents > 0 {
                        Text(incidentAnalysis.incidentSummary)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(Color(hex: "#FB923C"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(hex: "#FB923C").opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "#FB923C").opacity(0.3), lineWidth: 0.8)
                            )
                    }
                }
            }

            // Botones de acción
            HStack(spacing: 8) {
                if let startNavigation = onStartNavigation {
                    Button(action: {
                        HapticFeedback.confirm()
                        startNavigation()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill.viewfinder")
                                .font(.system(size: 13, weight: .heavy))
                            Text("Navegar")
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#3B82F6").opacity(0.45), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }

                if let viewAirQuality = onViewAirQuality {
                    Button(action: {
                        HapticFeedback.light()
                        viewAirQuality()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "aqi.medium")
                                .font(.system(size: 12, weight: .heavy))
                            Text("Aire")
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .foregroundColor(Color(hex: "#22D3EE"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: "#22D3EE").opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "#22D3EE").opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    HapticFeedback.warning()
                    onClear()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(Color(hex: "#F87171"))
                    .frame(width: 52)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#F87171").opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#F87171").opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Functions

    private func aqiColor(_ aqi: Double) -> Color {
        switch aqi {
        case ..<51:   return Color(hex: "#34D399")
        case ..<101:  return Color(hex: "#FBBF24")
        case ..<151:  return Color(hex: "#FB923C")
        default:      return Color(hex: "#F87171")
        }
    }

    /// Determina el color según el nivel de riesgo
    private func riskLevelColor(_ riskLevel: RiskLevel) -> Color {
        switch riskLevel {
        case .veryLow:  return Color(hex: "#34D399")
        case .low:      return Color(hex: "#A3E635")
        case .moderate: return Color(hex: "#FBBF24")
        case .high:     return Color(hex: "#FB923C")
        case .veryHigh: return Color(hex: "#F87171")
        }
    }
}

// MARK: - Enhanced Info Badge (Modernizado)

/// Badge mejorado para mostrar información de la ruta
struct EnhancedInfoBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 1)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Info Badge (Original - para compatibilidad)

/// Badge para mostrar información de la ruta
struct InfoBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Calculating Route Indicator

/// Vista que se muestra mientras se calcula la ruta
struct CalculatingRouteView: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // Indicador de carga
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan, .blue],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Calculating route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Compact Route Info

/// Vista compacta de la ruta (para mostrar en la parte superior)
struct CompactRouteInfo: View {
    let routeInfo: RouteInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)

            Text(routeInfo.distanceFormatted)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("•")
                .foregroundStyle(.secondary)

            Text(routeInfo.timeFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Route Error View

/// Vista para mostrar errores en el cálculo de ruta
struct RouteErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Route Error")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Enhanced Route Info Card with Air Quality

/// Card mejorado que muestra ruta con datos de calidad del aire
struct EnhancedRouteInfoCard: View {
    let scoredRoute: ScoredRoute
    let isCalculating: Bool
    let onClear: () -> Void
    let onStartNavigation: (() -> Void)?
    let showComparison: RouteComparison?

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header con información básica
            headerView

            // Métricas de distancia y tiempo
            distanceTimeView

            // Air quality metrics (si están disponibles)
            if let analysis = scoredRoute.airQualityAnalysis {
                airQualityMetricsView(analysis: analysis)
            }

            // Comparison con otra ruta (opcional)
            if let comparison = showComparison {
                comparisonView(comparison: comparison)
            }

            // Botones de acción
            actionButtons
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 12) {
            // Ícono de ruta
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Best Route")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    // Badge de ranking
                    if let rank = scoredRoute.rankPosition {
                        Text("#\(rank)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(scoredRoute.scoreDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Botón cerrar
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onClear()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private var distanceTimeView: some View {
        HStack(spacing: 16) {
            // Distancia
            EnhancedInfoBadge(
                icon: "arrow.left.and.right",
                value: scoredRoute.routeInfo.distanceFormatted,
                label: "Distance",
                color: .blue
            )

            Divider()
                .frame(height: 35)

            // Tiempo
            EnhancedInfoBadge(
                icon: "clock.fill",
                value: scoredRoute.routeInfo.timeFormatted,
                label: "Duration",
                color: .green
            )
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func airQualityMetricsView(analysis: AirQualityRouteAnalysis) -> some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                // AQI compact badge
                AirQualityBadge(aqi: analysis.averageAQI, compact: true)

                // PM2.5
                PM25Indicator(pm25: analysis.averagePM25)

                Spacer()

                // Health risk badge
                HealthRiskBadge(healthRisk: analysis.overallHealthRisk)
            }

            // Score combinado
            HStack(spacing: 16) {
                scoreIndicator(
                    label: "Speed",
                    score: scoredRoute.timeScore,
                    color: .blue
                )

                scoreIndicator(
                    label: "Air Quality",
                    score: scoredRoute.airQualityScore,
                    color: .green
                )

                scoreIndicator(
                    label: "Combined",
                    score: scoredRoute.combinedScore,
                    color: .purple
                )
            }
            .padding(.vertical, 8)
        }
    }

    private func scoreIndicator(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Int(score))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func comparisonView(comparison: RouteComparison) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(comparison.shortDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text("vs. alternative route")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Botón Start Navigation (opcional)
            if let startNavigation = onStartNavigation {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    startNavigation()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Start")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.95),
                                .blue.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }

            // Botón Clear Route
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onClear()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: onStartNavigation == nil ? .infinity : nil)
                .padding(.horizontal, onStartNavigation == nil ? 0 : 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.red.opacity(0.12))
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Route Info Card") {
    VStack(spacing: 20) {
        // Crear una ruta de ejemplo
        let mockRoute = createMockRoute()
        let routeInfo = RouteInfo(from: mockRoute)

        RouteInfoCard(
            routeInfo: routeInfo,
            scoredRoute: nil,  // Sin datos avanzados en el preview
            isCalculating: false,
            onClear: { print("Clear tapped") },
            onStartNavigation: { print("Start navigation") },
            onViewAirQuality: { print("View air quality") }
        )
        .padding()

        CalculatingRouteView()
            .padding()

        CompactRouteInfo(routeInfo: routeInfo)
            .padding()

        RouteErrorView(
            message: "No se pudo calcular la ruta. Intenta nuevamente.",
            onDismiss: { print("Dismiss error") }
        )
        .padding()

        Spacer()
    }
}

// MARK: - Mock Helper

private func createMockRoute() -> MKRoute {
    // Crear coordenadas de ejemplo
    let coordinates = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
    ]

    // Crear polyline
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

    // Crear un MKRoute simulado
    // Nota: MKRoute es difícil de mockear directamente, esta es una aproximación
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinates[0]))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinates[1]))

    // Para el preview, necesitamos un MKRoute real, pero esto es complicado sin hacer una request real
    // Por ahora, retornamos un placeholder - en producción esto vendrá de MKDirections
    let directions = MKDirections(request: request)

    // Hack para preview: crear estructura temporal que simule MKRoute
    // En código real, esto vendrá de MKDirections.calculate()
    fatalError("Mock route creation not implemented - use real MKDirections in production")
}
