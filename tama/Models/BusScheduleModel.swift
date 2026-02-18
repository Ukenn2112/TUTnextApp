import Foundation

// MARK: - バス時刻表データモデル

/// バス時刻表データを表すモデル
struct BusSchedule: Codable {

    // MARK: - 列挙型

    /// バス路線タイプ
    enum RouteType: String, Codable {
        case fromSeisekiToSchool
        case fromNagayamaToSchool
        case fromSchoolToSeiseki
        case fromSchoolToNagayama
    }

    /// バス時刻表タイプ
    enum ScheduleType: String, Codable {
        case weekday
        case saturday
        case wednesday
    }

    // MARK: - ネスト構造体

    /// 個別の時刻データ
    struct TimeEntry: Equatable, Codable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool
        let specialNote: String?

        /// フォーマットされた時間文字列（HH:MM）
        var formattedTime: String {
            String(format: "%02d:%02d", hour, minute)
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

    /// 臨時ダイヤメッセージ
    struct TemporaryMessage: Codable {
        let title: String
        let url: String
    }

    /// ピンメッセージ
    struct PinMessage: Codable {
        let title: String
        let url: String
    }

    // MARK: - プロパティ

    let weekdaySchedules: [DaySchedule]
    let saturdaySchedules: [DaySchedule]
    let wednesdaySchedules: [DaySchedule]
    let specialNotes: [SpecialNote]
    let temporaryMessages: [TemporaryMessage]?
    let pin: PinMessage?
}

// MARK: - APIレスポンス用デコード構造体

/// バスAPIのレスポンス
struct BusAPIResponse: Codable {
    let messages: [BusSchedule.TemporaryMessage]?
    let pin: BusSchedule.PinMessage?
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
