//
//  RoutePriorityPicker.swift
//  AcessNet
//
//  Selector de 3 pastillas glass — Rápido / Aire limpio / Balanceado.
//  Reemplaza al RoutePreferencesSelector legacy cuando el Trip Briefing
//  está activo. Mapea directo a RoutePreference.
//

import SwiftUI

// MARK: - Priority enum

enum TripPriority: String, CaseIterable, Identifiable {
    case fast
    case clean
    case balanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:     return "Rápido"
        case .clean:    return "Aire limpio"
        case .balanced: return "Balanceado"
        }
    }

    var icon: String {
        switch self {
        case .fast:     return "bolt.fill"
        case .clean:    return "leaf.fill"
        case .balanced: return "scalemass.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .fast:     return "#FFB830"  // ámbar
        case .clean:    return "#7ED957"  // verde
        case .balanced: return "#8EACC0"  // azul-gris
        }
    }

    /// Mapea a la `RoutePreference` del RouteManager.
    var routePreference: RoutePreference {
        switch self {
        case .fast:     return .fastest
        case .clean:    return .cleanestAir
        case .balanced: return .balanced
        }
    }
}

// MARK: - Picker

struct RoutePriorityPicker: View {
    @Binding var selection: TripPriority

    /// Pastilla que el sistema sugiere por contexto (AQI, modo).
    /// Si coincide con `selection`, se muestra un check. Si difiere,
    /// se muestra un punto discreto indicando "hay sugerencia".
    var suggested: TripPriority? = nil

    @Environment(\.weatherTheme) private var theme
    @Namespace private var highlightNS

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("¿QUÉ PRIORIZAS?")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.black.opacity(0.55))

                if let suggested, suggested != selection {
                    suggestedHint(suggested: suggested)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(TripPriority.allCases) { p in
                    pill(for: p)
                }
            }
        }
    }

    // MARK: - Pill

    private func pill(for priority: TripPriority) -> some View {
        let active = (selection == priority)
        let color = Color(hex: priority.accentHex)
        let isSuggested = (suggested == priority)

        return Button {
            guard selection != priority else { return }
            HapticFeedback.selection()
            selection = priority
        } label: {
            ZStack {
                if active {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.40), lineWidth: 0.6)
                        )
                        .shadow(color: color.opacity(0.45), radius: 8, y: 3)
                        .matchedGeometryEffect(id: "priorityHighlight", in: highlightNS)
                }

                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: priority.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                active ? Color.white : Color.black.opacity(0.65)
                            )
                        if isSuggested && !active {
                            // Dot indicando "sugerido"
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                                .offset(x: 9, y: -9)
                                .shadow(color: color.opacity(0.7), radius: 3)
                        }
                    }
                    Text(priority.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            active ? Color.white : Color.black.opacity(0.75)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .background(
                !active
                    ? RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                    : nil
            )
            .overlay(
                !active
                    ? RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSuggested
                                ? color.opacity(0.5)
                                : Color.black.opacity(0.12),
                            lineWidth: isSuggested ? 1 : 0.6
                        )
                    : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selection)
        .accessibilityLabel(Text(priority.title))
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityHint(Text(isSuggested ? "Sugerido por las condiciones actuales" : ""))
    }

    // MARK: - Suggested hint

    private func suggestedHint(suggested: TripPriority) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
            Text("Sugerido: \(suggested.title.lowercased())")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color(hex: suggested.accentHex))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Color(hex: suggested.accentHex).opacity(0.15))
        )
        .overlay(
            Capsule().stroke(Color(hex: suggested.accentHex).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview("Picker — default") {
    PickerWrapper(initial: .balanced, suggested: nil)
}

#Preview("Picker — con sugerencia") {
    PickerWrapper(initial: .fast, suggested: .clean)
}

private struct PickerWrapper: View {
    @State var selection: TripPriority
    let suggested: TripPriority?

    init(initial: TripPriority, suggested: TripPriority?) {
        _selection = State(initialValue: initial)
        self.suggested = suggested
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A0F"), Color(hex: "#1B1E2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                RoutePriorityPicker(selection: $selection, suggested: suggested)
                    .padding(.horizontal, 16)

                Text("Preference: \(String(describing: selection.routePreference))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
    }
}
