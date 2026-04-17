//
//  ModeComparisonSheet.swift
//  AcessNet
//
//  Sheet rediseñado: comparación visual auto/metro/uber/bici con champions,
//  AI insight, cards glass expandibles y resumen destacado.
//

import SwiftUI
import CoreLocation
import os

struct ModeComparisonSheet: View {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let vehicle: VehicleProfile?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettings

    @State private var response: TripCompareResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var expandedModeId: String?

    private var theme: WeatherTheme {
        WeatherTheme(condition: appSettings.weatherOverride ?? .overcast)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerHero
                        if loading {
                            loadingCard
                        } else if let err = error {
                            errorCard(err)
                        } else if let resp = response {
                            content(resp)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Compara modos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }
            }
            .environment(\.weatherTheme, theme)
            .task { await load() }
        }
    }

    // MARK: - Header

    private var headerHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("¿Cómo llegar?")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                    Text("4 modos · precio real + CO₂ + exposición")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ resp: TripCompareResponse) -> some View {
        if let insight = resp.aiInsight {
            aiInsightCard(insight)
        }

        championsRow(resp)

        modeList(resp)

        fullSummary(resp)
    }

    // MARK: - AI Insight

    private func aiInsightCard(_ insight: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#A78BFA"), Color(hex: "#6366F1")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
            }
            .shadow(color: Color(hex: "#A78BFA").opacity(0.5), radius: 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("INSIGHT AI")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#A78BFA"))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }
                Text(insight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#A78BFA").opacity(0.15),
                                 Color(hex: "#6366F1").opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#A78BFA").opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Champions Row

    @ViewBuilder
    private func championsRow(_ resp: TripCompareResponse) -> some View {
        let chips = buildChampionChips(resp)
        if !chips.isEmpty {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    championChip(title: chip.title, icon: chip.icon,
                                 mode: chip.mode, color: chip.color)
                }
            }
        }
    }

    private struct ChampionChipData: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let mode: TripMode
        let color: Color
    }

    private func buildChampionChips(_ resp: TripCompareResponse) -> [ChampionChipData] {
        var result: [ChampionChipData] = []
        if let c = resp.cheapest {
            result.append(.init(title: "Más barato", icon: "pesosign.circle.fill",
                                mode: c, color: Color(hex: "#34D399")))
        }
        if let f = resp.fastest {
            result.append(.init(title: "Más rápido", icon: "bolt.fill",
                                mode: f, color: Color(hex: "#FBBF24")))
        }
        if let h = resp.healthiest {
            result.append(.init(title: "Más sano", icon: "heart.fill",
                                mode: h, color: Color(hex: "#F472B6")))
        }
        return result
    }

    private func championChip(title: String, icon: String, mode: TripMode, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .heavy))
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.8)
            }
            .foregroundColor(color)

            HStack(spacing: 4) {
                Text(mode.emoji).font(.system(size: 14))
                Text(mode.mode.capitalized)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Mode List

    private func modeList(_ resp: TripCompareResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOS 4 MODOS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(resp.orderedModes) { mode in
                    ModeGlassCard(
                        mode: mode,
                        isCheapest: mode.mode == resp.cheapest?.mode,
                        isFastest: mode.mode == resp.fastest?.mode,
                        isHealthiest: mode.mode == resp.healthiest?.mode,
                        isExpanded: expandedModeId == mode.id,
                        onToggleExpand: {
                            HapticFeedback.light()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                expandedModeId = expandedModeId == mode.id ? nil : mode.id
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Full Summary

    @ViewBuilder
    private func fullSummary(_ resp: TripCompareResponse) -> some View {
        if resp.cheapest != nil || resp.fastest != nil || resp.healthiest != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("RESUMEN")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }

                VStack(spacing: 6) {
                    if let c = resp.cheapest {
                        summaryRow(
                            icon: "pesosign.circle.fill",
                            color: Color(hex: "#34D399"),
                            label: "Más barato",
                            mode: c,
                            value: c.costFormatted
                        )
                    }
                    if let f = resp.fastest {
                        summaryRow(
                            icon: "bolt.fill",
                            color: Color(hex: "#FBBF24"),
                            label: "Más rápido",
                            mode: f,
                            value: f.durationFormatted
                        )
                    }
                    if let h = resp.healthiest {
                        summaryRow(
                            icon: "heart.fill",
                            color: Color(hex: "#F472B6"),
                            label: "Más sano",
                            mode: h,
                            value: h.caloriesBurned > 0 ? "+\(h.caloriesBurned) cal" : "Low PM2.5"
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, mode: TripMode, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.5))
                HStack(spacing: 4) {
                    Text(mode.emoji).font(.system(size: 13))
                    Text(mode.displayName)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white)
            Text("Calculando 4 modos…")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white.opacity(0.85))
            Text("Precio real + CO₂ + exposición + tráfico")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(.orange)
            Text("No pudimos comparar")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.white)
            Text(msg)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.medium()
                Task { await load() }
            } label: {
                Text("Reintentar")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Color(hex: "#3B82F6")))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    // MARK: - Load

    private func load() async {
        loading = true
        error = nil
        AirWayLogger.ui.info(
            "ModeComparisonSheet loading vehicle=\(self.vehicle?.fullDisplayName ?? "nil", privacy: .public)"
        )
        defer { loading = false }
        do {
            response = try await TripCompareAPI.shared.compare(
                origin: origin, destination: destination, vehicle: vehicle
            )
            // Expandir automáticamente el modo recomendado
            if let rec = response?.recommendation?.modeSuggested {
                expandedModeId = rec
            }
        } catch {
            self.error = error.localizedDescription
            AirWayLogger.ui.error("ModeComparisonSheet failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Mode Glass Card

private struct ModeGlassCard: View {
    let mode: TripMode
    let isCheapest: Bool
    let isFastest: Bool
    let isHealthiest: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @Environment(\.weatherTheme) private var theme

    private var highlight: (color: Color, label: String, icon: String)? {
        if isCheapest { return (Color(hex: "#34D399"), "MÁS BARATO", "pesosign.circle.fill") }
        if isFastest { return (Color(hex: "#FBBF24"), "MÁS RÁPIDO", "bolt.fill") }
        if isHealthiest { return (Color(hex: "#F472B6"), "MÁS SANO", "heart.fill") }
        return nil
    }

    private var accentColor: Color {
        highlight?.color ?? Color(hex: "#60A5FA")
    }

    var body: some View {
        Button(action: onToggleExpand) {
            VStack(alignment: .leading, spacing: 0) {
                mainRow
                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.horizontal, 14)
                    detailGrid
                        .padding(14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        highlight != nil
                            ? accentColor.opacity(0.08)
                            : Color.white.opacity(0.04)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(highlight != nil ? 0.55 : 0.15),
                                     Color.white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var mainRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emoji avatar
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 54, height: 54)
                Text(mode.emoji).font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Título + badge
                HStack(spacing: 6) {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let h = highlight {
                        HStack(spacing: 3) {
                            Image(systemName: h.icon)
                                .font(.system(size: 7, weight: .heavy))
                            Text(h.label)
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.6)
                        }
                        .foregroundColor(h.color)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(h.color.opacity(0.15)))
                        .overlay(Capsule().stroke(h.color.opacity(0.4), lineWidth: 0.8))
                    }
                }

                // Primary stats
                HStack(spacing: 10) {
                    statInline(
                        icon: "clock.fill",
                        value: mode.durationFormatted,
                        color: Color(hex: "#60A5FA")
                    )
                    statInline(
                        icon: "pesosign.circle.fill",
                        value: mode.costFormatted,
                        color: Color(hex: "#34D399")
                    )
                    statInline(
                        icon: "leaf.fill",
                        value: mode.co2Formatted,
                        color: Color(hex: "#A78BFA")
                    )
                }

                // Secondary
                if mode.hiddenCostMxn > 1 || mode.caloriesBurned > 0 {
                    HStack(spacing: 8) {
                        if mode.hiddenCostMxn > 1 {
                            secondaryChip(
                                "+$\(Int(mode.hiddenCostMxn)) ocultos",
                                icon: "eye.slash.fill",
                                color: Color(hex: "#FB923C")
                            )
                        }
                        if mode.caloriesBurned > 0 {
                            secondaryChip(
                                "+\(mode.caloriesBurned) cal",
                                icon: "flame.fill",
                                color: Color(hex: "#F472B6")
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white.opacity(0.06)))
        }
        .padding(14)
    }

    private func statInline(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func secondaryChip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .heavy))
            Text(text)
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.6))
    }

    // MARK: - Detail Grid

    private var detailGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let v = mode.vehicleDisplay {
                detailInline(label: "Vehículo", value: v, icon: "car.fill")
            }
            if let liters = mode.liters {
                detailInline(label: "Consumo", value: String(format: "%.2f L", liters), icon: "fuelpump.fill")
            }
            if let tolls = mode.tollsMxn, tolls > 0 {
                detailInline(label: "Peajes", value: "$\(Int(tolls))", icon: "road.lanes")
            }
            if let parking = mode.parkingMxn, parking > 0 {
                detailInline(label: "Parking", value: "$\(Int(parking))", icon: "parkingsign.circle.fill")
            }
            if let dep = mode.depreciationMxn, dep > 0 {
                detailInline(label: "Depreciación", value: String(format: "$%.0f", dep), icon: "chart.line.downtrend.xyaxis")
            }
            if let walk = mode.walkingM, walk > 0 {
                detailInline(label: "Caminata", value: "\(walk) m", icon: "figure.walk")
            }
            if mode.pm25ExposureG > 0 {
                detailInline(
                    label: "Exposición PM2.5",
                    value: String(format: "%.3f g", mode.pm25ExposureG),
                    icon: "lungs.fill"
                )
            }
            if let surge = mode.surgeAssumed, surge != 1.0 {
                detailInline(
                    label: "Surge Uber",
                    value: String(format: "×%.2f", surge),
                    icon: "arrow.up.circle.fill"
                )
            }
            if let note = mode.healthNote {
                inlineNote(note, color: Color(hex: "#F472B6"))
            }
            if let note = mode.fareNote {
                inlineNote(note, color: Color(hex: "#60A5FA"))
            }
        }
    }

    private func detailInline(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func inlineNote(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 9, weight: .heavy))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(color)
    }
}
