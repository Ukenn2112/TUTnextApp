import SwiftUI
import WidgetKit

// MARK: - ヘルパー

/// 時間構成要素
private struct TimeComponents {
    let hour: Int
    let minute: Int

    var totalMinutes: Int { hour * 60 + minute }
}

/// 時間文字列（"HH:MM"）をパースして構成要素を返す
private func parseTimeString(_ timeString: String) -> TimeComponents? {
    let components = timeString.split(separator: ":")
    guard components.count == 2,
        let hour = Int(components[0]),
        let minute = Int(components[1])
    else { return nil }
    return TimeComponents(hour: hour, minute: minute)
}

/// 授業名のクリーンアップ
private extension String {
    func cleanedCourseName() -> String {
        replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: "")
    }
}

/// セルのボーダースタイル
private struct CellBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isCurrentPeriod: Bool
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isCurrentPeriod
                            ? Color.green.opacity(0.9)
                            : (colorScheme == .dark
                                ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)),
                        lineWidth: isCurrentPeriod ? 1.2 : 0.6
                    )
            )
    }
}

private extension View {
    func cellBorder(
        cornerRadius: CGFloat = 6, isCurrentPeriod: Bool, colorScheme: ColorScheme
    ) -> some View {
        modifier(
            CellBorderModifier(
                cornerRadius: cornerRadius, isCurrentPeriod: isCurrentPeriod,
                colorScheme: colorScheme))
    }
}

// MARK: - モデル

struct TimetableEntry: TimelineEntry {
    let date: Date
    let courses: [String: [String: CourseModel]]?
    let lastFetchTime: Date?
    let currentWeekday: String
    let currentPeriod: String?

    init(
        date: Date,
        courses: [String: [String: CourseModel]]?,
        lastFetchTime: Date?,
        dataProvider: TimetableWidgetDataProvider = .shared
    ) {
        self.date = date
        self.courses = courses
        self.lastFetchTime = lastFetchTime
        self.currentWeekday = dataProvider.getCurrentWeekday()
        self.currentPeriod = dataProvider.getCurrentPeriod()
    }
}

// MARK: - タイムラインプロバイダー

struct Provider: TimelineProvider {
    typealias Entry = TimetableEntry

