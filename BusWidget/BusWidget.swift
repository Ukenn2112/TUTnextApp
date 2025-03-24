//
//  BusWidget.swift
//  BusWidget
//
//  Created by 维安雨轩 on 2025/03/22.
//

import WidgetKit
import SwiftUI

// バス時刻表データモデル（メインアプリと互換）
struct BusSchedule: Codable {
    // 列挙型
    enum RouteType: String, Codable {
        case fromSeisekiToSchool   // 聖蹟桜ヶ丘駅発
        case fromNagayamaToSchool   // 永山駅発
        case fromSchoolToSeiseki   // 聖蹟桜ヶ丘駅行
        case fromSchoolToNagayama   // 永山駅行
    }
    
    // 構造体
    struct TimeEntry: Codable, Equatable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool
        let specialNote: String?
        
        var formattedTime: String {
            return String(format: "%02d:%02d", hour, minute)
        }
        
        static func == (lhs: TimeEntry, rhs: TimeEntry) -> Bool {
            return lhs.hour == rhs.hour && lhs.minute == rhs.minute
        }
    }
    
    struct HourSchedule: Codable {
        let hour: Int
        let times: [TimeEntry]
    }
    
    struct DaySchedule: Codable {
        let routeType: RouteType
        let scheduleType: String  // "weekday", "saturday", "wednesday"のいずれか
        let hourSchedules: [HourSchedule]
    }
    
    struct SpecialNote: Codable {
        let symbol: String
        let description: String
    }
    
    struct TemporaryMessage: Codable {
        let title: String
        let url: String
    }
    
    // プロパティ
    let weekdaySchedules: [DaySchedule]
    let saturdaySchedules: [DaySchedule]
    let wednesdaySchedules: [DaySchedule]
    let specialNotes: [SpecialNote]
    let temporaryMessages: [TemporaryMessage]?
}

// ウィジェット用の簡略化したバス時刻データモデル
struct BusWidgetSchedule {
    // 路線タイプ
    enum RouteType: String, Codable {
        case fromSeisekiToSchool   // 聖蹟桜ヶ丘駅発
        case fromNagayamaToSchool   // 永山駅発
        case fromSchoolToSeiseki   // 聖蹟桜ヶ丘駅行
        case fromSchoolToNagayama   // 永山駅行
    }
    
    // 時刻エントリー
    struct TimeEntry: Codable, Identifiable, Equatable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool
        let specialNote: String?
        
        var id: String {
            "\(hour):\(minute)"
        }
        
        var formattedTime: String {
            return String(format: "%02d:%02d", hour, minute)
        }
        
        static func == (lhs: TimeEntry, rhs: TimeEntry) -> Bool {
            return lhs.hour == rhs.hour && lhs.minute == rhs.minute
        }
        
        // 簡略コンストラクタ（プレビュー用）
        init(hour: Int, minute: Int) {
            self.hour = hour
            self.minute = minute
            self.isSpecial = false
            self.specialNote = nil
        }
        
        // 完全コンストラクタ
        init(hour: Int, minute: Int, isSpecial: Bool, specialNote: String?) {
            self.hour = hour
            self.minute = minute
            self.isSpecial = isSpecial
            self.specialNote = specialNote
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    // 次のバス時刻を取得
    func getNextBusTimes(routeType: RouteTypeEnum, from: Date) -> [BusWidgetSchedule.TimeEntry] {
        // 現在の曜日に基づいてスケジュールタイプを決定
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(from)
        
        // BusWidgetDataProviderから実際のデータを取得
        let routeTypeString = routeType.rawValue
        
        // App Groupsからデータを取得
        return BusWidgetDataProvider.getNextBusTimes(
            routeType: routeTypeString,
            scheduleType: scheduleType,
            from: from
        )
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        let nextBusTimes = [
            BusWidgetSchedule.TimeEntry(hour: 10, minute: 0),
            BusWidgetSchedule.TimeEntry(hour: 10, minute: 30),
            BusWidgetSchedule.TimeEntry(hour: 11, minute: 0)
        ]
        return SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), nextBusTimes: nextBusTimes, scheduleType: "weekday")
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // 現在の日付に基づいてスケジュールタイプを決定
        let currentDate = Date()
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(currentDate)
        
