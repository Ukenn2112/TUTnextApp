//
//  BusWidgetDataProvider.swift
//  BusWidget
//
//  Refactored to use Core/Storage and Core/Models
//

import Foundation
import SwiftUI
import WidgetKit

// MARK: - Constants

private struct BusWidgetKeys {
    static let cachedBusSchedule = "cachedBusSchedule"
    static let lastUpdateTime = "lastBusScheduleFetchTime"
    static let suiteName = "group.com.tutnext.tama"
}

// MARK: - Widget Data Provider

struct BusWidgetDataProvider {
    private static let sharedDefaults = UserDefaults(suiteName: BusWidgetKeys.suiteName)
    
    // MARK: - Schedule Type Methods
    
    static func getScheduleTypeForDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 日本の曜日: 1=日曜日, 2=月曜日, 3=火曜日, 4=水曜日, 5=木曜日, 6=金曜日, 7=土曜日
        if weekday == 7 {
            return "saturday"
        } else if weekday == 4 {
            return "wednesday"
        } else {
            return "weekday"
        }
    }
    
    static func getScheduleTypeDisplayName(_ scheduleType: String) -> String {
        switch scheduleType {
        case "weekday": return "平日"
        case "saturday": return "土曜日"
        case "wednesday": return "水曜日"
        default: return "平日"
        }
    }
    
    // MARK: - Data Access Methods
    
    static func getBusScheduleData() -> [String: Any]? {
        guard let busData = sharedDefaults?.data(forKey: BusWidgetKeys.cachedBusSchedule) else {
            print("BusWidgetDataProvider: App Groupsからデータが見つかりませんでした")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let busSchedule = try decoder.decode(BusSchedule.self, from: busData)
            return convertBusScheduleToDict(busSchedule)
        } catch {
            print("BusWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            return nil
        }
    }
    
    static func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: BusWidgetKeys.lastUpdateTime) as? Date
    }
    
    // MARK: - Bus Times Methods
    
    static func getBusTimes(routeType: String, scheduleType: String) -> [[String: Any]]? {
        guard let data = getBusScheduleData() else { return nil }
        
        guard let scheduleData = data[scheduleType] as? [String: Any] else { return nil }
        
        return scheduleData[routeType] as? [[String: Any]]
    }
    
    static func getNextBusTimes(routeType: String, scheduleType: String, from date: Date) -> [BusTimeEntry] {
        guard let busTimesData = getBusTimes(routeType: routeType, scheduleType: scheduleType) else {
            return []
        }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        
        var times: [BusTimeEntry] = []
        for busTimeData in busTimesData {
            if let hour = busTimeData["hour"] as? Int,
               let minute = busTimeData["minute"] as? Int {
                let isSpecial = busTimeData["isSpecial"] as? Bool ?? false
                let specialNote = busTimeData["specialNote"] as? String
                times.append(
                    BusTimeEntry(
                        id: UUID().uuidString,
                        hour: hour,
                        minute: minute,
                        isSpecial: isSpecial,
                        specialNote: specialNote
                    )
                )
            }
        }
        
        let upcomingTimes = times.filter { entry in
            return (entry.hour > currentHour) || (entry.hour == currentHour && entry.minute >= currentMinute)
        }
        
        return Array(upcomingTimes.prefix(3))
    }
    
    // MARK: - Conversion Helper
    
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