    func placeholder(in context: Context) -> Entry {
        TimetableEntry(
            date: Date(),
            courses: CourseModel.sampleCourses,
            lastFetchTime: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(createEntry(at: Date(), context: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let entry = createEntry(at: currentDate, context: context)
        let nextUpdateDate = calculateNextUpdate(from: currentDate, entry: entry)

        completion(Timeline(entries: [entry], policy: .after(nextUpdateDate)))
    }

    // MARK: エントリ作成

    private func createEntry(at date: Date, context: Context) -> TimetableEntry {
        let dataProvider = TimetableWidgetDataProvider.shared
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        let entryCourses = courses ?? (context.isPreview ? CourseModel.sampleCourses : [:])

        return TimetableEntry(
            date: date,
            courses: entryCourses,
            lastFetchTime: lastFetchTime,
            dataProvider: dataProvider
        )
    }

    // MARK: 更新時刻計算

    private func calculateNextUpdate(from currentDate: Date, entry: Entry) -> Date {
        let dataProvider = TimetableWidgetDataProvider.shared
        let calendar = Calendar.current
        var updateTimes: [Date] = []

        // 定期更新（10分ごと）
        updateTimes.append(currentDate.addingTimeInterval(10 * 60))

        // 授業時間前後の更新
        addClassUpdateTimes(
            to: &updateTimes, from: currentDate,
            dataProvider: dataProvider, calendar: calendar)

        // 翌日0時の更新
        addMidnightUpdate(to: &updateTimes, from: currentDate, calendar: calendar)

        // データが古い場合の即座更新
        addStaleDataUpdate(
            to: &updateTimes, from: currentDate,
            lastFetchTime: entry.lastFetchTime, calendar: calendar)

        // 授業中の頻繁な更新
        if entry.currentPeriod != nil {
            updateTimes.append(currentDate.addingTimeInterval(5 * 60))
        }

        return updateTimes.sorted().first ?? currentDate.addingTimeInterval(15 * 60)
    }

    private func addClassUpdateTimes(
        to updateTimes: inout [Date], from currentDate: Date,
        dataProvider: TimetableWidgetDataProvider, calendar: Calendar
    ) {
        let periods = dataProvider.getPeriods()

        for (_, startTimeStr, endTimeStr) in periods {
            // 授業開始時間
            if let start = parseTimeString(startTimeStr),
                let startDate = calendar.date(
                    from: makeDateComponents(
                        from: currentDate, hour: start.hour, minute: start.minute,
                        calendar: calendar))
            {
                appendIfFuture(
                    calendar.date(byAdding: .minute, value: -5, to: startDate),
                    after: currentDate, to: &updateTimes)
                appendIfFuture(startDate, after: currentDate, to: &updateTimes)
                appendIfFuture(
                    calendar.date(byAdding: .minute, value: 3, to: startDate),
                    after: currentDate, to: &updateTimes)
            }

            // 授業終了時間
            if let end = parseTimeString(endTimeStr),
                let endDate = calendar.date(
                    from: makeDateComponents(
                        from: currentDate, hour: end.hour, minute: end.minute,
                        calendar: calendar))
            {
                appendIfFuture(
                    calendar.date(byAdding: .minute, value: -5, to: endDate),
                    after: currentDate, to: &updateTimes)
                appendIfFuture(endDate, after: currentDate, to: &updateTimes)
                appendIfFuture(
                    calendar.date(byAdding: .minute, value: 1, to: endDate),
                    after: currentDate, to: &updateTimes)
            }
        }
    }

    private func addMidnightUpdate(
        to updateTimes: inout [Date], from currentDate: Date, calendar: Calendar
    ) {
        guard
            let nextMidnight = calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: currentDate),
                    month: calendar.component(.month, from: currentDate),
                    day: calendar.component(.day, from: currentDate) + 1,
                    hour: 0, minute: 0, second: 0
                ))
        else { return }

        if let fiveMinBefore = calendar.date(byAdding: .minute, value: -5, to: nextMidnight) {
            updateTimes.append(fiveMinBefore)
        }
        updateTimes.append(nextMidnight)
        if let fiveMinAfter = calendar.date(byAdding: .minute, value: 5, to: nextMidnight) {
            updateTimes.append(fiveMinAfter)
        }
    }

    private func addStaleDataUpdate(
        to updateTimes: inout [Date], from currentDate: Date,
        lastFetchTime: Date?, calendar: Calendar
    ) {
        let shouldUpdateSoon: Bool
        if let fetchTime = lastFetchTime {
            shouldUpdateSoon = currentDate.timeIntervalSince(fetchTime) > 30 * 60
        } else {
            shouldUpdateSoon = true
        }

        if shouldUpdateSoon {
            let immediateUpdate =
                calendar.date(byAdding: .minute, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(60)
            updateTimes.append(immediateUpdate)
        }
    }

    // MARK: ユーティリティ

    private func makeDateComponents(
        from date: Date, hour: Int, minute: Int, calendar: Calendar
    ) -> DateComponents {
        DateComponents(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date),
            hour: hour,
            minute: minute
        )
    }

    private func appendIfFuture(
        _ date: Date?, after currentDate: Date, to times: inout [Date]
    ) {
        guard let date = date, date > currentDate else { return }
        times.append(date)
    }
}

// MARK: - ウィジェットビュー

struct TimetableWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemLarge:
                LargeTimetableView(entry: entry)
            case .systemMedium:
                MediumTimetableView(entry: entry)
            case .systemSmall:
                SmallTimetableView(entry: entry)
            default:
                Text("このサイズはサポートされていません")
                    .font(.system(size: 10))
            }
        }
        .widgetURL(URL(string: "tama://timetable"))
    }
}

// MARK: - ラージウィジェット

