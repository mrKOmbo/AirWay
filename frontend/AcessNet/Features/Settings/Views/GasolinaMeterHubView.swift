//
//  GasolinaMeterHubView.swift
//  AcessNet
//
//  Centro de GasolinaMeter. Matches AQIHomeView theme: WeatherBackground + glass cards.
//

import SwiftUI
import CoreLocation
import os

struct GasolinaMeterHubView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var vehicleService = VehicleProfileService.shared

    @State private var showingVehicleProfile = false
    @State private var showingVehicleScan = false
    @State private var showingOBD2 = false
    @State private var showingStations = false
    @State private var showingTripRecorder = false
    @State private var showingTripSummary: TripTelemetry?

    // Coordenadas demo CDMX (Zócalo → Polanco)
    private let demoOrigin = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
    private let demoDestination = CLLocationCoordinate2D(latitude: 19.4330, longitude: -99.1950)

    // Weather theme (mismo que AQIHomeView)
    private var activeWeather: WeatherCondition {
        appSettings.weatherOverride ?? .overcast
    }

    private var theme: WeatherTheme {
        WeatherTheme(condition: activeWeather)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Fondo dinámico (respeta el tema AirWay light o climas oscuros)
                theme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        activeVehicleCard
                        fuelPricesCard

                        VehicleProfilePreviewCard(
                            onExpand: { showingVehicleProfile = true },
                            onAdd: { showingVehicleProfile = true },
                            onConnectOBD: {
                                OBD2Service.shared.scan()
                                showingOBD2 = true
                            }
                        )

                        FuelStationsPreviewCard(
                            origin: demoOrigin,
                            onExpand: { showingStations = true }
                        )

                        // Historial de viajes (acumulados + últimos 3 con tap a summary).
                        // La grabación en vivo se hace desde el mapa (auto + botón REC).
                        TripHistoryCard(
                            theme: theme,
                            onOpen: { showingTripRecorder = true },
                            onSelectTrip: { trip in showingTripSummary = trip }
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal)
                    .avoidTabBar(extraPadding: 20)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .environment(\.weatherTheme, theme)
        .sheet(isPresented: $showingVehicleProfile) { VehicleProfileView() }
        .sheet(isPresented: $showingVehicleScan) { VehicleScanView() }
        .sheet(isPresented: $showingOBD2) { OBD2ConnectionView() }
        .sheet(isPresented: $showingTripRecorder) {
            NavigationStack {
                TripRecorderView()
                    .navigationTitle("Historial")
                    .environment(\.weatherTheme, theme)
            }
        }
        .sheet(item: $showingTripSummary) { trip in
            TripSummaryView(trip: trip)
                .environment(\.weatherTheme, theme)
        }
        .fullScreenCover(isPresented: $showingStations) {
            FuelStationsMapView(origin: demoOrigin)
                .environment(\.weatherTheme, theme)
        }
    }

    // MARK: - Header (same style as AQIHomeView)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "fuelpump.circle.fill")
                        .foregroundColor(theme.textTint.opacity(0.9))
                        .font(.title3)
                    Text("GasolinaMeter")
                        .font(.title2.bold())
                        .foregroundColor(theme.textTint)
                }
                Text("Combustible · Rutas · Emisiones")
                    .font(.subheadline)
                    .foregroundColor(theme.textTint.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Active Vehicle Card (glass style)

    private var activeVehicleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vehículo activo")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textTint.opacity(0.5))
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
                if vehicleService.activeProfile == nil {
                    Text("SIN CONFIGURAR")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.3))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }

            if let v = vehicleService.activeProfile {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.green.opacity(0.4), .teal.opacity(0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: v.fuelType.systemIcon)
                            .font(.title3)
                            .foregroundColor(theme.textTint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.displayName)
                            .font(.headline)
                            .foregroundColor(theme.textTint)
                        HStack(spacing: 6) {
                            Text(v.fuelType.displayName)
                            Text("·")
                            Text(String(format: "%.1f km/L", v.conueeKmPerL))
                            Text("·")
                            Text(v.drivingStyleLabel)
                        }
                        .font(.caption)
                        .foregroundColor(theme.textTint.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
            } else {
                Button {
                    showingVehicleProfile = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Agregar mi vehículo")
                                .font(.subheadline.weight(.semibold))
                            Text("Elige de 49 autos CONUEE o escanea")
                                .font(.caption)
                                .foregroundColor(theme.textTint.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(theme.textTint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard(theme: theme)
    }

    // MARK: - Fuel Prices Card

    private var fuelPricesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Precios hoy · Profeco")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textTint.opacity(0.5))
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
                Text("MXN / L")
                    .font(.caption2)
                    .foregroundColor(theme.textTint.opacity(0.4))
            }

            HStack(spacing: 14) {
                priceTile(label: "Magna", price: 23.80, color: .green)
                priceTile(label: "Premium", price: 28.42, color: .red)
                priceTile(label: "Diésel", price: 28.28, color: .orange)
            }
        }
        .padding(16)
        .glassCard(theme: theme)
    }

    private func priceTile(label: String, price: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.caption2).foregroundColor(theme.textTint.opacity(0.7))
            }
            Text("$\(String(format: "%.2f", price))")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundColor(theme.textTint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Phase Section

    private func phaseSection<Content: View>(
        number: String,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.35))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(theme.textTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textTint)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(theme.textTint.opacity(0.6))
                }
                Spacer()
                Text(number)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(theme.textTint.opacity(0.1))
                    .foregroundColor(theme.textTint.opacity(0.7))
                    .cornerRadius(6)
            }
            VStack(spacing: 8) {
                content()
            }
        }
        .padding(16)
        .glassCard(theme: theme)
    }
}

