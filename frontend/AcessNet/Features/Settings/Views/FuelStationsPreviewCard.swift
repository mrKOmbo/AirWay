//
//  FuelStationsPreviewCard.swift
//  AcessNet
//
//  Preview embedded en GasolinaMeterHubView.
//  Mini-mapa + más barata destacada + top 3 + botón expandir.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct FuelStationsPreviewCard: View {
    let origin: CLLocationCoordinate2D
    let onExpand: () -> Void

    @StateObject private var vm = FuelStationsMapViewModel()
    @Environment(\.weatherTheme) private var theme
    @State private var camera: MapCameraPosition
    @State private var pulseLive: Bool = false

    init(origin: CLLocationCoordinate2D, onExpand: @escaping () -> Void) {
        self.origin = origin
        self.onExpand = onExpand
        let region = MKCoordinateRegion(
            center: origin,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        _camera = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            mapPreview
            if let cheapest = vm.cheapest() {
                cheapestHero(cheapest)
            }
            if vm.stations.count > 1 {
                topListSection
            }
            statsBar
            expandButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
        .task {
            await vm.load(origin: origin)
            fitCameraToStations()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange.opacity(0.6), .red.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Gasolineras cerca")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                    livePill
                }
                Text("Profeco · radio 5 km · \(vm.fuelType.displayShort)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            Text("2")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var livePill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 5, height: 5)
                .scaleEffect(pulseLive ? 1.5 : 1.0)
                .opacity(pulseLive ? 0.4 : 1.0)
            Text("LIVE")
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(
            Capsule().fill(.green.opacity(0.12))
        )
        .overlay(Capsule().stroke(.green.opacity(0.4), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                pulseLive = true
            }
        }
    }

    // MARK: - Mini Map Preview

    private var mapPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            mapBody
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if vm.loading { loadingChip }
                }

            expandBadge
        }
    }

    private var mapBody: some View {
        Map(position: $camera, interactionModes: []) {
            userAnnotation
            stationAnnotations
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    @MapContentBuilder
    private var userAnnotation: some MapContent {
        Annotation("Tú", coordinate: origin, anchor: .center) {
            userDot
        }
    }

    private var userDot: some View {
        ZStack {
            Circle().fill(.blue.opacity(0.25)).frame(width: 22, height: 22)
            Circle().stroke(.white, lineWidth: 1.5).frame(width: 12, height: 12)
            Circle().fill(.blue).frame(width: 10, height: 10)
        }
        .shadow(color: .blue.opacity(0.5), radius: 4)
    }

    @MapContentBuilder
    private var stationAnnotations: some MapContent {
        let cheapestId = vm.cheapest()?.id
        ForEach(Array(vm.stations.prefix(8))) { station in
            Annotation(station.brand, coordinate: station.coordinate, anchor: .bottom) {
                MiniMapPin(
                    station: station,
                    isCheapest: station.id == cheapestId,
                    priceColor: vm.priceColor(for: station)
                )
            }
        }
    }

    private var loadingChip: some View {
        HStack(spacing: 6) {
            ProgressView().tint(.white).scaleEffect(0.6)
            Text("Cargando…")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.7)))
        .padding(10)
    }

    private var expandBadge: some View {
        Button(action: onExpand) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .heavy))
                Text("Expandir")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.75)))
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Cheapest Hero

    private func cheapestHero(_ s: FuelStation) -> some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "#FBBF24").opacity(0.6), radius: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text("MÁS BARATA")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#FBBF24"))
                    Text(s.brand)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(s.distanceKmFormatted)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(s.priceFormatted)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .shadow(color: Color(hex: "#FBBF24").opacity(0.5), radius: 6)
                    if let savings = s.savingsFormatted {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.right.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(savings)
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(Color(hex: "#34D399"))
                    } else {
                        Text("MXN/L")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FBBF24").opacity(0.18),
                                Color(hex: "#F59E0B").opacity(0.05)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B").opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top list

    private var topListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("OTRAS CERCANAS")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(vm.stations.count - 1) más")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }

            VStack(spacing: 5) {
                ForEach(Array(vm.stations.dropFirst().prefix(3))) { station in
                    compactRow(station)
                }
            }
        }
    }

    private func compactRow(_ s: FuelStation) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(brandColor(s.brand).opacity(0.2))
                    .frame(width: 26, height: 26)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(brandColor(s.brand))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(s.brand)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(s.distanceKmFormatted) · \(s.address)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(s.priceFormatted)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(vm.priceColor(for: s))
                .monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(icon: "fuelpump.fill", value: "\(vm.stations.count)", label: "Cerca", color: .white)
            divider
            statItem(
                icon: "chart.line.flattrend.xyaxis",
                value: vm.averagePrice > 0 ? String(format: "$%.2f", vm.averagePrice) : "—",
                label: "Promedio",
                color: .white
            )
            divider
            statItem(
                icon: "arrow.down.circle.fill",
                value: maxSavingsFormatted,
                label: "Ahorro máx",
                color: Color(hex: "#34D399")
            )
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: 28)
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var maxSavingsFormatted: String {
        let max = vm.stations.compactMap(\.savingsPerLiter).max() ?? 0
        if max <= 0.01 { return "—" }
        return String(format: "$%.2f", max)
    }

    // MARK: - Expand Button

    private var expandButton: some View {
        Button(action: {
            HapticFeedback.medium()
            onExpand()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 13, weight: .heavy))
                Text("Ver mapa completo")
                    .font(.system(size: 14, weight: .heavy))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color(hex: "#3B82F6").opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func fitCameraToStations() {
        guard !vm.stations.isEmpty else { return }
        var lats = vm.stations.map(\.lat) + [origin.latitude]
        var lons = vm.stations.map(\.lon) + [origin.longitude]
        lats.sort(); lons.sort()
        let center = CLLocationCoordinate2D(
            latitude: (lats.first! + lats.last!) / 2,
            longitude: (lons.first! + lons.last!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.last! - lats.first!, 0.015) * 1.5,
            longitudeDelta: max(lons.last! - lons.first!, 0.015) * 1.5
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

// MARK: - Mini Map Pin (compact version)

struct MiniMapPin: View {
    let station: FuelStation
    let isCheapest: Bool
    let priceColor: Color

    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isCheapest {
                    Capsule()
                        .fill(Color(hex: "#FBBF24").opacity(0.5))
                        .frame(width: 50, height: 26)
                        .blur(radius: 8)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                        .opacity(pulse ? 0 : 0.7)
                }

                HStack(spacing: 2) {
                    if isCheapest {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(Color(hex: "#FBBF24"))
                    }
                    Text(station.priceFormatted)
                        .font(.system(size: isCheapest ? 10 : 9, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, isCheapest ? 7 : 5)
                .padding(.vertical, isCheapest ? 4 : 3)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.85))
                        .overlay(
                            Capsule().stroke(
                                isCheapest ? Color(hex: "#FBBF24") : priceColor,
                                lineWidth: isCheapest ? 1.5 : 1
                            )
                        )
                )
                .scaleEffect(isCheapest ? 1.05 : 1.0)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        .onAppear {
            if isCheapest {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
    }
}

// MARK: - FuelType helpers

private extension FuelType {
    var displayShort: String {
        switch self {
        case .magna: return "Magna"
        case .premium: return "Premium"
        case .diesel: return "Diésel"
        case .hybrid: return "Híbrido"
        case .electric: return "Eléctrico"
        }
    }
}
