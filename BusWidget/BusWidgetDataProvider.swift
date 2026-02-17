import Foundation
import WidgetKit

let APP_GROUP_ID = "group.com.meikenn.tama"

// デコード専用モデル（メインアプリの BusScheduleModel と互換）
private struct BusSchedule: Codable {
    struct TimeEntry: Codable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool
        let specialNote: String?
    }

    struct HourSchedule: Codable {
        let hour: Int
        let times: [TimeEntry]
    }

    struct DaySchedule: Codable {
        let routeType: String
        let scheduleType: String
        let hourSchedules: [HourSchedule]

        var flatTimes: [TimeEntry] {
            hourSchedules.flatMap(\.times)
        }
    }

    struct SpecialNote: Codable {
        let symbol: String
        let description: String
    }

    struct TemporaryMessage: Codable {
        let title: String
        let url: String
    }

    let weekdaySchedules: [DaySchedule]
    let saturdaySchedules: [DaySchedule]
    let wednesdaySchedules: [DaySchedule]
    let specialNotes: [SpecialNote]
    let temporaryMessages: [TemporaryMessage]?

    func schedules(for scheduleType: String) -> [DaySchedule] {
        switch scheduleType {
        case "weekday": weekdaySchedules
        case "saturday": saturdaySchedules
        case "wednesday": wednesdaySchedules
        default: weekdaySchedules
        }
    }
}

private enum BusWidgetKeys {
    static let cachedBusSchedule = "cachedBusSchedule"
}

struct BusWidgetDataProvider {
    private static let sharedDefaults = UserDefaults(suiteName: APP_GROUP_ID)

    static func getScheduleTypeForDate(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 7: return "saturday"
        case 4: return "wednesday"
        default: return "weekday"
        }
    }

    static func getScheduleTypeDisplayName(_ scheduleType: String) -> String {
        switch scheduleType {
        case "weekday": return NSLocalizedString("平日", comment: "")
        case "saturday": return NSLocalizedString("土曜日", comment: "")
        case "wednesday": return NSLocalizedString("水曜日", comment: "")
        default: return NSLocalizedString("平日", comment: "")
        }
    }

    static func getNextBusTimes(
        routeType: String,
        scheduleType: String,
        from date: Date
    ) -> [BusWidgetSchedule.TimeEntry] {
        guard let schedule = decodeBusSchedule() else { return [] }

        let daySchedule = schedule.schedules(for: scheduleType)
            .first { $0.routeType == routeType }
        guard let daySchedule else { return [] }

        let currentHour = Calendar.current.component(.hour, from: date)
        let currentMinute = Calendar.current.component(.minute, from: date)

        let upcoming = daySchedule.flatTimes
            .filter { $0.hour > currentHour || ($0.hour == currentHour && $0.minute >= currentMinute) }
            .prefix(3)
            .map { BusWidgetSchedule.TimeEntry(hour: $0.hour, minute: $0.minute, isSpecial: $0.isSpecial, specialNote: $0.specialNote) }

        return Array(upcoming)
    }

    // MARK: - Private

    private static func decodeBusSchedule() -> BusSchedule? {
        guard let data = sharedDefaults?.data(forKey: BusWidgetKeys.cachedBusSchedule) else {
            #if DEBUG
            print("BusWidgetDataProvider: App Groupsからデータが見つかりませんでした")
            #endif
            return nil
        }

        do {
            return try JSONDecoder().decode(BusSchedule.self, from: data)
        } catch {
            #if DEBUG
            print("BusWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
