import Foundation

// MARK: - /schedule/later レスポンスモデル

struct TodayScheduleResponse: Codable {
    let status: Bool
    let data: TodayScheduleData?
    let message: String?
}

struct TodayScheduleData: Codable {
    let dateInfo: DateInfo
    let allDayEvents: [AllDayEvent]
    let timeTable: [TodayLesson]

    enum CodingKeys: String, CodingKey {
        case dateInfo = "date_info"
        case allDayEvents = "all_day_events"
        case timeTable = "time_table"
    }
}

struct DateInfo: Codable {
    /// 日付（"2026/04/03" 形式）
    let date: String
    /// 曜日（"金" など）
    let dayOfWeek: String

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
    }
}

struct AllDayEvent: Codable {
    let title: String
    let id: String
    let isImportant: Bool

    enum CodingKeys: String, CodingKey {
        case title, id
        case isImportant = "is_important"
    }
}

// MARK: - 時限テーブル（JST 固定）

/// 時限番号 → 開始/終了時刻のマッピング
/// ⚠️ バックエンドの時限テーブルと完全に一致させること（バックエンドは lesson_num からトランジションを算出する）
enum ClassPeriodTable {
    /// 時限番号（1〜7）→ ("HH:mm" 開始, "HH:mm" 終了)
    static let periods: [Int: (start: String, end: String)] = [
        1: ("09:00", "10:30"),
        2: ("10:40", "12:10"),
        3: ("13:00", "14:30"),
        4: ("14:40", "16:10"),
        5: ("16:20", "17:50"),
        6: ("18:00", "19:30"),
        7: ("19:40", "21:10"),
    ]

    /// 時限番号から "HH:mm" 形式の時刻を返す（component: 0 = 開始, 1 = 終了）
    static func timeString(lessonNum: Int?, component: Int) -> String? {
        guard let lessonNum, let period = periods[lessonNum] else { return nil }
        return component == 0 ? period.start : period.end
    }
}

// MARK: - 時間割エントリ

struct TodayLesson: Codable {
    /// 時間帯（"09:00-10:30" または "09:00 - 10:30" 形式）
    let time: String?
    /// 時限番号（1〜7）
    let lessonNum: Int?
    /// 授業名
    let name: String?
    /// 担当教員リスト
    let teachers: [String]?
    /// 教室（"教室 M101" 形式）
    let room: String?
    /// 変更前の教室（教室変更時のみ）
    let previousRoom: String?
    /// 特殊タグ（"休講" など）
    let specialTags: [String]?

    enum CodingKeys: String, CodingKey {
        case time, name, teachers, room
        case lessonNum = "lesson_num"
        case previousRoom = "previous_room"
        case specialTags = "special_tags"
    }

    // MARK: - 算出プロパティ

    /// "教室" プレフィックスを除去した教室名
    var cleanRoom: String {
        (room ?? "")
            .replacingOccurrences(of: "教室", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// 休講かどうか
    var isCancelled: Bool {
        specialTags?.contains("休講") == true
    }

    /// 教室変更があるか
    var hasRoomChange: Bool {
        previousRoom != nil
    }

    /// 主担当教員名
    var primaryTeacher: String {
        teachers?.first ?? ""
    }

    // MARK: - 時間パース

    /// 授業開始時刻を Date に変換する
    /// - Parameter dateString: 日付文字列（"2026/04/03" 形式）
    func startTime(on dateString: String) -> Date? {
        parseTime(component: 0, on: dateString)
    }

    /// 授業終了時刻を Date に変換する
    /// - Parameter dateString: 日付文字列（"2026/04/03" 形式）
    func endTime(on dateString: String) -> Date? {
        parseTime(component: 1, on: dateString)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// `time` 文字列（"18:00-19:30" / "18:00 - 19:30" 両対応）から時刻を取り出す。
    /// パースに失敗した場合は `lessonNum` の固定時限テーブルにフォールバックする。
    private func parseTime(component: Int, on dateString: String) -> Date? {
        guard component == 0 || component == 1 else { return nil }

        var timeStr: String?
        if let time {
            // 区切りは "-"（前後の空白は任意）。全角ハイフン・波ダッシュも許容する
            let normalized = time
                .replacingOccurrences(of: "\u{301c}", with: "-")
                .replacingOccurrences(of: "\u{ff5e}", with: "-")
                .replacingOccurrences(of: "\u{ff0d}", with: "-")
            let parts = normalized
                .components(separatedBy: "-")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if parts.count == 2 {
                timeStr = parts[component]
            }
        }

        // フォールバック: 固定時限テーブル
        if timeStr == nil {
            timeStr = ClassPeriodTable.timeString(lessonNum: lessonNum, component: component)
        }

        guard let timeStr else { return nil }
        return Self.dateTimeFormatter.date(from: "\(dateString) \(timeStr)")
    }

    // MARK: - 表示名

    /// 末尾の主担当教員名を除去した授業名
    /// 例: "ホームゼミVI 小林 英夫" → "ホームゼミVI"
    var displayName: String {
        let raw = (name ?? "").trimmingCharacters(in: .whitespaces)
        guard let stripped = Self.stripTrailingTeacher(raw, teacher: primaryTeacher) else { return raw }
        let trimmed = stripped.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? raw : trimmed
    }

    /// 授業名末尾の教員名を取り除く。空白の有無の違いも吸収する
    private static func stripTrailingTeacher(_ raw: String, teacher: String) -> String? {
        let teacher = teacher.trimmingCharacters(in: .whitespaces)
        guard !teacher.isEmpty else { return nil }
        if raw.hasSuffix(teacher) { return String(raw.dropLast(teacher.count)) }

        // "小林 英夫" と "小林英夫" のような空白差を無視して後方一致させる
        var remaining = Array(teacher.filter { !$0.isWhitespace })
        guard !remaining.isEmpty else { return nil }
        var index = raw.endIndex
        while index > raw.startIndex, !remaining.isEmpty {
            let prev = raw.index(before: index)
            let character = raw[prev]
            index = prev
            if character.isWhitespace { continue }
            guard character == remaining.last else { return nil }
            remaining.removeLast()
        }
        return remaining.isEmpty ? String(raw[raw.startIndex..<index]) : nil
    }
}
