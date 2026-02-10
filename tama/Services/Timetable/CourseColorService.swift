import Foundation
import SwiftUI
import WidgetKit

/// 授業カラー管理サービス
final class CourseColorService {
    static let shared = CourseColorService()

    private let appGroupID = "group.com.meikenn.tama"
    private let courseColorsKey = "courseColors"

    private let userDefaults = UserDefaults.standard
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - パブリックメソッド

    /// 授業の色を保存する
    func saveCourseColor(jugyoCd: String, colorIndex: Int) {
        var courseColors = getCourseColors()
        courseColors[jugyoCd] = colorIndex

        if let encoded = try? JSONEncoder().encode(courseColors) {
            userDefaults.set(encoded, forKey: courseColorsKey)
        }

        // App Group共有ストレージのデータも更新する
        if let sharedDefaults = sharedDefaults,
            let timetableData = sharedDefaults.data(forKey: "cachedTimetableData")
        {
            do {
                var timetableDataDecoded = try JSONDecoder().decode(
                    [String: [String: CourseModel]].self, from: timetableData)

                // 全ての授業を検索して該当する授業IDの色を更新
                for (dayKey, dayData) in timetableDataDecoded {
                    for (periodKey, courseData) in dayData {
                        if courseData.jugyoCd == jugyoCd {
                            var updatedCourse = courseData
                            updatedCourse.colorIndex = colorIndex
                            timetableDataDecoded[dayKey]?[periodKey] = updatedCourse
                        }
                    }
                }

                if let encodedData = try? JSONEncoder().encode(timetableDataDecoded) {
                    sharedDefaults.set(encodedData, forKey: "cachedTimetableData")
                }
            } catch {
                print("【CourseColorService】App Group共有ストレージの更新失敗: \(error.localizedDescription)")
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
    }

    /// 授業の色を取得する
    func getCourseColor(jugyoCd: String) -> Int? {
        let courseColors = getCourseColors()
        return courseColors[jugyoCd]
    }

    /// 全ての授業色をクリアする
    func clearAllCourseColors() {
        userDefaults.removeObject(forKey: courseColorsKey)
    }

    // MARK: - プライベートメソッド

    /// 保存されている全ての授業色を取得する
    private func getCourseColors() -> [String: Int] {
        guard let data = userDefaults.data(forKey: courseColorsKey),
            let courseColors = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return courseColors
    }
}
