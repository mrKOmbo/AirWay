//
//  DailyForecastView.swift
//  AcessNet
//
//  Created by BICHOTEE
//

import SwiftUI

struct DailyForecastView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.weatherTheme) private var theme
    @State private var selectedDay: DailyForecast = DailyForecast.selected
    @State private var selectedTab: ForecastPeriod = .day
    @State private var hourlyData: [HourlyAQIData] = HourlyAQIData.generateSampleDay()
    @State private var showTipPopup = false
    @State private var selectedTipCategory: TipCategory?
    @State private var currentTipIndex = 0
    @State private var selectedMonth = "October"

    let weekDays = DailyForecast.sampleWeek
    let availableMonths = ["July", "August", "September", "October"]

    enum ForecastPeriod {
        case day
        case month
    }

    var body: some View {
        ZStack {
            // Background — matching home dark theme
            theme.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with tabs
                    headerView

                    if selectedTab == .day {
                        // Day selector
                        daySelector

                        // Main card with AQI info and Exposure
                        mainAQICard

                        // Tips by category
                        tipsSection

                        // Weather section
                        weatherSection

                        // More info section
                        moreInfoSection
                    } else {
                        // Month view
                        monthView
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
        .overlay(
            // Tip Popup Overlay - outside of ZStack to prevent safe area issues
            Group {
                if showTipPopup, let category = selectedTipCategory {
                    TipPopupView(
                        category: category,
                        currentTip: category.tips[currentTipIndex],
                        onDismiss: {
                            showTipPopup = false
                        },
                        onNext: {
                            currentTipIndex = (currentTipIndex + 1) % category.tips.count
                        }
                    )
                    .ignoresSafeArea()
                }
            }
        )
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(spacing: 16) {
            // Back button and Tabs
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(theme.cardColor)
                                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                        )
                }

                Spacer()

                // Tabs
                HStack(spacing: 0) {
                    TabButton(title: "DAY", isSelected: selectedTab == .day) {
                        selectedTab = .day
                    }

                    TabButton(title: "MONTH", isSelected: selectedTab == .month) {
                        selectedTab = .month
                    }
                }
                .frame(maxWidth: 300)

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(weekDays) { day in
                    DayButton(
                        day: day,
                        isSelected: selectedDay.id == day.id
                    ) {
                        withAnimation(.spring()) {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var mainAQICard: some View {
        VStack(spacing: 12) {
            // Date and level header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatSelectedDate())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text("Daily Air Quality")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                Spacer()

                Text(selectedDay.qualityLevel.rawValue)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: selectedDay.qualityLevel.color).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: selectedDay.qualityLevel.color), lineWidth: 1.5)
                            )
                    )
            }

            // Comparison timeline - Previous, Current, Next
            HStack(spacing: 0) {
                // Previous day
                if let prevDay = getPreviousDay() {
                    ComparisonDayCard(
                        day: prevDay,
                        label: "Yesterday",
                        isMain: false,
                        showTrend: true,
                        trendUp: selectedDay.aqi > prevDay.aqi,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDay = prevDay
                            }
                        }
                    )
                }

                Spacer()

                // Current day (main)
                VStack(spacing: 12) {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)

                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: selectedDay.qualityLevel.color).opacity(0.4),
                                        Color(hex: selectedDay.qualityLevel.color).opacity(0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 140, height: 140)

                        CircularAQIGauge(aqi: selectedDay.aqi)
                    }

                    // Pollutant indicators
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            PollutantBadge(label: "PM2.5", value: selectedDay.pm25)
                            PollutantBadge(label: "PM10", value: selectedDay.pm10)
                        }
                        HStack(spacing: 12) {
                            PollutantBadge(label: "NO2", value: selectedDay.no2)
                            PollutantBadge(label: "O3", value: selectedDay.o3)
                        }
                    }
                }

                Spacer()

                // Next day
                if let nextDay = getNextDay() {
                    ComparisonDayCard(
                        day: nextDay,
                        label: "Tomorrow",
                        isMain: false,
                        showTrend: true,
                        trendUp: nextDay.aqi > selectedDay.aqi,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDay = nextDay
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4)

            // Divider
            Divider()
                .background(.white.opacity(0.2))
                .padding(.vertical, 0)

            // Exposure History Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Exposure History")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DailyExposureCircularChart(selectedDay: selectedDay)
                    .frame(height: 290)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // Helper functions to get previous and next days
    private func getPreviousDay() -> DailyForecast? {
        guard let currentIndex = weekDays.firstIndex(where: { $0.id == selectedDay.id }),
              currentIndex > 0 else { return nil }
        return weekDays[currentIndex - 1]
    }

    private func getNextDay() -> DailyForecast? {
        guard let currentIndex = weekDays.firstIndex(where: { $0.id == selectedDay.id }),
              currentIndex < weekDays.count - 1 else { return nil }
        return weekDays[currentIndex + 1]
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current time indicator
            Text(currentTimeString())
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

            // Bar chart
            AQIBarChart(data: hourlyData, selectedTime: currentTimeString())
                .frame(height: 200)
                .padding(.horizontal)
        }
    }


    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TIPS BY CATEGORY")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            Text("Tap to learn more")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(TipCategory.sampleCategories) { category in
                        TipCategoryCard(category: category) {
                            selectedTipCategory = category
                            currentTipIndex = Int.random(in: 0..<category.tips.count)
                            withAnimation(.spring()) {
                                showTipPopup = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WEATHER")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            Text("Hourly averages")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal)

            HStack(spacing: 0) {
                WeatherMetric(
                    icon: "cloud.rain.fill",
                    value: "\(selectedDay.temperature)",
                    unit: "C°"
                )

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(0.2))

                WeatherMetric(
                    icon: "wind",
                    value: "\(selectedDay.windSpeed)",
                    unit: "km/h"
                )

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(0.2))

                WeatherMetric(
                    icon: "umbrella.fill",
                    value: "\(selectedDay.uvIndex)",
                    unit: "UV"
                )

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(0.2))

                WeatherMetric(
                    icon: "drop.fill",
                    value: "\(selectedDay.humidity)",
                    unit: "% Hum."
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .padding(.horizontal)
        }
    }

    private var moreInfoSection: some View {
        VStack(spacing: 0) {
            Text("MORE INFO")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                InfoRow(label: "Best day of the year", value: "37 AQI")
                Divider().background(.white.opacity(0.1))
                InfoRow(label: "Annual average", value: "63 AQI")
                Divider().background(.white.opacity(0.1))
                InfoRow(label: "Worst peak of the year", value: "99 AQI")
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .padding(.horizontal)
        }
    }

    private var monthView: some View {
        VStack(spacing: 20) {
            // Month Selector
            HStack {
                Button(action: {
                    if let currentIndex = availableMonths.firstIndex(of: selectedMonth),
                       currentIndex > 0 {
                        withAnimation(.spring()) {
                            selectedMonth = availableMonths[currentIndex - 1]
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .opacity(availableMonths.first == selectedMonth ? 0.3 : 1.0)
                }
                .disabled(availableMonths.first == selectedMonth)

                Spacer()

                Text("\(selectedMonth) 2025")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    if let currentIndex = availableMonths.firstIndex(of: selectedMonth),
                       currentIndex < availableMonths.count - 1 {
                        withAnimation(.spring()) {
                            selectedMonth = availableMonths[currentIndex + 1]
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .opacity(availableMonths.last == selectedMonth ? 0.3 : 1.0)
                }
                .disabled(availableMonths.last == selectedMonth)
            }
            .padding(.horizontal)

            // Monthly Stats Card
            MonthlyStatsCard(selectedMonth: selectedMonth)

            // Calendar Heat Map
            MonthlyCalendarHeatMap(selectedMonth: $selectedMonth)

            // Trend Graph
            MonthlyTrendGraph(selectedMonth: selectedMonth)

            // Best Days Insight
            BestDaysInsightCard()
        }
    }

    // MARK: - Helper Methods

    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00 EEE, MMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private func formatSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDay.date)
    }
}

// MARK: - Supporting Views

struct ComparisonDayCard: View {
    @Environment(\.weatherTheme) private var theme
    let day: DailyForecast
    let label: String
    let isMain: Bool
    let showTrend: Bool
    let trendUp: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)

                ZStack {
                    // Background circle with subtle gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: day.qualityLevel.color).opacity(0.15),
                                    Color(hex: day.qualityLevel.color).opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 70, height: 70)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(day.aqi) / 150.0)
                        .stroke(
                            Color(hex: day.qualityLevel.color).opacity(0.6),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(day.aqi)")
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text("AQI")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if showTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundColor(trendUp ? .red : Color(hex: "#E0E0E0"))

                        Text(day.qualityLevel.rawValue)
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PollutantBadge: View {
    @Environment(\.weatherTheme) private var theme
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.7))

            Text("\(value)")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.cardColor)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .fill(isSelected ? .white : .clear)
                        .frame(height: 2),
                    alignment: .bottom
                )
        }
    }
}

