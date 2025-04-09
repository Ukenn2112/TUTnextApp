//
//  TimetableWidget.swift
//  TimetableWidget
//
//  Created by 维安雨轩 on 2025/03/25.
//

import WidgetKit
import SwiftUI

// エントリーモデル
struct TimetableEntry: TimelineEntry {
    let date: Date
    let courses: [String: [String: CourseModel]]?
    let lastFetchTime: Date?
}

// プロバイダー
struct Provider: TimelineProvider {
    typealias Entry = TimetableEntry
    
    func placeholder(in context: Context) -> Entry {
        // プレースホルダーとしてサンプルデータを使用
        return TimetableEntry(
            date: Date(), 
            courses: CourseModel.sampleCourses, 
            lastFetchTime: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // データプロバイダーインスタンス取得
        let dataProvider = TimetableWidgetDataProvider.shared
        
        // データを取得
        let courses = dataProvider.getTimetableData()
        let lastFetchTime = dataProvider.getLastFetchTime()
        
        // サンプルデータがあればそれを使用し、なければ空のデータを返す
        let entryDate = Date()
        let entryCourses = courses ?? (context.isPreview ? CourseModel.sampleCourses : [:])
        
        let entry = TimetableEntry(
            date: entryDate, 
            courses: entryCourses, 
            lastFetchTime: lastFetchTime
        )
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
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
            lastFetchTime: lastFetchTime
        )
        
        // 更新時間の配列を作成
        var updateTimes: [Date] = []
        
        // 定期更新（10分ごと）- 基本的な更新頻度を確保
        let tenMinutesLater = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
        updateTimes.append(tenMinutesLater)
        
        // 1. 今日の各授業の開始時間と終了時間（終了1分後）を取得
        let calendar = Calendar.current
        let periods = dataProvider.getPeriods()
        
        for (_, startTimeStr, endTimeStr) in periods {
            // 開始時間を Date に変換
            if let startComponents = parseTimeString(startTimeStr) {
                let startDateComponents = DateComponents(
                    year: calendar.component(.year, from: currentDate),
                    month: calendar.component(.month, from: currentDate),
                    day: calendar.component(.day, from: currentDate),
                    hour: startComponents.hour,
                    minute: startComponents.minute
                )
                
                if let startDate = calendar.date(from: startDateComponents) {
                    // 授業開始の5分前にも更新
                    if let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: startDate),
                       fiveMinutesBefore > currentDate {
                        updateTimes.append(fiveMinutesBefore)
                    }
                    
                    // 授業開始時に更新
                    if startDate > currentDate {
                        updateTimes.append(startDate)
                    }
                    
                    // 授業開始の3分後にも更新（授業開始直後の状態を反映するため）
                    if let threeMinutesAfter = calendar.date(byAdding: .minute, value: 3, to: startDate),
                       threeMinutesAfter > currentDate {
                        updateTimes.append(threeMinutesAfter)
                    }
                }
            }
            
            // 終了時間を Date に変換
            if let endComponents = parseTimeString(endTimeStr) {
                let endDateComponents = DateComponents(
                    year: calendar.component(.year, from: currentDate),
                    month: calendar.component(.month, from: currentDate),
                    day: calendar.component(.day, from: currentDate),
                    hour: endComponents.hour,
                    minute: endComponents.minute
                )
                
                if let endDate = calendar.date(from: endDateComponents) {
                    // 授業終了の5分前にも更新
                    if let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: endDate),
                       fiveMinutesBefore > currentDate {
                        updateTimes.append(fiveMinutesBefore)
                    }
                    
                    // 授業終了時に更新
                    if endDate > currentDate {
                        updateTimes.append(endDate)
                    }
                    
                    // 授業終了1分後に更新
                    if let oneMinuteAfter = calendar.date(byAdding: .minute, value: 1, to: endDate),
                       oneMinuteAfter > currentDate {
                        updateTimes.append(oneMinuteAfter)
                    }
                }
            }
        }
        
        // 2. 翌日の0時も追加
        var nextMidnightComponents = DateComponents()
        nextMidnightComponents.year = calendar.component(.year, from: currentDate)
        nextMidnightComponents.month = calendar.component(.month, from: currentDate)
        nextMidnightComponents.day = calendar.component(.day, from: currentDate) + 1
        nextMidnightComponents.hour = 0
        nextMidnightComponents.minute = 0
        nextMidnightComponents.second = 0
        
        if let nextMidnight = calendar.date(from: nextMidnightComponents) {
            // 0時直前にも更新
            if let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: nextMidnight) {
                updateTimes.append(fiveMinutesBefore)
            }
            
            // 0時に更新
            updateTimes.append(nextMidnight)
            
            // 0時直後にも更新
            if let fiveMinutesAfter = calendar.date(byAdding: .minute, value: 5, to: nextMidnight) {
                updateTimes.append(fiveMinutesAfter)
            }
        }
        
        // 3. データが古い場合はすぐに更新
        if let fetchTime = lastFetchTime {
            let timeSinceFetch = currentDate.timeIntervalSince(fetchTime)
            if timeSinceFetch > 30 * 60 { // 30分以上経過している場合
                let immediateUpdate = calendar.date(byAdding: .minute, value: 1, to: currentDate)!
                updateTimes.append(immediateUpdate)
            }
        } else {
            // データがない場合もすぐに更新
            let immediateUpdate = calendar.date(byAdding: .minute, value: 1, to: currentDate)!
            updateTimes.append(immediateUpdate)
        }
        
        // 4. 現在授業中なら短い間隔で更新（現在時刻の状態を正確に表示するため）
        if dataProvider.getCurrentPeriod() != nil {
            let fiveMinutesLater = calendar.date(byAdding: .minute, value: 5, to: currentDate)!
            updateTimes.append(fiveMinutesLater)
        }
        
        // 更新時間をソートして最も近い時間を取得
        updateTimes.sort()
        
        // 最も近い更新時間を取得（デフォルトは15分後）
        let nextUpdateDate = updateTimes.first ?? calendar.date(byAdding: .minute, value: 15, to: currentDate)!
        
        // デバッグ用（必要に応じてコメントアウト）
        // print("Next update scheduled at: \(nextUpdateDate)")
        
        completion(Timeline(entries: [entry], policy: .after(nextUpdateDate)))
    }
}

