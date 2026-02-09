import Foundation
import SwiftUI
import WidgetKit

/// Course color storage service for widgets
/// Migrated from Services/CourseColorService.swift
@MainActor
public final class CourseColorService {
    public static let shared = CourseColorService()
    
    private let appGroupID = "group.com.meikenn.tama"
    private let courseColorsKey = "courseColors"
    
    private let userDefaults = UserDefaults.standard
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    public func saveCourseColor(jugyoCd: String, colorIndex: Int) {
        var courseColors = getCourseColors()
        courseColors[jugyoCd] = colorIndex
        
        if let encoded = try? JSONEncoder().encode(courseColors) {
            userDefaults.set(encoded, forKey: courseColorsKey)
        }
        
        updateSharedTimetableData(jugyoCd: jugyoCd, colorIndex: colorIndex)
        WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
    }
    
    public func getCourseColor(jugyoCd: String) -> Int? {
        getCourseColors()[jugyoCd]
    }
    
    public func clearAllCourseColors() {
        userDefaults.removeObject(forKey: courseColorsKey)
    }
    
    private func getCourseColors() -> [String: Int] {
        guard let data = userDefaults.data(forKey: courseColorsKey),
              let courseColors = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return courseColors
    }
    
    private func updateSharedTimetableData(jugyoCd: String, colorIndex: Int) {
        guard let sharedDefaults = sharedDefaults,
              let timetableData = sharedDefaults.data(forKey: "cachedTimetableData") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            var timetableDataDecoded = try decoder.decode(
                [String: [String: CourseModel]].self, from: timetableData)
            
            for (dayKey, dayData) in timetableDataDecoded {
                for (periodKey, courseData) in dayData {
                    if courseData.jugyoCd == jugyoCd {
                        var updatedCourse = courseData
                        updatedCourse.colorIndex = colorIndex
                        timetableDataDecoded[dayKey]?[periodKey] = updatedCourse
                    }
                }
            }
            
            let encoder = JSONEncoder()
            if let encodedData = try? encoder.encode(timetableDataDecoded) {
                sharedDefaults.set(encodedData, forKey: "cachedTimetableData")
                print("【CourseColorService】Updated App Group shared storage")
            }
        } catch {
            print("【CourseColorService】Failed to update App Group storage: \\(error.localizedDescription)")
        }
    }
}
