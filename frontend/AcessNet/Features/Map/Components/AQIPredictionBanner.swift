//
//  AQIPredictionBanner.swift
//  AcessNet
//
//  Banner compacto de predicción ML sobre el mapa.
//  Rediseño: tarjeta en 2 filas con jerarquía visual clara y mejor contraste
//  sobre fondos claros (temas sunny) y oscuros.
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
                predictionCard(pred)
            }
        }
        .task {
            guard !hasLoaded else { return }
            await loadData()
        }
    }

    // MARK: - Loading

    private var loadingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white).scaleEffect(0.7)
            Text("Cargando predicción…")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(cardBackground)
    }

    // MARK: - Prediction Card (rediseñada)

    private func predictionCard(_ pred: MLPredictionResponse) -> some View {
        VStack(spacing: 0) {
            // Header: nombre amigable (sin jerga técnica) + indicador de estado.
            HStack(spacing: 7) {
                Image(systemName: "wind")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))
                Text("Calidad del aire")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.92))
                Spacer()
                Circle()
                    .fill(Color(hex: "#34D399"))
                    .frame(width: 6, height: 6)
                Text("EN VIVO")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 6)

            // Fila principal: AQI actual → AQI 6h
            HStack(spacing: 8) {
                if let current = pred.current_aqi {
                    aqiPill(value: current, label: "AHORA", primary: true)
                }

                if let trend = pred.trend {
                    VStack(spacing: 2) {
                        Image(systemName: trendIcon(trend))
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(trendColor(trend))
                        Text(trendLabel(trend))
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(trendColor(trend).opacity(0.9))
                    }
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white.opacity(0.4))
                }

                if let pred6h = pred.predictions?["6h"] {
                    aqiPill(value: pred6h.aqi, label: "EN 6H", primary: false)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, bestTime?.best_window != nil ? 7 : 9)

            // Best time (opcional, fila inferior)
            if let best = bestTime?.best_window {
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color(hex: "#FBBF24"))
                    Text("Mejor salida:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text(extractHour(best.start))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#FBBF24"))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 9)
                .background(
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .padding(.top, 1)
                )
            }
        }
        .background(cardBackground)
    }

    // MARK: - AQI pill component

    private func aqiPill(value: Int, label: String, primary: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Circle()
                    .fill(colorForAQI(value))
                    .frame(width: 8, height: 8)
                Text("\(value)")
                    .font(.system(size: primary ? 22 : 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            Text(aqiCategory(value))
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(colorForAQI(value))
        }
        .frame(minWidth: 60)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorForAQI(value).opacity(primary ? 0.22 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(colorForAQI(value).opacity(primary ? 0.5 : 0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Background (consistent)

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.black.opacity(0.72))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 5)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let lat = 19.4326
        let lon = -99.1332
        let base = "https://airway-api.onrender.com/api/v1"

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
        case "bajando":  return "arrow.down.right"
        default:         return "arrow.right"
        }
    }

    private func trendLabel(_ trend: String) -> String {
        switch trend {
        case "subiendo": return "SUBE"
        case "bajando":  return "BAJA"
        default:         return "ESTABLE"
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
        case 0..<51:    return Color(hex: "#34D399")
        case 51..<101:  return Color(hex: "#FBBF24")
        case 101..<151: return Color(hex: "#FB923C")
        default:        return Color(hex: "#F87171")
        }
    }

    private func aqiCategory(_ aqi: Int) -> String {
        switch aqi {
        case 0..<51:    return "BUENO"
        case 51..<101:  return "MODER."
        case 101..<151: return "DAÑINO"
        default:        return "PELIG."
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
