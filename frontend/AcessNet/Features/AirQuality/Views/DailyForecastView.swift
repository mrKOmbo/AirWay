//
//  DailyForecastView.swift
//  AcessNet
//

import SwiftUI
import Charts

// MARK: - Main View

struct DailyForecastView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weatherTheme) private var theme

    @State private var selectedDay: DailyForecast
    @State private var selectedTab: ForecastPeriod = .day
    @State private var selectedMonth = "October"
    @State private var showTipPopup = false
    @State private var selectedTipCategory: TipCategory?
    @State private var currentTipIndex = 0

    private let weekDays: [DailyForecast]
    private let availableMonths = ["July", "August", "September", "October"]

    init() {
        let days = Self.generateDayHistory(pastDays: 14, futureDays: 3)
        self.weekDays = days
        // Today (or closest to today) is the initial selection
        let today = days.first(where: { Calendar.current.isDateInToday($0.date) }) ?? days[days.count / 2]
        self._selectedDay = State(initialValue: today)
    }

    private static func generateDayHistory(pastDays: Int, futureDays: Int) -> [DailyForecast] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEE"

        var out: [DailyForecast] = []
        for offset in (-pastDays...futureDays) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let seed = abs(offset) * 7 + Int(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 97))
            // Semi-deterministic values so the UI stays stable
            let aqi = 40 + (seed % 60)
            let pm25 = 20 + (seed % 35)
            let pm10 = 40 + (seed % 60)
            let no2 = 30 + (seed % 40)
            let o3 = 20 + (seed % 30)
            let temp = 14 + (seed % 12)
            let wind = 1 + (seed % 8)
            let uv = seed % 8
            let humidity = 55 + (seed % 25)

            out.append(DailyForecast(
                date: date,
                dayName: dayNameFormatter.string(from: date).uppercased(),
                dayNumber: calendar.component(.day, from: date),
                aqi: aqi,
                no2: no2,
                pm25: pm25,
                pm10: pm10,
                o3: o3,
                temperature: temp,
                windSpeed: wind,
                uvIndex: uv,
                humidity: humidity
            ))
        }
        return out
    }

    enum ForecastPeriod: String, CaseIterable {
        case day = "Day"
        case month = "Month"
    }

    var body: some View {
        ZStack {
            theme.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    segmentedTabs

                    if selectedTab == .day {
                        dayPillSelector
                        aqiAndExposureCard
                        compareAndPollutantsCard
                        weatherAndYearlyCard
                        tipsCarousel
                    } else {
                        monthOverviewCard
                        calendarAndTrendCard
                        insightsCard
                    }

                    Color.clear.frame(height: 30)
                }
                .padding(.top, 12)
            }
        }
        .navigationBarHidden(true)
        .overlay {
            if showTipPopup, let category = selectedTipCategory {
                TipPopupView(
                    category: category,
                    currentTip: category.tips[currentTipIndex],
                    onDismiss: { showTipPopup = false },
                    onNext: { currentTipIndex = (currentTipIndex + 1) % category.tips.count }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Card helper

    private func glassCard<Content: View>(padding: CGFloat = 16, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardColor)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.borderColor, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            )
            .padding(.horizontal, 16)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textTint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(theme.cardColor).overlay(Circle().stroke(theme.borderColor, lineWidth: 1)))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Air Quality")
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textTint)
                Text("Detailed Forecast")
                    .font(.caption2)
                    .foregroundColor(theme.textTint.opacity(0.5))
            }

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Segmented tabs

    private var segmentedTabs: some View {
        HStack(spacing: 0) {
            ForEach(ForecastPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selectedTab == period ? theme.textTint.opacity(0.18) : .clear)
                        )
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(theme.textTint.opacity(0.08)))
        .padding(.horizontal, 20)
    }

    // MARK: Day pill selector

    private var dayPillSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weekDays) { day in
                        dayPill(day)
                            .id(day.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(selectedDay.id, anchor: .center)
                    }
                }
            }
            .onChange(of: selectedDay.id) { newId in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    private func dayPill(_ day: DailyForecast) -> some View {
        let isSelected = day.id == selectedDay.id
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day.date)
        let isYesterday = cal.isDateInYesterday(day.date)
        let isTomorrow = cal.isDateInTomorrow(day.date)
        let isFuture = day.date > Date() && !isToday

        let topLabel: String = {
            if isToday { return "Today" }
            if isYesterday { return "Yest." }
            if isTomorrow { return "Tom." }
            return day.shortDayName
        }()

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedDay = day
            }
        }) {
            VStack(spacing: 4) {
                Text(topLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .white : (isToday ? .white.opacity(0.85) : theme.textTint.opacity(0.45)))
                Text("\(day.dayNumber)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : theme.textTint.opacity(0.8))
                    .opacity(isFuture ? 0.7 : 1.0)
                Circle()
                    .fill(Color(hex: day.qualityLevel.color))
                    .frame(width: 6, height: 6)
                    .opacity(isFuture ? 0.5 : 1.0)
            }
            .frame(width: 54, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? theme.textTint.opacity(0.2) : theme.cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? .white.opacity(0.45) :
                                    (isToday ? Color(hex: day.qualityLevel.color).opacity(0.5) : theme.borderColor),
                                lineWidth: isToday && !isSelected ? 1.5 : 1
                            )
                    )
            )
        }
    }

    // MARK: Main AQI + Exposure (unified)

    private var aqiAndExposureCard: some View {
        glassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                // Date
                Text(formatSelectedDate())
                    .font(.caption)
                    .foregroundColor(theme.textTint.opacity(0.5))
                    .textCase(.uppercase)

                // Horizontal: compact exposure (left) + AQI stack (right)
                HStack(alignment: .center, spacing: 16) {
                    CompactExposureChart(selectedDay: selectedDay)
                        .frame(width: 150)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(selectedDay.aqi)")
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                                .foregroundColor(theme.textTint)
                                .shadow(color: Color(hex: selectedDay.qualityLevel.color).opacity(0.5), radius: 14)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("AQI")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.textTint.opacity(0.5))
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: selectedDay.qualityLevel.color))
                                .frame(width: 7, height: 7)
                            Text(selectedDay.qualityLevel.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(Color(hex: selectedDay.qualityLevel.color))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: selectedDay.qualityLevel.color).opacity(0.15)))

                        Text("Exposure History")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textTint.opacity(0.5))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                scaleBar
            }
        }
    }

    private var scaleBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Color(hex: "#E0E0E0"), Color(hex: "#FDD835"),
                            Color(hex: "#FF9800"), Color(hex: "#E53935"), Color(hex: "#8E24AA")
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 6)
                    .clipShape(Capsule())

                    let pos = min(CGFloat(selectedDay.aqi) / 300.0, 1.0) * geo.size.width
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(hex: selectedDay.qualityLevel.color), lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: max(0, min(geo.size.width - 10, pos - 5)))
                }
            }
            .frame(height: 10)

            HStack {
                Text("0").font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
                Spacer()
                Text("50").font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
                Spacer()
                Text("100").font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
                Spacer()
                Text("150").font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
                Spacer()
                Text("200+").font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
            }
        }
    }

    // MARK: Compare + Pollutants (unified)

    private var compareAndPollutantsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Comparison", subtitle: "Previous & next days vs selected")

                HStack(alignment: .center, spacing: 8) {
                    comparisonCol(day: getPreviousDay(), label: "Yesterday", isMain: false)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(theme.textTint.opacity(0.25))
                    comparisonCol(day: selectedDay, label: "Selected", isMain: true)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(theme.textTint.opacity(0.25))
                    comparisonCol(day: getNextDay(), label: "Tomorrow", isMain: false)
                }

                Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)

                sectionHeader("Pollutants", subtitle: "Concentration levels")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    pollutantTile("PM2.5", value: selectedDay.pm25, unit: "µg/m³", max: 75, color: colorForPM25(selectedDay.pm25))
                    pollutantTile("PM10", value: selectedDay.pm10, unit: "µg/m³", max: 150, color: colorForPM10(selectedDay.pm10))
                    pollutantTile("NO₂", value: selectedDay.no2, unit: "ppb", max: 100, color: colorForNO2(selectedDay.no2))
                    pollutantTile("O₃", value: selectedDay.o3, unit: "ppb", max: 100, color: colorForO3(selectedDay.o3))
                }
            }
        }
    }

    @ViewBuilder
    private func comparisonCol(day: DailyForecast?, label: String, isMain: Bool) -> some View {
        if let day = day {
            Button(action: {
                if !isMain {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedDay = day
                    }
                }
            }) {
                VStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.textTint.opacity(0.5))
                    Text("\(day.aqi)")
                        .font(.system(size: isMain ? 28 : 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textTint)
                    Circle()
                        .fill(Color(hex: day.qualityLevel.color))
                        .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isMain ? 18 : 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMain ? Color(hex: day.qualityLevel.color).opacity(0.18) : theme.cardColor)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isMain ? Color(hex: day.qualityLevel.color).opacity(0.6) : theme.borderColor, lineWidth: 1))
                )
            }
        } else {
            VStack(spacing: 6) {
                Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(theme.textTint.opacity(0.3))
                Text("—").font(.system(size: isMain ? 28 : 20, weight: .bold)).foregroundColor(theme.textTint.opacity(0.3))
                Color.clear.frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isMain ? 18 : 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardColor.opacity(0.5)))
        }
    }

    private func pollutantTile(_ name: String, value: Int, unit: String, max: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(.system(size: 11, weight: .bold)).foregroundColor(theme.textTint.opacity(0.6))
                Spacer()
                Circle().fill(color).frame(width: 6, height: 6)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(theme.textTint)
                Text(unit).font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.textTint.opacity(0.08)).frame(height: 4)
                    Capsule().fill(color).frame(width: min(CGFloat(value) / CGFloat(max), 1.0) * geo.size.width, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.textTint.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.textTint.opacity(0.06), lineWidth: 1)))
    }

    // MARK: Weather + Yearly (unified)

    private var weatherAndYearlyCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Weather", subtitle: "Daily averages")

                HStack(spacing: 0) {
                    weatherMetric("thermometer.medium", "\(selectedDay.temperature)°", "Temp")
                    divider
                    weatherMetric("wind", "\(selectedDay.windSpeed)", "km/h")
                    divider
                    weatherMetric("sun.max.fill", "\(selectedDay.uvIndex)", "UV")
                    divider
                    weatherMetric("humidity.fill", "\(selectedDay.humidity)%", "Humidity")
                }

                Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)

                sectionHeader("This Year", subtitle: "Reference values")

                VStack(spacing: 0) {
                    yearlyRow(icon: "checkmark.seal.fill", iconColor: Color(hex: "#4CAF50"), label: "Best day", value: "37 AQI")
                    rowDivider
                    yearlyRow(icon: "equal.circle.fill", iconColor: Color(hex: "#FDD835"), label: "Annual average", value: "63 AQI")
                    rowDivider
                    yearlyRow(icon: "exclamationmark.triangle.fill", iconColor: Color(hex: "#E53935"), label: "Worst peak", value: "99 AQI")
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(theme.textTint.opacity(0.08)).frame(width: 1, height: 40)
    }

    private func weatherMetric(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(theme.textTint.opacity(0.5))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(theme.textTint)
            Text(label).font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Tips carousel

    private var tipsCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("Tips by Category", subtitle: "Tap any card to learn more")
                Spacer()
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TipCategory.sampleCategories) { category in
                        Button(action: {
                            selectedTipCategory = category
                            currentTipIndex = Int.random(in: 0..<category.tips.count)
                            withAnimation(.spring()) { showTipPopup = true }
                        }) {
                            tipTile(category)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func tipTile(_ category: TipCategory) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: category.color).opacity(0.18))
                    .frame(width: 50, height: 50)
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: category.color))
            }
            Text(category.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textTint)
        }
        .frame(width: 96, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.cardColor)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.borderColor, lineWidth: 1))
        )
    }

    private var rowDivider: some View {
        Rectangle().fill(theme.textTint.opacity(0.06)).frame(height: 1)
    }

    private func yearlyRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(iconColor).frame(width: 22)
            Text(label).font(.subheadline).foregroundColor(theme.textTint.opacity(0.8))
            Spacer()
            Text(value).font(.subheadline.bold()).foregroundColor(theme.textTint)
        }
        .padding(.vertical, 12)
    }

    // MARK: - MONTH VIEW

    // MARK: Month overview (selector + stats + comparison unified)

    private var monthOverviewCard: some View {
        let stats = MonthlyData.stats(for: selectedMonth)
        let cmp = MonthlyData.comparison(for: selectedMonth, in: availableMonths)

        return glassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Month selector row
                HStack {
                    Button(action: {
                        if let i = availableMonths.firstIndex(of: selectedMonth), i > 0 {
                            withAnimation(.spring()) { selectedMonth = availableMonths[i - 1] }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                            .foregroundColor(theme.textTint.opacity(availableMonths.first == selectedMonth ? 0.25 : 0.9))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.textTint.opacity(0.08)))
                    }
                    .disabled(availableMonths.first == selectedMonth)

                    Spacer()
                    Text("\(selectedMonth) 2025")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(theme.textTint)
                    Spacer()

                    Button(action: {
                        if let i = availableMonths.firstIndex(of: selectedMonth), i < availableMonths.count - 1 {
                            withAnimation(.spring()) { selectedMonth = availableMonths[i + 1] }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundColor(theme.textTint.opacity(availableMonths.last == selectedMonth ? 0.25 : 0.9))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.textTint.opacity(0.08)))
                    }
                    .disabled(availableMonths.last == selectedMonth)
                }

                // Stats row
                HStack(spacing: 10) {
                    statTile(title: "Average", value: "\(stats.average)", subtitle: "AQI", color: Color(hex: "#FDD835"), icon: "chart.line.uptrend.xyaxis")
                    statTile(title: "Best", value: "\(stats.best)", subtitle: stats.bestDay, color: Color(hex: "#4CAF50"), icon: "checkmark.seal.fill")
                    statTile(title: "Worst", value: "\(stats.worst)", subtitle: stats.worstDay, color: Color(hex: "#E53935"), icon: "exclamationmark.triangle.fill")
                }

                // Comparison chip
                HStack(spacing: 8) {
                    Image(systemName: cmp.isBetter ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundColor(cmp.isBetter ? Color(hex: "#4CAF50") : Color(hex: "#E53935"))
                    Text("\(cmp.percentage)% \(cmp.isBetter ? "better" : "worse") than \(cmp.previousMonthName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textTint.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(theme.textTint.opacity(0.06)))
            }
        }
    }

    private func statTile(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(theme.textTint)
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(theme.textTint.opacity(0.5))
            Text(subtitle).font(.system(size: 10, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.textTint.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: Calendar + Trend (unified)

    private var calendarAndTrendCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Calendar", subtitle: "Daily AQI across the month")

                let dows = ["S", "M", "T", "W", "T", "F", "S"]
                HStack(spacing: 4) {
                    ForEach(0..<dows.count, id: \.self) { i in
                        Text(dows[i])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textTint.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                }

                let weeks = MonthlyData.calendar(for: selectedMonth)
                VStack(spacing: 4) {
                    ForEach(0..<weeks.count, id: \.self) { w in
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { d in
                                if let aqi = weeks[w][d] {
                                    heatCell(aqi: aqi, dayNumber: MonthlyData.dayNumber(month: selectedMonth, week: w, dow: d))
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 38)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    legendDot(Color(hex: "#4CAF50"), "Good")
                    legendDot(Color(hex: "#FDD835"), "Moderate")
                    legendDot(Color(hex: "#FF9800"), "USG")
                    legendDot(Color(hex: "#E53935"), "Unhealthy")
                }

                Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)

                sectionHeader("Monthly Trend", subtitle: "AQI evolution through \(selectedMonth)")

                let series = MonthlyData.trend(for: selectedMonth).enumerated().map { (day: $0.offset + 1, aqi: Int($0.element)) }

                Chart {
                    ForEach(series, id: \.day) { p in
                        AreaMark(x: .value("Day", p.day), y: .value("AQI", p.aqi))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#FDD835").opacity(0.35), Color(hex: "#FDD835").opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            ))
                        LineMark(x: .value("Day", p.day), y: .value("AQI", p.aqi))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#E0E0E0"), Color(hex: "#FDD835"), Color(hex: "#FF9800")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [1, 7, 14, 21, 28]) {
                        AxisValueLabel().foregroundStyle(.white.opacity(0.4))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(.white.opacity(0.08))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.06))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private func heatCell(aqi: Int, dayNumber: Int) -> some View {
        let color = aqiColor(aqi)
        return VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(theme.textTint)
            Text("\(aqi)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.textTint.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.7), lineWidth: 1))
        )
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundColor(theme.textTint.opacity(0.5))
        }
    }

    // MARK: Insights

    private var insightsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundColor(Color(hex: "#FDD835"))
                    Text("Insights")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.textTint)
                }

                insightRow("sun.max.fill", Color(hex: "#FDD835"), "Sundays have 30% better AQI on average")
                Rectangle().fill(theme.textTint.opacity(0.06)).frame(height: 1)
                insightRow("figure.run", Color(hex: "#4CAF50"), "Best outdoor hours: 6 – 9 AM")
                Rectangle().fill(theme.textTint.opacity(0.06)).frame(height: 1)
                insightRow("calendar", Color(hex: "#4AB8FF"), "87% of days had moderate or good quality")
            }
        }
    }

    private func insightRow(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(color.opacity(0.15)))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(theme.textTint.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textTint)
            if let s = subtitle {
                Text(s)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTint.opacity(0.5))
            }
        }
    }

    private func getPreviousDay() -> DailyForecast? {
        guard let i = weekDays.firstIndex(where: { $0.id == selectedDay.id }), i > 0 else { return nil }
        return weekDays[i - 1]
    }

    private func getNextDay() -> DailyForecast? {
        guard let i = weekDays.firstIndex(where: { $0.id == selectedDay.id }), i < weekDays.count - 1 else { return nil }
        return weekDays[i + 1]
    }

    private func formatSelectedDate() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: selectedDay.date)
    }

    private func aqiColor(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<51: return Color(hex: "#4CAF50")
        case 51..<101: return Color(hex: "#FDD835")
        case 101..<151: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }

    private func colorForPM25(_ v: Int) -> Color {
        switch v {
        case 0..<13: return Color(hex: "#4CAF50")
        case 13..<36: return Color(hex: "#FDD835")
        case 36..<56: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
    private func colorForPM10(_ v: Int) -> Color {
        switch v {
        case 0..<55: return Color(hex: "#4CAF50")
        case 55..<155: return Color(hex: "#FDD835")
        case 155..<255: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
    private func colorForNO2(_ v: Int) -> Color {
        switch v {
        case 0..<54: return Color(hex: "#4CAF50")
        case 54..<101: return Color(hex: "#FDD835")
        case 101..<361: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
    private func colorForO3(_ v: Int) -> Color {
        switch v {
        case 0..<55: return Color(hex: "#4CAF50")
        case 55..<71: return Color(hex: "#FDD835")
        case 71..<86: return Color(hex: "#FF9800")
        default: return Color(hex: "#E53935")
        }
    }
}

// MARK: - Monthly Data (kept sample data)

enum MonthlyData {
    static let calendars: [String: [[Int?]]] = [
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

    static let trends: [String: [CGFloat]] = [
        "July": [68, 72, 65, 58, 54, 61, 69, 75, 71, 67, 63, 59, 56, 62, 68, 74, 70, 66, 62, 58, 64, 70, 76, 72, 68, 64, 60, 66, 72, 73, 69],
        "August": [69, 65, 61, 67, 73, 70, 66, 62, 58, 64, 70, 76, 68, 64, 60, 56, 62, 68, 74, 66, 62, 58, 54, 60, 66, 72, 64, 60, 56, 52, 58],
        "September": [59, 65, 61, 57, 53, 49, 55, 61, 67, 63, 59, 55, 51, 47, 53, 59, 65, 61, 57, 53, 49, 55, 61, 63, 59, 55, 51, 57, 63, 60],
        "October": [45, 48, 52, 38, 42, 55, 61, 58, 49, 43, 47, 51, 54, 48, 32, 39, 44, 56, 62, 71, 68, 55, 48, 41, 45, 52, 58, 61, 65, 59, 52]
    ]

    static func calendar(for month: String) -> [[Int?]] { calendars[month] ?? [] }
    static func trend(for month: String) -> [CGFloat] { trends[month] ?? [] }

    static func stats(for month: String) -> (average: Int, best: Int, worst: Int, bestDay: String, worstDay: String) {
        let data = (calendars[month] ?? []).flatMap { $0 }.compactMap { $0 }
        guard !data.isEmpty else { return (0, 0, 0, "—", "—") }
        let avg = data.reduce(0, +) / data.count
        let best = data.min() ?? 0
        let worst = data.max() ?? 0
        var counter = 1
        var bd = 1, wd = 1
        for w in (calendars[month] ?? []) {
            for v in w {
                if let v = v {
                    if v == best { bd = counter }
                    if v == worst { wd = counter }
                    counter += 1
                }
            }
        }
        let abbrev = String(month.prefix(3))
        return (avg, best, worst, "\(abbrev) \(bd)", "\(abbrev) \(wd)")
    }

    static func comparison(for month: String, in months: [String]) -> (percentage: Int, isBetter: Bool, previousMonthName: String) {
        guard let i = months.firstIndex(of: month), i > 0 else { return (0, true, "Previous") }
        let prev = months[i - 1]
        let current = stats(for: month).average
        let previous = stats(for: prev).average
        guard previous > 0 else { return (0, true, prev) }
        let diff = previous - current
        let pct = abs((diff * 100) / previous)
        return (pct, current < previous, prev)
    }

    static func dayNumber(month: String, week: Int, dow: Int) -> Int {
        let weeks = calendars[month] ?? []
        var counter = 1
        for w in 0..<weeks.count {
            for d in 0..<7 {
                if weeks[w][d] != nil {
                    if w == week && d == dow { return counter }
                    counter += 1
                }
            }
        }
        return counter
    }
}

// MARK: - Tip Popup (kept)

struct TipPopupView: View {
    @Environment(\.weatherTheme) private var theme
    let category: TipCategory
    let currentTip: String
    let onDismiss: () -> Void
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color(hex: category.color).opacity(0.2)).frame(width: 60, height: 60)
                        Image(systemName: category.icon)
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: category.color))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title).font(.title3.bold()).foregroundColor(theme.textTint)
                        Text("Tips & facts").font(.caption).foregroundColor(theme.textTint.opacity(0.5))
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.textTint.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.textTint.opacity(0.15)))
                    }
                }

                Text(currentTip)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textTint)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(theme.textTint.opacity(0.08)))

                Button(action: onNext) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Next tip")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: category.color).opacity(0.85)))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(theme.cardColor)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(theme.textTint.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
            )
            .padding(.horizontal, 28)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}

