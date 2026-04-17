//
//  RoutePreferenceSelector.swift
//  AcessNet
//
//  Selector interactivo de preferencias de ruta con sliders visuales
//

import SwiftUI
import Combine

// MARK: - Route Preference Selector

/// Vista principal del selector de preferencias
struct RoutePreferenceSelector: View {
    @Binding var isPresented: Bool
    @ObservedObject var preferences: RoutePreferencesModel
    let onApply: () -> Void

    @State private var selectedPreset: PresetType? = nil
    @State private var showingAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: 24) {
                    // Presets rápidos
                    presetsSection

                    // Sliders principales
                    slidersSection

                    // Opciones avanzadas
                    if showingAdvanced {
                        advancedOptionsSection
                    }

                    // Vista previa de impacto
                    impactPreviewSection
                }
                .padding()
            }

            // Footer con botones
            footerView
        }
        .background(
            ZStack {
                Color(hex: "#0A0F1A").ignoresSafeArea()
                LinearGradient(
                    colors: [Color(hex: "#1A2438").opacity(0.6), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 20, y: -5)
        .transition(.move(edge: .bottom))
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 38, height: 38)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Preferencias de ruta")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Personaliza tu ruta óptima")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Button(action: {
                    HapticFeedback.light()
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.1)))
                        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS RÁPIDOS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PresetButton(
                        type: .fastest,
                        isSelected: selectedPreset == .fastest,
                        action: { applyPreset(.fastest) }
                    )

                    PresetButton(
                        type: .safest,
                        isSelected: selectedPreset == .safest,
                        action: { applyPreset(.safest) }
                    )

                    PresetButton(
                        type: .healthiest,
                        isSelected: selectedPreset == .healthiest,
                        action: { applyPreset(.healthiest) }
                    )

                    PresetButton(
                        type: .balanced,
                        isSelected: selectedPreset == .balanced,
                        action: { applyPreset(.balanced) }
                    )
                }
            }
        }
    }

    private var slidersSection: some View {
        VStack(spacing: 16) {
            PreferenceSlider(
                title: "Velocidad",
                icon: "bolt.fill",
                value: $preferences.speedWeight,
                color: Color(hex: "#A78BFA"),
                description: speedDescription
            )

            PreferenceSlider(
                title: "Seguridad",
                icon: "shield.fill",
                value: $preferences.safetyWeight,
                color: Color(hex: "#34D399"),
                description: safetyDescription
            )

            PreferenceSlider(
                title: "Aire limpio",
                icon: "leaf.fill",
                value: $preferences.airQualityWeight,
                color: Color(hex: "#22D3EE"),
                description: airDescription
            )
        }
        .onChange(of: preferences.speedWeight) { _ in selectedPreset = nil }
        .onChange(of: preferences.safetyWeight) { _ in selectedPreset = nil }
        .onChange(of: preferences.airQualityWeight) { _ in selectedPreset = nil }
    }

    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OPCIONES AVANZADAS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))

            VStack(spacing: 8) {
                ToggleOption(
                    title: "Evitar autopistas",
                    icon: "road.lanes",
                    isOn: $preferences.avoidHighways,
                    description: "Usa calles locales cuando sea posible"
                )

                ToggleOption(
                    title: "Patrones de tráfico",
                    icon: "clock.arrow.circlepath",
                    isOn: $preferences.considerTrafficPatterns,
                    description: "Usa datos históricos de tráfico"
                )

                ToggleOption(
                    title: "Análisis predictivo",
                    icon: "chart.line.uptrend.xyaxis",
                    isOn: $preferences.predictiveAnalysis,
                    description: "Anticipa condiciones futuras"
                )
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var impactPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IMPACTO EN LA RUTA")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))

            HStack(spacing: 10) {
                ImpactIndicator(
                    label: "Tiempo",
                    impact: preferences.timeImpact,
                    icon: "clock.fill",
                    color: Color(hex: "#60A5FA")
                )

                ImpactIndicator(
                    label: "Seguridad",
                    impact: preferences.safetyImpact,
                    icon: "shield.fill",
                    color: Color(hex: "#34D399")
                )

                ImpactIndicator(
                    label: "Salud",
                    impact: preferences.healthImpact,
                    icon: "heart.fill",
                    color: Color(hex: "#F472B6")
                )
            }

            Text(preferences.impactSummary)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            advancedToggleButton
            Spacer()
            resetButton
            applyButton
        }
        .padding(14)
        .background(
            Rectangle().fill(.black.opacity(0.5))
                .overlay(Rectangle().fill(.ultraThinMaterial))
        )
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    private var advancedToggleButton: some View {
        Button(action: {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingAdvanced.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: showingAdvanced ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .heavy))
                Text(showingAdvanced ? "Ocultar" : "Avanzado")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundColor(Color(hex: "#A78BFA"))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Capsule().fill(Color(hex: "#A78BFA").opacity(0.15)))
            .overlay(Capsule().stroke(Color(hex: "#A78BFA").opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var resetButton: some View {
        Button(action: {
            HapticFeedback.warning()
            preferences.reset()
            selectedPreset = nil
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .heavy))
                Text("Reset")
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundColor(Color(hex: "#F87171"))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(Color(hex: "#F87171").opacity(0.15)))
            .overlay(Capsule().stroke(Color(hex: "#F87171").opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var applyButton: some View {
        Button(action: {
            HapticFeedback.confirm()
            onApply()
            isPresented = false
        }) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                Text("Aplicar")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 10)
            .background(applyButtonBackground)
            .shadow(color: Color(hex: "#3B82F6").opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var applyButtonBackground: some View {
        Capsule().fill(
            LinearGradient(
                colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: - Helper Methods

    private func applyPreset(_ preset: PresetType) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedPreset = preset
            preferences.applyPreset(preset)
        }
    }

    private var speedDescription: String {
        switch preferences.speedWeight {
        case 0..<0.3:   return "Prioriza otros factores antes que velocidad"
        case 0.3..<0.6: return "Velocidad moderada"
        case 0.6..<0.8: return "Prefiere rutas más rápidas"
        default:        return "Ruta más rápida posible"
        }
    }

    private var safetyDescription: String {
        switch preferences.safetyWeight {
        case 0..<0.3:   return "Aceptas riesgo por eficiencia"
        case 0.3..<0.6: return "Seguridad balanceada"
        case 0.6..<0.8: return "Evita incidentes activamente"
        default:        return "Máxima seguridad, evita peligros"
        }
    }

    private var airDescription: String {
        switch preferences.airQualityWeight {
        case 0..<0.3:   return "La calidad del aire no es prioridad"
        case 0.3..<0.6: return "Considera calidad moderadamente"
        case 0.6..<0.8: return "Prefiere aire limpio"
        default:        return "Máxima calidad de aire"
        }
    }
}

// MARK: - Preference Slider

struct PreferenceSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let color: Color
    let description: String

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                    .monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(color.opacity(0.15)))
            }

            CustomSlider(
                value: $value,
                color: color,
                isEditing: $isEditing
            )

            Text(description)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(isEditing ? 0.75 : 0.55))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(isEditing ? 0.35 : 0.12), lineWidth: 1)
        )
    }
}