struct DayButton: View {
    @Environment(\.weatherTheme) private var theme
    let day: DailyForecast
    let isSelected: Bool
    let action: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(day.qualityLevel.color == "#E0E0E0" ? Color(hex: "#E0E0E0") : .yellow)
                        .frame(width: 8, height: 8)

                    Text(isToday ? "Today" : "\(day.shortDayName) \(String(format: "%02d", day.dayNumber))")
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.cardColor : .clear)
            )
        }
    }
}

struct MetricItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
        }
    }
}

struct CircularAQIGauge: View {
    let aqi: Int

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0").opacity(0.2),
                            Color(hex: "#FDD835").opacity(0.2),
                            Color(hex: "#FF9800").opacity(0.2),
                            Color(hex: "#E53935").opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 16
                )
                .frame(width: 128, height: 128)
                .blur(radius: 3)

            // Background track
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0").opacity(0.15),
                            Color(hex: "#FDD835").opacity(0.15),
                            Color(hex: "#FF9800").opacity(0.15),
                            Color(hex: "#E53935").opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 14
                )
                .frame(width: 120, height: 120)

            // Progress arc - más brillante y evidente
            Circle()
                .trim(from: 0, to: CGFloat(aqi) / 150.0)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0"),
                            Color(hex: "#FDD835"),
                            Color(hex: "#FF9800"),
                            Color(hex: "#E53935")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color(hex: "#FDD835").opacity(0.5), radius: 8, x: 0, y: 0)

            // AQI value
            VStack(spacing: 4) {
                Text("\(aqi)")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                Text("AQI")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
            }

            // Indicator dot with glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(hex: "#FDD835")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 16, height: 16)
                .shadow(color: .white.opacity(0.8), radius: 6, x: 0, y: 0)
                .offset(y: -60)
                .rotationEffect(.degrees(Double(aqi) * 2.4))
        }
    }
}

