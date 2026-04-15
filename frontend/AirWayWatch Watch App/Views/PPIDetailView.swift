//
//  PPIDetailView.swift
//  AirWayWatch Watch App
//
//  Detailed breakdown of PPI Score showing each biometric component,
//  current values vs baseline, and deviation scores.
//

import SwiftUI

struct PPIDetailView: View {
    let score: Int
    let zone: PPIZone
    let components: PPIComponents
    let heartRate: Double?
    let hrv: Double?
    let spO2: Double?
    let respiratoryRate: Double?
    let heartRateBaseline: Double?
    let hrvBaseline: Double?
    let spO2Baseline: Double?
    let respBaseline: Double?
    let activityState: ActivityState
    let isCalibrated: Bool
    let aqi: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with score
                VStack(spacing: 4) {
                    Text("PPI Score")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(zoneColor)

                    Text(zone.labelES)
                        .font(.caption2)
                        .foregroundColor(zoneColor)
                }
                .padding(.bottom, 4)

                // AQI context (if available)
                if let aqi = aqi {
                    HStack {
                        Image(systemName: "aqi.medium")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("AQI: \(aqi)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                    )
                }

                // Activity state indicator
                if activityState != .resting {
                    HStack(spacing: 4) {
                        Image(systemName: activityIcon)
                            .font(.caption2)
                        Text(activityLabel)
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.orange.opacity(0.15))
                    )
                }

                // Metric cards
                MetricRow(
                    icon: "lungs.fill",
                    label: "SpO2",
                    value: spO2.map { String(format: "%.1f%%", $0) } ?? "—",
                    baseline: spO2Baseline.map { String(format: "%.1f%%", $0) } ?? "—",
                    deviation: components.spO2Deviation.map { String(format: "%+.1f pp", -$0) },
                    score: components.spO2Score,
                    weight: "35%",
                    tintColor: metricColor(score: components.spO2Score)
                )

                MetricRow(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: hrv.map { String(format: "%.0f ms", $0) } ?? "—",
                    baseline: hrvBaseline.map { String(format: "%.0f ms", $0) } ?? "—",
                    deviation: components.hrvDeviation.map { String(format: "%+.1f%%", -$0) },
                    score: components.hrvScore,
                    weight: "30%",
                    tintColor: metricColor(score: components.hrvScore)
                )

                MetricRow(
                    icon: "heart.fill",
                    label: "HR",
                    value: heartRate.map { String(format: "%.0f bpm", $0) } ?? "—",
                    baseline: heartRateBaseline.map { String(format: "%.0f bpm", $0) } ?? "—",
                    deviation: components.hrDeviation.map { String(format: "%+.0f bpm", $0) },
                    score: components.hrScore,
                    weight: "20%",
                    tintColor: metricColor(score: components.hrScore)
                )

                MetricRow(
                    icon: "wind",
                    label: "Resp",
                    value: respiratoryRate.map { String(format: "%.0f brpm", $0) } ?? "—",
                    baseline: respBaseline.map { String(format: "%.0f brpm", $0) } ?? "—",
                    deviation: components.respDeviation.map { String(format: "%+.1f%%", $0) },
                    score: components.respScore,
                    weight: "15%",
                    tintColor: metricColor(score: components.respScore)
                )

                // Calibration notice
                if !isCalibrated {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                        Text("Baseline calibrating — wear Watch for accurate results")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
                }

                // Disclaimer
                Text("Wellness info only — not medical advice")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#0A1D4D"), Color(hex: "#4AA1B3")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private var zoneColor: Color {
        switch zone {
        case .green: return Color(hex: "#4CD964")
        case .yellow: return Color(hex: "#FFD60A")
        case .orange: return Color(hex: "#FF9F0A")
        case .red: return Color(hex: "#FF3B30")
        }
    }

    private var activityIcon: String {
        switch activityState {
        case .resting: return "bed.double.fill"
        case .lightActivity: return "figure.walk"
        case .exercise: return "figure.run"
        case .postExercise: return "timer"
        }
    }

    private var activityLabel: String {
        switch activityState {
        case .resting: return "Resting"
        case .lightActivity: return "Light activity"
        case .exercise: return "Exercise — scoring paused"
        case .postExercise: return "Post-exercise cooldown"
        }
    }

    private func metricColor(score: Double?) -> Color {
        guard let s = score else { return .white.opacity(0.3) }
        switch s {
        case 0..<25: return Color(hex: "#4CD964")
        case 25..<50: return Color(hex: "#FFD60A")
        case 50..<75: return Color(hex: "#FF9F0A")
        default: return Color(hex: "#FF3B30")
        }
    }
}

// MARK: - Metric Row Component

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let baseline: String
    let deviation: String?
    let score: Double?
    let weight: String
    let tintColor: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(tintColor)
                    .frame(width: 16)

                Text(label)
                    .font(.caption2.bold())
                    .foregroundColor(.white)

                Spacer()

                if let score = score {
                    Text(String(format: "%.0f", score))
                        .font(.caption2.bold())
                        .foregroundColor(tintColor)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            HStack {
                Text(value)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                if let dev = deviation {
                    Text(dev)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(tintColor)
                }
            }

            // Mini progress bar
            if let score = score {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(tintColor)
                            .frame(width: max(0, geo.size.width * CGFloat(score / 100.0)), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}
