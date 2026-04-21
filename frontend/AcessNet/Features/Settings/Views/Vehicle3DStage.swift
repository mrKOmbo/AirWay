//
//  Vehicle3DStage.swift
//  AcessNet
//
//  Escenario 3D premium para mostrar el vehículo del usuario.
//  RealityView con auto-rotación, drag gesture, iluminación y floor shadow.
//

import SwiftUI
import RealityKit

// MARK: - Vehicle 3D Stage

struct Vehicle3DStage: View {
    @Environment(\.weatherTheme) private var theme
    let asset: Vehicle3DAsset
    let title: String
    let subtitle: String
    var height: CGFloat = 320
    var showsChrome: Bool = true
    var autoRotateInitially: Bool = true

    @State private var yaw: Float = 0.35
    @State private var dragYaw: Float = 0
    @State private var autoRotate: Bool
    @State private var loadError: Bool = false
    @State private var entityLoaded: Bool = false
    @State private var animateIn: Bool = false
    @State private var autoRotateTask: Task<Void, Never>? = nil

    init(
        asset: Vehicle3DAsset,
        title: String,
        subtitle: String,
        height: CGFloat = 320,
        showsChrome: Bool = true,
        autoRotateInitially: Bool = true
    ) {
        self.asset = asset
        self.title = title
        self.subtitle = subtitle
        self.height = height
        self.showsChrome = showsChrome
        self.autoRotateInitially = autoRotateInitially
        _autoRotate = State(initialValue: autoRotateInitially)
    }

