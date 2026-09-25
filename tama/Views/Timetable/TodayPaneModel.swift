import Foundation

// MARK: - 今日の1コマ

/// 「今日」ペインが扱う、今日の1コマ分の授業。
///
/// 時限の一覧（時限番号と開始・終了時刻）は `TimetableViewModel.getPeriods()` が持っているものを
/// そのまま受け取る。ここで時限表を作り直すことはしない
struct TodayClass: Identifiable, Equatable {

    /// 時限のキー（"1"〜"7"）
    let period: String

    /// 時限の番号（表示用）
    let periodNumber: Int

    /// その時限の授業
    let course: CourseModel

    /// 基準日に当てはめた開始・終了時刻（表示用の文字列は `TodayFormat.time` で作る）
    let start: Date
    let end: Date

    var id: String { period }
}

// MARK: - ペインの時計

/// 「今日」ペインが使う時計。
///
/// 通常は実時間そのままだが、DEBUGの `-DuoNowOverride HH:mm` を付けたときだけ一定のずれを持つ。
/// `Text(timerInterval:)` はシステムの時計で描かれるため、ずらした時刻を渡すときは
/// `systemDate(for:)` で実時間に戻してから渡すこと
struct TodayClock: Equatable {

    /// 実時間からのずれ（秒）
    var offset: TimeInterval = 0

    /// 実時間の値をペインの「今」に直す
    func now(_ realNow: Date) -> Date {
        offset == 0 ? realNow : realNow.addingTimeInterval(offset)
    }

    /// ペインの時刻を、システムの時計に合わせた実時間へ戻す
    func systemDate(for paneDate: Date) -> Date {
        offset == 0 ? paneDate : paneDate.addingTimeInterval(-offset)
    }

    /// 起動引数を反映した時計
    static var current: TodayClock {
        #if DEBUG
        return TodayClock(offset: DuoDebugTimetable.nowOffset)
        #else
        return TodayClock()
        #endif
    }
}

// MARK: - 組み立て

/// 今日の授業一覧といまの状態を組み立てるヘルパー（表示を持たない純粋な計算）
enum TodaySchedule {

    /// その曜日の授業を時限順に並べ、時限の時刻を基準日に当てはめる。
    /// - Parameters:
    ///   - courses: その曜日の授業（時限キー → 授業）
    ///   - periods: `TimetableViewModel.getPeriods()` が返す（時限, 開始, 終了）の一覧
    ///   - referenceDate: 時刻を当てはめる日
    static func classes(
        courses: [String: CourseModel],
        periods: [(String, String, String)],
        on referenceDate: Date,
        calendar: Calendar = .current
    ) -> [TodayClass] {
        periods.compactMap { period, startTime, endTime in
            guard let course = courses[period],
                  let periodNumber = Int(period),
                  let start = date(from: startTime, on: referenceDate, calendar: calendar),
                  let end = date(from: endTime, on: referenceDate, calendar: calendar)
            else {
                return nil
            }
            return TodayClass(
                period: period,
                periodNumber: periodNumber,
                course: course,
                start: start,
                end: end
            )
        }
    }

    /// 「今日」ペインが使う曜日のキー（"1"=月 〜 "7"=日）。DEBUGの曜日差し替えを反映する
    static func weekdayKey(for date: Date, calendar: Calendar = .current) -> String {
        #if DEBUG
        if let overridden = DuoDebugTimetable.todayWeekday { return overridden }
        #endif
        let weekday = calendar.component(.weekday, from: date)
        return "\(weekday == 1 ? 7 : weekday - 1)"
    }

    /// バスの時刻表の種類を決める `Calendar` の曜日（1＝日曜）。DEBUGの曜日差し替えを反映する
    static func calendarWeekday(for date: Date, calendar: Calendar = .current) -> Int {
        #if DEBUG
        if let overridden = DuoDebugTimetable.todayWeekday, let japanese = Int(overridden) {
            // 月=1〜日=7 を Calendar の 日=1〜土=7 に直す
            return japanese == 7 ? 1 : japanese + 1
        }
        #endif
        return calendar.component(.weekday, from: date)
    }

    /// その日の「今日」ペインの授業（時間割の全曜日から、その日の曜日の分を取り出す）。
    ///
    /// 日付はペインの時計から毎分渡されるので、日付が変わればそのまま翌日の授業に入れ替わる。
    /// DEBUGのモックの1日を使っているときはそちらを返す
    static func todayClasses(
        on date: Date,
        courses: [String: [String: CourseModel]],
        periods: [(String, String, String)]
    ) -> [TodayClass] {
        #if DEBUG
        if DuoDebugTimetable.usesMockDay {
            return DuoDebugTimetable.mockClasses(on: date)
        }
        #endif
        return classes(
            courses: courses[weekdayKey(for: date)] ?? [:], periods: periods, on: date)
    }

    /// "9:00" のような時刻表記を、基準日のその時刻に変換する
    private static func date(from timeString: String, on referenceDate: Date, calendar: Calendar) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate)
    }
}
