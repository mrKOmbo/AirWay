//
//  FuelStationsMapView.swift
//  AcessNet
//
//  Mapa de gasolineras CDMX con price markers + bottom sheet + ruta interna.
//  Pin destacado para la más barata. Tap → MKDirections + botón Apple Maps.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import os

// MARK: - View Model

@MainActor
final class FuelStationsMapViewModel: ObservableObject {
    @Published var stations: [FuelStation] = []
    @Published var averagePrice: Double = 0
    @Published var loading: Bool = false
    @Published var errorMsg: String?
    @Published var selectedStation: FuelStation?
    @Published var routePolyline: MKPolyline?
    @Published var routeETA: TimeInterval?
    @Published var routeDistanceM: CLLocationDistance?
    @Published var fuelType: FuelType = .magna
    @Published var radiusKm: Double = 5

    private let api = FuelStationsAPI.shared

    func load(origin: CLLocationCoordinate2D) async {
        loading = true
        errorMsg = nil
        do {
            let resp = try await api.stationsNear(
                coordinate: origin,
                fuelType: fuelType,
                radiusM: Int(radiusKm * 1000),
                limit: 30
            )
            stations = resp.stations.sorted { $0.price < $1.price }
            averagePrice = resp.averagePrice
        } catch {
            errorMsg = error.localizedDescription
        }
        loading = false
    }

    func cheapest() -> FuelStation? { stations.first }

    func priceColor(for station: FuelStation) -> Color {
        guard averagePrice > 0 else { return .white }
        let delta = station.price - averagePrice
        if delta <= -0.5 { return Color(hex: "#34D399") }       // muy barato
        if delta <= -0.05 { return Color(hex: "#A3E635") }      // barato
        if delta <  0.30 { return Color(hex: "#FBBF24") }       // promedio
        return Color(hex: "#F87171")                            // caro
    }

    func calcRoute(from origin: CLLocationCoordinate2D, to station: FuelStation) async {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        req.transportType = .automobile
        do {
            let resp = try await MKDirections(request: req).calculate()
            if let route = resp.routes.first {
                routePolyline = route.polyline
                routeETA = route.expectedTravelTime
                routeDistanceM = route.distance
            }
        } catch {
            routePolyline = nil
            routeETA = nil
            routeDistanceM = nil
        }
    }

    func clearRoute() {
        routePolyline = nil
        routeETA = nil
        routeDistanceM = nil
    }
}

// MARK: - Main View

struct FuelStationsMapView: View {
    let origin: CLLocationCoordinate2D

