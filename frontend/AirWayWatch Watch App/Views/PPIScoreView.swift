//
//  PPIScoreView.swift
//  AirWayWatch Watch App
//
//  Main PPI Score gauge visualization.
//  Shows a circular arc gauge colored green→yellow→orange→red
//  with the score number (0-100) prominently in the center.
//

import SwiftUI

struct PPIScoreView: View {
    let score: Int
    let zone: PPIZone
    let isCalibrating: Bool
    let scoringPaused: Bool
    let pauseReason: String?
    let availableMetrics: Int

    // Animation
    @State private var animatedScore: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private var normalizedScore: Double {
        Double(score) / 100.0
    }

    private var zoneColor: Color {
        switch zone {
        case .green: return Color(hex: "#4CD964")
        case .yellow: return Color(hex: "#FFD60A")
        case .orange: return Color(hex: "#FF9F0A")
        case .red: return Color(hex: "#FF3B30")
        }
    }

    private let gaugeGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(hex: "#4CD964"),
            Color(hex: "#4CD964"),
            Color(hex: "#FFD60A"),
            Color(hex: "#FF9F0A"),
            Color(hex: "#FF3B30"),
            Color(hex: "#FF3B30"),
        ]),
        center: .center,
        startAngle: .degrees(-225),
        endAngle: .degrees(45)
    )

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 120, height: 120)

                // Colored arc
                Circle()
                    .trim(from: 0, to: min(animatedScore * 0.75, 0.75))
                    .stroke(
                        gaugeGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .frame(width: 120, height: 120)

                // Center content
                VStack(spacing: 2) {
                    if isCalibrating {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                        Text("Calibrating")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else if scoringPaused {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("Paused")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("\(score)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(zoneColor)
                            .scaleEffect(pulseScale)

                        Text("PPI")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                }
            }

            // Zone badge
            if !isCalibrating && !scoringPaused {
                Text(zone.labelES)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(zoneColor.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(zoneColor.opacity(0.6), lineWidth: 1)
                            )
                    )
            }

            // Metrics indicator
            if !isCalibrating {
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < availableMetrics ? Color.white.opacity(0.6) : Color.white.opacity(0.15))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.top, 2)
            }
        }
        .onChange(of: score) { newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedScore = Double(newValue) / 100.0
            }
            // Pulse effect on zone change
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedScore = Double(score) / 100.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "#0A1D4D"), Color(hex: "#4AA1B3")],
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()

        PPIScoreView(
            score: 37,
            zone: .yellow,
            isCalibrating: false,
            scoringPaused: false,
            pauseReason: nil,
            availableMetrics: 3
        )
    }
}
