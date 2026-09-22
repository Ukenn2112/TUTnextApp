#if DEBUG
import Foundation

// MARK: - Duo検証用の起動引数

/// 時間割タブのDuo検証用の起動引数（DEBUGビルドのみ、`UserDefaults` の同名キーでも可）。
///
/// `-DuoInitialTab`（`ContentView`）・`-DuoMetricsOverlay`（`DuoMetricsOverlay`）と同じ仕組み。
/// CLIからはセルをタップできず、ポーズもタブも切り替えられないうえ、
/// 検証用のアカウントは授業がほとんど入っていないため、
/// 2ペインの右側をどの場面でも撮れるようにしてある:
///
/// - `-DuoSelectFirstCourse YES` … 時間割の読み込み後、最初の授業を選んだ状態にする
/// - `-DuoTodayOverride mon|tue|wed|thu|fri|sat|sun` … 「今日」ペインが使う曜日を差し替える
/// - `-DuoPreviewCourseDetail YES` … 科目詳細と「今日」ペインのお知らせをモックデータで描く
///   （`CourseDetailViewModel` と `CourseNoticeStore` が読む。T-NEXTへ繋がらない環境用）
/// - `-DuoNowOverride HH:mm` … 「今日」ペインの時計を差し替える（起動時からの経過は進む）
/// - `-DuoTodayMock YES` … 現実的なモックの1日（4コマ・教室変更あり・バス時刻表）に差し替える
/// - `-DuoOnCampus YES|NO` … 学内に居るかどうかの判定を差し替える（位置情報を使わない）
/// - `-DuoMockCourseColor 0〜10` … 「今日」ペインの授業の色を指定のプリセットに差し替える
/// - `-DuoMockClassCount 1〜6` … モックの1日のコマ数（既定は4）
///
/// 「今日」ペインの課題（「このあと」「明日まで」の組）は共有の `AssignmentStore` から来るので、
/// 課題も一緒に出したいときは `-DuoAssignmentsMock YES`（`DuoDebugAssignments`）を併せて指定する
enum DuoDebugTimetable {

    // MARK: - 表示の差し替え

    /// 最初の授業を選んだ状態で始めるかどうか
    static var selectsFirstCourse: Bool {
        UserDefaults.standard.bool(forKey: "DuoSelectFirstCourse")
    }

    /// `-DuoSelectTodayPeriod 2` … 「今日」ペインの「詳細」を押したのと同じように、
    /// 今日のその時限の授業を選んだ状態で始める（CLIからはボタンを押せないため）
    static var selectedTodayPeriod: String? {
        UserDefaults.standard.string(forKey: "DuoSelectTodayPeriod")
    }

    /// 「今日」ペインが使う曜日のキー（"1"=月 〜 "7"=日）。指定が無ければ nil
    static var todayWeekday: String? {
        switch UserDefaults.standard.string(forKey: "DuoTodayOverride")?.lowercased() {
        case "mon": return "1"
        case "tue": return "2"
        case "wed": return "3"
        case "thu": return "4"
        case "fri": return "5"
        case "sat": return "6"
        case "sun": return "7"
        default: return nil
        }
    }

    /// 科目詳細・お知らせをモックデータで描くかどうか
    static var usesMockCourseDetail: Bool {
        UserDefaults.standard.bool(forKey: "DuoPreviewCourseDetail") || usesMockDay
    }

    /// 「今日」ペインの授業の色を差し替えるプリセットの番号（0〜10）。指定が無ければ nil。
    /// どのプリセットでも文字が読めるかを確かめるために用意してある（現在の読み手は無し）
    static var mockCourseColorIndex: Int? {
        guard UserDefaults.standard.object(forKey: "DuoMockCourseColor") != nil else { return nil }
        return UserDefaults.standard.integer(forKey: "DuoMockCourseColor")
    }

    // MARK: - 時計

    /// 起動時に一度だけ決める時計のずれ（秒）。
    /// `-DuoNowOverride 8:05` を付けると「今」が 8:05 から始まり、そのあとは実時間と同じだけ進む
    static let nowOffset: TimeInterval = {
        guard let text = UserDefaults.standard.string(forKey: "DuoNowOverride"),
              let target = parseTime(text)
        else {
            return 0
        }
        return target.timeIntervalSince(Date())
    }()

    private static func parseTime(_ text: String) -> Date? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    // MARK: - 学内かどうか

    /// 学内に居るかどうかの差し替え（指定が無ければ nil＝実際の位置情報に従う）
    static var onCampusOverride: Bool? {
        guard UserDefaults.standard.object(forKey: "DuoOnCampus") != nil else { return nil }
        return UserDefaults.standard.bool(forKey: "DuoOnCampus")
    }

    // MARK: - モックの1日

    /// モックの1日に差し替えるかどうか
    static var usesMockDay: Bool {
        UserDefaults.standard.bool(forKey: "DuoTodayMock")
    }

