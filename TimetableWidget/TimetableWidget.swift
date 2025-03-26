//
//  TimetableWidget.swift
//  TimetableWidget
//
//  Created by 维安雨轩 on 2025/03/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// エントリーモデル
struct TimetableEntry: TimelineEntry {
    let date: Date
    let courses: [String: [String: CourseModel]]?
    let lastFetchTime: Date?
    let configuration: ConfigurationAppIntent
}

// プロバイダー
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TimetableEntry {
        // プレースホルダーとしてサンプルデータを使用
        return TimetableEntry(
            date: Date(), 
            courses: CourseModel.sampleCourses, 
            lastFetchTime: Date(),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> TimetableEntry {
        // データプロバイダーインスタンス取得
        let dataProvider = TimetableWidgetDataProvider.shared
        
        // データを取得
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        
        // サンプルデータがあればそれを使用し、なければ空のデータを返す
        let entryDate = Date()
        let entryCourses = courses ?? (context.isPreview ? CourseModel.sampleCourses : [:])
        
        return TimetableEntry(
            date: entryDate, 
            courses: entryCourses, 
            lastFetchTime: lastFetchTime,
            configuration: configuration
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<TimetableEntry> {
        // データプロバイダーインスタンス取得
        let dataProvider = TimetableWidgetDataProvider.shared
        
        // データを取得
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        
        // サンプルデータがあればそれを使用し、なければ空のデータを返す
        let currentDate = Date()
        let entryCourses = courses ?? (context.isPreview ? CourseModel.sampleCourses : [:])
        
        // エントリ作成
        let entry = TimetableEntry(
            date: currentDate, 
            courses: entryCourses, 
            lastFetchTime: lastFetchTime,
            configuration: configuration
        )
        
        // 更新間隔を決定
        var updateInterval: TimeInterval = 15 * 60 // デフォルト15分
        
        // データが古いかチェック
        if let fetchTime = lastFetchTime {
            let timeSinceFetch = currentDate.timeIntervalSince(fetchTime)
            if timeSinceFetch > 60 * 60 { // 1時間以上経過している場合
                updateInterval = 5 * 60 // 5分後に更新
            }
        } else {
            // データがない場合も5分後に更新
            updateInterval = 5 * 60
        }
        
        let nextUpdateDate = Calendar.current.date(byAdding: .second, value: Int(updateInterval), to: currentDate)!
        
        return Timeline(entries: [entry], policy: .after(nextUpdateDate))
    }
}

// ウィジェットビュー
struct TimetableWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch widgetFamily {
        case .systemLarge:
            LargeTimetableView(entry: entry, colorScheme: colorScheme)
        case .systemMedium:
            MediumTimetableView(entry: entry, colorScheme: colorScheme)
        case .systemSmall:
            SmallTimetableView(entry: entry, colorScheme: colorScheme)
        default:
            // その他のサイズは非サポート
            Text("このサイズはサポートされていません")
                .font(.system(size: 10))
        }
    }
}

// 大サイズのウィジェット表示
struct LargeTimetableView: View {
    let entry: TimetableEntry
    var colorScheme: ColorScheme
    
    // データプロバイダー
    private let dataProvider = TimetableWidgetDataProvider.shared
    
    // レイアウト定数
    private let itemSpacing: CGFloat = 2
    private let timeColumnWidth: CGFloat = 12
    private let cellHeight: CGFloat = 32
    private let weekdaySpacing: CGFloat = 2  // 曜日列の下に追加する余白
    private let periodSpacing: CGFloat = 2   // 時限列の右に追加する余白
    
    // 現在の曜日と時限
    private var currentWeekday: String {
        return dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        return dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: weekdaySpacing) {  // 曜日ヘッダーと時間割グリッドの間隔を調整
                // 曜日ヘッダー
                weekdayHeaderView()
                
                // 時間割グリッド
                timeTableGridView()
            }
            .padding(EdgeInsets(top: -8, leading: -12, bottom: -4, trailing: -2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    // 曜日ヘッダービュー
    private func weekdayHeaderView() -> some View {
        HStack(spacing: itemSpacing) {
            Text("")
                .frame(width: timeColumnWidth + periodSpacing)  // 時限列の幅に余白を追加
            
            ForEach(dataProvider.getWeekdays(), id: \.self) { day in
                if day == currentWeekday {
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
    
    // 現在の曜日表示
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
    
    // 時間割グリッド
    private func timeTableGridView() -> some View {
        VStack(spacing: itemSpacing) {
            ForEach(dataProvider.getPeriods(), id: \.0) { periodInfo in
                let period = periodInfo.0
                
                HStack(spacing: itemSpacing) {
                    timeColumnView(period: period)
                        .padding(.trailing, periodSpacing)  // 時限列の右に余白を追加
                    periodRowView(period: period)
                }
            }
        }
    }
    
    // 時間列
    private func timeColumnView(period: String) -> some View {
        Text(period)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: timeColumnWidth, height: cellHeight)
    }
    
    // 各時限の行
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

// 時限セル
struct TimeSlotCellWidget: View {
    let dayIndex: String
    let displayDay: String
    let period: String
    let course: CourseModel?
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool
    let colorScheme: ColorScheme
    
    // 背景色の調整
    private var adjustedBackgroundColor: Color {
        guard let course = course else {
            return Color.clear // 授業がない場合は透明背景
        }
        let baseColor = WidgetColorPalette.getColor(for: course.colorIndex)
        return colorScheme == .dark ? baseColor.opacity(0.7) : baseColor.opacity(0.9)
    }
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 4)
                .fill(adjustedBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            (isCurrentDay && isCurrentPeriod) ? 
                                Color.green.opacity(0.9) : 
                                (colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)),
                            lineWidth: (isCurrentDay && isCurrentPeriod) ? 1.2 : 0.6
                        )
                )
                .shadow(color: (isCurrentDay && isCurrentPeriod) ? Color.green.opacity(0.3) : Color.clear, radius: 1, x: 0, y: 0)
            
            if let course = course {
                // 授業情報
                VStack(spacing: 0) {
                    Text(course.name)
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

// 小サイズのウィジェット表示
struct SmallTimetableView: View {
    let entry: TimetableEntry
    var colorScheme: ColorScheme
    
    // データプロバイダー
    private let dataProvider = TimetableWidgetDataProvider.shared
    
    // 現在の曜日と時限
    private var currentWeekday: String {
        return dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        return dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // タイトルと曜日表示
            HStack {
                Text("時間割")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(dataProvider.getWeekdayDisplayString(from: currentWeekday))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal, 4)
            
            // 授業表示 - 現在と次の授業
            if let currentCourse = getCurrentCourse() {
                VStack(spacing: 2) {
                    // 現在の授業
                    currentCourseView(course: currentCourse, isCurrentCourse: true)
                    
                    // 次の授業があれば表示
                    if let nextCourse = getNextCourse() {
                        Divider()
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                        
                        currentCourseView(course: nextCourse, isCurrentCourse: false)
                    }
                }
            } else if let nextCourse = getNextCourse() {
                // 現在の授業がなければ次の授業のみ表示
                currentCourseView(course: nextCourse, isCurrentCourse: false)
            } else if let lastCourse = getLastCourseOfDay() {
                // すべての授業が終了していれば最後の授業を表示
                VStack(spacing: 4) {
                    Text("本日の授業は終了しました")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                        .padding(.horizontal, 6)
                    
                    currentCourseView(course: lastCourse, isCurrentCourse: false)
                        .opacity(0.8) // 終了した授業は少し薄く表示
                }
            } else {
                Text("本日の授業はありません")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            
            Spacer()
        }
    }
    
    // 現在の授業を取得
    private func getCurrentCourse() -> CourseModel? {
        guard let courses = entry.courses?[currentWeekday],
              let currentPeriod = currentPeriod,
              let currentCourse = courses[currentPeriod] else { return nil }
        
        return currentCourse
    }
    
    // 次の授業を取得
    private func getNextCourse() -> CourseModel? {
        guard let courses = entry.courses?[currentWeekday] else { return nil }
        
        // 現在の時限から次の時限を計算
        if let nextPeriod = getNextPeriod(), let nextCourse = courses[nextPeriod] {
            return nextCourse
        }
        
        // 現在時限がない場合は、これから始まる一番早い授業を返す
        if let currentPeriodInt = currentPeriod.flatMap(Int.init) {
            // 今より後の授業を時間順に取得
            let futureCourses = courses.values.filter { 
                ($0.period ?? 0) > currentPeriodInt 
            }.sorted { 
                (Int($0.period ?? 0) < Int($1.period ?? 0)) 
            }
            
            if !futureCourses.isEmpty {
                return futureCourses.first
            }
        } else {
            // 時間情報がない場合は、単純に一番早い授業を返す
            return courses.values.sorted { 
                (Int($0.period ?? 0) < Int($1.period ?? 0)) 
            }.first
        }
        
        return nil
    }
    
    // 最後の授業を取得（すべての授業が終了したかの判断用）
    private func getLastCourseOfDay() -> CourseModel? {
        guard let courses = entry.courses?[currentWeekday], !courses.isEmpty else { return nil }
        
        // 今日の全ての授業が終了したかどうかをチェック
        if let currentPeriodInt = currentPeriod.flatMap(Int.init) {
            // 今後の授業があるかどうか確認
            let hasRemainingCourses = courses.values.contains { ($0.period ?? 0) >= currentPeriodInt }
            
            // 今後の授業がある場合はnilを返す
            if hasRemainingCourses {
                return nil
            }
            
            // すべての授業が終了した場合は、最後の授業を返す
            return courses.values.sorted { 
                (Int($0.period ?? 0) > Int($1.period ?? 0)) 
            }.first
        }
        
        return nil
    }
    
    // 次の時限を取得
    private func getNextPeriod() -> String? {
        guard let currentPeriod = currentPeriod, let intPeriod = Int(currentPeriod) else { return "1" }
        let nextIntPeriod = intPeriod + 1
        if nextIntPeriod <= 7 {
            return String(nextIntPeriod)
        }
        return nil
    }
    
    // 授業表示
    private func currentCourseView(course: CourseModel, isCurrentCourse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 時間情報
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
                
                Text(isCurrentCourse ? "現在の授業" : "次の授業")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 6)
            
            // 授業情報
            VStack(alignment: .leading, spacing: 1) {
                Text(course.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                
                HStack {
                    Text(course.room)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if course.period != nil {
                        let periodInfo = dataProvider.getPeriods()[course.period! - 1]
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
}

// 中サイズのウィジェット表示
struct MediumTimetableView: View {
    let entry: TimetableEntry
    var colorScheme: ColorScheme
    
    // データプロバイダー
    private let dataProvider = TimetableWidgetDataProvider.shared
    
    // 現在の曜日と時限
    private var currentWeekday: String {
        return dataProvider.getCurrentWeekday()
    }
    
    private var currentPeriod: String? {
        return dataProvider.getCurrentPeriod()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // タイトルと曜日表示
            HStack {
                Text("時間割")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(dataProvider.getWeekdayDisplayString(from: currentWeekday))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            
            // 時間割グリッド表示
            dailyTimetableGridView()
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }
    
    // 一日の時間割グリッド
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
                // 時限番号ヘッダー
                HStack(spacing: 4) {
                    ForEach(sortedPeriods, id: \.self) { period in
                        Text("\(period)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 16)
                    }
                }
                
                // 時間割グリッド
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
    
    // 授業セル
    private func courseCellView(course: CourseModel, isCurrentPeriod: Bool) -> some View {
        VStack(spacing: 2) {
            // 授業名
            Text(course.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .foregroundColor(.primary)
            
            // 教室
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
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrentPeriod ? Color.green.opacity(0.9) : (colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)), 
                       lineWidth: isCurrentPeriod ? 1.2 : 0.6)
        )
    }
    
    // 空白セル
    private func emptyCellView(isCurrentPeriod: Bool = false) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCurrentPeriod ? Color.green.opacity(0.9) : (colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.25)), 
                           lineWidth: isCurrentPeriod ? 1.2 : 0.5)
            )
    }
    
    // ソート済みの時限を取得
    private func getSortedPeriods(from courses: [CourseModel]) -> [String] {
        // 実際の授業がある時限を取得
        let periods = courses.compactMap { $0.period }.map { String($0) }
        let sortedActualPeriods = Array(Set(periods)).sorted { Int($0)! < Int($1)! }
        
        // 最低限表示する時限数（1-5）
        let minimumPeriods = (1...5).map { String($0) }
        
        // 実際の授業の時限と最低限表示する時限をマージ
        var allPeriods = Set(minimumPeriods)
        for period in sortedActualPeriods {
            allPeriods.insert(period)
        }
        
        // 時限番号でソート
        return Array(allPeriods).sorted { Int($0)! < Int($1)! }
    }
    
    // 今日の授業を取得
    private func getTodayCourses() -> [CourseModel] {
        guard let courses = entry.courses?[currentWeekday] else { return [] }
        return Array(courses.values)
    }
}

// ウィジェット定義
struct TimetableWidget: Widget {
    let kind: String = "TimetableWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                TimetableWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TimetableWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("時間割表")
        .description("時間割を表示します")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) // 全サイズをサポート
    }
}

// プレビュー
struct TimetableWidget_Previews: PreviewProvider {
    static var previews: some View {
        TimetableWidgetEntryView(entry: TimetableEntry(
            date: Date(),
            courses: [:],
            lastFetchTime: Date(),
            configuration: ConfigurationAppIntent()
        ))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
