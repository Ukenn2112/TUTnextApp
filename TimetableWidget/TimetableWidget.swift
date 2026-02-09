//
//  TimetableWidget.swift
//  TimetableWidget
//
//  Refactored for iOS 17+ with Glassmorphism Design System
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - App Intent Configuration

struct TimetableConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "時間割表設定" }
    static var description: IntentDescription { "時間割を表示します。" }
    
    @Parameter(title: "表示する曜日", default: .current)
    var weekday: WeekdaySelection?
    
    @Parameter(title: "強調表示", default: true)
    var highlightCurrent: Bool
}

enum WeekdaySelection: String, AppEnum {
    case current
    case monday
    case tuesday
    wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "表示曜日")
    }
    
    static var caseDisplayRepresentations: [WeekdaySelection: DisplayRepresentation] = [
        .current: DisplayRepresentation(title: "現在の日付"),
        .monday: DisplayRepresentation(title: "月曜日"),
        .tuesday: DisplayRepresentation(title: "火曜日"),
        .wednesday: DisplayRepresentation(title: "水曜日"),
        .thursday: DisplayRepresentation(title: "木曜日"),
        .friday: DisplayRepresentation(title: "金曜日"),
        .saturday: DisplayRepresentation(title: "土曜日"),
        .sunday: DisplayRepresentation(title: "日曜日"),
    ]
}

// MARK: - Entry Model

struct TimetableEntry: TimelineEntry {
    let date: Date
    let courses: [String: [String: Course]]?
    let lastFetchTime: Date?
    let configuration: TimetableConfigurationIntent
}

// MARK: - Timeline Provider

struct TimetableProvider: AppIntentTimelineProvider {
    typealias Entry = TimetableEntry
    typealias Intent = TimetableConfigurationIntent
    
    func placeholder(in context: Context) -> Entry {
        Entry(
            date: Date(),
            courses: SampleDataProvider.sampleCourses,
            lastFetchTime: Date(),
            configuration: TimetableConfigurationIntent()
        )
    }
    
    func snapshot(for configuration: TimetableConfigurationIntent, in context: Context) async -> Entry {
        let dataProvider = TimetableWidgetDataProvider.shared
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        
        let entryCourses = courses ?? (context.isPreview ? SampleDataProvider.sampleCourses : [:])
        
        return Entry(
            date: Date(),
            courses: entryCourses,
            lastFetchTime: lastFetchTime,
            configuration: configuration
        )
    }
    
    func timeline(for configuration: TimetableConfigurationIntent, in context: Context) async -> Timeline<TimetableEntry> {
        let dataProvider = TimetableWidgetDataProvider.shared
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        
        let entryCourses = courses ?? (context.isPreview ? SampleDataProvider.sampleCourses : [:])
        let currentDate = Date()
        
        let entry = Entry(
            date: currentDate,
            courses: entryCourses,
            lastFetchTime: lastFetchTime,
            configuration: configuration
        )
        
        // Calculate next update time
        let nextUpdateDate = calculateNextUpdate(currentDate: currentDate, dataProvider: dataProvider)
        
        return Timeline(entries: [entry], policy: .after(nextUpdateDate))
    }
    
