#if DEBUG
import Foundation
import SwiftData
import WidgetKit

// MARK: - App Store のスクリーンショット用のデモモード

/// App Store のスクリーンショット用のデモモード（DEBUGビルドのみ、`UserDefaults` の同名キーでも可）。
///
/// 開発者の実際のアカウントには授業も課題もほとんど入っておらず、そのままでは撮れる画面が無いため、
/// 起動引数ひとつで「授業の詰まった経営情報学部の学生」の状態に差し替える:
///
/// - `-TUTDemoMode YES` … デモモードで起動する
/// - `-DemoOpenCourseDetail tue:2` … 1ペインの時間割で、その曜日・時限の科目詳細をシートで開いた状態にする
///
/// デモモードでは次のように振る舞う:
///
/// - ログイン: `UserService.getCurrentUser()` が架空の学生を返す（Keychain には書き込まない）
/// - 時間割: `TimetableService` がAPIの代わりに架空の時間割（2026年度秋学期）を、
///   APIから届いたときと同じ道で反映する（SwiftData の `CachedTimetable` に保存され、ウィジェットにも出る）。
///   教室変更を1件（3限の「Webプログラミング入門」201 → 202）と授業の色も入れておく
/// - 課題: `AssignmentService` と `AssignmentStore` が `DuoDebugAssignments` のモックを返す
/// - 科目詳細・お知らせ: 時間割に合わせたモック（`courseDetail(for:)`）を出す
/// - 時計: 「今」を今週の火曜日の 9:41 にする（`clockOffset`）。時間割の強調・「今日」ペイン・
///   バス・課題の締切がすべてこの時計で動き、ウィジェットにも App Group 経由で同じずれを渡す
/// - 「今日」ペイン: `DuoDebugTimetable` のモックの1日を使う
/// - バス: バックエンドの代わりにデモの時刻表（`busSchedule(specialNotes:)`、臨時ダイヤのお知らせ無し）を使い、
///   SwiftData の `CachedBusSchedule` にも保存してバスのウィジェットに出す
/// - 印刷・教員メール: 印刷の履歴を数件入れ、教員一覧は架空の教員を返す
/// - 架空のログイン情報でT-NEXT・バックエンドへ問い合わせないよう、Live Activity・通知の登録・
///   Classroom の認証状態・位置情報の許可は止める（エラー表示やシステムのダイアログを出さない）
///
/// Duo検証用の起動引数（`-DuoTodayMock` など）はデモモードが既定値として登録するだけなので、
/// 同じ引数を明示的に渡せば上書きできる（例: `-DuoNowOverride 13:20` で午後の場面にする）
enum DemoMode {

    // MARK: - 起動引数

