//
//  TripModeToggle.swift
//  AcessNet
//
//  Toggle glass (capsule con dos opciones) entre "A pie" y "En coche".
//  Usa matchedGeometryEffect para deslizar el highlight + haptic al cambiar.
//

import SwiftUI

struct TripModeToggle: View {
    @Binding var mode: BriefingMode
    @Environment(\.weatherTheme) private var theme
    @Namespace private var highlightNS

    var body: some View {
        HStack(spacing: 4) {
            ForEach(BriefingMode.allCases) { m in
                option(for: m)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: mode)
    }

    // MARK: - Option

    private func option(for m: BriefingMode) -> some View {
        let active = (mode == m)
        return Button {
            guard mode != m else { return }
            HapticFeedback.selection()
            mode = m
        } label: {
            ZStack {
                if active {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.95),
                                    theme.accent.opacity(0.70)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.6)
                        )
                        .shadow(color: theme.accent.opacity(0.55), radius: 10, y: 3)
                        .matchedGeometryEffect(id: "highlight", in: highlightNS)
                }

                HStack(spacing: 8) {
                    Image(systemName: m.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(active ? Color.white : Color.black.opacity(0.72))
                .padding(.vertical, 9)
                .padding(.horizontal, 18)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(m.title))
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Toggle — walking") {
    Wrapper(initial: .walking)
}

#Preview("Toggle — driving") {
    Wrapper(initial: .driving)
}

private struct Wrapper: View {
    @State var mode: BriefingMode

    init(initial: BriefingMode) {
        _mode = State(initialValue: initial)
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
                TripModeToggle(mode: $mode)
                Text("Modo: \(mode.title)")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.footnote.monospacedDigit())
            }
        }
        .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
    }
}