    @StateObject private var vm = FuelStationsMapViewModel()
    @Environment(\.weatherTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition
    @State private var sheetDetent: PresentationDetent = .fraction(0.42)

    init(origin: CLLocationCoordinate2D) {
        self.origin = origin
        let region = MKCoordinateRegion(
            center: origin,
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
        _camera = State(initialValue: .region(region))
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            VStack(spacing: 0) {
                topBar
                if vm.loading { loadingPill }
                if let err = vm.errorMsg { errorPill(err) }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.horizontal, 14)

            // Floating cheapest highlight chip
            if let best = vm.cheapest(), vm.selectedStation == nil {
                cheapestChip(best)
                    .padding(.top, 110)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            await vm.load(origin: origin)
            recenterAll()
        }
        .onChange(of: vm.fuelType) { _, _ in
            Task {
                await vm.load(origin: origin)
                recenterAll()
            }
        }
        .onChange(of: vm.radiusKm) { _, _ in
            Task { await vm.load(origin: origin) }
        }
        .sheet(isPresented: .constant(true)) {
            stationsBottomSheet
                .presentationDetents([.fraction(0.18), .fraction(0.45), .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .interactiveDismissDisabled()
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $camera, selection: bindingSelection) {
            // Origen (usuario)
            Annotation("Tú", coordinate: origin, anchor: .center) {
                userPin
            }
            .tag("origin")

            // Estaciones
            ForEach(vm.stations) { station in
                Annotation(station.brand, coordinate: station.coordinate, anchor: .bottom) {
                    StationPriceMarker(
                        station: station,
                        isCheapest: station.id == vm.cheapest()?.id,
                        isSelected: vm.selectedStation?.id == station.id,
                        priceColor: vm.priceColor(for: station)
                    )
                    .onTapGesture {
                        selectStation(station)
                    }
                }
                .tag(station.id)
            }

            // Ruta
            if let polyline = vm.routePolyline {
                MapPolyline(polyline)
                    .stroke(
                        Color(hex: "#34D399"),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    private var bindingSelection: Binding<String?> {
        Binding(
            get: { vm.selectedStation?.id },
            set: { newId in
                if let id = newId, let st = vm.stations.first(where: { $0.id == id }) {
                    selectStation(st)
                } else if newId == nil {
                    vm.selectedStation = nil
                    vm.clearRoute()
                }
            }
        )
    }

    private var userPin: some View {
        ZStack {
            Circle().fill(.blue.opacity(0.25)).frame(width: 30, height: 30)
            Circle().stroke(.white, lineWidth: 2).frame(width: 16, height: 16)
            Circle().fill(.blue).frame(width: 12, height: 12)
        }
        .shadow(color: .blue.opacity(0.5), radius: 6)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.black.opacity(0.55)))
                    .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Gasolineras")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill").font(.system(size: 9))
                    Text("\(vm.stations.count) en \(Int(vm.radiusKm)) km · prom $\(String(format: "%.2f", vm.averagePrice))")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.55)))
            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))

            Spacer()

            Menu {
                ForEach([FuelType.magna, .premium, .diesel], id: \.self) { type in
                    Button {
                        HapticFeedback.selection()
                        vm.fuelType = type
                    } label: {
                        Label(type.displayName, systemImage: vm.fuelType == type ? "checkmark" : "drop.fill")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(fuelDot(vm.fuelType)).frame(width: 8, height: 8)
                    Text(vm.fuelType.shortName)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Capsule().fill(.black.opacity(0.55)))
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private func fuelDot(_ t: FuelType) -> Color {
        switch t {
        case .magna: return .green
        case .premium: return .red
        case .diesel: return .orange
        default: return .gray
        }
    }

    private var loadingPill: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.white).scaleEffect(0.7)
            Text("Buscando gasolineras…")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.65)))
        .padding(.top, 8)
        .transition(.scale.combined(with: .opacity))
    }

    private func errorPill(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))
            Text(msg)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
            Button("Reintentar") { Task { await vm.load(origin: origin) } }
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.7)))
        .padding(.top, 8)
    }

    // MARK: - Cheapest Chip

    private func cheapestChip(_ station: FuelStation) -> some View {
        Button {
            selectStation(station)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "#FBBF24").opacity(0.6), radius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("MÁS BARATA")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#FBBF24"))
                    Text("\(station.brand) · \(station.distanceKmFormatted)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(station.priceFormatted)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    if let s = station.savingsFormatted {
                        Text(s)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(Color(hex: "#34D399"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.black.opacity(0.7))
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B").opacity(0.4)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Sheet

    private var stationsBottomSheet: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                if let sel = vm.selectedStation {
                    selectedStationDetail(sel)
                } else {
                    sheetHeader
                }

                if !vm.stations.isEmpty {
                    radiusPicker
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.stations) { station in
                            StationListRow(
                                station: station,
                                isCheapest: station.id == vm.cheapest()?.id,
                                isSelected: vm.selectedStation?.id == station.id,
                                priceColor: vm.priceColor(for: station)
                            )
                            .onTapGesture { selectStation(station) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .padding(.top, 14)
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.stations.count) estaciones")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                Text("Promedio CDMX · $\(String(format: "%.2f", vm.averagePrice)) MXN/L")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            if vm.loading {
                ProgressView().tint(.white).scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
    }

    private var radiusPicker: some View {
        HStack(spacing: 6) {
            ForEach([1.0, 3.0, 5.0, 10.0], id: \.self) { km in
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        vm.radiusKm = km
                    }
                } label: {
                    Text("\(Int(km)) km")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(vm.radiusKm == km ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            Capsule().fill(vm.radiusKm == km ? Color.white : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Selected Station Detail

    private func selectedStationDetail(_ s: FuelStation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(brandColor(s.brand).opacity(0.3))
                        .frame(width: 44, height: 44)
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(brandColor(s.brand))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(s.brand)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                        if s.id == vm.cheapest()?.id {
                            Text("⭐ MÁS BARATA")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.8)
                                .foregroundColor(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: "#FBBF24")))
                        }
                    }
                    Text(s.address)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    vm.selectedStation = nil
                    vm.clearRoute()
                    recenterAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
            }

            // Stats row
            HStack(spacing: 8) {
                detailStat(
                    icon: "dollarsign.circle.fill",
                    value: s.priceFormatted,
                    label: "MXN/L",
                    color: vm.priceColor(for: s)
                )
                detailStat(
                    icon: "ruler.fill",
                    value: s.distanceKmFormatted,
                    label: "distancia",
                    color: .white
                )
                if let eta = vm.routeETA {
                    detailStat(
                        icon: "clock.fill",
                        value: "\(Int(eta / 60)) min",
                        label: "en auto",
                        color: Color(hex: "#34D399")
                    )
                }
                if let saving = s.savingsFormatted {
                    detailStat(
                        icon: "arrow.down.circle.fill",
                        value: saving,
                        label: "vs prom",
                        color: Color(hex: "#34D399")
                    )
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    HapticFeedback.confirm()
                    s.openInMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 13, weight: .heavy))
                        Text("Navegar en Apple Maps")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    HapticFeedback.light()
                    centerOnRoute()
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func detailStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    // MARK: - Selection helpers

    private func selectStation(_ station: FuelStation) {
        HapticFeedback.medium()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            vm.selectedStation = station
            sheetDetent = .fraction(0.45)
        }
        Task {
            await vm.calcRoute(from: origin, to: station)
            centerOnRoute()
        }
    }

    private func centerOnRoute() {
        guard let st = vm.selectedStation else { return }
        let lats = [origin.latitude, st.coordinate.latitude]
        let lons = [origin.longitude, st.coordinate.longitude]
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(abs(lats[0] - lats[1]) * 1.8, 0.01),
            longitudeDelta: max(abs(lons[0] - lons[1]) * 1.8, 0.01)
        )
        withAnimation(.easeInOut(duration: 0.7)) {
            camera = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func recenterAll() {
        guard !vm.stations.isEmpty else { return }
        var lats = vm.stations.map(\.lat) + [origin.latitude]
        var lons = vm.stations.map(\.lon) + [origin.longitude]
        lats.sort(); lons.sort()
        let center = CLLocationCoordinate2D(
            latitude: (lats.first! + lats.last!) / 2,
            longitude: (lons.first! + lons.last!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.last! - lats.first!, 0.02) * 1.4,
            longitudeDelta: max(lons.last! - lons.first!, 0.02) * 1.4
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            camera = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func brandColor(_ b: String) -> Color {
        switch b.lowercased() {
        case "pemex": return Color(hex: "#34D399")
        case "shell": return Color(hex: "#FBBF24")
        case "bp", "bp ultimate": return Color(hex: "#10B981")
        case "mobil", "exxonmobil": return Color(hex: "#3B82F6")
        case "g500": return Color(hex: "#EF4444")
        case "oxxo gas": return Color(hex: "#DC2626")
        default: return Color(hex: "#F97316")
        }
    }
}

// MARK: - Price Marker (pin with price)

struct StationPriceMarker: View {
    let station: FuelStation
    let isCheapest: Bool
    let isSelected: Bool
    let priceColor: Color

    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Glow para más barata
                if isCheapest {
                    Capsule()
                        .fill(Color(hex: "#FBBF24").opacity(0.4))
                        .frame(width: 70, height: 38)
                        .blur(radius: 12)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .opacity(pulse ? 0.0 : 0.7)
                }

                HStack(spacing: 4) {
                    if isCheapest {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(Color(hex: "#FBBF24"))
                    }
                    Text(station.priceFormatted)
                        .font(.system(size: isCheapest ? 13 : 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, isCheapest ? 10 : 8)
                .padding(.vertical, isCheapest ? 6 : 5)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.85))
                        .overlay(
                            Capsule().stroke(
                                isCheapest
                                    ? LinearGradient(
                                        colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(colors: [priceColor, priceColor.opacity(0.5)],
                                                     startPoint: .top, endPoint: .bottom),
                                lineWidth: isCheapest ? 2 : 1.5
                            )
                        )
                )
                .scaleEffect(isSelected ? 1.18 : (isCheapest ? 1.1 : 1.0))
            }

            // Tail
            MarkerTailTriangle()
                .fill(.black.opacity(0.85))
                .frame(width: 9, height: 6)
                .overlay(
                    MarkerTailTriangle()
                        .stroke(isCheapest ? Color(hex: "#FBBF24") : priceColor, lineWidth: 1.5)
                )
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        .onAppear {
            if isCheapest {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
    }
}

private struct MarkerTailTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - List Row

struct StationListRow: View {
    let station: FuelStation
    let isCheapest: Bool
    let isSelected: Bool
    let priceColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(brandColor(station.brand).opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(brandColor(station.brand))
                if isCheapest {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(3)
                        .background(Circle().fill(Color(hex: "#FBBF24")))
                        .offset(x: 13, y: -13)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(station.brand)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text(station.distanceKmFormatted)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                Text(station.address)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(station.priceFormatted)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(priceColor)
                    .monospacedDigit()
                if let s = station.savingsFormatted {
                    Text(s)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: "#34D399"))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isCheapest
                        ? Color(hex: "#FBBF24").opacity(0.6)
                        : (isSelected ? .white.opacity(0.3) : .white.opacity(0.08)),
                    lineWidth: isCheapest ? 1.5 : 1
                )
        )
    }

    private func brandColor(_ b: String) -> Color {
        switch b.lowercased() {
        case "pemex": return Color(hex: "#34D399")
        case "shell": return Color(hex: "#FBBF24")
        case "bp", "bp ultimate": return Color(hex: "#10B981")
        case "mobil", "exxonmobil": return Color(hex: "#3B82F6")
        case "g500": return Color(hex: "#EF4444")
        case "oxxo gas": return Color(hex: "#DC2626")
        default: return Color(hex: "#F97316")
        }
    }
}

// MARK: - FuelType helpers

private extension FuelType {
    var shortName: String {
        switch self {
        case .magna: return "Magna"
        case .premium: return "Premium"
        case .diesel: return "Diésel"
        case .hybrid: return "Híbrido"
        case .electric: return "Eléctrico"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FuelStationsMapView(origin: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332))
        .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
}
#endif