// MARK: - Daily Exposure Chart (preserved)

struct DailyExposureCircularChart: View {
    @Environment(\.weatherTheme) private var theme
    let selectedDay: DailyForecast
    @State private var selectedCategory = "All"
    let categories = ["All", "Home", "Work", "Outdoor"]

    var exposureData: (home: CGFloat, work: CGFloat, outdoor: CGFloat)? {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(selectedDay.date)
        let isPast = selectedDay.date < Date()
        guard isPast || isToday else { return nil }
        let dow = cal.component(.weekday, from: selectedDay.date)
        switch dow {
        case 1: return (8, 0, 2)
        case 2: return (5, 6, 2)
        case 3: return (6, 5, 3)
        case 4: return (6, 4, 3)
        case 5: return (6, 4, 3)
        case 6: return (5, 5, 4)
        case 7: return (7, 1, 4)
        default: return (6, 4, 3)
        }
    }

    var totalHours: CGFloat {
        guard let d = exposureData else { return 0 }
        return d.home + d.work + d.outdoor
    }
    var showHome: Bool { selectedCategory == "All" || selectedCategory == "Home" }
    var showWork: Bool { selectedCategory == "All" || selectedCategory == "Work" }
    var showOutdoor: Bool { selectedCategory == "All" || selectedCategory == "Outdoor" }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    ExposureCategoryTab(title: cat, isSelected: selectedCategory == cat) {
                        withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
                    }
                }
            }

            if let data = exposureData {
                ZStack {
                    ForEach(0..<24, id: \.self) { hour in
                        ExposureHourMarker(hour: hour, totalHours: totalHours)
                    }
                    ZStack {
                        if showHome {
                            ExposureSegmentArc(startHour: 0, endHour: data.home, color: Color(hex: "#FFD54F"))
                        }
                        if showWork {
                            ExposureSegmentArc(startHour: data.home, endHour: data.home + data.work, color: Color(hex: "#81C784"))
                        }
                        if showOutdoor {
                            ExposureSegmentArc(startHour: data.home + data.work, endHour: data.home + data.work + data.outdoor, color: Color(hex: "#FFA726"))
                        }
                    }
                    VStack(spacing: 6) {
                        if selectedCategory == "All" {
                            Image(systemName: "figure.stand").font(.system(size: 44)).foregroundColor(theme.textTint.opacity(0.35))
                            Text("\(Int(totalHours))h").font(.title3.bold()).foregroundColor(theme.textTint.opacity(0.7))
                            Text("Total").font(.caption).foregroundColor(theme.textTint.opacity(0.4))
                        } else {
                            let h = selectedCategory == "Home" ? data.home : selectedCategory == "Work" ? data.work : data.outdoor
                            Text("\(Int(h))h").font(.system(size: 40, weight: .heavy)).foregroundColor(theme.textTint)
                            Text(selectedCategory.uppercased()).font(.caption.bold()).foregroundColor(theme.textTint.opacity(0.7))
                        }
                    }
                }
                .frame(height: 220)
            } else {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 28, dash: [6, 6]))
                        .foregroundColor(theme.textTint.opacity(0.1))
                        .frame(width: 160, height: 160)
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock").font(.system(size: 40)).foregroundColor(theme.textTint.opacity(0.3))
                        Text("No data").font(.subheadline.bold()).foregroundColor(theme.textTint.opacity(0.6))
                        Text("Not available yet").font(.caption).foregroundColor(theme.textTint.opacity(0.4))
                    }
                }
                .frame(height: 220)
            }
        }
    }
}

