//
//  NavigationPanel.swift
//  AcessNet
//
//  Panel principal de navegación que integra todos los componentes
//

import SwiftUI
import CoreLocation

// MARK: - Navigation Panel

struct NavigationPanel: View {
    let navigationState: NavigationState
    let currentZone: AirQualityZone?
    let distanceToManeuver: Double
    let onEndNavigation: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Top: Instrucción actual
            NavigationInstructionBar(
                step: navigationState.currentStep,
                distanceToManeuver: distanceToManeuver
            )

            // Middle: Zona de calidad del aire actual
            if let zone = currentZone {
                CurrentZoneCard(zone: zone)
            } else {
                EmptyZoneCard()
            }

            // Predicted AQI at arrival
            if let avgAQI = navigationState.selectedRoute?.averageAQI, avgAQI > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color(hex: "#22D3EE"))
                    Text("AQI al llegar:")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(Int(avgAQI))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(
                            avgAQI <= 50 ? Color(hex: "#34D399")
                            : avgAQI <= 100 ? Color(hex: "#FBBF24")
                            : Color(hex: "#F87171")
                        )
                        .monospacedDigit()

                    Spacer()

                    Text("ML")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(Color(hex: "#22D3EE"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#22D3EE").opacity(0.18)))
                        .overlay(Capsule().stroke(Color(hex: "#22D3EE").opacity(0.4), lineWidth: 0.8))
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.04))
                )
            }

            NavigationProgressBar(
                progress: navigationState.progress,
                distanceRemaining: navigationState.distanceRemaining,
                eta: navigationState.etaRemaining,
                averageAQI: navigationState.selectedRoute?.averageAQI
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.78))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 20, y: -6)
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Compact Navigation Panel (vista reducida)

struct CompactNavigationPanel: View {
    let navigationState: NavigationState
    let distanceToManeuver: Double
    let onExpand: () -> Void
    let onEndNavigation: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            VStack(spacing: 10) {
                CompactInstructionBar(
                    step: navigationState.currentStep,
                    distance: distanceToManeuver
                )
                CompactProgressBar(
                    progress: navigationState.progress,
                    distanceRemaining: navigationState.distanceRemaining,
                    eta: navigationState.etaRemaining
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: -4)
        .onTapGesture {
            HapticFeedback.light()
            onExpand()
        }
    }
}

// MARK: - Arrival Panel

struct ArrivalPanel: View {
    let destination: String
    let onDismiss: () -> Void

    @State private var confettiAnimation = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#10B981").opacity(0.25))
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)
                    .scaleEffect(confettiAnimation ? 1.2 : 1.0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#34D399"), Color(hex: "#10B981")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: "#10B981").opacity(0.55), radius: 18, y: 6)
                    .scaleEffect(confettiAnimation ? 1.08 : 1.0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(confettiAnimation ? 360 : 0))
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    confettiAnimation = true
                }
            }

            VStack(spacing: 4) {
                Text("¡Has llegado!")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)

                Text(destination)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button(action: {
                HapticFeedback.success()
                onDismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                    Text("Finalizar")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "#10B981").opacity(0.5), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#10B981").opacity(0.35), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "#10B981").opacity(0.4), radius: 22, y: 8)
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Off Route Alert

struct OffRouteAlert: View {
    let onRecalculate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FB923C"), Color(hex: "#EA580C")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
            }
            .shadow(color: Color(hex: "#FB923C").opacity(0.5), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fuera de ruta")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                Text("¿Quieres recalcular?")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button(action: {
                    HapticFeedback.light()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.1)))
                        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    HapticFeedback.medium()
                    onRecalculate()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .heavy))
                        Text("Recalcular")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hex: "#FB923C"), Color(hex: "#EA580C")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.78))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#FB923C").opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(hex: "#FB923C").opacity(0.35), radius: 12, y: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Navigation Panel") {
    VStack {
        Spacer()

        NavigationPanel(
            navigationState: NavigationState(
                isNavigating: true,
                selectedRoute: nil,
                currentStep: NavigationStep(
                    instruction: "Turn right on Main Street and continue for 2 blocks",
                    distance: 250,
                    maneuverType: .turnRight,
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ),
                nextStep: NavigationStep(
                    instruction: "Turn left on Market Street",
                    distance: 500,
                    maneuverType: .turnLeft,
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ),
                currentZone: AirQualityZone(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    radius: 500,
                    airQuality: AirQualityPoint(
                        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        aqi: 85,
                        pm25: 35.5,
                        pm10: 45.2,
                        timestamp: Date()
                    )
                ),
                progress: 0.45,
                distanceRemaining: 1800,
                etaRemaining: 360,
                distanceTraveled: 1500
            ),
            currentZone: AirQualityZone(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radius: 500,
                airQuality: AirQualityPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    aqi: 85,
                    pm25: 35.5,
                    pm10: 45.2,
                    timestamp: Date()
                )
            ),
            distanceToManeuver: 250,
            onEndNavigation: {}
        )
    }
    .ignoresSafeArea()
}

#Preview("Arrival Panel") {
    VStack {
        Spacer()

        ArrivalPanel(
            destination: "123 Main Street, San Francisco",
            onDismiss: {}
        )
    }
    .ignoresSafeArea()
}

#Preview("Off Route Alert") {
    VStack {
        OffRouteAlert(
            onRecalculate: {},
            onDismiss: {}
        )
        .padding()

        Spacer()
    }
}