// MARK: - Custom Slider

struct CustomSlider: View {
    @Binding var value: Double
    let color: Color
    @Binding var isEditing: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.55)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(value), height: 6)
                    .shadow(color: color.opacity(0.5), radius: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: color.opacity(0.55), radius: 5, y: 1)
                    .overlay(
                        Circle().stroke(color, lineWidth: 3)
                    )
                    .scaleEffect(isEditing ? 1.22 : 1.0)
                    .offset(x: geometry.size.width * CGFloat(value) - 11)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isEditing = true
                                let newValue = gesture.location.x / geometry.size.width
                                value = min(max(0, Double(newValue)), 1)
                                if Int(value * 10) != Int(newValue * 10) {
                                    HapticFeedback.selection()
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isEditing = false
                                }
                            }
                    )
            }
        }
        .frame(height: 22)
    }
}

// MARK: - Toggle Option

struct ToggleOption: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#3B82F6").opacity(isOn ? 0.25 : 0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(isOn ? Color(hex: "#3B82F6") : .white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(hex: "#3B82F6"))
                .scaleEffect(0.85)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let type: PresetType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(colors: type.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 50, height: 50)
                    Circle()
                        .stroke(isSelected ? .white.opacity(0.25) : .white.opacity(0.1), lineWidth: 1)
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                }
                .shadow(
                    color: isSelected ? type.colors.first?.opacity(0.5) ?? .clear : .clear,
                    radius: 7
                )

                Text(type.label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(isSelected ? type.colors.first ?? .white : .white.opacity(0.55))
            }
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Impact Indicator