struct ExposureCategoryTab: View {
    @Environment(\.weatherTheme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var catColor: Color {
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .white : theme.textTint.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? catColor.opacity(0.28) : theme.textTint.opacity(0.08))
                        .overlay(Capsule().stroke(isSelected ? catColor : .clear, lineWidth: 1.5))
                )
        }
    }
}

struct ExposureHourMarker: View {
    @Environment(\.weatherTheme) private var theme
    let hour: Int
    let totalHours: CGFloat

    var body: some View {
        VStack {
            Rectangle()
                .fill(theme.textTint.opacity(0.25))
                .frame(width: hour % 3 == 0 ? 2 : 1, height: hour % 3 == 0 ? 10 : 5)
            Spacer()
            if hour % 3 == 0 {
                Text("\(hour)")
                    .font(.system(size: 8))
                    .foregroundColor(theme.textTint.opacity(0.45))
                    .offset(y: -8)
            }
        }
        .frame(width: 90, height: 90)
        .rotationEffect(.degrees(Double(hour) * 15))
    }
}

struct ExposureSegmentArc: View {
    @Environment(\.weatherTheme) private var theme
    let startHour: CGFloat
    let endHour: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .trim(from: startHour / 24, to: endHour / 24)
            .stroke(color, lineWidth: 28)
            .frame(width: 160, height: 160)
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.35), radius: 6)
    }
}

