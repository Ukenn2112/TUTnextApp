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
    private static let modelContext = ModelContext(SharedModelContainer.shared)

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
        // ModelContext はメインスレッドで作成されたため、メインスレッドで同期的に実行
        var schedule: BusSchedule?
        if Thread.isMainThread {
            schedule = fetchBusScheduleFromContext()
        } else {
            DispatchQueue.main.sync {
                schedule = fetchBusScheduleFromContext()
            }
        }
        return schedule
    }
    
    private static func fetchBusScheduleFromContext() -> BusSchedule? {
        do {
            let descriptor = FetchDescriptor<CachedBusSchedule>(
                predicate: #Predicate { $0.key == "busSchedule" }
            )
            guard let cached = try modelContext.fetch(descriptor).first else {
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