// 時間文字列をパース
private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
    let components = timeString.split(separator: ":")
    guard components.count == 2,
          let hour = Int(components[0]),
          let minute = Int(components[1]) else {
        return nil
    }
    return (hour: hour, minute: minute)
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
                .widgetURL(URL(string: "tama://timetable"))
        case .systemMedium:
            MediumTimetableView(entry: entry, colorScheme: colorScheme)
                .widgetURL(URL(string: "tama://timetable"))
        case .systemSmall:
            SmallTimetableView(entry: entry, colorScheme: colorScheme)
                .widgetURL(URL(string: "tama://timetable"))
        default:
            // その他のサイズは非サポート
            Text("このサイズはサポートされていません")
                .font(.system(size: 10))
                .widgetURL(URL(string: "tama://timetable"))
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
            } else if getLastCourseOfDay() {
                // すべての授業が終了していれば
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
        if let _ = self.currentPeriod, let nextPeriod = getNextPeriod(), let nextCourse = courses[nextPeriod] {
            return nextCourse
        }
        
        // 現在時限がない場合（授業時間外）
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute // 現在時刻を分に変換
        
        // 全ての授業を時間でソート
        let sortedCourses = courses.values.sorted { 
            let period1 = $0.period ?? 0
            let period2 = $1.period ?? 0
            
            // 時限を分単位の時間に変換
            let timeForPeriod: (Int) -> Int = { period in
                if period <= 0 || period > 7 { return 0 }
                let periodData = dataProvider.getPeriods()[period - 1]
                let startTimeStr = periodData.1
                if let startComponents = parseTimeString(startTimeStr) {
                    return startComponents.hour * 60 + startComponents.minute
                }
                return 0
            }
            
            let time1 = timeForPeriod(period1)
            let time2 = timeForPeriod(period2)
            
            return time1 < time2
        }
        
        // 現在時刻より後の授業を探す
        for course in sortedCourses {
            if let period = course.period, period > 0 && period <= 7 {
                let periodData = dataProvider.getPeriods()[period - 1]
                let startTimeStr = periodData.1
                if let startComponents = parseTimeString(startTimeStr) {
                    let startTime = startComponents.hour * 60 + startComponents.minute
                    if startTime > currentTime {
                        return course
                    }
                }
            }
        }
        
        return nil
    }
    
    // 今日のすべての授業が終了したかを判断
    private func getLastCourseOfDay() -> Bool {
        guard let courses = entry.courses?[currentWeekday], !courses.isEmpty else { return false }
        
        // 現在の時刻を取得
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute // 現在時刻を分に変換
        
        // 時限がある場合はその後の授業があるかチェック
        if let currentPeriodInt = currentPeriod.flatMap(Int.init) {
            // 今後の授業があるかどうか確認
            let hasRemainingCourses = courses.values.contains { ($0.period ?? 0) > currentPeriodInt }
            
            // 今後の授業がない場合はtrueを返す
            return !hasRemainingCourses
        } else {
            // 時限がない場合（授業時間外）は、現在時刻より後に開始する授業があるかチェック
            let hasRemainingCourses = courses.values.contains { course in
                if let period = course.period, period > 0 && period <= 7 {
                    let periodData = dataProvider.getPeriods()[period - 1]
                    let startTimeStr = periodData.1
                    if let startComponents = parseTimeString(startTimeStr) {
                        let startTime = startComponents.hour * 60 + startComponents.minute
                        return startTime > currentTime
                    }
                }
                return false
            }
            
            return !hasRemainingCourses
        }
    }
    
    // 次の時限を取得
    private func getNextPeriod() -> String? {
        guard let currentPeriodStr = currentPeriod, let intPeriod = Int(currentPeriodStr) else { return nil }
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
                Text(course.name.replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: ""))
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
            Text(course.name.replacingOccurrences(of: "※私費外国人留学生のみ履修可能", with: ""))
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                TimetableWidgetEntryView(entry: entry)
                    .containerBackground(Color(UIColor { traitCollection in
                        return traitCollection.userInterfaceStyle == .dark ? .black : .white
                    }), for: .widget)
            } else {
                TimetableWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(UIColor { traitCollection in
                        return traitCollection.userInterfaceStyle == .dark ? .black : .white
                    }))
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
            lastFetchTime: Date()
        ))
        .containerBackground(Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .black : .white
        }), for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
