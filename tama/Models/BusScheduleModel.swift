import Foundation

// MARK: - バス時刻表データモデル
struct BusSchedule: Codable {
    // MARK: - 列挙型

    /// バス路線タイプ
    enum RouteType: String, Codable {
        case fromSeisekiToSchool  // 聖蹟桜ヶ丘駅発
        case fromNagayamaToSchool  // 永山駅発
        case fromSchoolToSeiseki  // 聖蹟桜ヶ丘駅行
        case fromSchoolToNagayama  // 永山駅行
    }

    /// バス時刻表タイプ
    enum ScheduleType: String, Codable {
        case weekday  // 平日（水曜日を除く）
        case saturday  // 土曜日
        case wednesday  // 水曜日特別ダイヤ
    }

    // MARK: - 構造体

    /// 個別の時刻データ
    struct TimeEntry: Equatable, Codable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool  // 特別便かどうか（◯や*などのマーク）
        let specialNote: String?  // 特別便の備考

        /// 時間を文字列にフォーマット (HH:MM)
        var formattedTime: String {
            return String(format: "%02d:%02d", hour, minute)
        }

        /// Equatableプロトコルの実装
        static func == (lhs: TimeEntry, rhs: TimeEntry) -> Bool {
            return lhs.hour == rhs.hour && lhs.minute == rhs.minute
                && lhs.isSpecial == rhs.isSpecial && lhs.specialNote == rhs.specialNote
        }
    }

    /// 1時間ごとの発車時刻
    struct HourSchedule: Codable {
        let hour: Int
        let times: [TimeEntry]
    }

    /// 1日の完全な時刻表
    struct DaySchedule: Codable {
        let routeType: RouteType
        let scheduleType: ScheduleType
        let hourSchedules: [HourSchedule]
    }

    /// 特別便の説明
    struct SpecialNote: Codable {
        let symbol: String
        let description: String
    }

    // MARK: - 臨時ダイヤメッセージ
    struct TemporaryMessage: Codable {
        let title: String
        let url: String
    }

    // MARK: - プロパティ

    /// すべての路線の時刻表
    let weekdaySchedules: [DaySchedule]  // 平日時刻表
    let saturdaySchedules: [DaySchedule]  // 土曜日時刻表
    let wednesdaySchedules: [DaySchedule]  // 水曜日時刻表
    let specialNotes: [SpecialNote]  // 特別便の説明
    let temporaryMessages: [TemporaryMessage]?  // 臨時ダイヤメッセージ
}

// MARK: - APIレスポンス用のデコード構造体
struct BusAPIResponse: Codable {
    let messages: [BusSchedule.TemporaryMessage]?
    let data: BusData

    struct BusData: Codable {
        let weekday: ScheduleData
        let wednesday: ScheduleData
        let saturday: ScheduleData

        struct ScheduleData: Codable {
            let fromSeisekiToSchool: [BusSchedule.HourSchedule]?
            let fromNagayamaToSchool: [BusSchedule.HourSchedule]?
            let fromSchoolToSeiseki: [BusSchedule.HourSchedule]?
            let fromSchoolToNagayama: [BusSchedule.HourSchedule]?
        }
    }
}
