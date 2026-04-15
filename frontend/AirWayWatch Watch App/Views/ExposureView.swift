//
//  ExposureView.swift
//  AirWayWatch Watch App
//
//  Real-time cigarette equivalence exposure tracking.
//  Shows cumulative dose as cigarettes, hourly timeline,
//  activity breakdown, and WHO/EPA context.
//
//  Based on Berkeley Earth (Muller 2015): 22 µg/m³ PM2.5 over 24h = 1 cigarette.
//  Enhanced with activity-adjusted ventilation (unique to AirWay).
//

import SwiftUI

struct ExposureView: View {
    @ObservedObject var cigaretteEngine: CigaretteEquivalenceEngine

    private var cigarettes: Double { cigaretteEngine.cigarettesToday }
    private var hourlyDoses: [HourlyDose] { cigaretteEngine.hourlyDoses }
    private var breakdown: ActivityDoseBreakdown { cigaretteEngine.activityBreakdown }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Hero: Total Cigarettes
                heroSection

                // MARK: - Hourly Timeline
                hourlyTimelineSection

                // MARK: - Activity Breakdown
                activityBreakdownSection

                // MARK: - WHO Context
                whoContextSection

                // MARK: - Methodology
                methodologyNote
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#0A1D4D"), Color(hex: "#4AA1B3")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("TODAY'S EXPOSURE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            // Cigarette count — the hero number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", cigarettes))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(cigaretteColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("cigarettes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("equivalent")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Current rate
            if cigaretteEngine.currentRatePerHour > 0.01 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                    Text(String(format: "%.2f cigs/hour right now", cigaretteEngine.currentRatePerHour))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(cigaretteColor.opacity(0.8))
            }

            // Deposited dose in µg
            Text(String(format: "%.1f \u{00B5}g PM2.5 deposited", cigaretteEngine.cumulativeDoseUg))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cigaretteColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cigaretteColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Hourly Timeline

    private var hourlyTimelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOURLY")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            // Only show hours that have data or are recent
            let currentHour = Calendar.current.component(.hour, from: Date())
            let relevantHours = hourlyDoses.filter { $0.hour <= currentHour && $0.hour >= max(0, currentHour - 11) }

            if relevantHours.isEmpty {
                Text("No data yet")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            } else {
                let maxDose = relevantHours.map(\.doseUg).max() ?? 1.0

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(relevantHours) { dose in
                        VStack(spacing: 2) {
                            // Bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(for: dose.cigarettes))
                                .frame(
                                    width: barWidth(count: relevantHours.count),
                                    height: max(3, CGFloat(dose.doseUg / maxDose) * 40)
                                )

                            // Hour label (show every other)
                            if dose.hour % 2 == 0 {
                                Text(dose.hourLabel)
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                }

                // Peak hour indicator
                if let peak = cigaretteEngine.peakHour, peak < hourlyDoses.count {
                    let peakDose = hourlyDoses[peak]
                    Text("Peak: \(peakDose.hourLabel) (\(String(format: "%.2f", peakDose.cigarettes)) cigs)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Activity Breakdown

    private var activityBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BY ACTIVITY")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            if breakdown.totalDose > 0 {
                activityRow(
                    icon: "figure.stand",
                    label: "Rest",
                    dose: breakdown.restingDose,
                    color: .blue
                )
                activityRow(
                    icon: "figure.walk",
                    label: "Walking",
                    dose: breakdown.lightActivityDose,
                    color: .green
                )
                activityRow(
                    icon: "figure.run",
                    label: "Exercise",
                    dose: breakdown.exerciseDose,
                    color: .orange
                )

                if breakdown.exercisePercentage > 5 {
                    Text(String(format: "%.0f%% of your dose was during activity", breakdown.exercisePercentage))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.top, 2)
                }
            } else {
                Text("Start monitoring to see breakdown")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - WHO Context

    private var whoContextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTEXT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            // WHO guideline
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("WHO safe limit: 0.23 cigs/day")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            // EPA guideline
            HStack(spacing: 6) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 6, height: 6)
                Text("EPA limit: 1.59 cigs/day")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            // User's position
            HStack(spacing: 6) {
                Circle()
                    .fill(cigaretteColor)
                    .frame(width: 6, height: 6)
                Text(String(format: "You: %.1f cigs/day", cigarettes))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(cigaretteColor)
            }

            // Context bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    // WHO marker
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .offset(x: markerOffset(value: 0.23, maxVal: 6.0, width: geo.size.width))

                    // EPA marker
                    Circle()
                        .fill(.yellow)
                        .frame(width: 6, height: 6)
                        .offset(x: markerOffset(value: 1.59, maxVal: 6.0, width: geo.size.width))

                    // User marker
                    Circle()
                        .fill(cigaretteColor)
                        .frame(width: 8, height: 8)
                        .offset(x: markerOffset(value: cigarettes, maxVal: 6.0, width: geo.size.width))
                }
            }
            .frame(height: 10)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Methodology Note

    private var methodologyNote: some View {
        VStack(spacing: 4) {
            Text("Based on Berkeley Earth (2015)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
            Text("Adjusted for your activity level via Apple Watch")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.2))
            Text("For awareness only — not medical advice")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.15))
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var cigaretteColor: Color {
        switch cigarettes {
        case ..<1:   return Color(hex: "#4CD964")
        case 1..<3:  return Color(hex: "#FFD60A")
        case 3..<5:  return Color(hex: "#FF9F0A")
        default:     return Color(hex: "#FF3B30")
        }
    }

    private func barColor(for cigs: Double) -> Color {
        switch cigs {
        case ..<0.05: return Color.white.opacity(0.15)
        case ..<0.1:  return Color(hex: "#4CD964")
        case ..<0.3:  return Color(hex: "#FFD60A")
        case ..<0.5:  return Color(hex: "#FF9F0A")
        default:      return Color(hex: "#FF3B30")
        }
    }

    private func barWidth(count: Int) -> CGFloat {
        let available: CGFloat = 140 // approximate
        return max(4, available / CGFloat(count) - 2)
    }

    private func markerOffset(value: Double, maxVal: Double, width: CGFloat) -> CGFloat {
        let clamped = min(value, maxVal)
        return CGFloat(clamped / maxVal) * (width - 8)
    }

    private func activityRow(icon: String, label: String, dose: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(String(format: "%.2f cigs", breakdown.cigarettes(dose)))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