    /// デモモードで起動したかどうか
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "TUTDemoMode")
    }

    /// 起動時に一度だけ呼ぶ。デモモードなら、Duo検証用の起動引数を既定値として登録する。
    ///
    /// `register(defaults:)` の値は起動引数より優先度が低いので、明示的に渡した引数がそのまま勝つ。
    /// 時計のずれ（`DuoDebugTimetable.nowOffset` など）は最初に読まれたときに決まるため、
    /// それより前（`TamaApp.init()`）で呼ぶこと
    static func activateIfNeeded() {
        guard isEnabled else { return }
        UserDefaults.standard.register(defaults: [
            "DuoTodayMock": true,
            "DuoAssignmentsMock": true,
            "DuoTodayOverride": "tue",
            "DuoNowOverride": "9:41",
            "DuoBusDayOverride": "weekday"
        ])
        print("【デモモード】有効（今日=火曜日 9:41）")
    }

    /// ウィジェットへ時計のずれを渡す（アプリの起動ごとに書き直す）。
    /// デモモードでないDEBUGの起動では消して、ウィジェットを実時間に戻す
    static func publishClockForWidgets() {
        guard let shared = UserDefaults(suiteName: AppConstants.appGroupID) else { return }
        if isEnabled {
            shared.set(clockOffset, forKey: DemoClock.offsetKey)
        } else if shared.object(forKey: DemoClock.offsetKey) != nil {
            shared.removeObject(forKey: DemoClock.offsetKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - 時計

    /// デモの「今」と実時間のずれ（秒）。起動時に一度だけ決め、そのあとは実時間と同じだけ進む。
    ///
    /// 「今」は今週（月曜始まり）の `-DuoTodayOverride` の曜日（既定は火曜日）の、
    /// `-DuoNowOverride` の時刻（既定は 9:41）。曜日だけでなく日付ごとずらすので、
    /// 課題の「今日」「明日」や掲示の日付も火曜日を基準に揃う
    static let clockOffset: TimeInterval = {
        let realNow = Date()
        let text = UserDefaults.standard.string(forKey: "DuoNowOverride") ?? "9:41"
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let time = Calendar.current.date(
                bySettingHour: parts[0], minute: parts[1], second: 0, of: realNow)
        else {
            return 0
        }
        return DuoDebugTimetable.displayDate(for: time).timeIntervalSince(realNow)
    }()

    /// デモの「今」
    static var now: Date {
        Date().addingTimeInterval(clockOffset)
    }

    /// `-DemoOpenCourseDetail tue:2` で指定された、科目詳細のシートを開く授業の位置
    static var openedCourseDetail: CourseSelection? {
        guard let text = UserDefaults.standard.string(forKey: "DemoOpenCourseDetail") else { return nil }
        let parts = text.lowercased().split(separator: ":")
        let days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        guard parts.count == 2, let index = days.firstIndex(of: String(parts[0])) else { return nil }
        return CourseSelection(day: "\(index + 1)", period: String(parts[1]))
    }

    // MARK: - 架空の学生

    /// デモモードでログインしている架空の学生（全未読掲示数は時間割の未読の合計と同じ）
    static let user = User(
        id: "2341087",
        username: "t2341087",
        fullName: "山田 彩花",
        encryptedPassword: "demo",
        allKeijiMidokCnt: unreadNoticeCount
    )

    // MARK: - 教室変更

    /// デモの教室変更（「今日」ペインのモック `DuoDebugTimetable.mockRoomChange` と同じ授業・教室）
    static var roomChange: RoomChange {
        RoomChange(
            courseName: "Webプログラミング入門", newRoom: "202",
            expiryDate: Date().addingTimeInterval(48 * 60 * 60))
    }
}

// MARK: - 時間割

extension DemoMode {

    /// 時間割の1コマ
    struct DemoCourse {
        let weekday: Int
        let period: Int
        let name: String
        let room: String
        let teacher: String
        let code: String
        let colorIndex: Int
        let unread: Int
    }

    /// 2026年度秋学期の時間割（月〜金 × 1〜5限、空きコマあり）。
    ///
    /// 火曜日は「今日」ペインのモックの1日（`DuoDebugTimetable.mockClasses`）と同じ授業・教室・色にしてある
    static let courses: [DemoCourse] = [
        // 月
        DemoCourse(weekday: 1, period: 1, name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝",
                   code: "CD001", colorIndex: 1, unread: 0),
        DemoCourse(weekday: 1, period: 2, name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一",
                   code: "CS001", colorIndex: 8, unread: 0),
        DemoCourse(weekday: 1, period: 4, name: "中国ビジネスコミュニケーションII", room: "113", teacher: "田 園",
                   code: "CB001", colorIndex: 3, unread: 0),
        // 火
        DemoCourse(weekday: 2, period: 1, name: "経営情報特講", room: "201", teacher: "青木 克彦",
                   code: "KJ001", colorIndex: 4, unread: 0),
        DemoCourse(weekday: 2, period: 2, name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美",
                   code: "DB001", colorIndex: 6, unread: 3),
        DemoCourse(weekday: 2, period: 3, name: "Webプログラミング入門", room: "201", teacher: "出原 至道",
                   code: "WP001", colorIndex: 9, unread: 1),
        DemoCourse(weekday: 2, period: 5, name: "ホームゼミII", room: "113", teacher: "小林 英夫",
                   code: "HZ001", colorIndex: 2, unread: 0),
        // 水
        DemoCourse(weekday: 3, period: 2, name: "消費心理学", room: "211", teacher: "浜田 正幸",
                   code: "SK001", colorIndex: 5, unread: 0),
        DemoCourse(weekday: 3, period: 3, name: "世界の宗教", room: "201", teacher: "高橋 恭寛",
                   code: "SR001", colorIndex: 7, unread: 0),
        DemoCourse(weekday: 3, period: 4, name: "現代メディア論", room: "101", teacher: "中澤 弥",
                   code: "GM001", colorIndex: 10, unread: 1),
        // 木
        DemoCourse(weekday: 4, period: 1, name: "経営科学", room: "212", teacher: "新西 誠人",
                   code: "KK001", colorIndex: 3, unread: 0),
        DemoCourse(weekday: 4, period: 2, name: "図化技術概論", room: "201", teacher: "出原 至道",
                   code: "ZG001", colorIndex: 1, unread: 0),
        DemoCourse(weekday: 4, period: 3, name: "統計学基礎", room: "305", teacher: "中村 その子",
                   code: "TK001", colorIndex: 7, unread: 0),
        DemoCourse(weekday: 4, period: 4, name: "マーケティング・心理実践II", room: "111", teacher: "菅沼 睦",
                   code: "MP001", colorIndex: 6, unread: 0),
        // 金
        DemoCourse(weekday: 5, period: 1, name: "英語コミュニケーション", room: "107", teacher: "久保田 貴文",
                   code: "EC001", colorIndex: 5, unread: 0),
        DemoCourse(weekday: 5, period: 2, name: "ミクロ経済学", room: "204", teacher: "中島 拓也",
                   code: "ME001", colorIndex: 2, unread: 0),
        DemoCourse(weekday: 5, period: 3, name: "国際関係論", room: "202", teacher: "伊藤 美咲",
                   code: "IR001", colorIndex: 4, unread: 0)
    ]

    /// 時間割の未読掲示の合計
    static var unreadNoticeCount: Int {
        courses.reduce(0) { $0 + $1.unread }
    }

    /// T-NEXT の `getJugyoKeijiMenuInfo` が返す `data` と同じ形の時間割（`jgkmDtoList` を除く部分）
    static var timetablePayload: [String: Any] {
        ["nendo": 2_026, "gakkiNo": 2, "gakkiName": "秋学期", "keijiCnt": unreadNoticeCount]
    }

    /// T-NEXT の `jgkmDtoList` と同じ形の授業一覧（`TimetableService` の変換をそのまま通す）
    static var courseList: [[String: Any]] {
        let times = [1: (900, 1_030), 2: (1_040, 1_210), 3: (1_300, 1_430), 4: (1_440, 1_610), 5: (1_620, 1_750)]
        return courses.map { course in
            [
                "jugyoName": course.name,
                "kaikoYobi": course.weekday,
                "jigenNo": course.period,
                "nendo": 2_026,
                "kaikoNendo": 2_026,
                "gakkiNo": 2,
                "keijiMidokCnt": course.unread,
                "kyostName": course.room,
                "kyoinName": course.teacher,
                "jugyoCd": course.code,
                "jugyoKbn": "1",
                "jugyoStartTime": times[course.period]?.0 ?? 0,
                "jugyoEndTime": times[course.period]?.1 ?? 0
            ]
        }
    }

    /// 授業の色を入れておく（利用者が科目詳細で色を変えたあとは上書きしない）
    static func seedCourseColorsIfNeeded() {
        for course in courses where CourseColorService.shared.getCourseColor(jugyoCd: course.code) == nil {
            CourseColorService.shared.saveCourseColor(jugyoCd: course.code, colorIndex: course.colorIndex)
        }
    }
}

// MARK: - 科目詳細

extension DemoMode {

    /// デモの科目詳細（お知らせ・出欠・メモ）。お知らせの日付は今日から数えた日数で作る
    static func courseDetail(for course: CourseModel) -> CourseDetailResponse {
        let notices = announcements[course.jugyoCd ?? ""] ?? [
            ("第\(lessonNumber(for: course))回の講義資料を掲載しました", 2),
            ("授業アンケートへのご協力のお願い", 9)
        ]
        // 授業ごとに出欠を少しずつ変える（`hashValue` は起動ごとに変わるので文字コードの和を使う）
        let seed = (course.jugyoCd ?? course.name).unicodeScalars.reduce(0) { $0 + Int($1.value) } % 3
        return CourseDetailResponse(
            announcements: notices.enumerated().map { index, notice in
                AnnouncementModel(
                    id: 9_000 + index, title: notice.title,
                    date: millisecondsSince1970(daysAgo: notice.daysAgo), torkDate: nil)
            },
            attendance: course.jugyoCd == "DB001"
                ? AttendanceModel(present: 11, absent: 1, late: 1, early: 0, sick: 0, unregistered: 0)
                : AttendanceModel(
                    present: 9 + seed, absent: seed == 2 ? 1 : 0, late: seed == 1 ? 1 : 0, early: 0,
                    sick: 0, unregistered: seed == 0 ? 1 : 0),
            memo: memos[course.jugyoCd ?? ""] ?? "",
            syllabusPubFlg: true,
            syuKetuKanriFlg: true
        )
    }

    /// 授業ごとのお知らせ（題名・何日前か）
    private static let announcements: [String: [(title: String, daysAgo: Int)]] = [
        "DB001": [
            ("第6回レポート『正規化と結合』の提出について", 0),
            ("中間試験の範囲（JOIN / GROUP BY まで）", 3),
            ("演習用サンプルDBを更新しました", 7)
        ],
        "WP001": [
            ("【教室変更】本日の授業は202教室で行います", 0),
            ("課題3（フォームの作成）の解説動画を公開しました", 6)
        ],
        "GM001": [
            ("期末レポートのテーマ一覧を掲載しました", 1)
        ],
        "KJ001": [
            ("次回は外部講師によるゲスト講義です", 2),
            ("第5回の講義資料を掲載しました", 7)
        ],
        "HZ001": [
            ("中間発表の順番を決めました", 1),
            ("ゼミ合宿の参加希望調査（11月6日まで）", 5)
        ]
    ]

    /// 授業ごとのメモ
    private static let memos: [String: String] = [
        "DB001": "第6回までの SQL 演習を復習する。\n- サブクエリ\n- 外部結合",
        "HZ001": "中間発表のスライドを金曜までに共有する"
    ]

    /// 秋学期の授業が何回目まで進んだか（10月の第3週あたりの想定）
    private static func lessonNumber(for course: CourseModel) -> Int {
        5 + (course.weekday ?? 1) % 2
    }

    private static func millisecondsSince1970(daysAgo: Int) -> Int {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return Int(date.timeIntervalSince1970 * 1_000)
    }
}

// MARK: - 印刷・教員メール

extension DemoMode {

    /// 印刷の予約1件
    private struct DemoUpload {
        let number: String
        let file: String
        let daysLeft: Int
        let pages: Int
        let plex: PlexType
        let size: String
        let nUp: NUpType
    }

    /// 印刷の履歴が空なら、デモの予約を数件入れる（期限が切れたものは読み込み時に消える）
    static func seedPrintUploadsIfNeeded(in context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<PrintUploadRecord>())) == 0 else { return }
        let uploads = [
            DemoUpload(number: "4KX7P2QM", file: "データベースII_第6回レポート.pdf", daysLeft: 7,
                       pages: 6, plex: .duplex, size: "842 KB", nUp: .none),
            DemoUpload(number: "9TR3W8ZD", file: "ホームゼミII_中間発表スライド.pdf", daysLeft: 6,
                       pages: 12, plex: .simplex, size: "3214 KB", nUp: .two),
            DemoUpload(number: "2HN6C5VB", file: "消費心理学_配布資料.pdf", daysLeft: 5,
                       pages: 4, plex: .simplex, size: "517 KB", nUp: .none)
        ]
        // 履歴は新しい順に並ぶので、先頭の予約が最後に入るようにする
        for upload in uploads.reversed() {
            let expiry = Calendar.current.date(byAdding: .day, value: upload.daysLeft, to: Date()) ?? Date()
            context.insert(PrintUploadRecord(
                printNumber: upload.number, fileName: upload.file, expiryDate: expiry,
                pageCount: upload.pages, duplex: upload.plex.displayName, fileSize: upload.size,
                nUp: upload.nUp.displayName))
        }
        try? context.save()
    }

    /// 教員メール一覧に出す架空の教員（メールアドレスは example ドメイン）
    static let teachers: [Teacher] = [
        ("青山 誠", "あおやま まこと", "aoyama"), ("石井 由紀", "いしい ゆき", "ishii"),
        ("上田 健一", "うえだ けんいち", "ueda"), ("岡本 早苗", "おかもと さなえ", "okamoto"),
        ("加藤 隆", "かとう たかし", "kato"), ("木村 麻衣", "きむら まい", "kimura"),
        ("佐々木 亮", "ささき りょう", "sasaki"), ("鈴木 恵美", "すずき えみ", "suzuki"),
        ("高田 浩二", "たかだ こうじ", "takada"), ("中野 真理", "なかの まり", "nakano"),
        ("林 大輔", "はやし だいすけ", "hayashi"), ("松本 千尋", "まつもと ちひろ", "matsumoto"),
        ("森 光太郎", "もり こうたろう", "mori"), ("吉田 彩", "よしだ あや", "yoshida")
    ].map { name, furigana, account in
        Teacher(name: name, furigana: furigana, email: "\(account)@example.ac.jp")
    }
}
// MARK: - バス時刻表

