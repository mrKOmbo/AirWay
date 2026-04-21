//
//  SearchBarView.swift
//  AcessNet
//
//  Barra de búsqueda refactorizada con soporte para focus y callbacks
//

import SwiftUI

// MARK: - Search Bar View

struct SearchBarView: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let placeholder: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    init(
        searchText: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        placeholder: String = "Where to?",
        onSubmit: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self._searchText = searchText
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icono con avatar glass
            ZStack {
                Circle()
                    .fill(
                        isFocused
                            ? LinearGradient(
                                colors: [Color(hex: "#3B82F6").opacity(0.9),
                                         Color(hex: "#1E40AF").opacity(0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(theme.textTint)
            }
            .shadow(
                color: isFocused ? Color(hex: "#3B82F6").opacity(0.5) : .clear,
                radius: 6
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)

            // Campo de texto
            TextField(placeholder, text: $searchText, prompt:
                Text(placeholder)
                    .foregroundColor(theme.textTint.opacity(0.4))
            )
            .font(.system(size: 15, weight: .heavy))
            .foregroundColor(theme.textTint)
            .tint(Color(hex: "#3B82F6"))
            .focused($isFocused)
            .submitLabel(.search)
            .onSubmit {
                HapticFeedback.light()
                onSubmit()
            }
            .autocorrectionDisabled()
            .onChange(of: isFocused) { newValue in
                if newValue { HapticFeedback.light() }
            }

            // Botón limpiar (cuando hay texto)
            if !searchText.isEmpty {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        searchText = ""
                        onClear()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(theme.textTint.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Botón cancelar enfocado
            if isFocused {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        searchText = ""
                        isFocused = false
                        onClear()
                    }
                } label: {
                    Text("Cancelar")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color(hex: "#3B82F6"))
                        )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.55))
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: isFocused
                        ? [Color(hex: "#3B82F6").opacity(0.55), theme.textTint.opacity(0.1)]
                        : [theme.textTint.opacity(0.12), theme.textTint.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: isFocused ? 1.5 : 1
            )
        )
        .clipShape(Capsule())
        .shadow(
            color: isFocused ? Color(hex: "#3B82F6").opacity(0.35) : .black.opacity(0.35),
            radius: isFocused ? 16 : 10,
            y: isFocused ? 6 : 4
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Compact Search Bar (para cuando hay poco espacio)

struct CompactSearchBar: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
                isFocused = true
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)

                Text(searchText.isEmpty ? "Search" : searchText)
                    .font(.system(size: 15))
                    .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Search Bar with Voice (futuro)

struct SearchBarWithVoice: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let placeholder: String
    let onVoiceSearch: () -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icono de búsqueda
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(isFocused ? .blue : .gray)

            // Campo de texto
            TextField(placeholder, text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            // Botón de limpiar o micrófono
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .transition(.scale)
            } else {
                Button(action: onVoiceSearch) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                }
                .transition(.scale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview("Standard Search Bar") {
    struct PreviewWrapper: View {
    @Environment(\.weatherTheme) private var theme
        @State private var searchText = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack(spacing: 20) {
                SearchBarView(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    placeholder: "Where to?",
                    onSubmit: {
                        print("Submit: \(searchText)")
                    },
                    onClear: {
                        print("Cleared")
                    }
                )
                .padding()

                Text("Focused: \(isFocused ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Toggle Focus") {
                    isFocused.toggle()
                }

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Compact Search Bar") {
    struct PreviewWrapper: View {
    @Environment(\.weatherTheme) private var theme
        @State private var searchText = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                CompactSearchBar(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    onTap: {
                        print("Tapped")
                    }
                )
                .padding()

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("With Voice") {
    struct PreviewWrapper: View {
    @Environment(\.weatherTheme) private var theme
        @State private var searchText = "Starbucks"
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                SearchBarWithVoice(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    placeholder: "Search places...",
                    onVoiceSearch: {
                        print("Voice search")
                    },
                    onSubmit: {
                        print("Submit: \(searchText)")
                    },
                    onClear: {
                        print("Cleared")
                    }
                )
                .padding()

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
