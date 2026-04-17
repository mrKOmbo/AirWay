//
//  NavigationInstructionBar.swift
//  AcessNet
//
//  Barra superior que muestra la próxima instrucción de navegación
//

import SwiftUI
import CoreLocation

// MARK: - Navigation Instruction Bar

struct NavigationInstructionBar: View {
    let step: NavigationStep?
    let distanceToManeuver: Double

    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // Icono de maniobra
            ZStack {
                if isUrgent {
                    Circle()
                        .fill(iconColor.opacity(0.4))
                        .frame(width: 72, height: 72)
                        .blur(radius: 10)
                        .scaleEffect(pulse ? 1.25 : 1.0)
                        .opacity(pulse ? 0.2 : 0.65)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: iconColor.opacity(0.6), radius: isUrgent ? 14 : 8, y: 4)
                    .scaleEffect(pulse && isUrgent ? 1.05 : 1.0)

                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1.2)
                    .frame(width: 58, height: 58)

                Image(systemName: step?.maneuverType.icon ?? "arrow.up")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
            }

            // Información
            VStack(alignment: .leading, spacing: 3) {
                Text(distanceText.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.0)
                    .foregroundColor(isUrgent ? iconColor : .white.opacity(0.6))

                Text(step?.shortInstruction ?? "Continúa en ruta")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isUrgent {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Color(hex: "#FBBF24"))
                    .opacity(pulse ? 1.0 : 0.5)
                    .shadow(color: Color(hex: "#FBBF24").opacity(0.6), radius: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isUrgent
                            ? [iconColor.opacity(0.55), iconColor.opacity(0.2)]
                            : [.white.opacity(0.12), .white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: isUrgent ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 5)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            if isUrgent { pulse = true }
        }
        .onChange(of: isUrgent) { _, newValue in
            pulse = newValue
        }
    }

    // MARK: - Computed Properties

    /// Indica si la maniobra es urgente (< 100m)
    private var isUrgent: Bool {
        return distanceToManeuver < 100
    }

    /// Texto de distancia formateado
    private var distanceText: String {
        if distanceToManeuver < 50 {
            return "Ahora"
        } else if distanceToManeuver < 1000 {
            return "En \(Int(distanceToManeuver)) m"
        } else {
            return "En \(String(format: "%.1f", distanceToManeuver / 1000)) km"
        }
    }

    /// Color del icono según tipo de maniobra
    private var iconColor: Color {
        guard let step = step else { return Color(hex: "#2196F3") }
        return Color(hex: step.maneuverType.color)
    }

    /// Colores del gradiente del icono
    private var iconGradientColors: [Color] {
        let base = iconColor
        return [base, base.opacity(0.8)]
    }
}

// MARK: - Compact Instruction Bar (vista reducida)

struct CompactInstructionBar: View {
    let step: NavigationStep?
    let distance: Double

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: step?.maneuverType.icon ?? "arrow.up")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
            }
            .shadow(color: iconColor.opacity(0.5), radius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(distanceText.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.55))

                Text(step?.shortInstruction ?? "Continúa")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }

    private var iconColor: Color {
        guard let step = step else { return Color(hex: "#2196F3") }
        return Color(hex: step.maneuverType.color)
    }

    private var distanceText: String {
        if distance < 50 {
            return "Now"
        } else if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Preview

#Preview("Navigation Instruction Bar") {
    VStack(spacing: 20) {
        Text("Navigation Instructions")
            .font(.title2.bold())
            .padding()

        // Turn Right - Normal
        NavigationInstructionBar(
            step: NavigationStep(
                instruction: "Turn right on Main Street",
                distance: 350,
                maneuverType: .turnRight,
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            distanceToManeuver: 350
        )

        // Turn Left - Urgent
        NavigationInstructionBar(
            step: NavigationStep(
                instruction: "Turn left on Market Street and continue for 2 blocks",
                distance: 50,
                maneuverType: .turnLeft,
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            distanceToManeuver: 50
        )

        // Arrive - Close
        NavigationInstructionBar(
            step: NavigationStep(
                instruction: "Arrive at your destination on the right",
                distance: 25,
                maneuverType: .arrive,
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            distanceToManeuver: 25
        )

        // Sharp Right - Far
        NavigationInstructionBar(
            step: NavigationStep(
                instruction: "Take sharp right onto Highway 101",
                distance: 1500,
                maneuverType: .sharpRight,
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            distanceToManeuver: 1500
        )

        Divider()

        // Compact versions
        VStack(spacing: 12) {
            CompactInstructionBar(
                step: NavigationStep(
                    instruction: "Turn right on Main St",
                    distance: 200,
                    maneuverType: .turnRight,
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ),
                distance: 200
            )

            CompactInstructionBar(
                step: NavigationStep(
                    instruction: "Arrive at destination",
                    distance: 50,
                    maneuverType: .arrive,
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ),
                distance: 50
            )
        }

        Spacer()
    }
    .padding()
}
