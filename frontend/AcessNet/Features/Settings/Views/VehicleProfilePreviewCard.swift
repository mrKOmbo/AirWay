//
//  VehicleProfilePreviewCard.swift
//  AcessNet
//
//  Preview embedded en GasolinaMeterHubView.
//  Mini-stage 3D + info del activo + carousel otros autos + CTAs.
//

import SwiftUI
import Combine

struct VehicleProfilePreviewCard: View {
    let onExpand: () -> Void
    let onAdd: () -> Void

    @StateObject private var service = VehicleProfileService.shared
    @Environment(\.weatherTheme) private var theme

    private var active: VehicleProfile? {
        service.activeProfile ?? service.savedProfiles.first
    }

    private var asset: Vehicle3DAsset {
        if let p = active { return .forProfile(p) }
        return .fallback
    }

    private var otherProfiles: [VehicleProfile] {
        guard let active = active else { return [] }
        return service.savedProfiles.filter { $0.id != active.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let active = active {
                miniStage(for: active)
                activeInfoRow(active)
                if !otherProfiles.isEmpty {
                    otherVehiclesCarousel
                }
                ctaRow
            } else {
                emptyState
            }
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#3B82F6").opacity(0.6), Color(hex: "#6366F1").opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Mi vehículo")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                    if !service.savedProfiles.isEmpty {
                        Text("\(service.savedProfiles.count)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
                Text(active != nil ? "Modelo 3D · consumo CONUEE" : "Sin vehículo configurado")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            Text("1")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Mini Stage

    private func miniStage(for profile: VehicleProfile) -> some View {
        ZStack(alignment: .topTrailing) {
            Vehicle3DStage(
                asset: asset,
                title: profile.displayName,
                subtitle: "",
                height: 200,
                showsChrome: false,
                autoRotateInitially: true
            )

            Button(action: {
                HapticFeedback.light()
                onExpand()
            }) {
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
            .padding(10)
        }
    }

    // MARK: - Active Info Row

    private func activeInfoRow(_ p: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(p.displayName)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        activeBadge
                    }
                    HStack(spacing: 4) {
                        Image(systemName: p.fuelType.systemIcon)
                            .font(.system(size: 9, weight: .bold))
                        Text(p.fuelType.displayName)
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(fuelColor(p.fuelType))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(fuelColor(p.fuelType).opacity(0.15)))
                    .overlay(Capsule().stroke(fuelColor(p.fuelType).opacity(0.4), lineWidth: 1))
                }
                Spacer(minLength: 4)

                miniStat(value: String(format: "%.1f", p.conueeKmPerL),
                         unit: "km/L",
                         color: Color(hex: "#34D399"))
                miniStat(value: "\(p.engineCc)",
                         unit: "cc",
                         color: Color(hex: "#FBBF24"))
            }

            if p.formattedLicensePlate != nil || p.color != nil || p.rangePerTankKm != nil {
                HStack(spacing: 6) {
                    if let plate = p.formattedLicensePlate {
                        compactPlate(plate)
                    }
                    if let color = p.color, !color.isEmpty {
                        compactColor(color)
                    }
                    if let range = p.rangePerTankKm {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 8, weight: .heavy))
                            Text("\(Int(range)) km")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(Color(hex: "#F472B6"))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#F472B6").opacity(0.12)))
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    private func compactPlate(_ plate: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(Color(hex: "#1E3A8A")).frame(width: 3, height: 12)
            Text(plate)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(.black)
                .tracking(0.8)
                .padding(.trailing, 5)
        }
        .background(
            RoundedRectangle(cornerRadius: 3).fill(.white)
        )
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.4), lineWidth: 0.8))
    }

    private func compactColor(_ name: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(parseColor(name))
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.5))
            Text(name)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.07)))
    }

    private func parseColor(_ name: String) -> Color {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return Color(hex: trimmed) }
        switch trimmed.lowercased() {
        case "rojo", "red": return Color(hex: "#DC2626")
        case "azul", "blue": return Color(hex: "#2563EB")
        case "verde", "green": return Color(hex: "#16A34A")
        case "amarillo", "yellow": return Color(hex: "#FACC15")
        case "naranja", "orange": return Color(hex: "#EA580C")
        case "negro", "black": return Color(hex: "#1F2937")
        case "blanco", "white": return Color(hex: "#F3F4F6")
        case "gris", "gray", "grey": return Color(hex: "#6B7280")
        case "plata", "plateado", "silver": return Color(hex: "#CBD5E1")
        case "café", "cafe", "brown", "marrón", "marron": return Color(hex: "#78350F")
        case "vino", "guinda", "burgundy": return Color(hex: "#881337")
        case "morado", "violeta", "purple", "violet": return Color(hex: "#7C3AED")
        default: return Color(hex: "#9CA3AF")
        }
    }

    private var activeBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.green)
                .frame(width: 5, height: 5)
                .shadow(color: .green, radius: 3)
            Text("ACTIVO")
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Capsule().fill(.green.opacity(0.12)))
        .overlay(Capsule().stroke(.green.opacity(0.4), lineWidth: 1))
    }

    private func miniStat(value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(unit.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Other Vehicles Carousel

    private var otherVehiclesCarousel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("OTROS GUARDADOS")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("Toca para cambiar")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.35))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(otherProfiles) { profile in
                        otherVehicleChip(profile)
                    }
                    addVehicleChip
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func otherVehicleChip(_ p: VehicleProfile) -> some View {
        Button {
            HapticFeedback.light()
            service.setActive(p)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: Vehicle3DAsset.forProfile(p).systemIcon)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                    Text(shortName(p))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Text("\(String(format: "%.1f", p.conueeKmPerL)) km/L")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(fuelColor(p.fuelType))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var addVehicleChip: some View {
        Button(action: onAdd) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11, weight: .heavy))
                Text("Agregar")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(hex: "#10B981").opacity(0.3), Color(hex: "#059669").opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
            .overlay(
                Capsule().stroke(Color(hex: "#10B981").opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Row

    private var ctaRow: some View {
        Button(action: {
            HapticFeedback.medium()
            onExpand()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "car.2.fill")
                    .font(.system(size: 13, weight: .heavy))
                Text("Ver todos (\(service.savedProfiles.count))")
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
            .shadow(color: Color(hex: "#3B82F6").opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Vehicle3DStage(
                asset: .fallback,
                title: "Demo",
                subtitle: "",
                height: 200,
                showsChrome: false,
                autoRotateInitially: true
            )

            Button(action: {
                HapticFeedback.medium()
                onExpand()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 13, weight: .heavy))
                    Text("Ver coches")
                        .font(.system(size: 14, weight: .heavy))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 12)
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
    }

    // MARK: - Helpers

    private func shortName(_ p: VehicleProfile) -> String {
        if let nick = p.nickname, !nick.isEmpty { return nick }
        return "\(p.make) \(p.model)"
    }

    private func fuelColor(_ t: FuelType) -> Color {
        switch t {
        case .magna: return Color(hex: "#34D399")
        case .premium: return Color(hex: "#F87171")
        case .diesel: return Color(hex: "#FBBF24")
        case .hybrid: return Color(hex: "#60A5FA")
        case .electric: return Color(hex: "#A78BFA")
        }
    }
}