struct AQIBarChart: View {
    let data: [HourlyAQIData]
    let selectedTime: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Time indicator line
                VStack {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                }
                .frame(width: geometry.size.width / CGFloat(data.count))
                .offset(x: geometry.size.width / 2 - geometry.size.width / CGFloat(data.count) / 2)

                // Bars
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(data) { item in
                        VStack(spacing: 4) {
                            Spacer()

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: item.qualityLevel.backgroundColor),
                                            Color(hex: item.qualityLevel.color)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: CGFloat(item.aqi) * 2)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Time labels
                VStack {
                    Spacer()
                    HStack {
                        ForEach([0, 3, 6, 9, 11], id: \.self) { index in
                            if index < data.count {
                                Text(data[index].hour)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TipCategoryCard: View {
    @Environment(\.weatherTheme) private var theme
    let category: TipCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: category.icon)
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: category.color))
                    .frame(width: 80, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.cardColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: category.color).opacity(0.3), lineWidth: 2)
                            )
                    )
            }
        }
    }
}

// MARK: - Tip Popup View

struct TipPopupView: View {
    @Environment(\.weatherTheme) private var theme
    let category: TipCategory
    let currentTip: String
    let onDismiss: () -> Void
    let onNext: () -> Void

    var body: some View {
        // Popup card only - no background
        VStack(spacing: 20) {
                // Icon and title
                HStack(spacing: 16) {
                    Image(systemName: category.icon)
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: category.color))
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(Color(hex: category.color).opacity(0.2))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Tip & Facts")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()
                }

                // Tip content
                Text(currentTip)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )

                // Buttons
                HStack(spacing: 12) {
                    Button(action: onNext) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Next Tip")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: category.color))
                        )
                    }

                    Button(action: onDismiss) {
                        Text("Close")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.cardColor,
                                theme.cardColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

struct WeatherMetric: View {
    let icon: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding()
    }
}

