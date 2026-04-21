//
//  PPIDisclaimerView.swift
//  AcessNet
//
//  Legal disclaimer view shown on first PPI activation.
//  Compliant with FDA General Wellness Policy (January 2026)
//  and EU MDR guidance for wellness software.
//
//  Key principle: frame as "wellness insight", never as medical diagnosis.
//  The regulation depends on HOW you market it, not WHAT it measures.
//

import SwiftUI

struct PPIDisclaimerView: View {
    @Environment(\.weatherTheme) private var theme
    let onAccept: () -> Void
    @State private var hasScrolledToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "#4AA1B3"))

                Text("Personal Pollution Impact")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textTint)

                Text("PPI Score")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#4AA1B3"))
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // What it does
                    disclaimerSection(
                        title: "What PPI Does",
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        items: [
                            "Measures how your biometrics (heart rate, HRV, SpO2, respiratory rate) deviate from your personal baseline",
                            "Correlates deviations with current air quality conditions",
                            "Provides a wellness score (0-100) to help you make informed decisions about outdoor activities",
                            "Adapts to your personal health profile for more relevant insights",
                        ]
                    )

                    // What it does NOT do
                    disclaimerSection(
                        title: "What PPI Does NOT Do",
                        icon: "xmark.circle.fill",
                        iconColor: .red,
                        items: [
                            "Does NOT diagnose, treat, cure, or prevent any disease",
                            "Does NOT provide medical advice or replace professional healthcare",
                            "Does NOT detect medical emergencies or life-threatening conditions",
                            "Is NOT a substitute for pulse oximeters, ECGs, or clinical monitoring",
                        ]
                    )

                    // Important notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }

                        Text("If you experience difficulty breathing, chest pain, persistent cough, dizziness, or any concerning symptoms, stop using this feature and seek medical attention immediately. Do not rely on PPI Score to assess medical emergencies.")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTint.opacity(0.7))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                    )

                    // Data privacy
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Color(hex: "#4AA1B3"))
                            Text("Your Data")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.textTint)
                        }

                        Text("All biometric data is processed locally on your Apple Watch. Health data is never sent to our servers. Your vulnerability profile is stored only on your device and synced via encrypted Watch Connectivity.")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTint.opacity(0.7))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#4AA1B3").opacity(0.08))
                    )

                    // Scientific basis
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.purple)
                            Text("Scientific Basis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.textTint)
                        }

                        Text("PPI weights and dose-response coefficients are derived from peer-reviewed epidemiological studies including the VA Normative Aging Study (Gold et al., PMC1253756), Steubenville Cohort (PMC3987810), and meta-analyses of 33+ panel studies on PM2.5 and cardiovascular effects.")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTint.opacity(0.5))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.06))
                    )

                    // Regulatory statement
                    Text("This product is classified as a general wellness product under FDA guidance (January 2026) and is not intended to be a medical device. EU MDR: This software does not support diagnostic or therapeutic decisions and is excluded from MDR scope.")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTint.opacity(0.25))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Accept button
            Button(action: onAccept) {
                Text("I Understand — Enable PPI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#4AA1B3"))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#0A1D4D"), Color(hex: "#132D5E")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }

    private func disclaimerSection(title: String, icon: String,
                                   iconColor: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(iconColor.opacity(0.6))
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTint.opacity(0.7))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.textTint.opacity(0.04))
        )
    }
}

// MARK: - Watch Disclaimer (compact version)

struct PPIWatchDisclaimerView: View {
    @Environment(\.weatherTheme) private var theme
    let onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "heart.text.clipboard")
                    .font(.title2)
                    .foregroundColor(.cyan)

                Text("PPI Score")
                    .font(.headline)
                    .foregroundColor(theme.textTint)

                Text("Wellness information only. Not medical advice. Does not diagnose or treat any condition.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTint.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text("If you feel unwell, seek medical help.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                Button(action: onAccept) {
                    Text("I Understand")
                        .font(.caption.bold())
                        .foregroundColor(theme.textTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.cyan.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
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
}