struct LargeTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme

    private let dataProvider = TimetableWidgetDataProvider.shared
    private let itemSpacing: CGFloat = 2
    private let timeColumnWidth: CGFloat = 12
    private let cellHeight: CGFloat = 32
    private let weekdaySpacing: CGFloat = 2
    private let periodSpacing: CGFloat = 2

    var body: some View {
        VStack(spacing: weekdaySpacing) {
            weekdayHeaderView()
            timeTableGridView()
        }
        .padding(EdgeInsets(top: -8, leading: -12, bottom: -4, trailing: -2))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: 曜日ヘッダー

    private func weekdayHeaderView() -> some View {
        HStack(spacing: itemSpacing) {
            Text("")
                .frame(width: timeColumnWidth + periodSpacing)

            ForEach(dataProvider.getWeekdays(), id: \.self) { day in
                if day == entry.currentWeekday {
                    currentDayView(day: day)
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

    private func currentDayView(day: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green)
                .frame(height: 12)
            Text(dataProvider.getWeekdayDisplayString(from: day))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 時間割グリッド

    private func timeTableGridView() -> some View {
        VStack(spacing: itemSpacing) {
            ForEach(dataProvider.getPeriods(), id: \.0) { periodInfo in
                let period = periodInfo.0

                HStack(spacing: itemSpacing) {
                    Text(period)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: timeColumnWidth, height: cellHeight)
                        .padding(.trailing, periodSpacing)

                    HStack(spacing: itemSpacing) {
                        ForEach(dataProvider.getWeekdays(), id: \.self) { day in
                            TimeSlotCellWidget(
                                period: period,
                                course: entry.courses?[day]?[period],
                                isCurrentDay: day == entry.currentWeekday,
                                isCurrentPeriod: period == entry.currentPeriod
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - スモールウィジェット

struct SmallTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme

    private let dataProvider = TimetableWidgetDataProvider.shared

    var body: some View {
        VStack(spacing: 2) {
            headerView()

            Divider()
                .padding(.horizontal, 4)

            contentView()

            Spacer()
        }
    }

    // MARK: ヘッダー

    private func headerView() -> some View {
        HStack {
            Text("時間割")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Text(dataProvider.getWeekdayDisplayString(from: entry.currentWeekday))
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: コンテンツ

    @ViewBuilder
    private func contentView() -> some View {
        if let currentCourse = getCurrentCourse() {
            VStack(spacing: 2) {
                courseCardView(course: currentCourse, label: "現在の授業")

                if let nextCourse = getNextCourse() {
                    Divider()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                    courseCardView(course: nextCourse, label: "次の授業")
                }
            }
        } else if let nextCourse = getNextCourse() {
            courseCardView(course: nextCourse, label: "次の授業")
        } else if hasCoursesFinished() {
            Text("本日の授業は終了しました")
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

    // MARK: 授業カード

    private func courseCardView(course: CourseModel, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if let period = course.period {
                    Text("\(period)限")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(3)
                }

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(course.name.cleanedCourseName())
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                HStack {
                    Text(course.room)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    if let period = course.period, period > 0, period <= dataProvider.getPeriods().count {
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
                    .fill(WidgetColorPalette.getColor(for: course.colorIndex))
                    .opacity(colorScheme == .dark ? 0.7 : 0.9)
            )
            .padding(.horizontal, 4)
        }
    }

    // MARK: データ取得

    private func getCurrentCourse() -> CourseModel? {
        guard let courses = entry.courses?[entry.currentWeekday],
            let currentPeriod = entry.currentPeriod
        else { return nil }
        return courses[currentPeriod]
    }

    private func getNextCourse() -> CourseModel? {
        guard let courses = entry.courses?[entry.currentWeekday] else { return nil }

        // 現在の時限がある場合、次の時限の授業を探す
        if let currentPeriod = entry.currentPeriod,
            let currentInt = Int(currentPeriod),
            currentInt < 7
        {
            let nextPeriod = String(currentInt + 1)
            if let nextCourse = courses[nextPeriod] {
                return nextCourse
            }
        }

        // 現在時限がない場合、現在時刻より後の最初の授業を探す
        let currentMinutes = currentTimeInMinutes()
        let periods = dataProvider.getPeriods()

        return courses.values
            .filter { course in
                guard let period = course.period, period > 0, period <= periods.count else {
                    return false
                }
                let startTimeStr = periods[period - 1].1
                guard let start = parseTimeString(startTimeStr) else { return false }
                return start.totalMinutes > currentMinutes
            }
            .sorted { ($0.period ?? 0) < ($1.period ?? 0) }
            .first
    }

    private func hasCoursesFinished() -> Bool {
        guard let courses = entry.courses?[entry.currentWeekday], !courses.isEmpty else {
            return false
        }

        let currentMinutes = currentTimeInMinutes()
        let periods = dataProvider.getPeriods()

        if let currentPeriod = entry.currentPeriod, let currentInt = Int(currentPeriod) {
            return !courses.values.contains { ($0.period ?? 0) > currentInt }
        }

        return !courses.values.contains { course in
            guard let period = course.period, period > 0, period <= periods.count else {
                return false
            }
            let startTimeStr = periods[period - 1].1
            guard let start = parseTimeString(startTimeStr) else { return false }
            return start.totalMinutes > currentMinutes
        }
    }

    private func currentTimeInMinutes() -> Int {
        let now = Date()
        let calendar = Calendar.current
        return calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    }
}

// MARK: - ミディアムウィジェット

struct MediumTimetableView: View {
    let entry: TimetableEntry
    @Environment(\.colorScheme) var colorScheme

    private let dataProvider = TimetableWidgetDataProvider.shared

    var body: some View {
        VStack(spacing: 4) {
            headerView()
            dailyTimetableGridView()
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }

    // MARK: ヘッダー

    private func headerView() -> some View {
        HStack {
            Text("時間割")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Text(dataProvider.getWeekdayDisplayString(from: entry.currentWeekday))
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    // MARK: 時間割グリッド

    @ViewBuilder
    private func dailyTimetableGridView() -> some View {
        let todayCourses = getTodayCourses()
        let sortedPeriods = getSortedPeriods(from: todayCourses)

        if sortedPeriods.isEmpty {
            Text("本日の授業はありません")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
                            courseCellView(
                                course: course, isCurrentPeriod: periodStr == entry.currentPeriod)
                        } else {
                            emptyCellView(isCurrentPeriod: periodStr == entry.currentPeriod)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: セルビュー

    private func courseCellView(course: CourseModel, isCurrentPeriod: Bool) -> some View {
        VStack(spacing: 2) {
            Text(course.name.cleanedCourseName())
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
                .fill(WidgetColorPalette.getColor(for: course.colorIndex))
                .opacity(colorScheme == .dark ? 0.7 : 0.9)
        )
        .cellBorder(isCurrentPeriod: isCurrentPeriod, colorScheme: colorScheme)
    }

    private func emptyCellView(isCurrentPeriod: Bool) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isCurrentPeriod
                            ? Color.green.opacity(0.9)
                            : (colorScheme == .dark
                                ? Color.gray.opacity(0.4) : Color.gray.opacity(0.25)),
                        lineWidth: isCurrentPeriod ? 1.2 : 0.5)
            )
    }

    // MARK: データ取得

    private func getSortedPeriods(from courses: [CourseModel]) -> [String] {
        let actualPeriods = Set(courses.compactMap { $0.period }.map { String($0) })
        let minimumPeriods = Set((1...5).map { String($0) })
        return actualPeriods.union(minimumPeriods).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private func getTodayCourses() -> [CourseModel] {
        guard let courses = entry.courses?[entry.currentWeekday] else { return [] }
        return Array(courses.values)
    }
}

// MARK: - サブビュー

struct TimeSlotCellWidget: View {
    let period: String
    let course: CourseModel?
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool
    @Environment(\.colorScheme) var colorScheme

    private var adjustedBackgroundColor: Color {
        guard let course = course else { return Color.clear }
        let baseColor = WidgetColorPalette.getColor(for: course.colorIndex)
        return colorScheme == .dark ? baseColor.opacity(0.7) : baseColor.opacity(0.9)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(adjustedBackgroundColor)
                .cellBorder(
                    cornerRadius: 4,
                    isCurrentPeriod: isCurrentDay && isCurrentPeriod,
                    colorScheme: colorScheme)
                .shadow(
                    color: (isCurrentDay && isCurrentPeriod)
                        ? Color.green.opacity(0.3) : Color.clear, radius: 1, x: 0, y: 0)

            if let course = course {
                VStack(spacing: 0) {
                    Text(course.name.cleanedCourseName())
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

// MARK: - ウィジェット定義

@main
struct TimetableWidget: Widget {
    let kind: String = "TimetableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TimetableWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("時間割表")
        .description("時間割を表示します")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - プレビュー

#Preview("Small", as: .systemSmall) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: .now,
        courses: CourseModel.sampleCourses,
        lastFetchTime: .now
    )
}

#Preview("Medium", as: .systemMedium) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: .now,
        courses: CourseModel.sampleCourses,
        lastFetchTime: .now
    )
}

#Preview("Large", as: .systemLarge) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: .now,
        courses: CourseModel.sampleCourses,
        lastFetchTime: .now
    )
}