// MARK: - Daily Exposure Chart

struct DailyExposureCircularChart: View {
    let selectedDay: DailyForecast
    @State private var selectedCategory = "All"
    let categories = ["All", "Home", "Work", "Outdoor"]

    // Exposure data varies by day
    var exposureData: (home: CGFloat, work: CGFloat, outdoor: CGFloat)? {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(selectedDay.date)
        let isPast = selectedDay.date < Date()

        // Solo hay datos para hoy y días pasados
        guard isPast || isToday else {
            return nil
        }

        // Datos diferentes según el día
        let dayIndex = calendar.component(.weekday, from: selectedDay.date)

        switch dayIndex {
        case 1: // Sunday
            return (home: 8, work: 0, outdoor: 2)
        case 2: // Monday
            return (home: 5, work: 6, outdoor: 2)
        case 3: // Tuesday
            return (home: 6, work: 5, outdoor: 3)
        case 4: // Wednesday
            return (home: 6, work: 4, outdoor: 3)
        case 5: // Thursday (default)
            return (home: 6, work: 4, outdoor: 3)
        case 6: // Friday
            return (home: 5, work: 5, outdoor: 4)
        case 7: // Saturday
            return (home: 7, work: 1, outdoor: 4)
        default:
            return (home: 6, work: 4, outdoor: 3)
        }
    }

    var totalHours: CGFloat {
        guard let data = exposureData else { return 0 }
        return data.home + data.work + data.outdoor
    }

    var showHome: Bool {
        selectedCategory == "All" || selectedCategory == "Home"
    }

    var showWork: Bool {
        selectedCategory == "All" || selectedCategory == "Work"
    }

    var showOutdoor: Bool {
        selectedCategory == "All" || selectedCategory == "Outdoor"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Category tabs
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    ExposureCategoryTab(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }

            // Circular clock-style chart or no data state
            if let data = exposureData {
                ZStack {
                    // Hour markers and labels
                    ForEach(0..<24) { hour in
                        ExposureHourMarker(hour: hour, totalHours: totalHours)
                    }

                    // Colored segments - conditional display
                    ZStack {
                        // Home segment (Yellow)
                        if showHome {
                            ExposureSegmentArc(
                                startHour: 0,
                                endHour: data.home,
                                color: Color(hex: "#FFD54F"),
                                label: "HOME",
                                hours: data.home
                            )
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Work segment (Green)
                        if showWork {
                            ExposureSegmentArc(
                                startHour: data.home,
                                endHour: data.home + data.work,
                                color: Color(hex: "#81C784"),
                                label: "WORK",
                                hours: data.work
                            )
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Outdoor segment (Orange)
                        if showOutdoor {
                            ExposureSegmentArc(
                                startHour: data.home + data.work,
                                endHour: data.home + data.work + data.outdoor,
                                color: Color(hex: "#FFA726"),
                                label: "OUTDOOR",
                                hours: data.outdoor
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Center content
                    VStack(spacing: 8) {
                        if selectedCategory == "All" {
                            Image(systemName: "figure.stand")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))

                            Text("\(Int(totalHours))h")
                                .font(.title3.bold())
                                .foregroundColor(.white.opacity(0.6))

                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            let hours = selectedCategory == "Home" ? data.home :
                                       selectedCategory == "Work" ? data.work : data.outdoor

                            Text("\(Int(hours))h")
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundColor(.white)

                            Text(selectedCategory.uppercased())
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .frame(height: 240)
            } else {
                // No data available state
                ZStack {
                    // Empty circle with hour markers
                    ForEach(0..<24) { hour in
                        ExposureHourMarker(hour: hour, totalHours: 0)
                    }

                    // Empty dotted circle
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 35, dash: [8, 8]))
                        .foregroundColor(.white.opacity(0.1))
                        .frame(width: 180, height: 180)

                    // No data message
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No Data")
                            .font(.title3.bold())
                            .foregroundColor(.white.opacity(0.6))

                        Text("Not available yet")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .frame(height: 240)
            }
        }
    }
}

struct ExposureCategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var categoryColor: Color {
        switch title {
        case "Home": return Color(hex: "#FFD54F")
        case "Work": return Color(hex: "#81C784")
        case "Outdoor": return Color(hex: "#FFA726")
        default: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? categoryColor.opacity(0.3) : Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? categoryColor : .clear, lineWidth: 2)
                        )
                )
        }
    }
}