    private func calculateNextUpdate(currentDate: Date, dataProvider: TimetableWidgetDataProvider) -> Date {
        let calendar = Calendar.current
        var updateTimes: [Date] = []
        
        // Regular update every 10 minutes
        if let tenMinutesLater = calendar.date(byAdding: .minute, value: 10, to: currentDate) {
            updateTimes.append(tenMinutesLater)
        }
        
        // Update at class start/end times
        let periods = dataProvider.getPeriods()
        for (_, startTimeStr, endTimeStr) in periods {
            if let startComponents = parseTimeString(startTimeStr) {
                let startComponents = DateComponents(
                    year: calendar.component(.year, from: currentDate),
                    month: calendar.component(.month, from: currentDate),
                    day: calendar.component(.day, from: currentDate),
                    hour: startComponents.hour,
                    minute: startComponents.minute
                )
                if let startDate = calendar.date(from: startComponents), startDate > currentDate {
                    updateTimes.append(startDate.addingTimeInterval(-300)) // 5 minutes before
                    updateTimes.append(startDate)
                    updateTimes.append(startDate.addingTimeInterval(180)) // 3 minutes after
                }
            }
            
            if let endComponents = parseTimeString(endTimeStr) {
                let endComponents = DateComponents(
                    year: calendar.component(.year, from: currentDate),
                    month: calendar.component(.month, from: currentDate),
                    day: calendar.component(.day, from: currentDate),
                    hour: endComponents.hour,
                    minute: endComponents.minute
                )
                if let endDate = calendar.date(from: endComponents), endDate > currentDate {
                    updateTimes.append(endDate.addingTimeInterval(-300)) // 5 minutes before
                    updateTimes.append(endDate)
                    updateTimes.append(endDate.addingTimeInterval(60)) // 1 minute after
                }
            }
        }
        
        // Update at midnight
        var nextMidnight = calendar.startOfDay(for: currentDate)
        nextMidnight = calendar.date(byAdding: .day, value: 1, to: nextMidnight)!
        updateTimes.append(nextMidnight.addingTimeInterval(-300))
        updateTimes.append(nextMidnight)
        updateTimes.append(nextMidnight.addingTimeInterval(300))
        
        // Update immediately if data is old
        if let fetchTime = lastFetchTime, currentDate.timeIntervalSince(fetchTime) > 1800 {
            updateTimes.append(currentDate.addingTimeInterval(60))
        } else if lastFetchTime == nil {
            updateTimes.append(currentDate.addingTimeInterval(60))
        }
        
        // Update more frequently during class hours
        if dataProvider.getCurrentPeriod() != nil {
            if let fiveMinutesLater = calendar.date(byAdding: .minute, value: 5, to: currentDate) {
                updateTimes.append(fiveMinutesLater)
            }
        }
        
        updateTimes.sort()
        return updateTimes.first ?? calendar.date(byAdding: .minute, value: 15, to: currentDate)!
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour: hour, minute: minute)
    }
}

// MARK: - Widget View

struct TimetableWidgetEntryView: View {
    var entry: TimetableEntry
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GlassWidgetContainer(colorScheme: colorScheme) {
            switch widgetFamily {
            case .systemLarge:
                LargeTimetableView(entry: entry)
                    .widgetURL(URL(string: "tama://timetable"))
            case .systemMedium:
                MediumTimetableView(entry: entry)
                    .widgetURL(URL(string: "tama://timetable"))
            case .systemSmall:
                SmallTimetableView(entry: entry)
                    .widgetURL(URL(string: "tama://timetable"))
            default:
                Text("Unsupported widget size")
                    .font(.caption)
                    .widgetURL(URL(string: "tama://timetable"))
            }
        }
    }
}

// MARK: - Glass Widget Container

struct GlassWidgetContainer<Content: View>: View {
    let colorScheme: ColorScheme
    let content: Content
    
    init(colorScheme: ColorScheme, @ViewBuilder content: () -> Content) {
        self.colorScheme = colorScheme
        self.content = content()
    }
    
    var body: some View {
        content
            .glassEffect(
                opacity: colorScheme == .dark ? 0.45 : 0.35,
                blurRadius: 20,
                cornerRadius: 16
            )
    }
}

// MARK: - Large Widget View

