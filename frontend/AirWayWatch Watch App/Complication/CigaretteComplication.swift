//
//  CigaretteComplication.swift
//  AirWayWatch Watch App
//
//  WidgetKit complication showing real-time cigarette equivalence
//  on the watch face. Shows accumulated dose as cigarettes smoked.
//
//  Based on Berkeley Earth (2015): 22 µg/m³ PM2.5 × 24h = 1 cigarette.
//  Activity-adjusted for ventilation rate.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct CigaretteComplicationEntry: TimelineEntry {
    let date: Date
    let cigarettes: Double
    let ratePerHour: Double
    let pm25: Double
}

// MARK: - Timeline Provider

struct CigaretteComplicationProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.airway.shared") ?? .standard

    func placeholder(in context: Context) -> CigaretteComplicationEntry {
        CigaretteComplicationEntry(date: Date(), cigarettes: 2.3, ratePerHour: 0.12, pm25: 28)
    }

    func getSnapshot(in context: Context, completion: @escaping (CigaretteComplicationEntry) -> Void) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CigaretteComplicationEntry>) -> Void) {
        let entry = readCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readCurrentEntry() -> CigaretteComplicationEntry {
        CigaretteComplicationEntry(
            date: Date(),
            cigarettes: defaults.double(forKey: "cig_complication_count"),
            ratePerHour: defaults.double(forKey: "cig_complication_rate"),
            pm25: defaults.double(forKey: "cig_complication_pm25")
        )
    }
}

// MARK: - Widget Definition

struct CigaretteComplicationWidget: Widget {
    let kind = "CigaretteComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CigaretteComplicationProvider()
        ) { entry in
            CigaretteComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Cigarette Equivalent")
        .description("PM2.5 exposure as cigarettes smoked today.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Entry View Router

struct CigaretteComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CigaretteComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CigCircularComplication(entry: entry)
        case .accessoryCorner:
            CigCornerComplication(entry: entry)
        case .accessoryInline:
            CigInlineComplication(entry: entry)
        case .accessoryRectangular:
            CigRectangularComplication(entry: entry)
        @unknown default:
            Text(String(format: "%.1f", entry.cigarettes))
        }
    }
}

// MARK: - Circular: Gauge with cigarette count

struct CigCircularComplication: View {
    let entry: CigaretteComplicationEntry

    private var gaugeGradient: Gradient {
        Gradient(colors: [.green, .yellow, .orange, .red])
    }

    var body: some View {
        Gauge(value: min(entry.cigarettes, 10), in: 0...10) {
            Text("\u{1F6AC}")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text(String(format: "%.1f", entry.cigarettes))
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeGradient)
    }
}

// MARK: - Corner: Score + curved gauge

struct CigCornerComplication: View {
    let entry: CigaretteComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(String(format: "%.1f", entry.cigarettes))
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .widgetLabel {
            Gauge(value: min(entry.cigarettes, 10), in: 0...10) {
                Text("CIG")
            }
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .gaugeStyle(.accessoryLinear)
        }
    }
}

// MARK: - Inline: Text

struct CigInlineComplication: View {
    let entry: CigaretteComplicationEntry

    var body: some View {
        ViewThatFits {
            Text("\u{1F6AC} \(String(format: "%.1f", entry.cigarettes)) cigs today | PM2.5: \(String(format: "%.0f", entry.pm25))")
            Text("\u{1F6AC} \(String(format: "%.1f", entry.cigarettes)) cigarettes today")
            Text("\u{1F6AC} \(String(format: "%.1f", entry.cigarettes)) cigs")
        }
    }
}

// MARK: - Rectangular: Full detail

struct CigRectangularComplication: View {
    let entry: CigaretteComplicationEntry

    private var color: Color {
        switch entry.cigarettes {
        case ..<1:  return .green
        case 1..<3: return .yellow
        case 3..<5: return .orange
        default:    return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text("\u{1F6AC}")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f", entry.cigarettes))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .widgetAccentable()
                }

                Text("cigarettes today")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                if entry.ratePerHour > 0.01 {
                    Text(String(format: "+%.2f/hr", entry.ratePerHour))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Gauge(value: min(entry.cigarettes, 10), in: 0...10) {
                Text("")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
        }
    }
}

// MARK: - Complication Store (writes data for widget to read)

enum CigaretteComplicationStore {
    private static let defaults = UserDefaults(suiteName: "group.com.airway.shared") ?? .standard

    static func update(cigarettes: Double, ratePerHour: Double, pm25: Double) {
        defaults.set(cigarettes, forKey: "cig_complication_count")
        defaults.set(ratePerHour, forKey: "cig_complication_rate")
        defaults.set(pm25, forKey: "cig_complication_pm25")

        WidgetCenter.shared.reloadTimelines(ofKind: "CigaretteComplication")
    }
}
