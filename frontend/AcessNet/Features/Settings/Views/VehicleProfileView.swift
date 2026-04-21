//
//  VehicleProfileView.swift
//  AcessNet
//
//  Vista de gestión de perfiles de vehículo con representación 3D.
//  - Escena 3D del vehículo activo
//  - Lista de perfiles guardados (multi-auto)
//  - Formulario para agregar/editar
//  - Búsqueda en catálogo CONUEE (autocomplete)
//

import SwiftUI

struct VehicleProfileView: View {
    @Environment(\.weatherTheme) private var theme
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var service = VehicleProfileService.shared
    @State private var showingEditor = false
    @State private var editingProfile: VehicleProfile?
    @State private var manualAsset: Vehicle3DAsset?

    private var activeWeather: WeatherCondition {
        appSettings.weatherOverride ?? .overcast
    }

    private var resolvedAsset: Vehicle3DAsset {
        if let manual = manualAsset { return manual }
        if let p = service.activeProfile ?? service.savedProfiles.first {
            return .forProfile(p)
        }
        return .fallback
    }

    private var stageTitle: String {
        service.activeProfile?.displayName
        ?? service.savedProfiles.first?.displayName
        ?? "Sin vehículo"
    }

    private var stageSubtitle: String {
        if let p = service.activeProfile ?? service.savedProfiles.first {
            return "\(String(format: "%.1f", p.conueeKmPerL)) km/L · \(p.fuelType.displayName)"
        }
        return "Agrega tu vehículo para ver el modelo 3D"
    }

    private var activeProfile: VehicleProfile? {
        service.activeProfile ?? service.savedProfiles.first
    }