struct LargeTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme
    
    private let dataProvider = TimetableWidgetDataProvider.shared
    private let itemSpacing: CGFloat = 2
    private let timeColumnWidth: CGFloat = 12
    private let cellHeight: CGFloat = 32
    
    private var currentWeekday: String {
        dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: -8) {
                weekdayHeaderView()
                timeTableGridView()
            }
            .padding(EdgeInsets(top: -8, leading: -12, bottom: -4, trailing: -2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private func weekdayHeaderView() -> some View {
        HStack(spacing: itemSpacing) {
            Text("")
                .frame(width: timeColumnWidth + 2)
            
            ForEach(dataProvider.getWeekdays(), id: \.self) { day in
                if day == currentWeekday {
                    currentDayBadge(day: day)
                } else {
                    Text(dataProvider.getWeekdayDisplayString(from: day))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 12)
    }
    
    private func currentDayBadge(day: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(ThemeColors.Semantic.success)
                .frame(height: 12)
            Text(dataProvider.getWeekdayDisplayString(from: day))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func timeTableGridView() -> some View {
        VStack(spacing: itemSpacing) {
            ForEach(dataProvider.getPeriods(), id: \.0) { periodInfo in
                let period = periodInfo.0
                HStack(spacing: itemSpacing) {
                    timeColumnView(period: period)
                    periodRowView(period: period)
                }
            }
        }
    }
    
    private func timeColumnView(period: String) -> some View {
        Text(period)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: timeColumnWidth, height: cellHeight)
    }
    
    private func periodRowView(period: String) -> some View {
        HStack(spacing: itemSpacing) {
            ForEach(dataProvider.getWeekdays(), id: \.self) { day in
                TimeSlotCellWidget(
                    dayIndex: day,
                    displayDay: dataProvider.getWeekdayDisplayString(from: day),
                    period: period,
                    course: entry.courses?[day]?[period],
                    isCurrentDay: day == currentWeekday,
                    isCurrentPeriod: period == currentPeriod,
                    colorScheme: colorScheme
                )
            }
        }
    }
}

// MARK: - Time Slot Cell

struct TimeSlotCellWidget: View {
    let dayIndex: String
    let displayDay: String
    let period: String
    let course: Course?
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool
    let colorScheme: ColorScheme
    
    private var backgroundColor: Color {
        guard let course = course else {
            return Color.clear
        }
        let baseColor = CourseColorPalette.getColor(for: course.colorIndex)
        return colorScheme == .dark ? baseColor.opacity(0.7) : baseColor.opacity(0.9)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            (isCurrentDay && isCurrentPeriod)
                                ? ThemeColors.Semantic.success.opacity(0.9)
                                : (colorScheme == .dark
                                    ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)),
                            lineWidth: (isCurrentDay && isCurrentPeriod) ? 1.2 : 0.6
                        )
                )
                .shadow(
                    color: (isCurrentDay && isCurrentPeriod)
                        ? ThemeColors.Semantic.success.opacity(0.3) : .clear,
                    radius: 1, x: 0, y: 0
                )
            
            if let course = course {
                VStack(spacing: 0) {
                    Text(course.name.replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: ""))
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.primary)
                    Text(course.room)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 1))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget View