extension DemoMode {

    /// デモのバス時刻表（平日・水曜日・土曜日 × 4路線、臨時ダイヤのお知らせ無し）。
    ///
    /// 平日の朝は駅発が10〜15分おきに出て、9:41 の時点で次の便（9:47）が数分後になるようにしてある。
    /// 時刻表の1行に収まるよう、1時間あたりの便は5本までにしてある。
    /// 夕方は学校発が増える（実際のダイヤの傾向に合わせた架空の時刻）
    static func busSchedule(specialNotes: [BusSchedule.SpecialNote]) -> BusSchedule {
        BusSchedule(
            weekdaySchedules: daySchedules(.weekday, weekdayTimes),
            saturdaySchedules: daySchedules(.saturday, saturdayTimes),
            wednesdaySchedules: daySchedules(.wednesday, wednesdayTimes),
            specialNotes: specialNotes,
            temporaryMessages: nil,
            pin: nil
        )
    }

    /// 路線ごとの時刻（時 → 分の一覧）。分の後ろに付けた記号は特別便の印（`BusScheduleService` の説明と同じ）
    private typealias RouteTimes = [BusSchedule.RouteType: [Int: [String]]]

    private static let weekdayTimes: RouteTimes = [
        .fromSeisekiToSchool: [
            7: ["40C", "55K"], 8: ["05", "15", "25M", "40", "55"],
            9: ["05M", "20", "35", "47", "58"], 10: ["10", "25◎", "40", "55"],
            11: ["15", "35", "55"], 12: ["15", "35", "55"], 13: ["15", "35", "55"],
            14: ["15", "35"], 15: ["00", "30"], 16: ["00", "30"], 17: ["00", "30"], 18: ["00"]
        ],
        .fromNagayamaToSchool: [
            7: ["50"], 8: ["10", "30", "50"], 9: ["10", "30", "52"], 10: ["20", "50"],
            11: ["20", "50"], 12: ["20", "50"], 13: ["20", "50"], 14: ["20"], 15: ["00"],
            16: ["00"], 17: ["00"]
        ],
        .fromSchoolToSeiseki: [
            9: ["50"], 10: ["20", "45"], 11: ["15", "45"], 12: ["15", "35", "55"],
            13: ["15", "45"], 14: ["15", "35", "50"], 15: ["05", "20", "35", "50"],
            16: ["05", "15", "25", "40", "55"], 17: ["10", "25", "40", "55*"],
            18: ["10", "30", "50"], 19: ["10", "40"], 20: ["10"]
        ],
        .fromSchoolToNagayama: [
            10: ["00", "40"], 11: ["30"], 12: ["20", "50"], 13: ["30"], 14: ["40"],
            15: ["10", "40"], 16: ["10", "30", "50"], 17: ["10", "30", "50"],
            18: ["20", "50"], 19: ["30"]
        ]
    ]