struct ExposureHourMarker: View {
    let hour: Int
    let totalHours: CGFloat

    var body: some View {
        VStack {
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: hour % 3 == 0 ? 2 : 1, height: hour % 3 == 0 ? 12 : 6)

            Spacer()

            if hour % 3 == 0 {
                Text("\(hour)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .offset(y: -10)
            }
        }
        .frame(width: 100, height: 100)
        .rotationEffect(.degrees(Double(hour) * 15))
    }
}

struct ExposureSegmentArc: View {
    let startHour: CGFloat
    let endHour: CGFloat
    let color: Color
    let label: String
    let hours: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .trim(from: startHour / 24, to: endHour / 24)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 35
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 0)
        }
    }
}

// MARK: - Monthly View Components

struct MonthlyStatsCard: View {
    @Environment(\.weatherTheme) private var theme
    let selectedMonth: String

    // Data structure for multiple months (July - October 2025)
    let monthsData: [String: [[Int?]]] = [
        "July": [
            [nil, nil, nil, nil, nil, nil, 68],
            [72, 65, 58, 54, 61, 69, 75],
            [71, 67, 63, 59, 56, 62, 68],
            [74, 70, 66, 62, 58, 64, 70],
            [76, 72, 68, 64, 60, 66, 72],
            [73, nil, nil, nil, nil, nil, nil]
        ],
        "August": [
            [nil, nil, 69, 65, 61, 67, 73],
            [70, 66, 62, 58, 64, 70, 76],
            [68, 64, 60, 56, 62, 68, 74],
            [66, 62, 58, 54, 60, 66, 72],
            [64, 60, 56, 52, 58, 64, 70],
            [nil, nil, nil, nil, 62, nil, nil]
        ],
        "September": [
            [nil, nil, nil, nil, nil, 59, 65],
            [61, 57, 53, 49, 55, 61, 67],
            [63, 59, 55, 51, 47, 53, 59],
            [65, 61, 57, 53, 49, 55, 61],
            [63, 59, 55, 51, 57, 63, nil]
        ],
        "October": [
            [nil, nil, nil, nil, 45, 48, 52],
            [38, 42, 55, 61, 58, 49, 43],
            [47, 51, 54, 48, 32, 39, 44],
            [56, 62, 71, 68, 55, 48, 41],
            [45, 52, 58, 61, 65, nil, nil]
        ]
    ]

    let availableMonths = ["July", "August", "September", "October"]

    var monthStats: (average: Int, best: Int, worst: Int, bestDay: String, worstDay: String) {
        let data = monthsData[selectedMonth]?.flatMap { $0 }.compactMap { $0 } ?? []
        guard !data.isEmpty else {
            return (0, 0, 0, "N/A", "N/A")
        }

        let avg = data.reduce(0, +) / data.count
        let best = data.min() ?? 0
        let worst = data.max() ?? 0

        // Find best and worst day numbers
        var dayCounter = 1
        var bestDay = 1
        var worstDay = 1

        if let monthData = monthsData[selectedMonth] {
            for week in monthData {
                for aqi in week {
                    if let aqi = aqi {
                        if aqi == best {
                            bestDay = dayCounter
                        }
                        if aqi == worst {
                            worstDay = dayCounter
                        }
                        dayCounter += 1
                    }
                }
            }
        }

        let monthAbbrev = String(selectedMonth.prefix(3))
        return (avg, best, worst, "\(monthAbbrev) \(bestDay)", "\(monthAbbrev) \(worstDay)")
    }

