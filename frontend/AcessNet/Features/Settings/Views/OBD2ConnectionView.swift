//
//  OBD2ConnectionView.swift
//  AcessNet
//
//  Rediseño premium: status pill animado, dashboard hero, gauges grid, log glass.
//

import SwiftUI

struct OBD2ConnectionView: View {
    @Environment(\.weatherTheme) private var theme
    @StateObject private var obd = OBD2Service.shared
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroHeader
                        statusPill

                        if obd.state.isConnected {
                            liveHero
                            metricsGrid
                            bleLogCard
                        } else {
                            instructionsCard
                        }

                        primaryControls
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("OBD-II Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.pageBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(theme.textTint)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(theme.textTint.opacity(0.1)))
                    }
                }
            }
            .environment(\.weatherTheme, theme)
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#06B6D4").opacity(0.35),
                                 Color(hex: "#0E7490").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 86, height: 86)
                    .blur(radius: 1)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#22D3EE"), Color(hex: "#06B6D4")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            VStack(spacing: 2) {
                Text("OBD-II Hardware Premium")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(theme.textTint)
                Text("ELM327 BLE · Vgate · OBDLink · Kiwi 3 · vLinker MC+")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: - Status Pill

    private var statusPill: some View {
        HStack(spacing: 10) {
            statusIndicator

            Text(obd.state.label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(theme.textTint)
                .lineLimit(1)

            Spacer(minLength: 4)

            if case .scanning = obd.state {
                ProgressView().tint(statusColor).scaleEffect(0.7)
            } else if case .connecting = obd.state {
                ProgressView().tint(statusColor).scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(statusColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(statusColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var statusIndicator: some View {
        Group {
            if obd.state.isConnected {
                BluetoothPulseDot(color: statusColor)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)
            }
        }
    }

    private var statusColor: Color {
        switch obd.state {
        case .connected: return Color(hex: "#34D399")
        case .scanning, .connecting: return Color(hex: "#60A5FA")
        case .failed: return Color(hex: "#F87171")
        case .disconnected: return Color(hex: "#94A3B8")
        }
    }

    // MARK: - Live Hero (gran número central)

    private var liveHero: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 9, weight: .heavy))
                Text("EN VIVO")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
            }
            .foregroundColor(Color(hex: "#22D3EE"))

            if let kmL = obd.liveData.instantKmPerL {
                Text(String(format: "%.1f", kmL))
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                    .shadow(color: Color(hex: "#22D3EE").opacity(0.5), radius: 12)
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 10, weight: .heavy))
                    Text("km/L instantáneo")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(theme.textTint.opacity(0.6))
            } else {
                Text(String(format: "%.2f", obd.liveData.computedFuelRateLh))
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                    .shadow(color: Color(hex: "#FBBF24").opacity(0.5), radius: 12)
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 10, weight: .heavy))
                    Text("L/hr consumo actual")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(theme.textTint.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#22D3EE").opacity(0.12),
                                 Color(hex: "#06B6D4").opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#22D3EE").opacity(0.5),
                                 Color(hex: "#0E7490").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TELEMETRÍA LIVE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.5))
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 4, height: 4)
                    Text("1 Hz")
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundColor(theme.textTint.opacity(0.45))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)],
                      spacing: 8) {
                gaugeCard(
                    icon: "gauge.open.with.lines.needle.33percent",
                    label: "Velocidad",
                    value: "\(obd.liveData.speedKmh)",
                    unit: "km/h",
                    color: Color(hex: "#60A5FA"),
                    progress: min(Double(obd.liveData.speedKmh) / 180, 1)
                )
                gaugeCard(
                    icon: "waveform.path.ecg",
                    label: "RPM",
                    value: "\(obd.liveData.rpm)",
                    unit: "rpm",
                    color: Color(hex: "#EF4444"),
                    progress: min(Double(obd.liveData.rpm) / 7000, 1)
                )
                gaugeCard(
                    icon: "wind",
                    label: "MAF",
                    value: String(format: "%.1f", obd.liveData.mafGs),
                    unit: "g/s",
                    color: Color(hex: "#A78BFA"),
                    progress: min(obd.liveData.mafGs / 100, 1)
                )
                gaugeCard(
                    icon: "gearshape.2.fill",
                    label: "Carga",
                    value: String(format: "%.0f", obd.liveData.engineLoadPct),
                    unit: "%",
                    color: Color(hex: "#FBBF24"),
                    progress: obd.liveData.engineLoadPct / 100
                )
                gaugeCard(
                    icon: "thermometer.high",
                    label: "Temp motor",
                    value: "\(obd.liveData.engineTempC)",
                    unit: "°C",
                    color: Color(hex: "#F87171"),
                    progress: min(Double(obd.liveData.engineTempC) / 110, 1)
                )
                gaugeCard(
                    icon: "hand.raised.fill",
                    label: "Acelerador",
                    value: String(format: "%.0f", obd.liveData.throttlePct),
                    unit: "%",
                    color: Color(hex: "#34D399"),
                    progress: obd.liveData.throttlePct / 100
                )
            }
        }
    }

    private func gaugeCard(icon: String, label: String, value: String, unit: String,
                           color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(color)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(theme.textTint.opacity(0.55))
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.textTint.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.55)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(progress)))
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "#22D3EE"))
                Text("CÓMO CONECTAR")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(theme.textTint.opacity(0.55))
            }

            VStack(spacing: 8) {
                instructionStep(
                    number: "1",
                    icon: "bolt.car.fill",
                    title: "Enchufa el dongle",
                    subtitle: "Puerto OBD-II abajo del volante"
                )
                instructionStep(
                    number: "2",
                    icon: "key.fill",
                    title: "Enciende el auto",
                    subtitle: "Ignición en ON, no necesita arrancar"
                )
                instructionStep(
                    number: "3",
                    icon: "dot.radiowaves.left.and.right",
                    title: "Permite Bluetooth",
                    subtitle: "Ajustes → AirWay → Bluetooth"
                )
                instructionStep(
                    number: "4",
                    icon: "antenna.radiowaves.left.and.right.circle.fill",
                    title: "Buscar dongles",
                    subtitle: "Toca el botón abajo"
                )
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

    private func instructionStep(number: String, icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#22D3EE").opacity(0.15))
                    .frame(width: 34, height: 34)
                Circle()
                    .stroke(Color(hex: "#22D3EE").opacity(0.4), lineWidth: 1)
                    .frame(width: 34, height: 34)
                Text(number)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#22D3EE"))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(theme.textTint.opacity(0.65))
                    Text(title)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(theme.textTint)
                }
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTint.opacity(0.55))
            }
            Spacer()
        }
    }

    // MARK: - BLE Log

    private var bleLogCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(obd.recentResponses.suffix(10), id: \.self) { r in
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(Color(hex: "#22D3EE"))
                        Text(r)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(theme.textTint.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(hex: "#22D3EE"))
                Text("Log BLE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(theme.textTint)
                Spacer()
                Text("\(obd.recentResponses.suffix(10).count)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(theme.textTint.opacity(0.5))
            }
        }
        .tint(.white.opacity(0.6))
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
    }

    // MARK: - Controls

    private var primaryControls: some View {
        Group {
            if obd.state.isConnected {
                Button {
                    HapticFeedback.warning()
                    obd.disconnect()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .heavy))
                        Text("Desconectar dongle")
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(theme.textTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#EF4444").opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#EF4444").opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    HapticFeedback.confirm()
                    obd.scan()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .heavy))
                        Text("Buscar dongles BLE")
                            .font(.system(size: 14, weight: .heavy))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundColor(theme.textTint)
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#22D3EE"), Color(hex: "#0E7490")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color(hex: "#22D3EE").opacity(0.45), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Bluetooth Pulse Dot

private struct BluetoothPulseDot: View {
    @Environment(\.weatherTheme) private var theme
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.5))
                .frame(width: 12, height: 12)
                .scaleEffect(pulse ? 1.8 : 1.0)
                .opacity(pulse ? 0 : 0.6)
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.7), radius: 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
