import Foundation
import SwiftUI
import WidgetKit

// CourseModelの定義
struct CourseModel: Identifiable, Equatable, Codable {
    var id = UUID()
    let name: String
    let room: String
    let teacher: String
    let startTime: String
    let endTime: String
    var colorIndex: Int = 1

    // 曜日と時限を追加
    let weekday: Int?  // 1=月, 2=火, 3=水, 4=木, 5=金, 6=土, 7=日
    let period: Int?  // 1〜7限

    // 授業コード（色の保存用）
    let jugyoCd: String?

    // 学年
    let academicYear: Int?

    // コース年
    let courseYear: Int?

    // コース期間
    let courseTerm: Int?

    // 授業区分
    let jugyoKbn: String?

    // 未読掲示数
    let keijiMidokCnt: Int?

    // 曜日を日本語表記で取得
    var weekdayString: String {
        guard let weekday = weekday else { return "" }
        let weekdays = [
            NSLocalizedString("月", comment: ""),
            NSLocalizedString("火", comment: ""),
            NSLocalizedString("水", comment: ""),
            NSLocalizedString("木", comment: ""),
            NSLocalizedString("金", comment: ""),
            NSLocalizedString("土", comment: ""),
            NSLocalizedString("日", comment: "")
        ]
        if weekday >= 1 && weekday <= 7 {
            return weekdays[weekday - 1]
        }
        return ""
    }

    // 時限と時間の表示用文字列
    var periodInfo: String {
        if let period = period {
            return String(format: NSLocalizedString("%@曜日 %d限", comment: ""), weekdayString, period)
        }
        return String(
            format: NSLocalizedString("%@ %@ - %@", comment: ""), weekdayString, startTime, endTime)
    }