    var previousMonthComparison: (percentage: Int, isBetter: Bool, previousMonthName: String) {
        guard let currentIndex = availableMonths.firstIndex(of: selectedMonth),
              currentIndex > 0 else {
            return (0, true, "Previous")
        }

        let previousMonth = availableMonths[currentIndex - 1]

        // Get averages for both months
        let currentData = monthsData[selectedMonth]?.flatMap { $0 }.compactMap { $0 } ?? []
        let previousData = monthsData[previousMonth]?.flatMap { $0 }.compactMap { $0 } ?? []

        guard !currentData.isEmpty && !previousData.isEmpty else {
            return (0, true, previousMonth)
        }

        let currentAvg = currentData.reduce(0, +) / currentData.count
        let previousAvg = previousData.reduce(0, +) / previousData.count

        let difference = previousAvg - currentAvg
        let percentage = abs((difference * 100) / previousAvg)
        let isBetter = currentAvg < previousAvg

        return (percentage, isBetter, previousMonth)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Average AQI
                StatBox(
                    title: "Average",
                    value: "\(monthStats.average)",
                    subtitle: "AQI",
                    color: Color(hex: "#FDD835"),
                    icon: "chart.line.uptrend.xyaxis"
                )

                // Best Day
                StatBox(
                    title: "Best Day",
                    value: "\(monthStats.best)",
                    subtitle: monthStats.bestDay,
                    color: Color(hex: "#E0E0E0"),
                    icon: "checkmark.circle.fill"
                )

                // Worst Day
                StatBox(
                    title: "Worst Day",
                    value: "\(monthStats.worst)",
                    subtitle: monthStats.worstDay,
                    color: Color(hex: "#FF9800"),
                    icon: "exclamationmark.triangle.fill"
                )
            }

            // Comparison with last month
            let comparison = previousMonthComparison
            HStack {
                Image(systemName: comparison.isBetter ? "arrow.down.right" : "arrow.up.right")
                    .foregroundColor(comparison.isBetter ? Color(hex: "#E0E0E0") : Color(hex: "#FF9800"))
                Text("\(comparison.percentage)% \(comparison.isBetter ? "better" : "worse") than \(comparison.previousMonthName)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.cardColor,
                            theme.cardColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title.bold())
                .foregroundColor(.white)

            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))

            Text(subtitle)
                .font(.caption2.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
    }
}

struct MonthlyCalendarHeatMap: View {
    @Environment(\.weatherTheme) private var theme
    @Binding var selectedMonth: String
    let days = ["S", "M", "T", "W", "T", "F", "S"]

    // Data structure for multiple months (July - October 2025)
    let monthsData: [String: (data: [[Int?]], offset: Int, totalDays: Int)] = [
        "July": (
            data: [
                [nil, nil, nil, nil, nil, nil, 68],
                [72, 65, 58, 54, 61, 69, 75],
                [71, 67, 63, 59, 56, 62, 68],
                [74, 70, 66, 62, 58, 64, 70],
                [76, 72, 68, 64, 60, 66, 72],
                [73, nil, nil, nil, nil, nil, nil]
            ],
            offset: 6,
            totalDays: 31
        ),
        "August": (
            data: [
                [nil, nil, 69, 65, 61, 67, 73],
                [70, 66, 62, 58, 64, 70, 76],
                [68, 64, 60, 56, 62, 68, 74],
                [66, 62, 58, 54, 60, 66, 72],
                [64, 60, 56, 52, 58, 64, 70],
                [nil, nil, nil, nil, 62, nil, nil]
            ],
            offset: 2,
            totalDays: 31
        ),
        "September": (
            data: [
                [nil, nil, nil, nil, nil, 59, 65],
                [61, 57, 53, 49, 55, 61, 67],
                [63, 59, 55, 51, 47, 53, 59],
                [65, 61, 57, 53, 49, 55, 61],
                [63, 59, 55, 51, 57, 63, nil]
            ],
            offset: 5,
            totalDays: 30
        ),
        "October": (
            data: [
                [nil, nil, nil, nil, 45, 48, 52],
                [38, 42, 55, 61, 58, 49, 43],
                [47, 51, 54, 48, 32, 39, 44],
                [56, 62, 71, 68, 55, 48, 41],
                [45, 52, 58, 61, 65, nil, nil]
            ],
            offset: 4,
            totalDays: 31
        )
    ]

    var monthData: [[Int?]] {
        monthsData[selectedMonth]?.data ?? []
    }