    var body: some View {
        ZStack {
            stageBackground

            RealityView { content in
                // Cámara
                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = 40
                camera.look(at: SIMD3<Float>(0, 0, 0),
                            from: SIMD3<Float>(0, 0.35, 2.4),
                            relativeTo: nil)
                content.add(camera)

                // Luces
                let keyLight = DirectionalLight()
                keyLight.light.intensity = 3500
                keyLight.light.color = .white
                keyLight.orientation = simd_quatf(angle: -0.6, axis: SIMD3<Float>(1, 0, 0)) *
                                       simd_quatf(angle: 0.3, axis: SIMD3<Float>(0, 1, 0))
                keyLight.shadow = DirectionalLightComponent.Shadow()
                content.add(keyLight)

                let fillLight = DirectionalLight()
                fillLight.light.intensity = 1200
                fillLight.light.color = .init(red: 0.6, green: 0.75, blue: 1.0, alpha: 1.0)
                fillLight.orientation = simd_quatf(angle: 0.4, axis: SIMD3<Float>(1, 0, 0)) *
                                        simd_quatf(angle: -0.9, axis: SIMD3<Float>(0, 1, 0))
                content.add(fillLight)

                let ambient = PointLight()
                ambient.light.intensity = 2000
                ambient.light.color = .white
                ambient.position = SIMD3<Float>(0, 2, 0)
                content.add(ambient)

                // Carga del modelo
                guard let url = Bundle.main.url(
                    forResource: asset.assetName,
                    withExtension: asset.fileExtension
                ) else {
                    print("[Vehicle3DStage] ❌ Bundle NO contiene: \(asset.assetName).\(asset.fileExtension)")
                    print("[Vehicle3DStage] Bundle path: \(Bundle.main.bundlePath)")
                    loadError = true
                    return
                }

                print("[Vehicle3DStage] Cargando: \(url.lastPathComponent)")
                do {
                    let vehicle = try await Entity(contentsOf: url)
                    vehicle.name = "vehicle"

                    let bounds = vehicle.visualBounds(relativeTo: nil as Entity?)
                    let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                    let targetSize: Float = 1.35
                    let scaleFactor: Float = maxDim > 0 ? (targetSize / maxDim) : 1.0
                    vehicle.scale = SIMD3<Float>(repeating: scaleFactor)
                    let center = bounds.center
                    vehicle.position = SIMD3<Float>(-center.x, -center.y, -center.z) * scaleFactor

                    let root = Entity()
                    root.name = "vehicleRoot"
                    root.addChild(vehicle)
                    root.position = SIMD3<Float>(0, 0, 0)
                    content.add(root)

                    print("[Vehicle3DStage] ✅ Cargado \(asset.assetName)")
                    entityLoaded = true
                } catch {
                    print("[Vehicle3DStage] ❌ Error cargando \(asset.assetName): \(error.localizedDescription)")
                    loadError = true
                }
            } update: { content in
                if let root = content.entities.first(where: { $0.name == "vehicleRoot" }) {
                    root.transform.rotation = simd_quatf(angle: yaw + dragYaw, axis: SIMD3<Float>(0, 1, 0))
                }
            }
            .id(asset.id)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if autoRotate {
                            autoRotate = false
                            stopAutoRotate()
                        }
                        dragYaw = Float(value.translation.width) * 0.008
                    }
                    .onEnded { _ in
                        yaw += dragYaw
                        dragYaw = 0
                    }
            )
            .opacity(entityLoaded ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: entityLoaded)
            .scaleEffect(animateIn ? 1.0 : 0.92)
            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: animateIn)

            if !entityLoaded && !loadError {
                loadingView
            }
            if loadError {
                errorView
            }

            if showsChrome { overlayChrome }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.textTint.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .task(id: asset) {
            stopAutoRotate()
            entityLoaded = false
            loadError = false
            animateIn = false
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation { animateIn = true }
            if autoRotate { startAutoRotate() }
        }
        .onAppear { if autoRotate { startAutoRotate() } }
        .onDisappear { stopAutoRotate() }
    }

    // MARK: - Background

    private var stageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#1A2438"),
                    Color(hex: "#0A0F1A")
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Glow radial detrás del auto
            RadialGradient(
                colors: [
                    Color(hex: "#3B82F6").opacity(0.3),
                    Color(hex: "#3B82F6").opacity(0.05),
                    .clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 220
            )
            .blendMode(.screen)

            // Grid floor sutil
            GridFloor()
                .opacity(0.22)
        }
    }

    // MARK: - Overlay Chrome

    private var overlayChrome: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green, radius: 4)
                        Text("3D MODEL")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.2)
                            .foregroundColor(.green)
                    }
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textTint.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        autoRotate.toggle()
                    }
                    if autoRotate {
                        startAutoRotate()
                    } else {
                        stopAutoRotate()
                    }
                } label: {
                    Image(systemName: autoRotate ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .overlay(Circle().stroke(theme.textTint.opacity(0.15), lineWidth: 1))
                }
            }
            .padding(14)

            Spacer()

            HStack {
                gestureHint
                Spacer()
                assetChip
            }
            .padding(14)
        }
    }

    private var gestureHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 9, weight: .heavy))
            Text("Arrastra para rotar")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.4)
        }
        .foregroundColor(theme.textTint.opacity(0.7))
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.4)))
        .overlay(Capsule().stroke(theme.textTint.opacity(0.1), lineWidth: 1))
    }

    private var assetChip: some View {
        HStack(spacing: 5) {
            Image(systemName: asset.systemIcon)
                .font(.system(size: 9, weight: .heavy))
            Text(asset.displayName.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundColor(theme.textTint)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color(hex: "#3B82F6").opacity(0.8), Color(hex: "#1E40AF").opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        )
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().tint(theme.textTint)
            Text("Cargando modelo 3D…")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.7))
        }
    }

    private var errorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(theme.textTint.opacity(0.4))
            Text("Modelo no disponible")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.65))
            Text(asset.assetName + "." + asset.fileExtension)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textTint.opacity(0.4))
        }
    }

    // MARK: - Auto Rotate

    private func startAutoRotate() {
        autoRotateTask?.cancel()
        autoRotateTask = Task { @MainActor [autoRotateTask] in
            while autoRotate && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000) // ~30 fps
                if Task.isCancelled || !autoRotate { break }
                yaw += 0.004
            }
            _ = autoRotateTask  // keep reference silenced
        }
    }

    private func stopAutoRotate() {
        autoRotateTask?.cancel()
        autoRotateTask = nil
    }
}

// MARK: - Grid Floor (perspective lines)

private struct GridFloor: View {
    @Environment(\.weatherTheme) private var theme
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizonY = h * 0.6

            ZStack {
                // Horizontal lines (distance)
                ForEach(0..<6) { i in
                    let t = CGFloat(i) / 5.0
                    let y = horizonY + (h - horizonY) * t * t
                    Rectangle()
                        .fill(theme.textTint.opacity(0.08 + Double(i) * 0.02))
                        .frame(height: 1)
                        .offset(y: y - h / 2)
                }

                // Vertical perspective lines
                ForEach(-5...5, id: \.self) { i in
                    let startX = w / 2 + CGFloat(i) * (w / 2.5)
                    Path { path in
                        path.move(to: CGPoint(x: w / 2, y: horizonY))
                        path.addLine(to: CGPoint(x: startX, y: h))
                    }
                    .stroke(theme.textTint.opacity(0.08), lineWidth: 0.8)
                }
            }
        }
    }
}

// MARK: - Vehicle Specs Card (glass row)

struct VehicleSpecsCard: View {
    let profile: VehicleProfile
    @Environment(\.weatherTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FICHA TÉCNICA")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Spacer()
                Text(profile.fuelType.displayName.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(fuelColor(profile.fuelType))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(fuelColor(profile.fuelType).opacity(0.18)))
            }