    /// モックの授業に出すコマ数（`-DuoMockClassCount 6` で増やす。既定は4）
    static var mockClassCount: Int {
        guard UserDefaults.standard.object(forKey: "DuoMockClassCount") != nil else { return 4 }
        return max(1, UserDefaults.standard.integer(forKey: "DuoMockClassCount"))
    }

    /// モックの授業（時限・時刻は `TimetableViewModel.getPeriods()` と同じ表）
    static func mockClasses(on referenceDate: Date) -> [TodayClass] {
        let periods = [
            ("1", "9:00", "10:30"), ("2", "10:40", "12:10"),
            ("3", "13:00", "14:30"), ("5", "16:20", "17:50"),
            ("4", "14:40", "16:10"), ("6", "18:00", "19:30")
        ]
        let courses = [
            mockCourse(
                name: "経営情報特講", room: "201", teacher: "青木 克彦",
                period: 1, jugyoCd: "KJ001", colorIndex: 4, unread: 0),
            mockCourse(
                name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美",
                period: 2, jugyoCd: "DB001", colorIndex: 6, unread: 3),
            mockCourse(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道",
                period: 3, jugyoCd: "WP001", colorIndex: 9, unread: 1),
            mockCourse(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫",
                period: 5, jugyoCd: "HZ001", colorIndex: 2, unread: 0),
            mockCourse(
                name: "統計学基礎", room: "305", teacher: "中村 その子",
                period: 4, jugyoCd: "TK001", colorIndex: 7, unread: 0),
            mockCourse(
                name: "英語コミュニケーション", room: "107", teacher: "久保田 貴文",
                period: 6, jugyoCd: "EC001", colorIndex: 5, unread: 0)
        ]

        let limit = mockClassCount
        return zip(periods.prefix(limit), courses.prefix(limit)).compactMap { period, course in
            guard let start = date(period.1, on: referenceDate),
                  let end = date(period.2, on: referenceDate),
                  let number = Int(period.0)
            else {
                return nil
            }
            return TodayClass(
                period: period.0, periodNumber: number, course: course,
                start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }

    /// モックの教室変更（3限の「Webプログラミング入門」が 201 → 202 に変わった想定）
    static func mockRoomChange(forCourseNamed name: String) -> RoomChange? {
        guard name == "Webプログラミング入門" else { return nil }
        return RoomChange(
            courseName: name, newRoom: "202",
            expiryDate: Date().addingTimeInterval(24 * 60 * 60))
    }

    /// モックのバス時刻表（実データのキャッシュが無効なときだけ使う）
    static func mockBusSchedule() -> BusSchedule {
        BusSchedule(
            weekdaySchedules: [
                daySchedule(
                    .fromSeisekiToSchool,
                    [(7, [(40, nil), (55, nil)]),
                     (8, [(10, nil), (25, nil), (35, "M"), (45, "C")]),
                     (9, [(0, nil), (20, nil)])]),
                daySchedule(
                    .fromNagayamaToSchool,
                    [(8, [(5, nil), (25, "◎"), (45, nil)]), (9, [(10, nil)])]),
                daySchedule(
                    .fromSchoolToSeiseki,
                    [(16, [(20, nil), (50, nil)]), (17, [(20, nil), (55, "*")]),
                     (18, [(30, nil)])]),
                daySchedule(
                    .fromSchoolToNagayama,
                    [(16, [(30, nil)]), (17, [(0, nil), (40, nil)]), (18, [(20, nil)])])
            ],
            saturdaySchedules: [],
            wednesdaySchedules: [],
            specialNotes: [],
            temporaryMessages: nil,
            pin: nil
        )
    }

    // MARK: - 組み立ての補助

    private static func daySchedule(
        _ route: BusSchedule.RouteType, _ hours: [(Int, [(Int, String?)])]
    ) -> BusSchedule.DaySchedule {
        BusSchedule.DaySchedule(
            routeType: route,
            scheduleType: .weekday,
            hourSchedules: hours.map { hour, minutes in
                BusSchedule.HourSchedule(
                    hour: hour,
                    times: minutes.map { minute, note in
                        BusSchedule.TimeEntry(
                            hour: hour, minute: minute,
                            isSpecial: note != nil, specialNote: note)
                    })
            })
    }

    private static func mockCourse(
        name: String, room: String, teacher: String,
        period: Int, jugyoCd: String, colorIndex: Int, unread: Int
    ) -> CourseModel {
        CourseModel(
            name: name, room: room, teacher: teacher,
            startTime: "", endTime: "", colorIndex: colorIndex,
            weekday: 2, period: period, jugyoCd: jugyoCd,
            academicYear: 2_026, courseYear: 2_026, courseTerm: 1,
            jugyoKbn: "A", keijiMidokCnt: unread)
    }

    private static func date(_ time: String, on referenceDate: Date) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: referenceDate)
    }
}
#endif