        // ウィジェットギャラリー用のプレビューデータを作成
        if context.isPreview {
            // プレビュー用の固定データを提供
            let previewTimes: [BusWidgetSchedule.TimeEntry] = [
                BusWidgetSchedule.TimeEntry(hour: 8, minute: 30, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 9, minute: 0, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 9, minute: 30, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 10, minute: 0, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 10, minute: 30, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 12, minute: 30, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 22, minute: 00, isSpecial: false, specialNote: nil),
                BusWidgetSchedule.TimeEntry(hour: 23, minute: 59, isSpecial: false, specialNote: nil),
            ]
            return SimpleEntry(date: currentDate, configuration: configuration, nextBusTimes: previewTimes, scheduleType: scheduleType)
        }
        
        // 実際のデータを使用
        let nextBusTimes = getNextBusTimes(
            routeType: configuration.routeType,
            from: currentDate
        )
        return SimpleEntry(date: currentDate, configuration: configuration, nextBusTimes: nextBusTimes, scheduleType: scheduleType)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        var entries: [SimpleEntry] = []
        
        // 次のバス時刻を取得
        let busTimes = getNextBusTimes(
            routeType: configuration.routeType,
            from: currentDate
        )
        
        // タイムライン更新時刻を計算
        var refreshDates = [currentDate] // 最初のエントリーは現在時刻
        
        // 最大3つのバスについてタイムラインを生成
        let maxBusesToProcess = min(3, busTimes.count)
        
        if maxBusesToProcess > 0 {
            // バスの出発時間をDate型に変換
            var busDates: [Date] = []
            
            for i in 0..<maxBusesToProcess {
                let bus = busTimes[i]
                if let busDate = calculateBusDate(from: currentDate, hour: bus.hour, minute: bus.minute) {
                    busDates.append(busDate)
                    
                    // バスの時刻に関連する更新タイミングを追加
                    let timeToNextBus = busDate.timeIntervalSince(currentDate)
                    
                    if timeToNextBus > 0 {
                        // バスまでの更新スケジュールを設定（残り時間に応じて頻度を変える）
                        if timeToNextBus <= 300 { // 5分以内
                            // より頻繁に更新（10秒ごと）
                            for second in stride(from: 0, to: min(300, timeToNextBus), by: 10) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        } else if timeToNextBus <= 900 { // 15分以内
                            // 30秒ごとに更新
                            for second in stride(from: 0, to: min(900, timeToNextBus), by: 30) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        } else if timeToNextBus <= 1800 { // 30分以内
                            // 1分ごとに更新
                            for second in stride(from: 0, to: min(1800, timeToNextBus), by: 60) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        }
                        
                        // バス出発の直前と直後に更新
                        if timeToNextBus <= 1800 { // 30分以内のバスのみ詳細更新
                            refreshDates.append(busDate.addingTimeInterval(-30)) // 30秒前
                            refreshDates.append(busDate.addingTimeInterval(-5))  // 5秒前
                        }
                        
                        // バス出発時刻とその直後
                        refreshDates.append(busDate)
                        refreshDates.append(busDate.addingTimeInterval(1))  // 1秒後
                        refreshDates.append(busDate.addingTimeInterval(5))  // 5秒後
                    }
                }
            }
        } else {
            // バスがない場合は30分ごとに更新
            for minuteOffset in stride(from: 30, to: 180, by: 30) {
                refreshDates.append(Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!)
            }
        }
        
        // 深夜0時の更新ポイントを追加（日付変更による運行ダイヤ変更のため）
        let calendar = Calendar.current
        var midnight = calendar.startOfDay(for: currentDate)
        midnight = calendar.date(byAdding: .day, value: 1, to: midnight)! // 翌日の深夜0時
        refreshDates.append(midnight)
        refreshDates.append(calendar.date(byAdding: .second, value: 10, to: midnight)!) // 0時10秒後（確実に更新するため）
        
        // 重複を削除して昇順にソート
        refreshDates = Array(Set(refreshDates)).sorted()
        
        // 現在時刻より過去の日時は除外
        refreshDates = refreshDates.filter { $0 >= currentDate }
        
        // 各更新時点でのエントリーを作成
        for date in refreshDates {
            // 各更新時点で日付に基づいてスケジュールタイプを再評価
            let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(date)
            let times = getNextBusTimes(
                routeType: configuration.routeType,
                from: date
            )
            entries.append(SimpleEntry(date: date, configuration: configuration, nextBusTimes: times, scheduleType: scheduleType))
        }
        
        // 次のリロードポリシーを決定
        let reloadPolicy: TimelineReloadPolicy
        
