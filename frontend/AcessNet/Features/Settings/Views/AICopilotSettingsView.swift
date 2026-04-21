//
//  AICopilotSettingsView.swift
//  AcessNet
//
//  Settings del asistente de IA (Gemini).
//  Tono, idioma, modelo y memoria editable estilo ChatGPT.
//

import SwiftUI

// MARK: - Enums públicos (consumibles por LLMService)

enum AITone: String, CaseIterable, Identifiable {
    case technical, friendly, concise, motivational
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .technical: return "Técnico"
        case .friendly: return "Cercano"
        case .concise: return "Conciso"
        case .motivational: return "Motivacional"
        }
    }

    var icon: String {
        switch self {
        case .technical: return "function"
        case .friendly: return "bubble.left.and.bubble.right.fill"
        case .concise: return "text.alignleft"
        case .motivational: return "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .technical: return Color(hex: "#4ECDC4")
        case .friendly: return Color(hex: "#FFD93D")
        case .concise: return Color(hex: "#95A5A6")
        case .motivational: return Color(hex: "#FF6B6B")
        }
    }

    /// Fragmento de system prompt que se inyectará al LLM.
    var systemPromptFragment: String {
        switch self {
        case .technical:
            return "Usa lenguaje técnico preciso. Cita unidades (µg/m³, ppb) e incluye valores de referencia OMS/EPA cuando apliquen."
        case .friendly:
            return "Habla en tono cercano, como un amigo experto. Usa analogías del día a día para explicar la contaminación."
        case .concise:
            return "Responde en máximo 2-3 frases. Directo, sin relleno."
        case .motivational:
            return "Enfatiza el control y el progreso. Termina cada respuesta con una acción concreta que el usuario pueda hacer hoy."
        }
    }
}

enum AILanguage: String, CaseIterable, Identifiable {
    case auto, es, en
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .auto: return "Auto (sigue el sistema)"
        case .es: return "Español"
        case .en: return "English"
        }
    }
}

enum AIModel: String, CaseIterable, Identifiable {
    case flash, pro
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .flash: return "Gemini Flash"
        case .pro: return "Gemini Pro"
        }
    }
    var subtitle: String {
        switch self {
        case .flash: return "Rápido · ideal para alertas"
        case .pro: return "Profundo · mejor para análisis"
        }
    }
    var icon: String {
        switch self {
        case .flash: return "bolt.fill"
        case .pro: return "brain.head.profile"
        }
    }
}

// MARK: - Vista

struct AICopilotSettingsView: View {
    @Environment(\.weatherTheme) private var theme
    @EnvironmentObject var appSettings: AppSettings
    @State private var newMemoryEntry: String = ""
    @State private var showingAddMemory: Bool = false
    @FocusState private var memoryFieldFocused: Bool

