import Foundation
import SwiftUI

class CourseColorService {
    static let shared = CourseColorService()
    
    private let userDefaults = UserDefaults.standard
    private let courseColorsKey = "courseColors"
    
    private init() {}
    
    // 課程の色を保存
    func saveCourseColor(jugyoCd: String, colorIndex: Int) {
        var courseColors = getCourseColors()
        courseColors[jugyoCd] = colorIndex
        
        if let encoded = try? JSONEncoder().encode(courseColors) {
            userDefaults.set(encoded, forKey: courseColorsKey)
        }
    }
    
    // 課程の色を取得
    func getCourseColor(jugyoCd: String) -> Int? {
        let courseColors = getCourseColors()
        return courseColors[jugyoCd]
    }
    
    // 保存されている全ての課程色を取得
    private func getCourseColors() -> [String: Int] {
        guard let data = userDefaults.data(forKey: courseColorsKey),
              let courseColors = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return courseColors
    }
    
    // 全ての課程色をクリア
    func clearAllCourseColors() {
        userDefaults.removeObject(forKey: courseColorsKey)
    }
} 