    // サンプルデータ
    static let sampleCourses: [String: [String: CourseModel]] = [
        "月": [
            "1": CourseModel(
                name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝", startTime: "0900",
                endTime: "1030", colorIndex: 1, weekday: 1, period: 1, jugyoCd: "CD001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "2": CourseModel(
                name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一", startTime: "1040",
                endTime: "1210", colorIndex: 2, weekday: 1, period: 2, jugyoCd: "CS001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "中国ビジネスコミュニケーションII", room: "113", teacher: "田 園", startTime: "1440",
                endTime: "1610", colorIndex: 3, weekday: 1, period: 4, jugyoCd: "CB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            )
        ],
        "火": [
            "1": CourseModel(
                name: "経営情報特講", room: "201", teacher: "青木 克彦", startTime: "0900", endTime: "1030",
                colorIndex: 4, weekday: 2, period: 1, jugyoCd: "KJ001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "2": CourseModel(
                name: "消費心理学", room: "211", teacher: "浜田 正幸", startTime: "1040", endTime: "1210",
                colorIndex: 5, weekday: 2, period: 2, jugyoCd: "SK001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "3": CourseModel(
                name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美", startTime: "1300",
                endTime: "1430", colorIndex: 6, weekday: 2, period: 3, jugyoCd: "DB001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "世界の宗教", room: "201", teacher: "高橋 恭寛", startTime: "1440", endTime: "1610",
                colorIndex: 7, weekday: 2, period: 4, jugyoCd: "SR001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "5": CourseModel(
                name: "マーケティング・心理実践II", room: "111", teacher: "菅沼 睦", startTime: "1620",
                endTime: "1750", colorIndex: 8, weekday: 2, period: 5, jugyoCd: "MP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            )
        ],
        "水": [
            "3": CourseModel(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道", startTime: "1300",
                endTime: "1430", colorIndex: 9, weekday: 3, period: 3, jugyoCd: "WP001",
                academicYear: 2_025, courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "現代メディア論", room: "101", teacher: "中澤 弥", startTime: "1440", endTime: "1610",
                colorIndex: 10, weekday: 3, period: 4, jugyoCd: "GM001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1)
        ],
        "木": [
            "1": CourseModel(
                name: "経営科学", room: "212", teacher: "新西 誠人", startTime: "0900", endTime: "1030",
                colorIndex: 2, weekday: 4, period: 1, jugyoCd: "KK001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "2": CourseModel(
                name: "図化技術概論", room: "201", teacher: "出原 至道", startTime: "1040", endTime: "1210",
                colorIndex: 3, weekday: 4, period: 2, jugyoCd: "ZG001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "5": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫", startTime: "1620", endTime: "1750",
                colorIndex: 4, weekday: 4, period: 5, jugyoCd: "HZ001", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1)
        ],
        "金": [
            "3": CourseModel(
                name: "図化技概論", room: "201", teacher: "出原 至道", startTime: "1300", endTime: "1430",
                colorIndex: 5, weekday: 5, period: 3, jugyoCd: "ZG002", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1),
            "4": CourseModel(
                name: "ホームゼII", room: "113", teacher: "小林 英夫", startTime: "1440", endTime: "1610",
                colorIndex: 6, weekday: 5, period: 4, jugyoCd: "HZ002", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1)
        ],
        "土": [
            "7": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫", startTime: "1940", endTime: "2110",
                colorIndex: 7, weekday: 6, period: 6, jugyoCd: "HZ003", academicYear: 2_025,
                courseYear: 2_025, courseTerm: 1, jugyoKbn: "A", keijiMidokCnt: 1)
        ]
    ]

    // Equatable プロトコルの実装
    static func == (lhs: CourseModel, rhs: CourseModel) -> Bool {
        return lhs.id == rhs.id
    }
}

// アプリグループのID（TimetableServiceと同じ値を使用）
let APP_GROUP_ID = "group.com.meikenn.tama"

// キー定数（TimetableServiceと同じ値を使用）
private struct TimetableWidgetKeys {
    static let cachedTimetableData = "cachedTimetableData"
    static let lastUpdateTime = "lastTimetableFetchTime"
}

// ウィジェット用の時間割データプロバイダー
class TimetableWidgetDataProvider {
    // シングルトンインスタンス
    static let shared = TimetableWidgetDataProvider()

    // 共有UserDefaultsアクセス
    private let sharedDefaults = UserDefaults(suiteName: APP_GROUP_ID)

    // 初期化
    private init() {}

    // App Groupsから時間割データを取得（公開メソッド）
    func getTimetableData() -> [String: [String: CourseModel]]? {
        do {
            // UserDefaultsへのアクセスチェック
            guard let userDefaults = sharedDefaults else {
                #if DEBUG
                print("TimetableWidgetDataProvider: App Groupsにアクセスできません")
                #endif
                return CourseModel.sampleCourses
            }

            // データの存在チェック
            guard
                let timetableData = userDefaults.data(
                    forKey: TimetableWidgetKeys.cachedTimetableData)
            else {
                #if DEBUG
                print("TimetableWidgetDataProvider: App Groupsからデータが見つかりませんでした")
                #endif
                // データがなければサンプルデータでフォールバック
                return CourseModel.sampleCourses
            }

            // JSONデータをデコード
            let decoder = JSONDecoder()
            let timetableDataDecoded = try decoder.decode(
                [String: [String: CourseModel]].self, from: timetableData)

            return timetableDataDecoded
        } catch {
            #if DEBUG
            print("TimetableWidgetDataProvider: データのデコードに失敗しました - \(error.localizedDescription)")
            #endif
            return CourseModel.sampleCourses
        }
    }

    // 最終更新時刻を取得
    func getLastFetchTime() -> Date? {
        guard let userDefaults = sharedDefaults else {
            return nil
        }

        if let fetchTime = userDefaults.object(forKey: TimetableWidgetKeys.lastUpdateTime) as? Date {
            return fetchTime
        }

        return nil
    }

    // 現在の曜日を取得
    func getCurrentWeekday() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())

        // 日本の曜日を整数値の文字列に変換 (1-7)
        let japaneseWeekday = weekday == 1 ? 7 : weekday - 1
        return String(japaneseWeekday)
    }

    // 現在の時限を取得
    func getCurrentPeriod() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute  // 現在時刻を分に変換

