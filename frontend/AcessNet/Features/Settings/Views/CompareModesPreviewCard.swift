//
//  CompareModesPreviewCard.swift
//  AcessNet
//
//  Preview compacto de "Compara modos" para el Hub (lado izquierdo del dashboard).
//  Muestra recomendación AI + grid 2x2 de modos con tiempo/costo/impact.
//

import SwiftUI
import CoreLocation
import Combine

struct CompareModesPreviewCard: View {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let vehicle: VehicleProfile?
    let onExpand: () -> Void

    @Environment(\.weatherTheme) private var theme
    @State private var modes: [TripMode] = CompareModesPreviewCard.mockModes
    @State private var recommended: TripMode? = CompareModesPreviewCard.mockModes.first(where: { $0.mode == "bici" })
    @State private var loading: Bool = false

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onExpand()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                header
                heroRecommendation
                modesGrid
                footerCTA
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA").opacity(0.4), Color.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#A78BFA").opacity(0.7), Color(hex: "#7C3AED").opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Compara modos")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("4 opciones · IA")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Text("3")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(.white.opacity(0.1)))
        }
    }

    // MARK: - Hero recommendation

    @ViewBuilder
    private var heroRecommendation: some View {
        if let rec = recommended {
            HStack(spacing: 8) {
                Text(rec.emoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("RECOMENDADO")
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(Color(hex: "#FBBF24"))
                        Image(systemName: "sparkles")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(Color(hex: "#FBBF24"))
                    }
                    Text(rec.displayName)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(rec.durationFormatted)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text(rec.costFormatted)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: "#34D399"))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FBBF24").opacity(0.15),
                                     Color(hex: "#F59E0B").opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "#FBBF24").opacity(0.35), lineWidth: 1)
            )
        }
    }

    // MARK: - Modes grid

    private var modesGrid: some View {
        let maxCost = modes.map(\.totalCostMxn).max() ?? 1
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                                   GridItem(.flexible(), spacing: 6)],
                         spacing: 6) {
            ForEach(modes) { mode in
                modeTile(mode, maxCost: maxCost)
            }
        }
    }

    private func modeTile(_ mode: TripMode, maxCost: Double) -> some View {
        let isRecommended = mode.mode == recommended?.mode
        let progress = maxCost > 0 ? CGFloat(mode.totalCostMxn / maxCost) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(mode.emoji)
                    .font(.system(size: 13))
                Text(mode.mode.capitalized)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(mode.durationMin))")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("min")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 2) {
                Image(systemName: "pesosign.circle.fill")
                    .font(.system(size: 7, weight: .heavy))
                Text("\(Int(mode.totalCostMxn))")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(costColor(mode.totalCostMxn, max: maxCost))

            // Cost bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.06))
                    Capsule()
                        .fill(costColor(mode.totalCostMxn, max: maxCost))
                        .frame(width: max(2, geo.size.width * progress))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 7).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isRecommended ? Color(hex: "#FBBF24").opacity(0.08) : .white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isRecommended ? Color(hex: "#FBBF24").opacity(0.5) : .white.opacity(0.08),
                    lineWidth: isRecommended ? 1 : 0.8
                )
        )
    }

    private func costColor(_ cost: Double, max: Double) -> Color {
        guard max > 0 else { return .white }
        let r = cost / max
        if r < 0.25 { return Color(hex: "#34D399") }
        if r < 0.6  { return Color(hex: "#FBBF24") }
        return Color(hex: "#F87171")
    }

    // MARK: - Footer

    private var footerCTA: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.horizontal.page.fill")
                .font(.system(size: 9, weight: .heavy))
            Text("Ver comparación completa")
                .font(.system(size: 10, weight: .heavy))
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: [Color(hex: "#A78BFA").opacity(0.85), Color(hex: "#7C3AED").opacity(0.85)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Mock data

    private static let mockModes: [TripMode] = [
        TripMode(
            mode: "auto",
            durationMin: 18,
            distanceKm: 6.5,
            directCostMxn: 30,
            hiddenCostMxn: 18,
            totalCostMxn: 48,
            co2Kg: 1.8,
            pm25ExposureG: 0.45,
            caloriesBurned: 0,
            liters: 0.56,
            vehicleDisplay: nil,
            tollsMxn: 0,
            parkingMxn: 5,
            depreciationMxn: 13,
            walkingM: 50,
            fareBreakdown: nil,
            surgeAssumed: nil,
            fareNote: nil,
            ecobiciAvailable: nil,
            healthNote: nil
        ),
        TripMode(
            mode: "metro",
            durationMin: 32,
            distanceKm: 6.5,
            directCostMxn: 5,
            hiddenCostMxn: 0,
            totalCostMxn: 5,
            co2Kg: 0.3,
            pm25ExposureG: 0.8,
            caloriesBurned: 180,
            liters: nil,
            vehicleDisplay: nil,
            tollsMxn: nil,
            parkingMxn: nil,
            depreciationMxn: nil,
            walkingM: 650,
            fareBreakdown: nil,
            surgeAssumed: nil,
            fareNote: nil,
            ecobiciAvailable: nil,
            healthNote: "+180 cal"
        ),
        TripMode(
            mode: "uber",
            durationMin: 15,
            distanceKm: 6.5,
            directCostMxn: 85,
            hiddenCostMxn: 0,
            totalCostMxn: 85,
            co2Kg: 1.2,
            pm25ExposureG: 0.32,
            caloriesBurned: 0,
            liters: nil,
            vehicleDisplay: nil,
            tollsMxn: nil,
            parkingMxn: nil,
            depreciationMxn: nil,
            walkingM: 30,
            fareBreakdown: nil,
            surgeAssumed: 1.0,
            fareNote: nil,
            ecobiciAvailable: nil,
            healthNote: nil
        ),
        TripMode(
            mode: "bici",
            durationMin: 25,
            distanceKm: 6.5,
            directCostMxn: 0,
            hiddenCostMxn: 0,
            totalCostMxn: 0,
            co2Kg: 0,
            pm25ExposureG: 0.22,
            caloriesBurned: 240,
            liters: nil,
            vehicleDisplay: nil,
            tollsMxn: nil,
            parkingMxn: nil,
            depreciationMxn: nil,
            walkingM: 0,
            fareBreakdown: nil,
            surgeAssumed: nil,
            fareNote: nil,
            ecobiciAvailable: true,
            healthNote: "+240 cal"
        ),
    ]
}