    var monthStats: (average: Int, best: Int, worst: Int, bestDay: String, worstDay: String) {
        let data = monthData.flatMap { $0 }.compactMap { $0 }
        guard !data.isEmpty else {
            return (0, 0, 0, "N/A", "N/A")
        }

        let avg = data.reduce(0, +) / data.count
        let best = data.min() ?? 0
        let worst = data.max() ?? 0

        // Find best and worst day numbers
        var dayCounter = 1
        var bestDay = 1
        var worstDay = 1

        for week in monthData {
            for aqi in week {
                if let aqi = aqi {
                    if aqi == best {
                        bestDay = dayCounter
                    }
                    if aqi == worst {
                        worstDay = dayCounter
                    }
                    dayCounter += 1
                }
            }
        }

        let monthAbbrev = String(selectedMonth.prefix(3))
        return (avg, best, worst, "\(monthAbbrev) \(bestDay)", "\(monthAbbrev) \(worstDay)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly Overview")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Month selector dropdown style
                Menu {
                    ForEach(["July", "August", "September", "October"], id: \.self) { month in
                        Button(month) {
                            withAnimation(.spring()) {
                                selectedMonth = month
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedMonth)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                // Week days header
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                ForEach(0..<monthData.count, id: \.self) { week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            if let aqi = monthData[week][day] {
                                CalendarDayCell(aqi: aqi, dayNumber: getDayNumber(week: week, day: day))
                            } else {
                                Color.clear
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .padding(.horizontal)
        }
    }

    func getDayNumber(week: Int, day: Int) -> Int {
        return week * 7 + day - 3 // Offset for first week
    }
}

struct CalendarDayCell: View {
    let aqi: Int
    let dayNumber: Int

    var color: Color {
        switch aqi {
        case 0..<51: return Color(hex: "#E0E0E0")
        case 51..<101: return Color(hex: "#FDD835")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.caption2.bold())
                .foregroundColor(.white)

            Text("\(aqi)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 1)
                )
        )
    }
}

struct MonthlyTrendGraph: View {
    @Environment(\.weatherTheme) private var theme
    let selectedMonth: String

    // Data structure for multiple months (July - October 2025)
    let monthsData: [String: [CGFloat]] = [
        "July": [68, 72, 65, 58, 54, 61, 69, 75, 71, 67, 63, 59, 56, 62, 68, 74, 70, 66, 62, 58, 64, 70, 76, 72, 68, 64, 60, 66, 72, 73, 69],
        "August": [69, 65, 61, 67, 73, 70, 66, 62, 58, 64, 70, 76, 68, 64, 60, 56, 62, 68, 74, 66, 62, 58, 54, 60, 66, 72, 64, 60, 56, 52, 58],
        "September": [59, 65, 61, 57, 53, 49, 55, 61, 67, 63, 59, 55, 51, 47, 53, 59, 65, 61, 57, 53, 49, 55, 61, 63, 59, 55, 51, 57, 63, 60],
        "October": [45, 48, 52, 38, 42, 55, 61, 58, 49, 43, 47, 51, 54, 48, 32, 39, 44, 56, 62, 71, 68, 55, 48, 41, 45, 52, 58, 61, 65, 59, 52]
    ]

    var data: [CGFloat] {
        monthsData[selectedMonth] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trend")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            GeometryReader { geometry in
                Path { path in
                    let maxValue: CGFloat = 100
                    let stepX = geometry.size.width / CGFloat(data.count - 1)
                    let stepY = geometry.size.height / maxValue

                    path.move(to: CGPoint(x: 0, y: geometry.size.height - data[0] * stepY))

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - value * stepY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0"),
                            Color(hex: "#FDD835"),
                            Color(hex: "#FF9800")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
            }
            .frame(height: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
            )
            .padding(.horizontal)
        }
    }
}

struct BestDaysInsightCard: View {
    @Environment(\.weatherTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "#FDD835"))
                Text("Insights")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "sun.max.fill",
                    color: "#E0E0E0",
                    text: "Sundays have 30% better AQI on average"
                )

                InsightRow(
                    icon: "figure.run",
                    color: "#4CAF50",
                    text: "Best outdoor activity hours: 6-9 AM"
                )

                InsightRow(
                    icon: "calendar",
                    color: "#FDD835",
                    text: "87% of days this month had moderate or good air quality"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.cardColor,
                            theme.cardColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct InsightRow: View {
    let icon: String
    let color: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: color))
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Preview

#Preview {
    DailyForecastView()
}