        if let firstBus = busTimes.first, let firstBusDate = calculateBusDate(from: currentDate, hour: firstBus.hour, minute: firstBus.minute) {
            let timeToFirstBus = firstBusDate.timeIntervalSince(currentDate)
            
            if timeToFirstBus <= 0 {
                // バスの時間が過ぎた場合、すぐに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(1))
            } else if timeToFirstBus <= 60 { // 1分以内
                // 10秒ごとに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(10))
            } else if timeToFirstBus <= 300 { // 5分以内
                // 30秒ごとに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(30))
            } else if timeToFirstBus <= 900 { // 15分以内
                // 1分ごとに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(60))
            } else if timeToFirstBus <= 1800 { // 30分以内
                // 3分ごとに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(180))
            } else {
                // それ以上は15分ごとに更新
                reloadPolicy = .after(currentDate.addingTimeInterval(900))
            }
        } else {
            // バスがない場合は30分後に更新
            reloadPolicy = .after(currentDate.addingTimeInterval(1800))
        }
        
        return Timeline(entries: entries, policy: reloadPolicy)
    }
    
    // 日付とバスの時間からバスの具体的な日時を計算
    private func calculateBusDate(from currentDate: Date, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard var busDate = calendar.date(from: components) else { return nil }
        
        // バス時刻が過去の場合は翌日とする
        if busDate < currentDate {
            busDate = calendar.date(byAdding: .day, value: 1, to: busDate)!
        }
        
        return busDate
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let nextBusTimes: [BusWidgetSchedule.TimeEntry]
    let scheduleType: String
    
    // バス時刻をDate型に変換するメソッド
    func getBusTimeAsDate(index: Int) -> Date? {
        guard index < nextBusTimes.count else { return nil }
        
        let busTime = nextBusTimes[index]
        let calendar = Calendar.current
        let now = date // エントリーの日時を基準にする
        
        // 現在の日付の年月日を取得
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        // バスの時間と分を設定
        components.hour = busTime.hour
        components.minute = busTime.minute
        components.second = 0
        
        guard let busDate = calendar.date(from: components) else { return nil }
        
        // バス時刻が過去の場合は翌日とする
        if busDate <= now {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: busDate)!
            return nextDay
        }
        
        return busDate
    }
    
    // 現在表示すべき最初のバスのインデックスを返す
    // これはバスの時刻が過ぎた場合に自動的に次のバスを表示するために使用
    func getCurrentBusIndex() -> Int {
        // バスがない場合は0を返す
        if nextBusTimes.isEmpty {
            return 0
        }
        
        // 現在の時刻（エントリーの日時）
        let now = date
        
        // 各バスについて、時間が過ぎていないかチェック
        for (index, busTime) in nextBusTimes.enumerated() {
            // バスの日時を取得
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = busTime.hour
            components.minute = busTime.minute
            components.second = 0
            
            guard let busDate = calendar.date(from: components) else { continue }
            
            // バス時刻が過去の場合は翌日の日付にする
            var actualBusDate = busDate
            if busDate < now {
                // 当日中にまだ到着していないバスがある場合は、翌日のバスではなく当日のバスを表示する
                let hasLaterBusesToday = nextBusTimes.dropFirst(index+1).contains { laterBus in
                    var laterComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    laterComponents.hour = laterBus.hour
                    laterComponents.minute = laterBus.minute
                    laterComponents.second = 0
                    
                    guard let laterBusDate = calendar.date(from: laterComponents) else { return false }
                    return laterBusDate > now
                }
                
                if !hasLaterBusesToday {
                    // 翌日のこのバスを表示
                    actualBusDate = calendar.date(byAdding: .day, value: 1, to: busDate)!
                } else {
                    // 過去のバスなのでスキップ
                    continue
                }
            }
            
            // 現在時刻より未来のバスを見つけたらそのインデックスを返す
            if actualBusDate > now {
                return index
            }
        }
        
        // すべてのバスが過去の場合は最初のバスを返す（翌日分として）
        return 0
    }
    
    // 現在表示すべき次のバス
    var currentBus: BusWidgetSchedule.TimeEntry? {
        let index = getCurrentBusIndex()
        return index < nextBusTimes.count ? nextBusTimes[index] : nil
    }
    
    // 現在のバスの時刻をDate型で取得
    var currentBusDate: Date? {
        let index = getCurrentBusIndex()
        return getBusTimeAsDate(index: index)
    }
    
    // 本日の運行が終了したかどうか
    var isServiceEndedForToday: Bool {
        guard let _ = currentBus, let busDate = currentBusDate else {
            // バスがない場合は運行終了と判断
            return true
        }
        
        let calendar = Calendar.current
        let now = date
        
        // バスの日付が翌日かどうかをチェック
        let busDay = calendar.component(.day, from: busDate)
        let todayDay = calendar.component(.day, from: now)
        
        // 翌日のバスを表示している場合、かつバスまでの残り時間が6時間以上ある場合は、本日の運行は終了と判断
        if busDay != todayDay {
            let timeInterval = busDate.timeIntervalSince(now)
            // 6時間（21600秒）以上先のバスは翌日のバスとみなす
            return timeInterval >= 21600
        }
        
        return false
    }
    
    // 現在のバスの次に来るバス配列 - その日のバスをすべて表示
    var upcomingBuses: [BusWidgetSchedule.TimeEntry] {
        // 本日の運行が終了した場合は空配列を返す
        if isServiceEndedForToday {
            return []
        }
        
        // 現在時刻
        let now = date
        let calendar = Calendar.current
        
        // 現在の表示中バスのインデックスを取得
        let currentIndex = getCurrentBusIndex()
        
        // 現在表示中の次のバスをスキップして、その後のバスを表示
        let upcomingIndices = currentIndex + 1..<min(currentIndex + 3, nextBusTimes.count)
        let todayBuses = upcomingIndices.compactMap { index -> BusWidgetSchedule.TimeEntry? in
            let bus = nextBusTimes[index]
            
            // バス時刻のコンポーネントを取得
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = bus.hour
            components.minute = bus.minute
            
            guard let busDate = calendar.date(from: components) else { return nil }
            
            // 今日のバスのみを表示（翌日のバスは除外）
            return calendar.isDate(busDate, inSameDayAs: now) ? bus : nil
        }
        
        return todayBuses
    }
}

