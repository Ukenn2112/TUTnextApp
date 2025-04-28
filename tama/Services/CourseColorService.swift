import Foundation
import SwiftUI
import WidgetKit

class CourseColorService {
    static let shared = CourseColorService()

    // App Group ID
    private let appGroupID = "group.com.meikenn.tama"
    private let courseColorsKey = "courseColors"

    // 通常のUserDefaultsとApp Group用UserDefaults
    private let userDefaults = UserDefaults.standard
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // 課程の色を保存
    func saveCourseColor(jugyoCd: String, colorIndex: Int) {
        // 通常のUserDefaultsに保存
        var courseColors = getCourseColors()
        courseColors[jugyoCd] = colorIndex

        if let encoded = try? JSONEncoder().encode(courseColors) {
            userDefaults.set(encoded, forKey: courseColorsKey)
        }

        // App Group共有ストレージからデータを読み込み、更新して保存する
        if let sharedDefaults = sharedDefaults,
            let timetableData = sharedDefaults.data(forKey: "cachedTimetableData")
        {
            do {
                let decoder = JSONDecoder()
                var timetableDataDecoded = try decoder.decode(
                    [String: [String: CourseModel]].self, from: timetableData)

                // 全ての授業を検索して、該当する授業IDの色を更新
                for (dayKey, dayData) in timetableDataDecoded {
                    for (periodKey, courseData) in dayData {
                        if courseData.jugyoCd == jugyoCd {
                            // 色を更新
                            var updatedCourse = courseData
                            updatedCourse.colorIndex = colorIndex
                            timetableDataDecoded[dayKey]?[periodKey] = updatedCourse
                        }
                    }
                }

                // 更新したデータを保存
                let encoder = JSONEncoder()
                if let encodedData = try? encoder.encode(timetableDataDecoded) {
                    sharedDefaults.set(encodedData, forKey: "cachedTimetableData")
                    print("【CourseColorService】App Group共有ストレージのデータを更新しました")
                }
            } catch {
                print("【CourseColorService】App Group共有ストレージの更新に失敗: \(error.localizedDescription)")
            }
        }

        // ウィジェットを更新
        WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
    }

    // 課程の色を取得
    func getCourseColor(jugyoCd: String) -> Int? {
        let courseColors = getCourseColors()
        return courseColors[jugyoCd]
    }

    // 保存されている全ての課程色を取得
    private func getCourseColors() -> [String: Int] {
        guard let data = userDefaults.data(forKey: courseColorsKey),
            let courseColors = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return courseColors
    }

    // 全ての課程色をクリア
    func clearAllCourseColors() {
        userDefaults.removeObject(forKey: courseColorsKey)
    }
}
