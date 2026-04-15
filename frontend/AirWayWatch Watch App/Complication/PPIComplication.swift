//
//  PPIComplication.swift
//  AirWayWatch Watch App
//
//  WidgetKit-based watch face complication showing the PPI Score.
//  Supports accessoryCircular, accessoryCorner, accessoryInline, and accessoryRectangular.
//
//  Data flows: App calculates PPI → saves to shared UserDefaults → complication reads it.
//  Updates are triggered via WidgetCenter.shared.reloadTimelines(ofKind:).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PPIComplicationEntry: TimelineEntry {
    let date: Date
    let ppiScore: Int
    let zone: String // "green", "yellow", "orange", "red"
    let aqi: Int
    let location: String
    let isCalibrating: Bool
}

// MARK: - Timeline Provider

struct PPIComplicationProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.airway.shared") ?? UserDefaults.standard

    func placeholder(in context: Context) -> PPIComplicationEntry {
        PPIComplicationEntry(
            date: Date(),
            ppiScore: 23,
            zone: "green",
            aqi: 42,
            location: "CDMX",
            isCalibrating: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PPIComplicationEntry) -> Void) {
        let entry = readCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PPIComplicationEntry>) -> Void) {
        let entry = readCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readCurrentEntry() -> PPIComplicationEntry {
        PPIComplicationEntry(
            date: Date(),
            ppiScore: defaults.integer(forKey: "ppi_score"),
            zone: defaults.string(forKey: "ppi_zone") ?? "green",
            aqi: defaults.integer(forKey: "ppi_aqi"),
            location: defaults.string(forKey: "ppi_location") ?? "—",
            isCalibrating: defaults.bool(forKey: "ppi_calibrating")
        )
    }
}

// MARK: - Complication Widget

struct PPIComplicationWidget: Widget {
    let kind: String = "PPIComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: PPIComplicationProvider()
        ) { entry in
            PPIComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("PPI Score")
        .description("Your Personal Pollution Impact score.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Entry View Router

struct PPIComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PPIComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            PPICircularComplication(entry: entry)
        case .accessoryCorner:
            PPICornerComplication(entry: entry)
        case .accessoryInline:
            PPIInlineComplication(entry: entry)
        case .accessoryRectangular:
            PPIRectangularComplication(entry: entry)
        @unknown default:
            Text("\(entry.ppiScore)")
        }
    }
}

// MARK: - Circular (Gauge with Color Gradient)

struct PPICircularComplication: View {
    let entry: PPIComplicationEntry

    private var gaugeGradient: Gradient {
        Gradient(colors: [.green, .green, .yellow, .orange, .red])
    }

    var body: some View {
        if entry.isCalibrating {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption)
                    Text("PPI")
                        .font(.system(size: 9))
                }
            }
        } else {
            Gauge(value: Double(entry.ppiScore), in: 0...100) {
                Image(systemName: "figure.stand")
            } currentValueLabel: {
                Text("\(entry.ppiScore)")
                    .font(.system(.body, design: .rounded, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient)
        }
    }
}

// MARK: - Corner (Score + Curved Gauge)

struct PPICornerComplication: View {
    let entry: PPIComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("\(entry.ppiScore)")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .widgetLabel {
            Gauge(value: Double(entry.ppiScore), in: 0...100) {
                Text("PPI")
            }
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .gaugeStyle(.accessoryLinear)
        }
    }
}

// MARK: - Inline (Text)

struct PPIInlineComplication: View {
    let entry: PPIComplicationEntry

    private var zoneLabel: String {
        switch entry.zone {
        case "green": return "OK"
        case "yellow": return "Mild"
        case "orange": return "Moderate"
        case "red": return "High"
        default: return "—"
        }
    }

    var body: some View {
        ViewThatFits {
            Text("PPI: \(entry.ppiScore) — \(zoneLabel) | AQI: \(entry.aqi)")
            Text("PPI: \(entry.ppiScore) — \(zoneLabel)")
            Text("PPI: \(entry.ppiScore)")
        }
    }
}

// MARK: - Rectangular (Score + Details)

struct PPIRectangularComplication: View {
    let entry: PPIComplicationEntry

    private var zoneColor: Color {
        switch entry.zone {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("PPI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(entry.ppiScore)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .widgetAccentable()
                }

                Text(entry.location)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text("AQI: \(entry.aqi)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Gauge(value: Double(entry.ppiScore), in: 0...100) {
                Text("")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(zoneColor)
        }
    }
}

// MARK: - Helper to Save PPI Data for Complication

enum PPIComplicationStore {
    private static let defaults = UserDefaults(suiteName: "group.com.airway.shared") ?? UserDefaults.standard

    static func update(score: Int, zone: PPIZone, aqi: Int, location: String, isCalibrating: Bool) {
        defaults.set(score, forKey: "ppi_score")
        defaults.set(zone.rawValue, forKey: "ppi_zone")
        defaults.set(aqi, forKey: "ppi_aqi")
        defaults.set(location, forKey: "ppi_location")
        defaults.set(isCalibrating, forKey: "ppi_calibrating")

        WidgetCenter.shared.reloadTimelines(ofKind: "PPIComplication")
    }
}