// MARK: - Phase Row

private struct PhaseRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let theme: WeatherTheme
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.textTint.opacity(isActive ? 0.25 : 0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(isActive ? .green : theme.textTint.opacity(0.9))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textTint)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(theme.textTint.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textTint.opacity(0.35))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.textTint.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.textTint.opacity(isActive ? 0.2 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Card Modifier

private extension View {
    func glassCard(theme: WeatherTheme) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
    }
}

// MARK: - No Vehicle Hint

struct NoVehicleHintView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                Text("Configura un vehículo primero")
                    .font(.title3.bold())
                Text("Ve al tab Fuel → Mi vehículo → Mis vehículos")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Entendido") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(40)
        }
    }
}

// MARK: - Stations Near Test View (glass style)

struct StationsNearbyTestView: View {
    let origin: CLLocationCoordinate2D
    @Environment(\.weatherTheme) private var theme

    @State private var stations: [FuelStation] = []
    @State private var averagePrice: Double = 0
    @State private var loading = true
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if loading {
                            HStack { Spacer(); ProgressView("Buscando...").tint(theme.textTint); Spacer() }
                                .padding(.top, 60)
                        } else if let err = errorMsg {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("No se pudo cargar", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text(err).font(.caption).foregroundColor(theme.textTint.opacity(0.7))
                                Button("Reintentar") {
                                    Task { await load() }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardColor))
                        } else {
                            // Precio promedio
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Promedio Magna")
                                        .font(.caption).foregroundColor(theme.textTint.opacity(0.6))
                                    Text("$\(String(format: "%.2f", averagePrice))")
                                        .font(.title2.bold())
                                        .foregroundColor(theme.textTint)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Image(systemName: "fuelpump.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardColor))

                            // Lista estaciones
                            ForEach(stations) { s in
                                stationCard(s)
                            }

                            if stations.isEmpty {
                                Text("Sin estaciones en el radio")
                                    .font(.callout)
                                    .foregroundColor(theme.textTint.opacity(0.5))
                                    .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Gasolineras cercanas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await load() }
        }
    }

