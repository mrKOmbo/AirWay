//
//  OrganDetailSheet.swift
//  AcessNet
//
//  Sheet que aparece al tocar un órgano afectado en el modelo 3D.
//

import SwiftUI

struct OrganDetailSheet: View {

    let organ: BodyHealthState.Organ
    let health: OrganHealth
    var onSeeMore: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow
            damageBar
            conditionsList
            Spacer(minLength: 0)
            seeMoreButton
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(Color(hex: "#0A0A0F"))
        .presentationDetents([.fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 14) {
            severityBadge
            VStack(alignment: .leading, spacing: 3) {
                Text(organ.localizedName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(health.severity.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(health.severity.tint)
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6), .white.opacity(0.1))
            }
            .accessibilityLabel(String(localized: "Cerrar"))
        }
    }

    private var severityBadge: some View {
        ZStack {
            Circle()
                .fill(health.severity.tint.opacity(0.18))
            Circle()
                .stroke(health.severity.tint.opacity(0.65), lineWidth: 2)
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(health.severity.tint)
        }
        .frame(width: 52, height: 52)
    }

    private var iconName: String {
        switch organ {
        case .lungs:  return "lungs.fill"
        case .nose:   return "nose"
        case .brain:  return "brain.head.profile"
        case .throat: return "waveform.path"
        case .heart:  return "heart.fill"
        case .skin:   return "hand.raised.fill"
        }
    }

    // MARK: Damage bar

    private var damageBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "Nivel de daño"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.0)
                    .textCase(.uppercase)
                Spacer()
                Text("\(Int(health.damageLevel * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(health.severity.tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [health.severity.tint.opacity(0.8), health.severity.tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(health.damageLevel)))
                        .shadow(color: health.severity.tint.opacity(0.6), radius: 6, x: 0, y: 0)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: Conditions

    private var conditionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Factores activos"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.0)
                .textCase(.uppercase)

            if health.activeConditions.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "#4ADE80"))
                    Text(String(localized: "Sin factores ambientales adversos"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                ForEach(health.activeConditions) { condition in
                    HStack(spacing: 12) {
                        Image(systemName: condition.iconSystemName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(health.severity.tint)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(health.severity.tint.opacity(0.12))
                            )
                        Text(condition.localizedName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: CTA

    private var seeMoreButton: some View {
        Button(action: onSeeMore) {
            HStack(spacing: 8) {
                Text(String(localized: "Ver más información"))
                    .font(.system(size: 14, weight: .bold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(health.severity.tint.opacity(0.85))
                    .shadow(color: health.severity.tint.opacity(0.55), radius: 14, x: 0, y: 6)
            )
        }
    }
}
