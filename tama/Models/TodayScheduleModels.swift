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

// MARK: - 時間割エントリ

struct TodayLesson: Codable {
    /// 時間帯（"09:00 - 10:40" 形式）
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

    private func parseTime(component: Int, on dateString: String) -> Date? {
        guard let time else { return nil }
        let parts = time.components(separatedBy: " - ")
        guard parts.count == 2, component < 2 else { return nil }
        let timeStr = parts[component].trimmingCharacters(in: .whitespaces)
        return Self.dateTimeFormatter.date(from: "\(dateString) \(timeStr)")
    }
}
