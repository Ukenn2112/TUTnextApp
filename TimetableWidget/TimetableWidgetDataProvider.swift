//
//  TimetableWidgetDataProvider.swift
//  TimetableWidget
//
//  Refactored to use Core/Storage and shared WidgetModels
//

import Foundation
import SwiftUI
import WidgetKit

// MARK: - Constants

private struct TimetableWidgetKeys {
    static let cachedTimetableData = "cachedTimetableData"
    static let lastUpdateTime = "lastTimetableFetchTime"
    static let suiteName = "group.com.tutnext.tama"
}

// MARK: - Widget Data Provider

class TimetableWidgetDataProvider {
    static let shared = TimetableWidgetDataProvider()
    
    private let sharedDefaults: UserDefaults?
    
    private init() {
        sharedDefaults = UserDefaults(suiteName: TimetableWidgetKeys.suiteName)
    }
    
    // MARK: - Data Access Methods
    
    func getTimetableData() -> [String: [String: Course]]? {
        guard let userDefaults = sharedDefaults else {
            print("TimetableWidgetDataProvider: App Groupsにアクセスできません")
            return SampleDataProvider.sampleCourses
        }
        
        guard let timetableData = userDefaults.data(forKey: TimetableWidgetKeys.cachedTimetableData) else {
            print("TimetableWidgetDataProvider: App Groupsからデータが見つかりませんでした")
            return SampleDataProvider.sampleCourses
        }
        
        do {
            let decoder = JSONDecoder()
            let timetableDataDecoded = try decoder.decode(
                [String: [String: Course]].self, from: timetableData)
            return timetableDataDecoded
        } catch {
            print("TimetableWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            return SampleDataProvider.sampleCourses
        }
    }
    
    func getLastFetchTime() -> Date? {
        guard let userDefaults = sharedDefaults else {
            return nil
        }
        
        return userDefaults.object(forKey: TimetableWidgetKeys.lastUpdateTime) as? Date
    }
    
    // MARK: - Time Access Methods
    
    func getCurrentWeekday() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let japaneseWeekday = weekday == 1 ? 7 : weekday - 1
        return String(japaneseWeekday)
    }
    
    func getCurrentPeriod() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute
        
        let periods: [(String, Int, Int)] = [
            ("1", 9 * 60, 10 * 60 + 30),
            ("2", 10 * 60 + 40, 12 * 60 + 10),
            ("3", 13 * 60, 14 * 60 + 30),
            ("4", 14 * 60 + 40, 16 * 60 + 10),
            ("5", 16 * 60 + 20, 17 * 60 + 50),
            ("6", 18 * 60, 19 * 60 + 30),
            ("7", 19 * 60 + 40, 21 * 60 + 10),
        ]
        
        for (periodNumber, startMinutes, endMinutes) in periods {
            if currentTime >= startMinutes && currentTime <= endMinutes {
                return periodNumber
            }
        }
        
        return nil
    }
    
    func getWeekdays() -> [String] {
        let baseWeekdays = ["1", "2", "3", "4", "5"]
        
        if let saturdayCourses = getTimetableData()?["6"], !saturdayCourses.isEmpty {
            return baseWeekdays + ["6"]
        }
        
        return baseWeekdays
    }
    
    func getWeekdayDisplayString(from index: String) -> String {
        guard let idx = Int(index), idx >= 1 && idx <= 7 else { return "" }
        let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
        return weekdays[idx - 1]
    }
    
    func getPeriods() -> [(String, String, String)] {
        let basePeriods = [
            ("1", "9:00", "10:30"),
            ("2", "10:40", "12:10"),
            ("3", "13:00", "14:30"),
            ("4", "14:40", "16:10"),
            ("5", "16:20", "17:50"),
            ("6", "18:00", "19:30"),
            ("7", "19:40", "21:10"),
        ]
        
        let has7thPeriod = hasSpecificPeriod("7")
        let has6thPeriod = hasSpecificPeriod("6")
        
        if has7thPeriod {
            return basePeriods
        } else if has6thPeriod {
            return Array(basePeriods.prefix(6))
        } else {
            return Array(basePeriods.prefix(5))
        }
    }
    
    private func hasSpecificPeriod(_ period: String) -> Bool {
        guard let timetableData = getTimetableData() else { return false }
        
        for (_, coursesForDay) in timetableData {
            if coursesForDay.keys.contains(period) {
                return true
            }
        }
        
        return false
    }
    
    func getCourse(day: String, period: String) -> Course? {
        return getTimetableData()?[day]?[period]
    }
    
    func getCoursesForDay(day: String) -> [String: Course]? {
        return getTimetableData()?[day]
    }
    
    func getAllCourses() -> [Course] {
        guard let timetableData = getTimetableData() else { return [] }
        
        var allCourses: [Course] = []
        for (_, coursesForDay) in timetableData {
            allCourses.append(contentsOf: coursesForDay.values)
        }
        
        return allCourses
    }
}
