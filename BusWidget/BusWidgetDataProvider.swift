import Foundation
import WidgetKit

// アプリグループのID（BusScheduleServiceと同じ値を使用）
let APP_GROUP_ID = "group.com.meikenn.tama"

// キー定数（BusScheduleServiceと同じ値を使用）
private struct BusWidgetKeys {
    static let cachedBusSchedule = "cachedBusSchedule"
    static let lastUpdateTime = "lastBusScheduleFetchTime"
}

// ウィジェット用のバス時刻データプロバイダー
struct BusWidgetDataProvider {
    // 共有UserDefaultsアクセス
    private static let sharedDefaults = UserDefaults(suiteName: APP_GROUP_ID)

    // 日付から適切なスケジュールタイプを判断
    static func getScheduleTypeForDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        // 日本の曜日: 1=日曜日, 2=月曜日, 3=火曜日, 4=水曜日, 5=木曜日, 6=金曜日, 7=土曜日
        if weekday == 7 {
            return "saturday"  // 土曜日
        } else if weekday == 4 {
            return "wednesday"  // 水曜日
        } else {
            return "weekday"  // その他の平日
        }
    }

    // スケジュールタイプに対応する表示名を取得
    static func getScheduleTypeDisplayName(_ scheduleType: String) -> String {
        switch scheduleType {
        case "weekday":
            return NSLocalizedString("平日", comment: "")
        case "saturday":
            return NSLocalizedString("土曜日", comment: "")
        case "wednesday":
            return NSLocalizedString("水曜日", comment: "")
        default:
            return NSLocalizedString("平日", comment: "")
        }
    }

    // App Groupsからバススケジュールデータを取得
    static func getBusScheduleData() -> [String: Any]? {
        guard let busData = sharedDefaults?.data(forKey: BusWidgetKeys.cachedBusSchedule) else {
            #if DEBUG
            print("BusWidgetDataProvider: App Groupsからデータが見つかりませんでした")
            #endif
            return nil
        }

        do {
            // JSONデータをデコード
            let decoder = JSONDecoder()
            let busSchedule = try decoder.decode(BusSchedule.self, from: busData)

            // BusScheduleをディクショナリに変換
            return convertBusScheduleToDict(busSchedule)
        } catch {
            #if DEBUG
            print("BusWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // 最終更新時刻を取得
    static func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: BusWidgetKeys.lastUpdateTime) as? Date
    }

    // 特定の路線とスケジュールタイプのバス時刻を取得
    static func getBusTimes(routeType: String, scheduleType: String) -> [[String: Any]]? {
        guard let data = getBusScheduleData() else { return nil }

        // スケジュールタイプのデータを取得
        guard let scheduleData = data[scheduleType] as? [String: Any] else { return nil }

        // 路線タイプのデータを取得
        return scheduleData[routeType] as? [[String: Any]]
    }

    // 次のバス時刻を取得（現在時刻以降の最大3件）
    static func getNextBusTimes(routeType: String, scheduleType: String, from date: Date)
        -> [BusWidgetSchedule.TimeEntry]
    {
        guard let busTimesData = getBusTimes(routeType: routeType, scheduleType: scheduleType)
        else {
            // データが取得できない場合は空の配列を返す
            return []
        }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)

        // バス時刻のエントリーに変換
        var times: [BusWidgetSchedule.TimeEntry] = []
        for busTimeData in busTimesData {
            if let hour = busTimeData["hour"] as? Int,
                let minute = busTimeData["minute"] as? Int
            {
                let isSpecial = busTimeData["isSpecial"] as? Bool ?? false
                let specialNote = busTimeData["specialNote"] as? String
                times.append(
                    BusWidgetSchedule.TimeEntry(
                        hour: hour, minute: minute, isSpecial: isSpecial, specialNote: specialNote))
            }
        }

        // 現在時刻以降のバス時刻をフィルター
        let upcomingTimes = times.filter { entry in
            return (entry.hour > currentHour)
                || (entry.hour == currentHour && entry.minute >= currentMinute)
        }

        // 最大3件まで返す
        return Array(upcomingTimes.prefix(3))
    }

    // BusScheduleオブジェクトをディクショナリに変換するヘルパーメソッド
    private static func convertBusScheduleToDict(_ busSchedule: BusSchedule) -> [String: Any] {
        var result: [String: Any] = [:]

        // 平日スケジュール
        var weekdayDict: [String: Any] = [:]
        for daySchedule in busSchedule.weekdaySchedules {
            let routeTypeKey = daySchedule.routeType.rawValue
            let hourSchedules = daySchedule.hourSchedules

            var timesArray: [[String: Any]] = []
            for hourSchedule in hourSchedules {
                for time in hourSchedule.times {
                    timesArray.append([
                        "hour": time.hour,
                        "minute": time.minute,
                        "isSpecial": time.isSpecial,
                        "specialNote": time.specialNote as Any,
                    ])
                }
            }

            weekdayDict[routeTypeKey] = timesArray
        }
        result["weekday"] = weekdayDict

        // 水曜日スケジュール
        var wednesdayDict: [String: Any] = [:]
        for daySchedule in busSchedule.wednesdaySchedules {
            let routeTypeKey = daySchedule.routeType.rawValue
            let hourSchedules = daySchedule.hourSchedules

            var timesArray: [[String: Any]] = []
            for hourSchedule in hourSchedules {
                for time in hourSchedule.times {
                    timesArray.append([
                        "hour": time.hour,
                        "minute": time.minute,
                        "isSpecial": time.isSpecial,
                        "specialNote": time.specialNote as Any,
                    ])
                }
            }

            wednesdayDict[routeTypeKey] = timesArray
        }
        result["wednesday"] = wednesdayDict

        // 土曜日スケジュール
        var saturdayDict: [String: Any] = [:]
        for daySchedule in busSchedule.saturdaySchedules {
            let routeTypeKey = daySchedule.routeType.rawValue
            let hourSchedules = daySchedule.hourSchedules

            var timesArray: [[String: Any]] = []
            for hourSchedule in hourSchedules {
                for time in hourSchedule.times {
                    timesArray.append([
                        "hour": time.hour,
                        "minute": time.minute,
                        "isSpecial": time.isSpecial,
                        "specialNote": time.specialNote as Any,
                    ])
                }
            }

            saturdayDict[routeTypeKey] = timesArray
        }
        result["saturday"] = saturdayDict

        return result
    }
}