struct BusWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // 路線名を取得
    var routeName: String {
        switch entry.configuration.routeType {
        case .fromSeisekiToSchool:
            return NSLocalizedString("聖蹟桜ヶ丘駅発", comment: "")
        case .fromNagayamaToSchool:
            return NSLocalizedString("永山駅発", comment: "")
        case .fromSchoolToSeiseki:
            return NSLocalizedString("聖蹟桜ヶ丘駅行", comment: "")
        case .fromSchoolToNagayama:
            return NSLocalizedString("永山駅行", comment: "")
        }
    }
    
    // ダイヤタイプ
    var scheduleTypeName: String {
        return BusWidgetDataProvider.getScheduleTypeDisplayName(entry.scheduleType)
    }
    
    // テーマカラー - ダークモード対応
    var themeColor: Color {
        return colorScheme == .dark ? .cyan : .blue
    }
    
    // セカンダリテキストカラー - ダークモード対応
    var secondaryTextColor: Color {
        return .secondary
    }
    
    // 背景色 - ダークモード対応
    func cardBackgroundColor(opacity: Double = 0.05) -> Color {
        return colorScheme == .dark ? Color.white.opacity(opacity) : themeColor.opacity(opacity)
    }

    var body: some View {
        if family == .systemSmall {
            smallWidgetLayout
        } else {
            mediumWidgetLayout
        }
    }
    
    // ウィジェット共通のヘッダー部分
    private func headerView(fontSize: Font = .caption) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "bus.fill")
                .foregroundColor(themeColor)
                .font(fontSize)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(routeName)
                    .font(fontSize)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(scheduleTypeName)
                    .font(fontSize == .caption ? .caption2 : .caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
    }
    
    // バスがない場合の表示
    private func noScheduleView(fontSize: Font = .caption, widgetType: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(fontSize == .caption ? .title3 : .title2)
                    .foregroundColor(secondaryTextColor)
                Text(widgetType == "medium" ? "本日の運行終了しました" : "本日の運行終了")
                    .font(fontSize)
                    .foregroundColor(secondaryTextColor)
            }
            Spacer()
        }
    }
    
    // タイマー形式の残り時間表示コンポーネント
    private func timerView(for busDate: Date, fontSize: Font = .caption2, style: Text.DateStyle = .timer) -> some View {
        // バスまでの残り時間（秒）
        let timeInterval = busDate.timeIntervalSince(entry.date)
        // バスの時刻が過ぎていないか確認
        guard timeInterval > 0 else {
            // 過ぎている場合は「出発済み」と表示
            return AnyView(ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(fontSize)
                        .foregroundColor(.green)
                    
                    Text("出発済み")
                        .font(fontSize)
                        .fontWeight(.medium)
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            })
        }
        
        // 最大表示時間（30分 = 1800秒）
        let maxInterval: TimeInterval = 1800
        // 進捗バーの幅（0.0〜1.0）
        let progressWidth = min(1.0, max(0.0, timeInterval / maxInterval))
        
        return AnyView(ZStack(alignment: .leading) {
            // 背景 - 薄いグレー
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
            
            // 進捗バー - 時間に応じた色
            RoundedRectangle(cornerRadius: 6)
                .fill(getTimeColor(for: busDate).opacity(colorScheme == .dark ? 0.25 : 0.15))
                .frame(width: progressWidth > 0.05 ? nil : 0, alignment: .leading)
                .scaleEffect(x: progressWidth, y: 1, anchor: .leading)
            
            // 内容
            HStack(spacing: 4) {
                // タイマーアイコン
                Image(systemName: "timer")
                    .font(fontSize)
                    .foregroundColor(getTimeColor(for: busDate))
                
                // 時間表示
                Text(busDate, style: style)
                    .font(fontSize)
                    .fontWeight(.medium)
                    .foregroundColor(getTimeColor(for: busDate))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        })
    }
    
    // 小サイズウィジェットのレイアウト
    var smallWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ヘッダー
            headerView()
            
            Divider()
                .padding(.vertical, 2)
            
            if entry.nextBusTimes.isEmpty || entry.isServiceEndedForToday {
                Spacer()
                noScheduleView(widgetType: "small")
                Spacer()
            } else if let currentBus = entry.currentBus, let currentBusDate = entry.currentBusDate {
                // バス時刻が現在時刻より未来かどうか確認
                let timeToNextBus = currentBusDate.timeIntervalSince(entry.date)
                let isBusDeparted = timeToNextBus <= 0
                
                // 次のバス情報パネル
                VStack(spacing: 2) {
                    // 「次のバス」ラベル行
                    HStack {
                        Text("次のバス")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                        
                        Spacer()
                        
                        // 特殊タグがある場合は表示
                        if currentBus.isSpecial, let note = currentBus.specialNote {
                            Text(note)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // バス時刻
                    Text(currentBus.formattedTime)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(isBusDeparted ? secondaryTextColor : themeColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // タイマー形式の残り時間
                    timerView(for: currentBusDate)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 4)
                
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .id("widget-\(entry.date.timeIntervalSince1970)") // 強制的に更新するためのID
    }
    
    // 中サイズウィジェットのレイアウト
    var mediumWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー部分
            headerView(fontSize: .subheadline)
            
            Divider()
                .background(themeColor.opacity(0.2))
            
            if entry.nextBusTimes.isEmpty || entry.isServiceEndedForToday {
                HStack {
                    Spacer()
                    noScheduleView(fontSize: .subheadline, widgetType: "medium")
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                // バス時刻情報を2列レイアウトで表示
                HStack(alignment: .top, spacing: 16) {
                    // 左列 - 現在の次のバス
                    if let currentBus = entry.currentBus, let currentBusDate = entry.currentBusDate {
                        // バス時刻が現在時刻より未来かどうか確認
                        let timeToNextBus = currentBusDate.timeIntervalSince(entry.date)
                        let isBusDeparted = timeToNextBus <= 0
                        
                        nextBusColumn(bus: currentBus, busDate: currentBusDate, isDeparted: isBusDeparted)
                    }
                    
                    // 右列 - その後のバス
                    upcomingBusesColumn
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .id("widget-\(entry.date.timeIntervalSince1970)") // 強制的に更新するためのID
    }
    
    // 次のバス情報の列
    private func nextBusColumn(bus: BusWidgetSchedule.TimeEntry, busDate: Date, isDeparted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // ヘッダー
            HStack {
                Text("次のバス")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                
                // 特殊タグがある場合は表示
                if bus.isSpecial, let note = bus.specialNote {
                    Text(note)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(4)
                }
            }
            
            // 時刻
            Text(bus.formattedTime)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(isDeparted ? secondaryTextColor : themeColor)
            
            // 相対時間形式の残り時間
            timerView(for: busDate, fontSize: .caption, style: .relative)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackgroundColor())
        )
    }
    
    // その後のバス情報の列
    private var upcomingBusesColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("その後のバス")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.bottom, 2)
            
            if entry.upcomingBuses.isEmpty {
                Text("本日の次のバスはありません")
                    .font(.caption2)
                    .foregroundColor(secondaryTextColor)
                    .padding(.vertical, 8)
            } else {
                // その後のバス時刻を表示 - 最大2行に制限
                let maxVisibleBuses = 2 // 画面に表示する最大バス数
                
                ForEach(0..<min(maxVisibleBuses, entry.upcomingBuses.count), id: \.self) {
                    index in busRowView(for: entry.upcomingBuses[index], at: index)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // バス行の表示（上のメソッドから利用）
    private func busRowView(for bus: BusWidgetSchedule.TimeEntry, at index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // 時刻と特殊タグを重ねて表示
                ZStack(alignment: .topTrailing) {
                    // 時刻
                    Text(bus.formattedTime)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.trailing, bus.isSpecial ? 14 : 0) // 特殊タグがある場合はパディングを追加
                    
                    // 特殊タグの表示
                    if bus.isSpecial, let note = bus.specialNote {
                        Text(note)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.red)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 0.3)
                            .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.05))
                            .cornerRadius(2)
                            .offset(x: 2,y: 3) // 少し上にオフセット
                    }
                }
                
                Spacer()
                
                // 相対時間形式の残り時間
                if let busIndex = entry.nextBusTimes.firstIndex(where: { $0.id == bus.id }),
                   let busDate = entry.getBusTimeAsDate(index: busIndex) {
                    HStack(spacing: 2) {
                        Text(busDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            
            // 区切り線 - 最初のバスと2番目のバスの間にのみ表示（バスが2つある場合）
            if index == 0 && entry.upcomingBuses.count > 1 {
                Divider()
                    .padding(.vertical, 4)
                    .padding(.leading, 20)
            }
        }
    }
    
    // 残り時間によって色を変える
    private func getTimeColor(for busDate: Date) -> Color {
        let timeInterval = busDate.timeIntervalSince(entry.date)
        
        if timeInterval <= 60 { // 1分以内
            return colorScheme == .dark ? .pink : .red
        } else if timeInterval <= 600 { // 10分以内
            return colorScheme == .dark ? .yellow : .orange
        } else {
            return colorScheme == .dark ? .cyan : .blue
        }
    }
}