    private func stationCard(_ s: FuelStation) -> some View {
        Button { s.openInMaps() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(brandColor(s.brand).opacity(0.3)).frame(width: 40, height: 40)
                    Image(systemName: "fuelpump.fill").foregroundColor(brandColor(s.brand))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(s.brand)").font(.subheadline.weight(.semibold)).foregroundColor(theme.textTint)
                        Text("· \(s.distanceKmFormatted)")
                            .font(.caption).foregroundColor(theme.textTint.opacity(0.5))
                    }
                    Text(s.address)
                        .font(.caption2)
                        .foregroundColor(theme.textTint.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(s.priceFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                        .monospacedDigit()
                    if let sv = s.savingsFormatted {
                        Text(sv).font(.caption2.weight(.semibold)).foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.cardColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func brandColor(_ b: String) -> Color {
        switch b.lowercased() {
        case "pemex": return .green
        case "shell": return .yellow
        case "bp": return .green
        case "mobil": return .blue
        default: return .orange
        }
    }

    private func load() async {
        loading = true
        errorMsg = nil
        defer { loading = false }
        AirWayLogger.stations.info("StationsNearbyTestView loading")
        do {
            let resp = try await FuelStationsAPI.shared.stationsNear(
                coordinate: origin, fuelType: .magna, radiusM: 5000, limit: 5
            )
            stations = resp.stations
            averagePrice = resp.averagePrice
        } catch {
            errorMsg = error.localizedDescription
            AirWayLogger.stations.error("StationsNearbyTestView: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Backend Test View (glass style)

struct BackendTestView: View {
    @Environment(\.weatherTheme) private var theme

    @State private var catalogStatus = "—"
    @State private var pricesStatus = "—"
    @State private var estimateStatus = "—"
    @State private var stationsStatus = "—"
    @State private var running = false
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Base URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BASE URL")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(theme.textTint.opacity(0.5))
                                .tracking(1.5)
                            Text(AppConfig.backendBaseURL.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundColor(theme.textTint)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(theme.cardColor))

                        // Endpoints
                        VStack(spacing: 10) {
                            testRow("GET /fuel/catalog", status: catalogStatus)
                            testRow("GET /fuel/prices", status: pricesStatus)
                            testRow("POST /fuel/estimate", status: estimateStatus)
                            testRow("GET /fuel/stations_near", status: stationsStatus)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(theme.cardColor))

                        // Button
                        Button {
                            Task { await runAllTests() }
                        } label: {
                            HStack {
                                Spacer()
                                if running {
                                    ProgressView().tint(theme.textTint)
                                    Text("Ejecutando...").foregroundColor(theme.textTint)
                                } else {
                                    Image(systemName: "play.fill")
                                    Text("Correr tests")
                                }
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundColor(theme.textTint)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.6)))
                        }
                        .disabled(running)

                        if let err = lastError {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ÚLTIMO ERROR")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(theme.textTint.opacity(0.5))
                                    .tracking(1.5)
                                Text(err)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.15)))
                        }

                        Text("⚠️ Render duerme tras 15 min. Primer request ~30s. Reintenta si falla.")
                            .font(.caption2)
                            .foregroundColor(theme.textTint.opacity(0.5))
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Backend Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func testRow(_ title: String, status: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.monospaced())
                .foregroundColor(theme.textTint.opacity(0.8))
            Spacer()
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundColor(statusColor(status))
                .monospacedDigit()
        }
    }

    private func statusColor(_ s: String) -> Color {
        if s.contains("✓") { return .green }
        if s.contains("✗") { return .red }
        if s.contains("…") { return .blue }
        return theme.textTint.opacity(0.4)
    }

    private func runAllTests() async {
        running = true
        lastError = nil
        defer { running = false }

        AirWayLogger.network.notice("Backend Health tests start: \(AppConfig.backendBaseURL.absoluteString, privacy: .public)")

        catalogStatus = "…"
        do {
            let resp = try await FuelAPIClient.shared.fetchCatalog()
            catalogStatus = "✓ \(resp.vehicles?.count ?? 0) autos"
        } catch {
            catalogStatus = "✗ falla"
            lastError = "catalog: \(error.localizedDescription)"
        }

        pricesStatus = "…"
        do {
            let prices = try await FuelAPIClient.shared.fetchPrices()
            pricesStatus = "✓ Magna $\(String(format: "%.2f", prices.magna))"
        } catch {
            pricesStatus = "✗ falla"
            lastError = "prices: \(error.localizedDescription)"
        }

        stationsStatus = "…"
        do {
            let resp = try await FuelStationsAPI.shared.stationsNear(
                coordinate: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
                fuelType: .magna, radiusM: 5000, limit: 5
            )
            stationsStatus = "✓ \(resp.count) estaciones"
        } catch {
            stationsStatus = "✗ falla"
            lastError = "stations: \(error.localizedDescription)"
        }

        estimateStatus = "…"
        let dummyPoly = "_piF~poU_ulL~ztH"
        let vehicle = VehicleProfileService.shared.activeProfile ?? VehicleProfile.sample
        do {
            let est = try await FuelAPIClient.shared.estimate(
                polyline: dummyPoly, vehicle: vehicle,
                durationMin: 15, passengers: 1
            )
            estimateStatus = "✓ \(est.pesosFormatted)"
        } catch {
            estimateStatus = "✗ falla"
            lastError = "estimate: \(error.localizedDescription)"
        }
    }
}