    var body: some View {
        let theme = WeatherTheme(condition: WeatherCondition(rawValue: appSettings.weatherOverrideRaw) ?? .overcast)

        ZStack {
            theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    toneSection(theme: theme)
                    modelSection(theme: theme)
                    languageSection(theme: theme)
                    memorySection(theme: theme)
                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("AI Copilot")
                    .font(.headline)
                    .foregroundColor(theme.textTint)
            }
        }
        .sheet(isPresented: $showingAddMemory) {
            addMemorySheet
                .presentationDetents([.height(260)])
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#6EE7D9"), Color(hex: "#4ECDC4").opacity(0)],
                            center: .center, startRadius: 0, endRadius: 48
                        )
                    )
                    .frame(width: 90, height: 90)
                Image(systemName: "sparkles")
                    .font(.system(size: 34))
                    .foregroundColor(theme.textTint)
            }
            Text("Tu asistente de aire con IA")
                .font(.title3.bold())
                .foregroundColor(theme.textTint)
            Text("Gemini analiza tu entorno y responde según tus preferencias.")
                .font(.footnote)
                .foregroundColor(theme.textTint.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Tone

    private func toneSection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TONO DE RESPUESTA")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AITone.allCases) { tone in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            appSettings.aiToneRaw = tone.rawValue
                        }
                    } label: {
                        let selected = appSettings.aiToneRaw == tone.rawValue
                        VStack(spacing: 8) {
                            Image(systemName: tone.icon)
                                .font(.title2)
                                .foregroundColor(selected ? tone.tint : theme.textTint.opacity(0.5))
                            Text(tone.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(theme.textTint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected ? tone.tint.opacity(0.12) : theme.textTint.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected ? tone.tint.opacity(0.5) : .clear, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Model

    private func modelSection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MODELO")

            VStack(spacing: 8) {
                ForEach(AIModel.allCases) { model in
                    Button {
                        appSettings.aiModelRaw = model.rawValue
                    } label: {
                        let selected = appSettings.aiModelRaw == model.rawValue
                        HStack(spacing: 14) {
                            Image(systemName: model.icon)
                                .font(.title3)
                                .foregroundColor(selected ? Color(hex: "#4ECDC4") : theme.textTint.opacity(0.5))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(theme.textTint)
                                Text(model.subtitle)
                                    .font(.caption)
                                    .foregroundColor(theme.textTint.opacity(0.55))
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#4ECDC4"))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.textTint.opacity(selected ? 0.08 : 0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Language

    private func languageSection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("IDIOMA")

            HStack(spacing: 8) {
                ForEach(AILanguage.allCases) { lang in
                    let selected = appSettings.aiLanguageRaw == lang.rawValue
                    Button {
                        appSettings.aiLanguageRaw = lang.rawValue
                    } label: {
                        Text(lang.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selected ? .black : theme.textTint.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Color.white : theme.textTint.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Memory

    private func memorySection(theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("MEMORIA DEL ASISTENTE")
                Spacer()
                Toggle("", isOn: $appSettings.aiMemoryEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#4ECDC4"))
            }

            Text("AirWay recuerda estos datos entre conversaciones. Editable en cualquier momento.")
                .font(.caption)
                .foregroundColor(theme.textTint.opacity(0.5))

            if appSettings.aiMemoryEnabled {
                VStack(spacing: 6) {
                    let entries = appSettings.aiMemoryEntries
                    if entries.isEmpty {
                        emptyMemoryPlaceholder
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            memoryRow(entry: entry, index: index)
                        }
                    }

                    Button {
                        newMemoryEntry = ""
                        showingAddMemory = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Añadir dato")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#4ECDC4").opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .transition(.opacity)
            }
        }
    }

    private var emptyMemoryPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundColor(theme.textTint.opacity(0.3))
            Text("Sin memoria todavía")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.textTint.opacity(0.6))
            Text("Ej: \"Tengo asma\", \"Corro a las 6am\"")
                .font(.caption2)
                .foregroundColor(theme.textTint.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private func memoryRow(entry: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundColor(Color(hex: "#4ECDC4"))
            Text(entry)
                .font(.callout)
                .foregroundColor(theme.textTint)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                var list = appSettings.aiMemoryEntries
                guard list.indices.contains(index) else { return }
                list.remove(at: index)
                appSettings.aiMemoryEntries = list
            } label: {
                Image(systemName: "trash.fill")
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.textTint.opacity(0.05))
        )
    }

    private var addMemorySheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nuevo dato para el asistente")
                    .font(.headline)
                Spacer()
                Button("Cancelar") { showingAddMemory = false }
            }

            TextField("Ej: Soy asmática, vivo en Coyoacán…", text: $newMemoryEntry, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($memoryFieldFocused)
                .lineLimit(3...5)

            Button {
                let trimmed = newMemoryEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                var list = appSettings.aiMemoryEntries
                list.append(trimmed)
                appSettings.aiMemoryEntries = list
                showingAddMemory = false
            } label: {
                Text("Guardar")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#4ECDC4"))
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(newMemoryEntry.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding()
        .onAppear { memoryFieldFocused = true }
    }

    // MARK: - helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(theme.textTint.opacity(0.6))
            .tracking(1)
    }
}

#Preview {
    NavigationStack {
        AICopilotSettingsView()
            .environmentObject(AppSettings.shared)
    }
}
