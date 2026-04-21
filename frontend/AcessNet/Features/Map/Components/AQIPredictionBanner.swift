//
//  AQIPredictionBanner.swift
//  AcessNet
//
//  Banner compacto de predicción ML sobre el mapa.
//  Muestra AQI actual → predicho + mejor hora para salir.
//

import SwiftUI

struct AQIPredictionBanner: View {
    @Environment(\.weatherTheme) private var theme
    @State private var prediction: MLPredictionResponse?
    @State private var bestTime: BestTimeResponse?
    @State private var isLoading = true
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if isLoading && !hasLoaded {
                loadingBanner
            } else if let pred = prediction, pred.model_available == true {
                predictionContent(pred)
            }
        }
        .task {
            guard !hasLoaded else { return }
            await loadData()
        }
    }

    // MARK: - Loading

    private var loadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView().tint(theme.textTint).scaleEffect(0.6)
            Text("Cargando predicción…")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.6))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(theme.textTint.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
    }

    // MARK: - Prediction Content

    private func predictionContent(_ pred: MLPredictionResponse) -> some View {
        HStack(spacing: 10) {
            // Current AQI
            if let current = pred.current_aqi {
                HStack(spacing: 4) {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(colorForAQI(current))
                    Text("\(current)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.textTint)
                        .monospacedDigit()
                }
            }

            // Arrow trend chip
            if let trend = pred.trend {
                HStack(spacing: 3) {
                    Image(systemName: trendIcon(trend))
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundColor(trendColor(trend))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(Capsule().fill(trendColor(trend).opacity(0.18)))
            }

            // Predicted 6h
            if let pred6h = pred.predictions?["6h"] {
                HStack(spacing: 3) {
                    Text("\(pred6h.aqi)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("en 6h")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.5)
                        .foregroundColor(theme.textTint.opacity(0.55))
                }
                .foregroundColor(colorForAQI(pred6h.aqi))
            }

            // Separator
            if bestTime?.best_window != nil {
                Rectangle()
                    .fill(theme.textTint.opacity(0.15))
                    .frame(width: 1, height: 14)
            }

            // Best time
            if let best = bestTime?.best_window {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(hex: "#FBBF24"))
                    Text("Óptimo: \(extractHour(best.start))")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(theme.textTint)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.65))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(theme.textTint.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let lat = 19.4326
        let lon = -99.1332
        let base = "https://airway-api.onrender.com/api/v1"

        // Prediction
        do {
            guard let url = URL(string: "\(base)/air/prediction?lat=\(lat)&lon=\(lon)&mode=walk") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PredictionEndpointResponse.self, from: data)
            await MainActor.run {
                prediction = response.prediction
            }
        } catch {
            print("Banner prediction error: \(error)")
        }

        // Best time
        do {
            guard let url = URL(string: "\(base)/air/best-time?lat=\(lat)&lon=\(lon)&mode=bike&hours=12") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(BestTimeResponse.self, from: data)
            await MainActor.run { bestTime = response }
        } catch {
            print("Banner best-time error: \(error)")
        }

        await MainActor.run {
            isLoading = false
            hasLoaded = true
        }
    }

    // MARK: - Helpers

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "subiendo": return "arrow.up.right"
        case "bajando": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "subiendo": return Color(hex: "#FB923C")
        case "bajando":  return Color(hex: "#34D399")
        default:         return Color(hex: "#94A3B8")
        }
    }

    private func colorForAQI(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<51:   return Color(hex: "#34D399")
        case 51..<101: return Color(hex: "#FBBF24")
        case 101..<151: return Color(hex: "#FB923C")
        default:        return Color(hex: "#F87171")
        }
    }

    private func extractHour(_ time: String) -> String {
        if let tIndex = time.firstIndex(of: "T") {
            return String(time[time.index(after: tIndex)...].prefix(5))
        }
        return time
    }
}

// Response from /air/prediction endpoint (wraps MLPredictionResponse)
struct PredictionEndpointResponse: Codable {
    let prediction: MLPredictionResponse?
    let current: PredictionCurrentData?

    enum CodingKeys: String, CodingKey {
        case prediction, current
    }
}

struct PredictionCurrentData: Codable {
    let aqi: Int?
    let category: String?
    let pm25: Double?
}
