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
    /// 表示する曜日（エントリ生成時に確定させ、描画時に SwiftData を読まない）
    let weekdays: [String]
    /// 表示する時限（番号・開始時刻・終了時刻）
    let periods: [(String, String, String)]

    /// 時間割データが未取得（アプリ未ログインなど）かどうか
    var hasNoTimetableData: Bool { courses == nil }

    init(
        date: Date,
        courses: [String: [String: CourseModel]]?,
        lastFetchTime: Date?,
        dataProvider: TimetableWidgetDataProvider = .shared
    ) {
        self.date = date
        self.courses = courses
        self.lastFetchTime = lastFetchTime
        self.currentWeekday = dataProvider.getCurrentWeekday(for: date)
        self.currentPeriod = dataProvider.getCurrentPeriod(at: date)
        self.weekdays = dataProvider.getWeekdays(from: courses)
        self.periods = dataProvider.getPeriods(from: courses)
    }

    /// プレビュー/スクリーンショット用：曜日と時限を明示的に指定
    init(
        date: Date,
        courses: [String: [String: CourseModel]]?,
        lastFetchTime: Date?,
        currentWeekday: String,
        currentPeriod: String?,
        dataProvider: TimetableWidgetDataProvider = .shared
    ) {
        self.date = date
        self.courses = courses
        self.lastFetchTime = lastFetchTime
        self.currentWeekday = currentWeekday
        self.currentPeriod = currentPeriod
        self.weekdays = dataProvider.getWeekdays(from: courses)
        self.periods = dataProvider.getPeriods(from: courses)
    }
}

// MARK: - タイムラインプロバイダー

struct Provider: TimelineProvider {
    typealias Entry = TimetableEntry

    /// 1回のタイムラインで生成する最大エントリ数（安全弁）
    private let maxEntryCount = 60