// MARK: - Compact Exposure Chart

struct CompactExposureChart: View {
    @Environment(\.weatherTheme) private var theme
    let selectedDay: DailyForecast
    @State private var selectedCategory = "All"

    private let categories = ["All", "Home", "Work", "Outdoor"]

    private var exposureData: (home: CGFloat, work: CGFloat, outdoor: CGFloat)? {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(selectedDay.date)
        let isPast = selectedDay.date < Date()
        guard isPast || isToday else { return nil }
        let dow = cal.component(.weekday, from: selectedDay.date)
        switch dow {
        case 1: return (8, 0, 2)
        case 2: return (5, 6, 2)
        case 3: return (6, 5, 3)
        case 4: return (6, 4, 3)
        case 5: return (6, 4, 3)
        case 6: return (5, 5, 4)
        case 7: return (7, 1, 4)
        default: return (6, 4, 3)
        }
    }

    private var totalHours: CGFloat {
        guard let d = exposureData else { return 0 }
        return d.home + d.work + d.outdoor
    }

    private var showHome: Bool { selectedCategory == "All" || selectedCategory == "Home" }
    private var showWork: Bool { selectedCategory == "All" || selectedCategory == "Work" }
    private var showOutdoor: Bool { selectedCategory == "All" || selectedCategory == "Outdoor" }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let data = exposureData {
                    Circle().stroke(theme.textTint.opacity(0.08), lineWidth: 16)
                        .frame(width: 110, height: 110)

                    ZStack {
                        if showHome {
                            Circle().trim(from: 0, to: data.home / 24)
                                .stroke(Color(hex: "#FFD54F"), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .transition(.opacity)
                        }
                        if showWork {
                            Circle().trim(from: data.home / 24, to: (data.home + data.work) / 24)
                                .stroke(Color(hex: "#81C784"), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .transition(.opacity)
                        }
                        if showOutdoor {
                            Circle().trim(from: (data.home + data.work) / 24, to: (data.home + data.work + data.outdoor) / 24)
                                .stroke(Color(hex: "#FFA726"), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                                .transition(.opacity)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        if selectedCategory == "All" {
                            Text("\(Int(totalHours))h")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(theme.textTint)
                            Text("Total")
                                .font(.system(size: 9))
                                .foregroundColor(theme.textTint.opacity(0.5))
                        } else {
                            let h: CGFloat = {
                                switch selectedCategory {
                                case "Home": return data.home
                                case "Work": return data.work
                                case "Outdoor": return data.outdoor
                                default: return 0
                                }
                            }()
                            Text("\(Int(h))h")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(theme.textTint)
                            Text(selectedCategory.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(theme.textTint.opacity(0.6))
                        }
                    }
                } else {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 16, dash: [4, 4]))
                        .foregroundColor(theme.textTint.opacity(0.12))
                        .frame(width: 110, height: 110)
                    VStack(spacing: 3) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundColor(theme.textTint.opacity(0.3))
                        Text("No data")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.textTint.opacity(0.45))
                    }
                }
            }

            // Tabs grid 2x2 to fit narrow column
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    CompactExposureTab(title: "All", isSelected: selectedCategory == "All") { selectedCategory = "All" }
                    CompactExposureTab(title: "Home", isSelected: selectedCategory == "Home") { selectedCategory = "Home" }
                }
                HStack(spacing: 4) {
                    CompactExposureTab(title: "Work", isSelected: selectedCategory == "Work") { selectedCategory = "Work" }
                    CompactExposureTab(title: "Outdoor", isSelected: selectedCategory == "Outdoor") { selectedCategory = "Outdoor" }
                }
            }
        }
    }
}

struct CompactExposureTab: View {
    @Environment(\.weatherTheme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color {
        switch title {
        case "Home": return Color(hex: "#FFD54F")
        case "Work": return Color(hex: "#81C784")
        case "Outdoor": return Color(hex: "#FFA726")
        default: return .white
        }
    }

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { action() } }) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isSelected ? .white : theme.textTint.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? tint.opacity(0.3) : theme.textTint.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? tint : .clear, lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DailyForecastView()
    }
}
