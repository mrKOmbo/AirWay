//
//  FuelStationSuggestionBanner.swift
//  AcessNet
//
//  Banner sugiriendo la gasolinera más barata en la ruta del usuario.
//  Se dispara cuando el nivel de tanque es bajo (Fase 7+) o manualmente.
//

import SwiftUI
import MapKit

struct FuelStationSuggestionBanner: View {
    let station: FuelStation
    let averagePrice: Double
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            brandBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(station.brand)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("a \(station.distanceKmFormatted)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.55))
                }
                HStack(spacing: 6) {
                    Text(station.priceFormatted)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color(hex: "#34D399"))
                    if let savings = station.savingsFormatted {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 8, weight: .heavy))
                            Text(savings)
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundColor(Color(hex: "#34D399"))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#34D399").opacity(0.18)))
                        .overlay(Capsule().stroke(Color(hex: "#34D399").opacity(0.4), lineWidth: 0.8))
                    }
                }
                Text(station.address)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(action: {
                HapticFeedback.light()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.72))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#FBBF24").opacity(0.5),
                                 Color(hex: "#F59E0B").opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
        .onTapGesture {
            HapticFeedback.medium()
            onTap()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var brandBadge: some View {
        ZStack {
            Circle()
                .fill(brandColor.opacity(0.25))
                .frame(width: 42, height: 42)
            Circle()
                .stroke(brandColor.opacity(0.4), lineWidth: 1)
                .frame(width: 42, height: 42)
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(brandColor)
        }
        .shadow(color: brandColor.opacity(0.35), radius: 6)
    }

    private var brandColor: Color {
        switch station.brand.lowercased() {
        case "pemex":            return Color(hex: "#34D399")
        case "shell":            return Color(hex: "#FBBF24")
        case "bp", "bp ultimate": return Color(hex: "#10B981")
        case "mobil", "exxonmobil": return Color(hex: "#3B82F6")
        case "g500":             return Color(hex: "#EF4444")
        case "oxxo gas":         return Color(hex: "#DC2626")
        default:                 return Color(hex: "#F97316")
        }
    }
}

// MARK: - Open in Maps helper

extension FuelStation {
    /// Abre la estación en Apple Maps con driving directions.
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        FuelStationSuggestionBanner(
            station: FuelStation(
                id: "1", brand: "Pemex", name: "Pemex Reforma",
                address: "Paseo de la Reforma 100, Juárez",
                lat: 19.4356, lon: -99.1531, price: 23.62,
                fuelType: "magna", distanceM: 400, savingsPerLiter: 0.68
            ),
            averagePrice: 24.30,
            onTap: {},
            onDismiss: {}
        )

        FuelStationSuggestionBanner(
            station: FuelStation(
                id: "2", brand: "Shell", name: "Shell Polanco",
                address: "Av. Masaryk 61, Polanco",
                lat: 19.43, lon: -99.20, price: 24.10,
                fuelType: "magna", distanceM: 1200, savingsPerLiter: 0.20
            ),
            averagePrice: 24.30,
            onTap: {},
            onDismiss: {}
        )
    }
    .padding()
}
#endif