struct SmallTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme
    
    private let dataProvider = TimetableWidgetDataProvider.shared
    
    private var currentWeekday: String {
        dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        VStack(spacing: 2) {
            headerView
            Divider()
                .padding(.horizontal, 4)
            courseContentView
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
    
    private var headerView: some View {
        HStack {
            Text("時間割")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            Text(dataProvider.getWeekdayDisplayString(from: currentWeekday))
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(ThemeColors.Semantic.success.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private var courseContentView: some View {
        if let currentCourse = getCurrentCourse() {
            VStack(spacing: 2) {
                currentCourseView(course: currentCourse, isCurrentCourse: true)
                
                if let nextCourse = getNextCourse() {
                    Divider()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                    currentCourseView(course: nextCourse, isCurrentCourse: false)
                }
            }
        } else if let nextCourse = getNextCourse() {
            currentCourseView(course: nextCourse, isCurrentCourse: false)
        } else if isLastCourseOfDay() {
            Text("本日の授業は終了")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Text("本日の授業はありません")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 6)
        }
    }
    
    private func getCurrentCourse() -> Course? {
        guard let courses = entry.courses?[currentWeekday],
              let currentPeriod = currentPeriod,
              let currentCourse = courses[currentPeriod] else {
            return nil
        }
        return currentCourse
    }
    
    private func getNextCourse() -> Course? {
        guard let courses = entry.courses?[currentWeekday] else { return nil }
        
        if let currentPeriod = currentPeriod.flatMap(Int.init) {
            let nextPeriodInt = currentPeriod + 1
            if nextPeriodInt <= 7, let nextCourse = courses[String(nextPeriodInt)] {
                return nextCourse
            }
        }
        
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute
        
        let sortedCourses = courses.values.sorted {
            let time1 = getTimeForPeriod($0.period ?? 0)
            let time2 = getTimeForPeriod($1.period ?? 0)
            return time1 < time2
        }
        
        for course in sortedCourses {
            let time = getTimeForPeriod(course.period ?? 0)
            if time > currentTime {
                return course
            }
        }
        
        return nil
    }
    
    private func getTimeForPeriod(_ period: Int) -> Int {
        guard period > 0 && period <= 7 else { return 0 }
        let periodData = dataProvider.getPeriods()[period - 1]
        if let startComponents = parseTimeString(periodData.1) {
            return startComponents.hour * 60 + startComponents.minute
        }
        return 0
    }
    
    private func isLastCourseOfDay() -> Bool {
        guard let courses = entry.courses?[currentWeekday], !courses.isEmpty else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute
        
        if let currentPeriodInt = currentPeriod.flatMap(Int.init) {
            return !courses.values.contains { ($0.period ?? 0) > currentPeriodInt }
        } else {
            return !courses.values.contains { course in
                if let period = course.period, period > 0 && period <= 7 {
                    let time = getTimeForPeriod(period)
                    return time > currentTime
                }
                return false
            }
        }
    }
    
    private func currentCourseView(course: Course, isCurrentCourse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if let period = course.period {
                    Text("\(period)限")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(ThemeColors.Semantic.success.opacity(0.8))
                        .cornerRadius(3)
                }
                
                Text(isCurrentCourse ? "現在の授業" : "次の授業")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(course.name.replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                
                HStack {
                    Text(course.room)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let period = course.period {
                        let periodInfo = dataProvider.getPeriods()[period - 1]
                        Text("\(periodInfo.1)-\(periodInfo.2)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(CourseColorPalette.getColor(for: course.colorIndex))
                    .opacity(colorScheme == .dark ? 0.7 : 0.9)
            )
            .padding(.horizontal, 4)
        }
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour: hour, minute: minute)
    }
}

// MARK: - Medium Widget View

struct MediumTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme
    
    private let dataProvider = TimetableWidgetDataProvider.shared
    
    private var currentWeekday: String {
        dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("時間割")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text(dataProvider.getWeekdayDisplayString(from: currentWeekday))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(ThemeColors.Semantic.success.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            
            dailyTimetableGridView()
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }
    
    private func dailyTimetableGridView() -> some View {
        let todayCourses = getTodayCourses()
        let sortedPeriods = getSortedPeriods(from: todayCourses)
        
        if sortedPeriods.isEmpty {
            return AnyView(
                Text("本日の授業はありません")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
        
        return AnyView(
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    ForEach(sortedPeriods, id: \.self) { period in
                        Text("\(period)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 16)
                    }
                }
                
                HStack(spacing: 4) {
                    ForEach(sortedPeriods, id: \.self) { periodStr in
                        if let course = todayCourses.first(where: { $0.period == Int(periodStr) }) {
                            courseCellView(course: course, isCurrentPeriod: periodStr == currentPeriod)
                        } else {
                            emptyCellView(isCurrentPeriod: periodStr == currentPeriod)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        )
    }
    
    private func courseCellView(course: Course, isCurrentPeriod: Bool) -> some View {
        VStack(spacing: 2) {
            Text(course.name.replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: ""))
                .font(.system(size: 9, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .foregroundColor(.primary)
            
            Text(course.room)
                .font(.system(size: 7))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CourseColorPalette.getColor(for: course.colorIndex))
                .opacity(colorScheme == .dark ? 0.7 : 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isCurrentPeriod
                        ? ThemeColors.Semantic.success.opacity(0.9)
                        : (colorScheme == .dark
                            ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)),
                    lineWidth: isCurrentPeriod ? 1.2 : 0.6
                )
        )
    }
    
    private func emptyCellView(isCurrentPeriod: Bool) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isCurrentPeriod
                            ? ThemeColors.Semantic.success.opacity(0.9)
                            : (colorScheme == .dark
                                ? Color.gray.opacity(0.4) : Color.gray.opacity(0.25)),
                        lineWidth: isCurrentPeriod ? 1.2 : 0.5
                    )
            )
    }
    
    private func getSortedPeriods(from courses: [Course]) -> [String] {
        let periods = courses.compactMap { $0.period }.map { String($0) }
        let sortedActualPeriods = Array(Set(periods)).sorted { Int($0)! < Int($1)! }
        
        let minimumPeriods = (1...5).map { String($0) }
        var allPeriods = Set(minimumPeriods)
        for period in sortedActualPeriods {
            allPeriods.insert(period)
        }
        
        return Array(allPeriods).sorted { Int($0)! < Int($1)! }
    }
    
    private func getTodayCourses() -> [Course] {
        guard let courses = entry.courses?[currentWeekday] else { return [] }
        return Array(courses.values)
    }
}

// MARK: - Course Color Palette

struct CourseColorPalette {
    private static let colors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 0.9, blue: 0.8),
        Color(red: 1.0, green: 1.0, blue: 0.8),
        Color(red: 0.9, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 1.0),
        Color(red: 1.0, green: 0.8, blue: 0.9),
        Color(red: 0.9, green: 0.8, blue: 1.0),
        Color(red: 0.8, green: 0.9, blue: 1.0),
        Color(red: 1.0, green: 0.9, blue: 1.0),
    ]
    
    static func getColor(for index: Int) -> Color {
        guard index >= 0 && index < colors.count else {
            return colors[0]
        }
        return colors[index]
    }
}

// MARK: - Sample Data Provider

struct SampleDataProvider {
    static let sampleCourses: [String: [String: Course]] = [
        "1": [
            "1": Course(
                name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝",
                startTime: "0900", endTime: "1030", colorIndex: 1,
                weekday: .monday, period: 1, jugyoCd: "CD001"
            ),
            "2": Course(
                name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一",
                startTime: "1040", endTime: "1210", colorIndex: 2,
                weekday: .monday, period: 2, jugyoCd: "CS001"
            ),
        ],
        "2": [
            "1": Course(
                name: "経営情報特講", room: "201", teacher: "青木 克彦",
                startTime: "0900", endTime: "1030", colorIndex: 3,
                weekday: .tuesday, period: 1, jugyoCd: "KJ001"
            ),
        ],
        "3": [
            "3": Course(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道",
                startTime: "1300", endTime: "1430", colorIndex: 4,
                weekday: .wednesday, period: 3, jugyoCd: "WP001"
            ),
        ],
        "4": [
            "1": Course(
                name: "経営科学", room: "212", teacher: "新西 誠人",
                startTime: "0900", endTime: "1030", colorIndex: 5,
                weekday: .thursday, period: 1, jugyoCd: "KK001"
            ),
        ],
        "5": [
            "3": Course(
                name: "図化技概論", room: "201", teacher: "出原 至道",
                startTime: "1300", endTime: "1430", colorIndex: 6,
                weekday: .friday, period: 3, jugyoCd: "ZG002"
            ),
        ],
    ]
}

// MARK: - Widget Definition

struct TimetableWidget: Widget {
    let kind: String = "TimetableWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TimetableConfigurationIntent.self,
            provider: TimetableProvider()
        ) { entry in
            TimetableWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    glassBackground
                }
                .widgetURL(URL(string: "tama://timetable")!)
        }
        .configurationDisplayName("時間割表")
        .description("時間割を表示します")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .disableContentMarginsIfAvailable()
    }
    
    private var glassBackground: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    ThemeColors.Gradient.startGradient(for: .light),
                    ThemeColors.Gradient.endGradient(for: .light)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                GlassBackground(
                    opacity: 0.3,
                    blurRadius: 20,
                    saturation: 1.5,
                    borderOpacity: 0.3,
                    cornerRadius: 16
                )
            }
        }
    }
}

