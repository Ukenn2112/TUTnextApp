import Foundation
import SwiftData
import WidgetKit

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

struct BusWidgetDataProvider {

    /// 一度デコードした時刻表のスナップショット
    /// タイムライン生成時に1回だけ読み込み、以降はローカル計算のみで使用する
    struct Snapshot {
        fileprivate let schedule: BusSchedule?

        var isAvailable: Bool { schedule != nil }
    }

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

    /// SwiftData から時刻表を読み込む（呼び出しスレッド上で ModelContext を生成）
    static func loadSnapshot() -> Snapshot {
        Snapshot(schedule: fetchBusSchedule())
    }

    /// 指定時刻以降の次のバス（最大3本）
    static func getNextBusTimes(
        routeType: String,
        scheduleType: String,
        from date: Date,
        snapshot: Snapshot? = nil
    ) -> [BusWidgetSchedule.TimeEntry] {
        let all = getAllRemainingBusTimes(
            routeType: routeType, scheduleType: scheduleType, from: date, snapshot: snapshot)
        return Array(all.prefix(3))
    }

    /// 指定時刻以降に残っているその日の全てのバス
    static func getAllRemainingBusTimes(
        routeType: String,
        scheduleType: String,
        from date: Date,
        snapshot: Snapshot? = nil
    ) -> [BusWidgetSchedule.TimeEntry] {
        let schedule = snapshot?.schedule ?? fetchBusSchedule()
        guard let schedule else { return [] }

        let daySchedule = schedule.schedules(for: scheduleType)
            .first { $0.routeType == routeType }
        guard let daySchedule else { return [] }

        let currentHour = Calendar.current.component(.hour, from: date)
        let currentMinute = Calendar.current.component(.minute, from: date)

        return daySchedule.flatTimes
            .filter { $0.hour > currentHour || ($0.hour == currentHour && $0.minute >= currentMinute) }
            .map {
                BusWidgetSchedule.TimeEntry(
                    hour: $0.hour, minute: $0.minute,
                    isSpecial: $0.isSpecial, specialNote: $0.specialNote)
            }
    }

    // MARK: - Private

    /// ModelContext は呼び出しごとに生成する（SwiftData はスレッド間で共有できない）
    private static func fetchBusSchedule() -> BusSchedule? {
        guard let container = SharedModelContainer.sharedForExtension else {
            #if DEBUG
            print("BusWidgetDataProvider: ModelContainer が利用できません")
            #endif
            return nil
        }

        let context = ModelContext(container)
        do {
            let descriptor = FetchDescriptor<CachedBusSchedule>(
                predicate: #Predicate { $0.key == "busSchedule" }
            )
            guard let cached = try context.fetch(descriptor).first else {
                #if DEBUG
                print("BusWidgetDataProvider: SwiftData からデータが見つかりませんでした")
                #endif
                return nil
            }
            return try JSONDecoder().decode(BusSchedule.self, from: cached.data)
        } catch {
            #if DEBUG
            print("BusWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