    func placeholder(in context: Context) -> Entry {
        TimetableEntry(
            date: Date(),
            courses: CourseModel.sampleCourses,
            lastFetchTime: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let loaded = TimetableWidgetDataProvider.shared.loadTimetable()
        completion(makeEntry(at: Date(), loaded: loaded, context: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        // ModelContext は呼び出しスレッド上で生成し、以降はローカルデータのみで計算する
        let loaded = TimetableWidgetDataProvider.shared.loadTimetable()
        let entryDates = timelineDates(from: now, loaded: loaded, context: context)

        let entries = entryDates.map { makeEntry(at: $0, loaded: loaded, context: context) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    // MARK: エントリ作成

    private func makeEntry(
        at date: Date,
        loaded: TimetableWidgetDataProvider.LoadedTimetable,
        context: Context
    ) -> TimetableEntry {
        // プレビュー時のみサンプルデータを使用（実機ではデータ未取得の状態をそのまま表示）
        let courses = loaded.courses ?? (context.isPreview ? CourseModel.sampleCourses : nil)

        return TimetableEntry(
            date: date,
            courses: courses,
            lastFetchTime: loaded.lastFetchTime
        )
    }

    // MARK: タイムライン時刻の計算

    /// 当日と翌日の時限境界＋翌日0時のエントリ時刻を生成する
    private func timelineDates(
        from now: Date,
        loaded: TimetableWidgetDataProvider.LoadedTimetable,
        context: Context
    ) -> [Date] {
        let calendar = Calendar.current
        let courses = loaded.courses ?? (context.isPreview ? CourseModel.sampleCourses : nil)
        let periods = TimetableWidgetDataProvider.shared.getPeriods(from: courses)
        let today = calendar.startOfDay(for: now)

        var dates: [Date] = []
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            dates.append(contentsOf: periodBoundaries(on: day, periods: periods, calendar: calendar))
            if dayOffset == 1 {
                // 翌日0時（曜日の切り替え）
                dates.append(day)
            }
        }

        let future = dates.filter { $0 > now }.sorted()
        return Array(([now] + future).prefix(maxEntryCount))
    }

    /// 指定日の各時限の開始時刻と終了直後（終了時刻+1分）を返す
    private func periodBoundaries(
        on day: Date, periods: [(String, String, String)], calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []

        for (_, startTimeStr, endTimeStr) in periods {
            if let start = parseTimeString(startTimeStr),
                let startDate = calendar.date(
                    bySettingHour: start.hour, minute: start.minute, second: 0, of: day)
            {
                dates.append(startDate)
            }

            // 終了時刻は「その分まで授業中」の扱いのため、終了の1分後に状態が変わる
            if let end = parseTimeString(endTimeStr),
                let endDate = calendar.date(
                    bySettingHour: end.hour, minute: end.minute, second: 0, of: day),
                let afterEnd = calendar.date(byAdding: .minute, value: 1, to: endDate)
            {
                dates.append(afterEnd)
            }
        }

        return dates
    }
}

// MARK: - 未取得ビュー

/// 時間割データが存在しない場合の表示
struct TimetableEmptyStateView: View {
    var fontSize: CGFloat = 11

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: fontSize + 5))
                .foregroundStyle(.tertiary)
            Text("アプリを開いて時間割を取得してください")
                .font(.system(size: fontSize))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Group {
            if entry.hasNoTimetableData {
                TimetableEmptyStateView(fontSize: 13)
            } else {
                VStack(spacing: weekdaySpacing) {
                    weekdayHeaderView()
                    timeTableGridView()
                }
            }
        }
        .padding(EdgeInsets(top: -8, leading: -12, bottom: -4, trailing: -2))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: 曜日ヘッダー

    private func weekdayHeaderView() -> some View {
        HStack(spacing: itemSpacing) {
            Text("")
                .frame(width: timeColumnWidth + periodSpacing)

            ForEach(entry.weekdays, id: \.self) { day in
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
            ForEach(entry.periods, id: \.0) { periodInfo in
                let period = periodInfo.0

                HStack(spacing: itemSpacing) {
                    Text(period)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: timeColumnWidth, height: cellHeight)
                        .padding(.trailing, periodSpacing)

                    HStack(spacing: itemSpacing) {
                        ForEach(entry.weekdays, id: \.self) { day in
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
        if entry.hasNoTimetableData {
            TimetableEmptyStateView()
        } else if let currentCourse = getCurrentCourse() {
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

                    if let period = course.period, period > 0, period <= entry.periods.count {
                        let periodInfo = entry.periods[period - 1]
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
        let currentMinutes = entryTimeInMinutes
        let periods = entry.periods

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

        let currentMinutes = entryTimeInMinutes
        let periods = entry.periods

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

    /// エントリの時刻（分単位）。描画時刻ではなくエントリ生成時刻に基づく
    private var entryTimeInMinutes: Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: entry.date) * 60
            + calendar.component(.minute, from: entry.date)
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

        if entry.hasNoTimetableData {
            TimetableEmptyStateView()
        } else if sortedPeriods.isEmpty {
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

extension CourseModel {
    /// スクリーンショット用のフル時間割データ（月〜金 × 1〜5限を全て埋める）
    /// キーは曜日番号（"1"=月 〜 "5"=金）、`TimetableWidgetDataProvider.getWeekdays()` と対応
    static let previewFullCourses: [String: [String: CourseModel]] = [
        "1": [
            "1": CourseModel(
                name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝", startTime: "0900",
                endTime: "1030", colorIndex: 1, weekday: 1, period: 1, jugyoCd: "CD001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一", startTime: "1040",
                endTime: "1210", colorIndex: 2, weekday: 1, period: 2, jugyoCd: "CS001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "統計学入門", room: "203", teacher: "佐藤 健", startTime: "1300",
                endTime: "1430", colorIndex: 11, weekday: 1, period: 3, jugyoCd: "ST001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "中国ビジネスコミュニケーションII", room: "113", teacher: "田 園", startTime: "1440",
                endTime: "1610", colorIndex: 3, weekday: 1, period: 4, jugyoCd: "CB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "英語コミュニケーションII", room: "105", teacher: "山田 花子", startTime: "1620",
                endTime: "1750", colorIndex: 12, weekday: 1, period: 5, jugyoCd: "EC001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "2": [
            "1": CourseModel(
                name: "経営情報特講", room: "201", teacher: "青木 克彦", startTime: "0900",
                endTime: "1030", colorIndex: 4, weekday: 2, period: 1, jugyoCd: "KJ001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "消費心理学", room: "211", teacher: "浜田 正幸", startTime: "1040",
                endTime: "1210", colorIndex: 5, weekday: 2, period: 2, jugyoCd: "SK001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美", startTime: "1300",
                endTime: "1430", colorIndex: 6, weekday: 2, period: 3, jugyoCd: "DB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "世界の宗教", room: "201", teacher: "高橋 恭寛", startTime: "1440",
                endTime: "1610", colorIndex: 7, weekday: 2, period: 4, jugyoCd: "SR001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "マーケティング・心理実践II", room: "111", teacher: "菅沼 睦", startTime: "1620",
                endTime: "1750", colorIndex: 8, weekday: 2, period: 5, jugyoCd: "MP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "3": [
            "1": CourseModel(
                name: "基礎数学", room: "103", teacher: "鈴木 一郎", startTime: "0900",
                endTime: "1030", colorIndex: 13, weekday: 3, period: 1, jugyoCd: "BM001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "国際関係論", room: "202", teacher: "伊藤 美咲", startTime: "1040",
                endTime: "1210", colorIndex: 14, weekday: 3, period: 2, jugyoCd: "IR001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道", startTime: "1300",
                endTime: "1430", colorIndex: 9, weekday: 3, period: 3, jugyoCd: "WP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "現代メディア論", room: "101", teacher: "中澤 弥", startTime: "1440",
                endTime: "1610", colorIndex: 10, weekday: 3, period: 4, jugyoCd: "GM001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "会計学基礎", room: "213", teacher: "渡辺 智也", startTime: "1620",
                endTime: "1750", colorIndex: 15, weekday: 3, period: 5, jugyoCd: "KG001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "4": [
            "1": CourseModel(
                name: "経営科学", room: "212", teacher: "新西 誠人", startTime: "0900",
                endTime: "1030", colorIndex: 2, weekday: 4, period: 1, jugyoCd: "KK001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "図化技術概論", room: "201", teacher: "出原 至道", startTime: "1040",
                endTime: "1210", colorIndex: 3, weekday: 4, period: 2, jugyoCd: "ZG001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "アルゴリズムとデータ構造", room: "243", teacher: "小川 大輔", startTime: "1300",
                endTime: "1430", colorIndex: 16, weekday: 4, period: 3, jugyoCd: "AD001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "日本文化論", room: "112", teacher: "森 優子", startTime: "1440",
                endTime: "1610", colorIndex: 17, weekday: 4, period: 4, jugyoCd: "JB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫", startTime: "1620",
                endTime: "1750", colorIndex: 4, weekday: 4, period: 5, jugyoCd: "HZ001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "5": [
            "1": CourseModel(
                name: "ミクロ経済学", room: "204", teacher: "中島 拓也", startTime: "0900",
                endTime: "1030", colorIndex: 18, weekday: 5, period: 1, jugyoCd: "ME001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "iOSアプリ開発演習", room: "244", teacher: "藤井 翔", startTime: "1040",
                endTime: "1210", colorIndex: 19, weekday: 5, period: 2, jugyoCd: "IA001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "図化技概論", room: "201", teacher: "出原 至道", startTime: "1300",
                endTime: "1430", colorIndex: 5, weekday: 5, period: 3, jugyoCd: "ZG002",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "ホームゼII", room: "113", teacher: "小林 英夫", startTime: "1440",
                endTime: "1610", colorIndex: 6, weekday: 5, period: 4, jugyoCd: "HZ002",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "プレゼンテーション技法", room: "114", teacher: "岡田 真理", startTime: "1620",
                endTime: "1750", colorIndex: 20, weekday: 5, period: 5, jugyoCd: "PT001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
    ]
}

/// スクリーンショット用：月曜日 12:00（2限中）を再現
private var previewMondayAt1200: Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    // 月曜日になるまで日付を前後に調整（1=日, 2=月 ...）
    if let base = Calendar.current.date(from: components) {
        let weekday = Calendar.current.component(.weekday, from: base)
        let offset = (2 - weekday + 7) % 7
        if let monday = Calendar.current.date(byAdding: .day, value: offset, to: base) {
            components = Calendar.current.dateComponents([.year, .month, .day], from: monday)
        }
    }
    components.hour = 12
    components.minute = 0
    return Calendar.current.date(from: components) ?? .now
}

#Preview("Small", as: .systemSmall) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: previewMondayAt1200,
        courses: CourseModel.previewFullCourses,
        lastFetchTime: previewMondayAt1200,
        currentWeekday: "1",
        currentPeriod: "2"
    )
}

#Preview("Medium", as: .systemMedium) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: previewMondayAt1200,
        courses: CourseModel.previewFullCourses,
        lastFetchTime: previewMondayAt1200,
        currentWeekday: "1",
        currentPeriod: "2"
    )
}

#Preview("Large", as: .systemLarge) {
    TimetableWidget()
} timeline: {
    TimetableEntry(
        date: previewMondayAt1200,
        courses: CourseModel.previewFullCourses,
        lastFetchTime: previewMondayAt1200,
        currentWeekday: "1",
        currentPeriod: "2"
    )
}