// MARK: - Previews

struct TimetableWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TimetableWidgetEntryView(
                entry: TimetableEntry(
                    date: Date(),
                    courses: SampleDataProvider.sampleCourses,
                    lastFetchTime: Date(),
                    configuration: TimetableConfigurationIntent()
                )
            )
            .containerBackground(
                LinearGradient(
                    colors: [ThemeColors.Gradient.startGradient(for: .light),
                             ThemeColors.Gradient.endGradient(for: .light)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                for: .widget
            )
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            
            TimetableWidgetEntryView(
                entry: TimetableEntry(
                    date: Date(),
                    courses: SampleDataProvider.sampleCourses,
                    lastFetchTime: Date(),
                    configuration: TimetableConfigurationIntent()
                )
            )
            .containerBackground(
                LinearGradient(
                    colors: [ThemeColors.Gradient.startGradient(for: .light),
                             ThemeColors.Gradient.endGradient(for: .light)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                for: .widget
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            TimetableWidgetEntryView(
                entry: TimetableEntry(
                    date: Date(),
                    courses: SampleDataProvider.sampleCourses,
                    lastFetchTime: Date(),
                    configuration: TimetableConfigurationIntent()
                )
            )
            .containerBackground(
                LinearGradient(
                    colors: [ThemeColors.Gradient.startGradient(for: .light),
                             ThemeColors.Gradient.endGradient(for: .light)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                for: .widget
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