struct BusWidget: Widget {
    let kind: String = "BusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                        .overlay {
                            // ダークモード対応のグラデーション背景
                            WidgetBackgroundView()
                        }
                }
        }
        .configurationDisplayName("学校バス時刻表")
        .description("次のバスの発車時刻を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ウィジェット背景ビュー
struct WidgetBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        // ライト/ダークモードに応じた背景色
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [
                Color(uiColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)),
                Color(uiColor: UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0))
            ] : [
                Color(uiColor: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)),
                Color(uiColor: UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0))
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// ColorSchemeキー
private struct ColorSchemeKey: PreferenceKey {
    static var defaultValue: ColorScheme = .light
    static func reduce(value: inout ColorScheme, nextValue: () -> ColorScheme) {
        value = nextValue()
    }
}

// プレビュー用の拡張
extension ConfigurationAppIntent {
    fileprivate static var seiseki: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromSeisekiToSchool
        return intent
    }
    
    fileprivate static var nagayama: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromNagayamaToSchool
        return intent
    }
}

#Preview(as: .systemSmall) {
    BusWidget()
} timeline: {
    let times1 = [
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 0),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 30),
        BusWidgetSchedule.TimeEntry(hour: 11, minute: 0)
    ]
    let times2 = [
        BusWidgetSchedule.TimeEntry(hour: 9, minute: 45),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 15),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 45)
    ]
    SimpleEntry(date: .now, configuration: .seiseki, nextBusTimes: times1, scheduleType: "weekday")
    SimpleEntry(date: .now, configuration: .nagayama, nextBusTimes: times2, scheduleType: "weekday")
}

#Preview(as: .systemMedium) {
    BusWidget()
} timeline: {
    let times1 = [
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 0),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 30),
        BusWidgetSchedule.TimeEntry(hour: 11, minute: 0)
    ]
    let times2 = [
        BusWidgetSchedule.TimeEntry(hour: 9, minute: 45),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 15),
        BusWidgetSchedule.TimeEntry(hour: 10, minute: 45)
    ]
    let emptyTimes: [BusWidgetSchedule.TimeEntry] = []
    
    SimpleEntry(date: .now, configuration: .seiseki, nextBusTimes: times1, scheduleType: "weekday")
    SimpleEntry(date: .now, configuration: .nagayama, nextBusTimes: times2, scheduleType: "weekday")
    SimpleEntry(date: .now, configuration: .seiseki, nextBusTimes: emptyTimes, scheduleType: "weekday")
}