struct ImpactIndicator: View {
    let label: String
    let impact: ImpactLevel
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(impact.color)

            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.55))

            Text(impact.label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(impact.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(impact.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(impact.color.opacity(0.3), lineWidth: 0.8)
        )
    }
}

// MARK: - Models

/// Modelo de preferencias de ruta
class RoutePreferencesModel: ObservableObject {
    @Published var speedWeight: Double = 0.4 {
        didSet { normalizeWeights() }
    }
    @Published var safetyWeight: Double = 0.3 {
        didSet { normalizeWeights() }
    }
    @Published var airQualityWeight: Double = 0.3 {
        didSet { normalizeWeights() }
    }

    @Published var avoidHighways: Bool = false
    @Published var considerTrafficPatterns: Bool = true
    @Published var predictiveAnalysis: Bool = true

    // Computed properties
    var timeImpact: ImpactLevel {
        switch speedWeight {
        case 0..<0.3: return .low
        case 0.3..<0.6: return .medium
        default: return .high
        }
    }

    var safetyImpact: ImpactLevel {
        switch safetyWeight {
        case 0..<0.3: return .low
        case 0.3..<0.6: return .medium
        default: return .high
        }
    }

    var healthImpact: ImpactLevel {
        switch airQualityWeight {
        case 0..<0.3: return .low
        case 0.3..<0.6: return .medium
        default: return .high
        }
    }

    var impactSummary: String {
        if speedWeight > 0.6 {
            return "Routes will prioritize speed over safety and air quality"
        } else if safetyWeight > 0.6 {
            return "Routes will avoid incidents, even if it takes longer"
        } else if airQualityWeight > 0.6 {
            return "Routes will seek cleaner air, potentially increasing travel time"
        } else {
            return "Routes will balance all factors for optimal results"
        }
    }

    func applyPreset(_ preset: PresetType) {
        switch preset {
        case .fastest:
            speedWeight = 0.8
            safetyWeight = 0.1
            airQualityWeight = 0.1
        case .safest:
            speedWeight = 0.2
            safetyWeight = 0.6
            airQualityWeight = 0.2
        case .healthiest:
            speedWeight = 0.2
            safetyWeight = 0.3
            airQualityWeight = 0.5
        case .balanced:
            speedWeight = 0.34
            safetyWeight = 0.33
            airQualityWeight = 0.33
        }
    }

    func reset() {
        speedWeight = 0.4
        safetyWeight = 0.3
        airQualityWeight = 0.3
        avoidHighways = false
        considerTrafficPatterns = true
        predictiveAnalysis = true
    }

    private func normalizeWeights() {
        let total = speedWeight + safetyWeight + airQualityWeight
        guard total > 0 else { return }

        // No normalizar si ya está cerca de 1
        if abs(total - 1.0) < 0.01 { return }

        // Normalizar para que sumen 1.0
        speedWeight = speedWeight / total
        safetyWeight = safetyWeight / total
        airQualityWeight = airQualityWeight / total
    }
}

/// Tipos de preset
enum PresetType {
    case fastest
    case safest
    case healthiest
    case balanced

    var icon: String {
        switch self {
        case .fastest: return "bolt.fill"
        case .safest: return "shield.fill"
        case .healthiest: return "leaf.fill"
        case .balanced: return "scale.3d"
        }
    }

    var label: String {
        switch self {
        case .fastest: return "Fastest"
        case .safest: return "Safest"
        case .healthiest: return "Healthiest"
        case .balanced: return "Balanced"
        }
    }

    var colors: [Color] {
        switch self {
        case .fastest: return [.purple, .indigo]
        case .safest: return [.green, .mint]
        case .healthiest: return [.teal, .cyan]
        case .balanced: return [.blue, .blue.opacity(0.7)]
        }
    }
}

/// Nivel de impacto
enum ImpactLevel {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - View Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}