    private var otherProfiles: [VehicleProfile] {
        guard let active = activeProfile else { return [] }
        return service.savedProfiles.filter { $0.id != active.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 3D Stage
                        Vehicle3DStage(
                            asset: resolvedAsset,
                            title: stageTitle,
                            subtitle: stageSubtitle
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Asset switcher — cambia el vehículo activo al que matchee
                        if Vehicle3DAsset.allCases.count > 1 && !service.savedProfiles.isEmpty {
                            Vehicle3DAssetSwitcher(
                                selected: Binding(
                                    get: { resolvedAsset },
                                    set: { newAsset in
                                        // Si hay un vehículo guardado con ese asset, actívalo
                                        if let match = service.savedProfiles.first(where: {
                                            Vehicle3DAsset.forProfile($0) == newAsset
                                        }) {
                                            service.setActive(match)
                                            manualAsset = nil
                                        } else {
                                            manualAsset = newAsset
                                        }
                                    }
                                )
                            )
                            .padding(.horizontal, 16)
                        }

                        if let active = activeProfile {
                            // Hero card con placa grande + identidad
                            VehicleHeroCard(profile: active) {
                                editingProfile = active
                                showingEditor = true
                            }
                            .padding(.horizontal, 16)

                            // Ficha técnica detallada
                            VehicleSpecsCard(profile: active)
                                .padding(.horizontal, 16)

                            // Otros vehículos guardados (sin duplicar el activo)
                            if !otherProfiles.isEmpty {
                                otherVehiclesSection
                            }
                        } else {
                            emptyStateCard
                        }

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Mi vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingProfile = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.textTint)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                VehicleEditorView(profile: editingProfile) { newProfile in
                    service.save(newProfile)
                    manualAsset = nil
                    showingEditor = false
                }
            }
            .environment(\.weatherTheme, theme)
        }
    }

    // MARK: - Other Vehicles Section

    @ViewBuilder
    private var otherVehiclesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OTROS GUARDADOS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Spacer()
                Text("\(otherProfiles.count)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.4))
            }
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(otherProfiles) { profile in
                    GlassProfileRow(
                        profile: profile,
                        isActive: false,
                        onTap: {
                            HapticFeedback.light()
                            service.setActive(profile)
                            manualAsset = nil
                        },
                        onEdit: {
                            editingProfile = profile
                            showingEditor = true
                        },
                        onDelete: {
                            HapticFeedback.warning()
                            service.delete(profile)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(theme.textTint.opacity(0.3))
            Text("No tienes vehículos")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(theme.textTint)
            Text("Agrega el tuyo o carga los dos autos demo con datos reales.")
                .font(.system(size: 11))
                .foregroundColor(theme.textTint.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button {
                    HapticFeedback.medium()
                    editingProfile = nil
                    showingEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12, weight: .heavy))
                        Text("Agregar")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(theme.textTint.opacity(0.08)))
                    .overlay(Capsule().stroke(theme.textTint.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    HapticFeedback.confirm()
                    service.loadDemoVehicles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .heavy))
                        Text("Cargar demo")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Vehicle Hero Card

private struct VehicleHeroCard: View {
    let profile: VehicleProfile
    let onEdit: () -> Void

    @Environment(\.weatherTheme) private var theme

    private var asset: Vehicle3DAsset { .forProfile(profile) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Identidad
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: asset.systemIcon)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(theme.textTint.opacity(0.6))
                        Text(asset.displayName.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.2)
                            .foregroundColor(theme.textTint.opacity(0.5))
                    }
                    Text(profile.displayName)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(profile.fullDisplayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textTint.opacity(0.45))
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.textTint.opacity(0.1)))
                        .overlay(Circle().stroke(theme.textTint.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Placa gigante — protagonista
            if let plate = profile.formattedLicensePlate {
                bigLicensePlate(plate)
            }

            // Chips rápidos: combustible + color + transmisión
            HStack(spacing: 6) {
                chipPill(
                    icon: profile.fuelType.systemIcon,
                    text: profile.fuelType.displayName,
                    color: fuelColor(profile.fuelType)
                )
                if let c = profile.color, !c.isEmpty {
                    colorChip(c)
                }
                chipPill(
                    icon: "gearshift.layout.sixspeed",
                    text: profile.transmission.capitalized,
                    color: Color(hex: "#A78BFA")
                )
                Spacer()
            }

            // Driving style visual
            drivingStyleIndicator
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }

    private func bigLicensePlate(_ plate: String) -> some View {
        HStack(spacing: 0) {
            // Franja lateral tipo placa MEX
            VStack(spacing: 3) {
                Image(systemName: "car.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(theme.textTint)
                Text("MX")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(theme.textTint)
            }
            .frame(width: 26)
            .frame(maxHeight: .infinity)
            .background(Color(hex: "#1E3A8A"))

            VStack(spacing: 2) {
                Text("MÉXICO")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(Color(hex: "#1E3A8A"))
                    .tracking(1.0)
                Text(plate)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(2.5)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .frame(height: 58)
        .background(
            LinearGradient(
                colors: [Color.white, Color(white: 0.92)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func chipPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }

    private func colorChip(_ name: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(parseColor(name))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(theme.textTint.opacity(0.4), lineWidth: 1))
            Text(name)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(theme.textTint.opacity(0.07)))
        .overlay(Capsule().stroke(theme.textTint.opacity(0.12), lineWidth: 1))
    }

    private var drivingStyleIndicator: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "figure.wave.circle.fill")
                        .font(.system(size: 9, weight: .heavy))
                    Text("ESTILO DE MANEJO")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                }
                .foregroundColor(theme.textTint.opacity(0.45))
                Spacer()
                Text(profile.drivingStyleLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(drivingStyleColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTint.opacity(0.06))
                    LinearGradient(
                        colors: [Color(hex: "#34D399"), Color(hex: "#FBBF24"), Color(hex: "#F87171")],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .mask(
                        Capsule()
                            .frame(width: geo.size.width * drivingStyleProgress)
                    )
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .offset(x: geo.size.width * drivingStyleProgress - 5)
                }
            }
            .frame(height: 6)
        }
    }

    private var drivingStyleProgress: CGFloat {
        let raw = (profile.drivingStyle - 0.85) / (1.30 - 0.85)
        return CGFloat(max(0.0, min(1.0, raw)))
    }

    private var drivingStyleColor: Color {
        switch profile.drivingStyle {
        case ..<0.95: return Color(hex: "#34D399")
        case ..<1.10: return Color(hex: "#FBBF24")
        default:      return Color(hex: "#F87171")
        }
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

    private func parseColor(_ name: String) -> Color {
        let t = name.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#") { return Color(hex: t) }
        switch t.lowercased() {
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
}

// MARK: - Glass Profile Row

private struct GlassProfileRow: View {
    let profile: VehicleProfile
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.weatherTheme) private var theme

    private var asset: Vehicle3DAsset { .forProfile(profile) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isActive
                              ? LinearGradient(colors: [.green.opacity(0.5), .teal.opacity(0.3)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom))
                        .frame(width: 46, height: 46)
                    Image(systemName: asset.systemIcon)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(theme.textTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.displayName)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(theme.textTint)
                            .lineLimit(1)
                        if isActive {
                            Text("ACTIVO")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.8)
                                .foregroundColor(.green)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(.green.opacity(0.18)))
                                .overlay(Capsule().stroke(.green.opacity(0.4), lineWidth: 1))
                        }
                    }

                    if let plate = profile.formattedLicensePlate {
                        plateChip(plate)
                    }

                    HStack(spacing: 5) {
                        miniChip(profile.fuelType.displayName, icon: profile.fuelType.systemIcon)
                        miniChip(String(format: "%.1f km/L", profile.conueeKmPerL), icon: "gauge")
                        if let color = profile.color, !color.isEmpty {
                            miniChip(color, icon: "paintpalette.fill")
                        }
                    }
                }

                Spacer(minLength: 4)

                Menu {
                    Button { onEdit() } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(theme.textTint.opacity(0.06)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? theme.textTint.opacity(0.08) : theme.textTint.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.green.opacity(0.3) : theme.textTint.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .heavy))
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundColor(theme.textTint.opacity(0.7))
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(theme.textTint.opacity(0.06)))
    }

    private func plateChip(_ plate: String) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(Color(hex: "#1E3A8A"))
                .frame(width: 4, height: 14)
            Text(plate)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(.black)
                .tracking(1.0)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.textTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.black.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Editor (unchanged shell, styled form)