            // Placa + color row
            if profile.formattedLicensePlate != nil || profile.color != nil {
                HStack(spacing: 8) {
                    if let plate = profile.formattedLicensePlate {
                        licensePlateBadge(plate)
                    }
                    if let c = profile.color, !c.isEmpty {
                        colorBadge(c)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                specTile(
                    icon: "gauge.with.dots.needle.67percent",
                    value: String(format: "%.1f", profile.conueeKmPerL),
                    unit: "km/L",
                    label: "Rendimiento",
                    color: Color(hex: "#34D399")
                )
                specTile(
                    icon: "engine.combustion.fill",
                    value: "\(profile.engineCc)",
                    unit: "cc",
                    label: "Motor",
                    color: Color(hex: "#FBBF24")
                )
                specTile(
                    icon: "scalemass.fill",
                    value: "\(profile.weightKg)",
                    unit: "kg",
                    label: "Peso",
                    color: Color(hex: "#60A5FA")
                )
            }

            // Segunda fila de specs (autonomía + odómetro)
            if profile.fuelTankCapacityL != nil || profile.odometerKm != nil {
                HStack(spacing: 10) {
                    if let cap = profile.fuelTankCapacityL {
                        specTile(
                            icon: "fuelpump.fill",
                            value: String(format: "%.0f", cap),
                            unit: "L",
                            label: "Tanque",
                            color: Color(hex: "#A78BFA")
                        )
                    }
                    if let range = profile.rangePerTankKm {
                        specTile(
                            icon: "arrow.triangle.swap",
                            value: String(format: "%.0f", range),
                            unit: "km",
                            label: "Autonomía",
                            color: Color(hex: "#F472B6")
                        )
                    }
                    if let odo = profile.odometerKm {
                        specTile(
                            icon: "speedometer",
                            value: formatOdo(odo),
                            unit: "km",
                            label: "Odómetro",
                            color: Color(hex: "#FB923C")
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                inlineInfo(icon: "calendar", text: "\(profile.year)")
                dividerDot
                inlineInfo(icon: "gearshift.layout.sixspeed", text: profile.transmission.capitalized)
                dividerDot
                inlineInfo(icon: "figure.wave.circle.fill", text: profile.drivingStyleLabel)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    private func specTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.55))
            }
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(theme.textTint.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textTint.opacity(0.04))
        )
    }

    private func inlineInfo(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(theme.textTint.opacity(0.55))
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.85))
        }
    }

    private var dividerDot: some View {
        Circle().fill(theme.textTint.opacity(0.25)).frame(width: 3, height: 3)
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

    private func licensePlateBadge(_ plate: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color(hex: "#1E3A8A"))
                .frame(width: 6, height: 22)
            VStack(spacing: 0) {
                Text("MEX")
                    .font(.system(size: 6, weight: .heavy))
                    .foregroundColor(.black)
                    .tracking(0.5)
                Text(plate)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(1.2)
            }
            .padding(.trailing, 6)
        }
        .padding(.leading, 0)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(theme.textTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }

    private func colorBadge(_ colorName: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(parseColor(colorName))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(theme.textTint.opacity(0.3), lineWidth: 1))
            Text(colorName)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.85))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(theme.textTint.opacity(0.06)))
        .overlay(Capsule().stroke(theme.textTint.opacity(0.1), lineWidth: 1))
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

    private func formatOdo(_ km: Int) -> String {
        if km >= 1000 { return String(format: "%.0fk", Double(km) / 1000) }
        return "\(km)"
    }
}

// MARK: - Asset Switcher (opcional, carousel de modelos)

struct Vehicle3DAssetSwitcher: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var selected: Vehicle3DAsset

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Vehicle3DAsset.allCases) { asset in
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selected = asset
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: asset.systemIcon)
                            .font(.system(size: 11, weight: .heavy))
                        Text(asset.displayName)
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundColor(selected == asset ? .black : theme.textTint.opacity(0.75))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        Capsule().fill(selected == asset ? Color.white : theme.textTint.opacity(0.08))
                    )
                    .overlay(
                        Capsule().stroke(
                            selected == asset ? .clear : theme.textTint.opacity(0.12),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Stage") {
    ZStack {
        Color(hex: "#0A0F1A").ignoresSafeArea()
        VStack(spacing: 16) {
            Vehicle3DStage(
                asset: .sedan,
                title: "Chevrolet Aveo 2018",
                subtitle: "14.2 km/L · Magna"
            )
            VehicleSpecsCard(profile: .sample)
        }
        .padding()
    }
    .environment(\.weatherTheme, WeatherTheme(condition: .overcast))
}
#endif
