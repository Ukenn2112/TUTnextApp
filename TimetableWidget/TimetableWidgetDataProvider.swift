import Foundation
import SwiftUI
import WidgetKit

// MARK: - モデル

struct CourseModel: Identifiable, Equatable, Codable {
    var id = UUID()
    let name: String
    let room: String
    let teacher: String
    let startTime: String
    let endTime: String
    var colorIndex: Int = 1
    let weekday: Int?
    let period: Int?
    let jugyoCd: String?
    let academicYear: Int?
    let courseYear: Int?
    let courseTerm: Int?
    let jugyoKbn: String?
    let keijiMidokCnt: Int?

    var weekdayString: String {
        guard let weekday = weekday, weekday >= 1, weekday <= 7 else { return "" }
        let weekdays = [
            NSLocalizedString("月", comment: ""),
            NSLocalizedString("火", comment: ""),
            NSLocalizedString("水", comment: ""),
            NSLocalizedString("木", comment: ""),
            NSLocalizedString("金", comment: ""),
            NSLocalizedString("土", comment: ""),
            NSLocalizedString("日", comment: ""),
        ]
        return weekdays[weekday - 1]
    }

    var periodInfo: String {
        if let period = period {
            return String(format: NSLocalizedString("%@曜日 %d限", comment: ""), weekdayString, period)
        }
        return String(
            format: NSLocalizedString("%@ %@ - %@", comment: ""), weekdayString, startTime, endTime)
    }

    static func == (lhs: CourseModel, rhs: CourseModel) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: サンプルデータ