    /// 水曜日（平日より午後の便が少ない）
    private static let wednesdayTimes: RouteTimes = weekdayTimes.mapValues { hours in
        hours.mapValues { minutes in
            minutes.count > 2 ? minutes.enumerated().filter { $0.offset % 3 != 2 }.map(\.element) : minutes
        }
    }

    /// 土曜日（30分おき、午後早めに終わる）
    private static let saturdayTimes: RouteTimes = [
        .fromSeisekiToSchool: [8: ["00", "30"], 9: ["00", "30"], 10: ["00", "30"], 11: ["00"], 12: ["00"]],
        .fromNagayamaToSchool: [8: ["15", "45"], 9: ["15", "45"], 10: ["30"]],
        .fromSchoolToSeiseki: [12: ["10", "40"], 13: ["10", "40"], 14: ["10", "40"], 15: ["10"]],
        .fromSchoolToNagayama: [12: ["25"], 13: ["25"], 14: ["25"]]
    ]

    private static func daySchedules(
        _ type: BusSchedule.ScheduleType, _ routes: RouteTimes
    ) -> [BusSchedule.DaySchedule] {
        let order: [BusSchedule.RouteType] = [
            .fromSeisekiToSchool, .fromNagayamaToSchool, .fromSchoolToSeiseki, .fromSchoolToNagayama
        ]
        return order.map { route in
            BusSchedule.DaySchedule(
                routeType: route,
                scheduleType: type,
                hourSchedules: (routes[route] ?? [:]).keys.sorted().map { hour in
                    BusSchedule.HourSchedule(
                        hour: hour,
                        times: (routes[route]?[hour] ?? []).compactMap { timeEntry(hour: hour, text: $0) })
                })
        }
    }

    /// "25M" のような表記を時刻と特別便の印に分ける
    private static func timeEntry(hour: Int, text: String) -> BusSchedule.TimeEntry? {
        let digits = text.prefix { $0.isNumber }
        guard let minute = Int(digits) else { return nil }
        let note = text.dropFirst(digits.count)
        return BusSchedule.TimeEntry(
            hour: hour, minute: minute, isSpecial: !note.isEmpty, specialNote: note.isEmpty ? nil : String(note))
    }
}
#endif