struct VehicleEditorView: View {
    @Environment(\.weatherTheme) private var theme
    let profile: VehicleProfile?
    let onSave: (VehicleProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var catalogResults: [ConueeVehicleEntry] = []
    @State private var isSearching = false

    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = 2020
    @State private var fuelType: FuelType = .magna
    @State private var kmPerL: Double = 14.0
    @State private var engineCc: Int = 1600
    @State private var transmission: String = "manual"
    @State private var weightKg: Int = 1150
    @State private var nickname: String = ""
    @State private var odometerKm: String = ""
    @State private var licensePlate: String = ""
    @State private var color: String = ""
    @State private var tankCapacity: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Buscar en catálogo CONUEE") {
                    TextField("Ej. Versa, Aveo, Prius...", text: $searchQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onChange(of: searchQuery) { _, newValue in
                            Task { await searchCatalog(newValue) }
                        }

                    if isSearching {
                        ProgressView()
                    } else if !catalogResults.isEmpty {
                        ForEach(catalogResults) { entry in
                            Button {
                                apply(entry: entry)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(entry.make) \(entry.model) \(entry.year)")
                                            .font(.subheadline)
                                        Text("\(String(format: "%.1f", entry.conueeKmPerL)) km/L · \(entry.fuelType.displayName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Datos básicos") {
                    TextField("Marca", text: $make)
                    TextField("Modelo", text: $model)
                    Stepper("Año: \(year)", value: $year, in: 1990...2026)
                    Picker("Combustible", selection: $fuelType) {
                        ForEach(FuelType.allCases) { ft in
                            Text(ft.displayName).tag(ft)
                        }
                    }
                }

                Section("Rendimiento (CONUEE)") {
                    HStack {
                        Text("km/L")
                        Spacer()
                        TextField("14.0", value: $kmPerL, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Motor (opcional)") {
                    HStack {
                        Text("Cilindrada")
                        Spacer()
                        TextField("1600", value: $engineCc, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("cc")
                    }
                    Picker("Transmisión", selection: $transmission) {
                        Text("Manual").tag("manual")
                        Text("Automática").tag("automatic")
                        Text("CVT").tag("cvt")
                    }
                    HStack {
                        Text("Peso")
                        Spacer()
                        TextField("1150", value: $weightKg, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                }

                Section("Identificación") {
                    HStack(spacing: 8) {
                        Image(systemName: "signpost.right.fill")
                            .foregroundColor(.blue)
                        TextField("Matrícula (ej. ABC-123-D)", text: $licensePlate)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced))
                    }
                    TextField("Color (ej. Rojo, Negro, Blanco...)", text: $color)
                        .textInputAutocapitalization(.words)
                    TextField("Apodo (opcional)", text: $nickname)
                }

                Section("Combustible y odómetro") {
                    HStack {
                        Text("Capacidad tanque")
                        Spacer()
                        TextField("50", text: $tankCapacity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("L")
                    }
                    HStack {
                        Text("Kilometraje")
                        Spacer()
                        TextField("0", text: $odometerKm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("km")
                    }
                }
            }
            .navigationTitle(profile == nil ? "Nuevo vehículo" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(make.isEmpty || model.isEmpty)
                }
            }
            .onAppear(perform: loadInitial)
        }
    }

    private func loadInitial() {
        if let p = profile {
            make = p.make
            model = p.model
            year = p.year
            fuelType = p.fuelType
            kmPerL = p.conueeKmPerL
            engineCc = p.engineCc
            transmission = p.transmission
            weightKg = p.weightKg
            nickname = p.nickname ?? ""
            licensePlate = p.licensePlate ?? ""
            color = p.color ?? ""
            if let odo = p.odometerKm { odometerKm = String(odo) }
            if let cap = p.fuelTankCapacityL { tankCapacity = String(format: "%.1f", cap) }
        }
    }

    private func apply(entry: ConueeVehicleEntry) {
        make = entry.make
        model = entry.model
        year = entry.year
        fuelType = entry.fuelType
        kmPerL = entry.conueeKmPerL
        engineCc = entry.engineCc
        transmission = entry.transmission
        weightKg = entry.weightKg
        catalogResults = []
        searchQuery = "\(entry.make) \(entry.model)"
    }

    private func searchCatalog(_ query: String) async {
        guard query.count >= 2 else {
            catalogResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let resp = try await FuelAPIClient.shared.searchCatalog(query: query, limit: 10)
            catalogResults = resp.results
        } catch {
            catalogResults = []
        }
    }

    private func save() {
        let odoInt = Int(odometerKm)
        let tank = Double(tankCapacity.replacingOccurrences(of: ",", with: "."))
        let plate = licensePlate.trimmingCharacters(in: .whitespaces)
        let colorStr = color.trimmingCharacters(in: .whitespaces)
        let newProfile = VehicleProfile(
            id: profile?.id ?? UUID(),
            make: make,
            model: model,
            year: year,
            fuelType: fuelType,
            conueeKmPerL: kmPerL,
            engineCc: engineCc,
            transmission: transmission,
            weightKg: weightKg,
            dragCoefficient: profile?.dragCoefficient ?? 0.33,
            drivingStyle: profile?.drivingStyle ?? 1.0,
            nickname: nickname.isEmpty ? nil : nickname,
            odometerKm: odoInt,
            licensePlate: plate.isEmpty ? nil : plate.uppercased(),
            color: colorStr.isEmpty ? nil : colorStr,
            fuelTankCapacityL: tank,
            createdAt: profile?.createdAt ?? Date(),
            updatedAt: Date()
        )
        onSave(newProfile)
        dismiss()
    }
}

#Preview {
    VehicleProfileView()
        .environmentObject(AppSettings.shared)
}