    static let sampleCourses: [String: [String: CourseModel]] = [
        "月": [
            "1": CourseModel(
                name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝", startTime: "0900",
                endTime: "1030", colorIndex: 1, weekday: 1, period: 1, jugyoCd: "CD001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一", startTime: "1040",
                endTime: "1210", colorIndex: 2, weekday: 1, period: 2, jugyoCd: "CS001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "中国ビジネスコミュニケーションII", room: "113", teacher: "田 園", startTime: "1440",
                endTime: "1610", colorIndex: 3, weekday: 1, period: 4, jugyoCd: "CB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "火": [
            "1": CourseModel(
                name: "経営情報特講", room: "201", teacher: "青木 克彦", startTime: "0900",
                endTime: "1030", colorIndex: 4, weekday: 2, period: 1, jugyoCd: "KJ001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "消費心理学", room: "211", teacher: "浜田 正幸", startTime: "1040",
                endTime: "1210", colorIndex: 5, weekday: 2, period: 2, jugyoCd: "SK001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "3": CourseModel(
                name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美", startTime: "1300",
                endTime: "1430", colorIndex: 6, weekday: 2, period: 3, jugyoCd: "DB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "世界の宗教", room: "201", teacher: "高橋 恭寛", startTime: "1440",
                endTime: "1610", colorIndex: 7, weekday: 2, period: 4, jugyoCd: "SR001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "マーケティング・心理実践II", room: "111", teacher: "菅沼 睦", startTime: "1620",
                endTime: "1750", colorIndex: 8, weekday: 2, period: 5, jugyoCd: "MP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "水": [
            "3": CourseModel(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道", startTime: "1300",
                endTime: "1430", colorIndex: 9, weekday: 3, period: 3, jugyoCd: "WP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "現代メディア論", room: "101", teacher: "中澤 弥", startTime: "1440",
                endTime: "1610", colorIndex: 10, weekday: 3, period: 4, jugyoCd: "GM001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "木": [
            "1": CourseModel(
                name: "経営科学", room: "212", teacher: "新西 誠人", startTime: "0900",
                endTime: "1030", colorIndex: 2, weekday: 4, period: 1, jugyoCd: "KK001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "2": CourseModel(
                name: "図化技術概論", room: "201", teacher: "出原 至道", startTime: "1040",
                endTime: "1210", colorIndex: 3, weekday: 4, period: 2, jugyoCd: "ZG001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "5": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫", startTime: "1620",
                endTime: "1750", colorIndex: 4, weekday: 4, period: 5, jugyoCd: "HZ001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "金": [
            "3": CourseModel(
                name: "図化技概論", room: "201", teacher: "出原 至道", startTime: "1300",
                endTime: "1430", colorIndex: 5, weekday: 5, period: 3, jugyoCd: "ZG002",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
            "4": CourseModel(
                name: "ホームゼII", room: "113", teacher: "小林 英夫", startTime: "1440",
                endTime: "1610", colorIndex: 6, weekday: 5, period: 4, jugyoCd: "HZ002",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
        "土": [
            "7": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫", startTime: "1940",
                endTime: "2110", colorIndex: 7, weekday: 6, period: 6, jugyoCd: "HZ003",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A",
                keijiMidokCnt: 1),
        ],
    ]
}

// MARK: - 定数

let APP_GROUP_ID = "group.com.meikenn.tama"

private struct TimetableWidgetKeys {
    static let cachedTimetableData = "cachedTimetableData"
    static let lastUpdateTime = "lastTimetableFetchTime"
}

// MARK: - データプロバイダー

class TimetableWidgetDataProvider {
    static let shared = TimetableWidgetDataProvider()

    private let sharedDefaults = UserDefaults(suiteName: APP_GROUP_ID)
    private var cachedData: [String: [String: CourseModel]]?
    private var lastCacheTime: Date?
    private let cacheValidity: TimeInterval = 60

    private init() {}

    // MARK: データ取得

    func getTimetableData() -> [String: [String: CourseModel]]? {
        if let cached = cachedData,
            let cacheTime = lastCacheTime,
            Date().timeIntervalSince(cacheTime) < cacheValidity
        {
            return cached
        }

        do {
            guard let userDefaults = sharedDefaults else {
                #if DEBUG
                    print("TimetableWidgetDataProvider: App Groupsにアクセスできません")
                #endif
                return CourseModel.sampleCourses
            }

            guard
                let timetableData = userDefaults.data(
                    forKey: TimetableWidgetKeys.cachedTimetableData)
            else {
                #if DEBUG
                    print("TimetableWidgetDataProvider: App Groupsからデータが見つかりませんでした")
                #endif
                return CourseModel.sampleCourses
            }

            let decoded = try JSONDecoder().decode(
                [String: [String: CourseModel]].self, from: timetableData)
            cachedData = decoded
            lastCacheTime = Date()
            return decoded
        } catch {
            #if DEBUG
                print(
                    "TimetableWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)"
                )
            #endif
            return CourseModel.sampleCourses
        }
    }

    func getLastFetchTime() -> Date? {
        sharedDefaults?.object(forKey: TimetableWidgetKeys.lastUpdateTime) as? Date
    }

    // MARK: 時間情報

    func getCurrentWeekday() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let japaneseWeekday = weekday == 1 ? 7 : weekday - 1
        return String(japaneseWeekday)
    }

    func getCurrentPeriod() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let currentTime = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)

        let periods: [(String, Int, Int)] = [
            ("1", 540, 630),
            ("2", 640, 730),
            ("3", 780, 870),
            ("4", 880, 970),
            ("5", 980, 1070),
            ("6", 1080, 1170),
            ("7", 1180, 1270),
        ]

        for (periodNumber, startMinutes, endMinutes) in periods
        where currentTime >= startMinutes && currentTime <= endMinutes {
            return periodNumber
        }

        return nil
    }

    // MARK: 表示用データ

    func getWeekdays() -> [String] {
        let baseWeekdays = ["1", "2", "3", "4", "5"]

        if let saturdayCourses = getTimetableData()?["6"], !saturdayCourses.isEmpty {
            return baseWeekdays + ["6"]
        }

        return baseWeekdays
    }

    func getWeekdayDisplayString(from index: String) -> String {
        guard let idx = Int(index), idx >= 1, idx <= 7 else { return "" }
        let weekdays = [
            NSLocalizedString("月", comment: ""),
            NSLocalizedString("火", comment: ""),
            NSLocalizedString("水", comment: ""),
            NSLocalizedString("木", comment: ""),
            NSLocalizedString("金", comment: ""),
            NSLocalizedString("土", comment: ""),
            NSLocalizedString("日", comment: ""),
        ]
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
        return timetableData.values.contains { $0.keys.contains(period) }
    }
}

// MARK: - カラーパレット

struct WidgetColorPalette {
    private static let colors: [Color] = [
        .white,
        Color(red: 0.98, green: 0.86, blue: 0.86),  // ピンク
        Color(red: 0.98, green: 0.92, blue: 0.86),  // オレンジ
        Color(red: 0.98, green: 0.98, blue: 0.86),  // イエロー
        Color(red: 0.92, green: 0.98, blue: 0.86),  // ライトグリーン
        Color(red: 0.86, green: 0.98, blue: 0.86),  // グリーン
        Color(red: 0.86, green: 0.98, blue: 0.98),  // シアン
        Color(red: 0.98, green: 0.86, blue: 0.92),  // ピンクパープル
        Color(red: 0.92, green: 0.86, blue: 0.98),  // パープル
        Color(red: 0.86, green: 0.92, blue: 0.98),  // ブルー
        Color(red: 0.98, green: 0.86, blue: 0.98)   // マゼンタ
    ]

    static func getColor(for index: Int) -> Color {
        guard index >= 0, index < colors.count else { return colors[0] }
        return colors[index]
    }
}
