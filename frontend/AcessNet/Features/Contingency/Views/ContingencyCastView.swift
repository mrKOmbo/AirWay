//
//  ContingencyCastView.swift
//  AcessNet
//
//  Pantalla principal de ContingencyCast — pronóstico probabilístico
//  de contingencias ambientales en CDMX con 48-72h de anticipación.
//

import SwiftUI

struct ContingencyCastView: View {
    @Environment(\.weatherTheme) private var theme

    // MARK: - Environment

    @ObservedObject private var appSettings = AppSettings.shared

    // MARK: - State

    @State private var response: ContingencyForecastResponse?
    @State private var selectedHorizon: Int = 24
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var naturalExplanation: String = ""
    @State private var isGeneratingExplanation = false

    @State private var headerAppear: Bool = false

    @AppStorage("user_hologram") private var userHologram: String = ""

    private var activeWeather: WeatherCondition {
        appSettings.weatherOverride ?? .overcast
    }

    // MARK: - Derived

    private var selectedForecast: HorizonForecast? {
        response?.forecasts.first(where: { $0.horizonH == selectedHorizon })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(spacing: 20) {
                    header
                        .opacity(headerAppear ? 1 : 0)
                        .offset(y: headerAppear ? 0 : -10)
                        .animation(.easeOut(duration: 0.45), value: headerAppear)

                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let selected = selectedForecast {
                        ProbabilityGauge(
                            probability: selected.probFase1O3,
                            ci80Lower: selected.o3Ci80Ppb.first,
                            ci80Upper: selected.o3Ci80Ppb.last,
                            o3ExpectedPpb: selected.o3ExpectedPpb,
                            horizonHours: selected.horizonH
                        )
                        .frame(height: 260)
                        .padding(.horizontal)

                        horizonSelector

                        if !naturalExplanation.isEmpty {
                            explanationCard
                        } else if isGeneratingExplanation {
                            explanationLoading
                        }

                        if !selected.recommendations.isEmpty {
                            RecommendationsPanel(
                                recommendations: selected.recommendations,
                                probabilityLevel: selected.probabilityLevel
                            )
                            .padding(.horizontal)
                        }

                        if !selected.topDrivers.isEmpty {
                            DriversPanel(drivers: selected.topDrivers)
                                .padding(.horizontal)
                        }

                        disclaimerView
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("ContingencyCast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadForecast()
        }
        .refreshable {
            await loadForecast()
        }
        .onAppear { headerAppear = true }
    }

    // MARK: - Background

    private var backgroundView: some View {
        WeatherBackground(condition: activeWeather)
            .ignoresSafeArea()
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.4), Color.red.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "wind.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textTint)
                }
                Text("CONTINGENCY CAST")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.6))
                    .tracking(2.2)
            }

            Text("Probabilidad de Contingencia")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text("ZMVM")
                    .font(.system(size: 10, weight: .semibold))
                Text("·")
                    .font(.system(size: 10))
                Text("Fase 1 Ozono")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(theme.textTint.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(theme.textTint.opacity(0.06)))
        }
    }

    private var horizonSelector: some View {
        HStack(spacing: 10) {
            ForEach(response?.forecasts ?? []) { forecast in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedHorizon = forecast.horizonH
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    HorizonCard(forecast: forecast, isSelected: selectedHorizon == forecast.horizonH)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.textTint.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textTint.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Explicación")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(theme.textTint)
                    Text("Análisis del pronóstico")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.0)
                }
            }

            Text(naturalExplanation)
                .font(.system(size: 13))
                .foregroundColor(theme.textTint.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.textTint.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.textTint.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        ))
    }

    private var explanationLoading: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7).tint(.white.opacity(0.7))
            Text("Generando explicación…")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(theme.textTint.opacity(0.06)))
    }

    private var disclaimerView: some View {
        Text(response?.disclaimer ?? "")
            .font(.system(size: 10))
            .foregroundColor(theme.textTint.opacity(0.35))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.top, 6)
            .padding(.bottom, 16)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(theme.textTint)
            Text("Calculando pronóstico…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.6))
        }
        .padding(.vertical, 60)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.orange)
            }
            .shadow(color: .orange.opacity(0.4), radius: 14)

            Text("No pudimos obtener el pronóstico")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textTint)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(theme.textTint.opacity(0.55))
                .multilineTextAlignment(.center)

            Button {
                Task { await loadForecast() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Reintentar")
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(theme.textTint)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .shadow(color: .orange.opacity(0.5), radius: 8)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    @MainActor
    private func loadForecast() async {
        isLoading = true
        errorMessage = nil
        naturalExplanation = ""
        defer { isLoading = false }

        do {
            let hologram = userHologram.isEmpty ? nil : userHologram
            let resp = try await ContingencyService.shared.fetchForecast(hologram: hologram)
            self.response = resp

            // Seleccionar h+24 por defecto si existe
            if let first = resp.forecasts.first {
                self.selectedHorizon = first.horizonH
            }

            // Pedir a Foundation Models que expanda el hint en explicación natural
            Task {
                await generateExplanation(for: resp)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func generateExplanation(for resp: ContingencyForecastResponse) async {
        guard let selected = resp.forecasts.first(where: { $0.horizonH == selectedHorizon }) else {
            return
        }
        isGeneratingExplanation = true
        defer { isGeneratingExplanation = false }

        let text = await ContingencyExplanationService.shared.explain(
            forecast: selected,
            hint: resp.explanationHint
        )
        self.naturalExplanation = text
    }
}

#Preview {
    NavigationStack {
        ContingencyCastView()
    }
}
