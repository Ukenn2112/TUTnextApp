import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// 授業カラー管理サービス
final class CourseColorService {
    static let shared = CourseColorService()

    /// SwiftData ModelContext
    private var modelContext: ModelContext?

    private init() {
        setupModelContext()
    }

    /// ModelContext を初期化
    private func setupModelContext() {
        modelContext = ModelContext(SharedModelContainer.shared)
    }

    // MARK: - パブリックメソッド

    /// 授業の色を保存する
    func saveCourseColor(jugyoCd: String, colorIndex: Int) {
        guard let context = modelContext else { return }

        do {
            // CourseColorRecord を upsert
            let searchCd = jugyoCd
            let descriptor = FetchDescriptor<CourseColorRecord>(
                predicate: #Predicate { $0.jugyoCd == searchCd }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.colorIndex = colorIndex
            } else {
                let record = CourseColorRecord(jugyoCd: jugyoCd, colorIndex: colorIndex)
                context.insert(record)
            }

            // CachedTimetable の blob 内カラーも更新
            let timetableDescriptor = FetchDescriptor<CachedTimetable>(
                predicate: #Predicate { $0.key == "timetable" }
            )
            if let cached = try context.fetch(timetableDescriptor).first {
                var timetableData = try JSONDecoder().decode(
                    [String: [String: CourseModel]].self, from: cached.data)

                for (dayKey, dayData) in timetableData {
                    for (periodKey, courseData) in dayData {
                        if courseData.jugyoCd == jugyoCd {
                            var updatedCourse = courseData
                            updatedCourse.colorIndex = colorIndex
                            timetableData[dayKey]?[periodKey] = updatedCourse
                        }
                    }
                }

                cached.data = try JSONEncoder().encode(timetableData)
            }

            try context.save()
        } catch {
            print("【CourseColorService】色の保存に失敗: \(error.localizedDescription)")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
    }

    /// 授業の色を取得する（スレッドセーフ）
    func getCourseColor(jugyoCd: String) -> Int? {
        var colorIndex: Int?
        
        // ModelContext はメインスレッドで作成されたため、メインスレッドで同期的に実行
        if Thread.isMainThread {
            colorIndex = fetchColorFromContext(jugyoCd: jugyoCd)
        } else {
            DispatchQueue.main.sync {
                colorIndex = self.fetchColorFromContext(jugyoCd: jugyoCd)
            }
        }
        
        return colorIndex
    }
    
    /// ModelContext から色を取得（内部メソッド）
    private func fetchColorFromContext(jugyoCd: String) -> Int? {
        guard let context = modelContext else { return nil }

        do {
            let searchCd = jugyoCd
            let descriptor = FetchDescriptor<CourseColorRecord>(
                predicate: #Predicate { $0.jugyoCd == searchCd }
            )
            return try context.fetch(descriptor).first?.colorIndex
        } catch {
            print("【CourseColorService】色の取得に失敗: \(error.localizedDescription)")
            return nil
        }
    }

    /// 全ての授業色をクリアする
    func clearAllCourseColors() {
        guard let context = modelContext else { return }

        do {
            try context.delete(model: CourseColorRecord.self)
            try context.save()
        } catch {
            print("【CourseColorService】色のクリアに失敗: \(error.localizedDescription)")
        }
    }
}