        // 時限の時間範囲（分で表現）
        // 時限：開始時間-終了時間
        let periods: [(String, Int, Int)] = [
            ("1", 9 * 60, 10 * 60 + 30),  // 1限：9:00-10:30
            ("2", 10 * 60 + 40, 12 * 60 + 10),  // 2限：10:40-12:10
            ("3", 13 * 60, 14 * 60 + 30),  // 3限：13:00-14:30
            ("4", 14 * 60 + 40, 16 * 60 + 10),  // 4限：14:40-16:10
            ("5", 16 * 60 + 20, 17 * 60 + 50),  // 5限：16:20-17:50
            ("6", 18 * 60, 19 * 60 + 30),  // 6限：18:00-19:30
            ("7", 19 * 60 + 40, 21 * 60 + 10)  // 7限：19:40-21:10
        ]

        for (periodNumber, startMinutes, endMinutes) in periods where currentTime >= startMinutes && currentTime <= endMinutes {
            return periodNumber
        }

        return nil
    }

    // 曜日リストを取得
    func getWeekdays() -> [String] {
        // 基本の曜日配列（月～金）
        let baseWeekdays = ["1", "2", "3", "4", "5"]

        // 土曜日の授業があるかチェック
        if let saturdayCourses = getTimetableData()?["6"], !saturdayCourses.isEmpty {
            return baseWeekdays + ["6"]
        }

        return baseWeekdays
    }

    // 曜日インデックスを表示用文字列に変換
    func getWeekdayDisplayString(from index: String) -> String {
        guard let idx = Int(index), idx >= 1 && idx <= 7 else { return "" }
        let weekdays = [
            NSLocalizedString("月", comment: ""),
            NSLocalizedString("火", comment: ""),
            NSLocalizedString("水", comment: ""),
            NSLocalizedString("木", comment: ""),
            NSLocalizedString("金", comment: ""),
            NSLocalizedString("土", comment: ""),
            NSLocalizedString("日", comment: "")
        ]
        return weekdays[idx - 1]
    }

    // 時限情報を取得
    func getPeriods() -> [(String, String, String)] {
        let basePeriods = [
            ("1", "9:00", "10:30"),
            ("2", "10:40", "12:10"),
            ("3", "13:00", "14:30"),
            ("4", "14:40", "16:10"),
            ("5", "16:20", "17:50"),
            ("6", "18:00", "19:30"),
            ("7", "19:40", "21:10")
        ]

        // 時限の存在チェック
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

    // 特定の時限が存在するかチェック
    private func hasSpecificPeriod(_ period: String) -> Bool {
        guard let timetableData = getTimetableData() else { return false }

        for (_, coursesForDay) in timetableData where coursesForDay.keys.contains(period) {
            return true
        }

        return false
    }

    // 特定の曜日・時限の授業を取得
    func getCourse(day: String, period: String) -> CourseModel? {
        return getTimetableData()?[day]?[period]
    }

    // 指定した曜日の全授業を取得
    func getCoursesForDay(day: String) -> [String: CourseModel]? {
        return getTimetableData()?[day]
    }

    // 全授業データを取得
    func getAllCourses() -> [CourseModel] {
        guard let timetableData = getTimetableData() else { return [] }

        var allCourses: [CourseModel] = []
        for (_, coursesForDay) in timetableData {
            allCourses.append(contentsOf: coursesForDay.values)
        }

        return allCourses
    }
}

// ウィジェット用の色パレット
struct WidgetColorPalette {
    // 色パレット（CourseColorServiceのカラーパレットと同じもの）
    private static let colors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),  // ライトピンク
        Color(red: 1.0, green: 0.9, blue: 0.8),  // ライトオレンジ
        Color(red: 1.0, green: 1.0, blue: 0.8),  // ライトイエロー
        Color(red: 0.9, green: 1.0, blue: 0.8),  // ライトグリーン
        Color(red: 0.8, green: 1.0, blue: 0.8),  // グリーン
        Color(red: 0.8, green: 1.0, blue: 1.0),  // シアン
        Color(red: 1.0, green: 0.8, blue: 0.9),  // ピンクパープル
        Color(red: 0.9, green: 0.8, blue: 1.0),  // ライトパープル
        Color(red: 0.8, green: 0.9, blue: 1.0),  // ライトブルー
        Color(red: 1.0, green: 0.9, blue: 1.0)  // ライトパープル
    ]

    // 色インデックスに対応する色を取得
    static func getColor(for index: Int) -> Color {
        guard index >= 0 && index < colors.count else {
            return colors[0]  // インデックスが範囲外の場合はデフォルト色
        }
        return colors[index]
    }
}
