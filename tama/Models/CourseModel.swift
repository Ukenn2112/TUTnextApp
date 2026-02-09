import SwiftUI

/// 授業科目を表すモデル
struct CourseModel: Identifiable, Equatable, Codable {

    // MARK: - プロパティ

    var id = UUID()
    let name: String
    let room: String
    let teacher: String
    let startTime: String
    let endTime: String
    var colorIndex: Int = 1

    /// 曜日（1=月, 2=火, 3=水, 4=木, 5=金, 6=土, 7=日）
    let weekday: Int?

    /// 時限（1〜7限）
    let period: Int?

    /// 授業コード（色の保存用）
    let jugyoCd: String?

    /// 学年
    let academicYear: Int?

    /// 開講年度
    let courseYear: Int?

    /// 学期（1=前期, 2=後期）
    let courseTerm: Int?

    /// 授業区分
    let jugyoKbn: String?

    /// 未読掲示数
    let keijiMidokCnt: Int?

    // MARK: - 計算プロパティ

    /// 曜日を日本語表記で取得
    var weekdayString: String {
        guard let weekday, weekday >= 1, weekday <= 7 else { return "" }
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

    /// 時限と時間の表示用文字列
    var periodInfo: String {
        if let period {
            return String(format: NSLocalizedString("%@曜日 %d限", comment: ""), weekdayString, period)
        }
        return String(
            format: NSLocalizedString("%@ %@ - %@", comment: ""), weekdayString, startTime, endTime
        )
    }

    // MARK: - Equatable

    static func == (lhs: CourseModel, rhs: CourseModel) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - サンプルデータ

    static let sampleCourses: [String: [String: CourseModel]] = [
        "月": [
            "1": CourseModel(
                name: "キャリア・デザインII C", room: "101", teacher: "葛本 幸枝",
                startTime: "0900", endTime: "1030", colorIndex: 1,
                weekday: 1, period: 1, jugyoCd: "CD001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "2": CourseModel(
                name: "コンピュータ・サイエンス", room: "242", teacher: "中村 有一",
                startTime: "1040", endTime: "1210", colorIndex: 2,
                weekday: 1, period: 2, jugyoCd: "CS001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "中国ビジネスコミュニケーションII", room: "113", teacher: "田 園",
                startTime: "1440", endTime: "1610", colorIndex: 3,
                weekday: 1, period: 4, jugyoCd: "CB001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
        "火": [
            "1": CourseModel(
                name: "経営情報特講", room: "201", teacher: "青木 克彦",
                startTime: "0900", endTime: "1030", colorIndex: 4,
                weekday: 2, period: 1, jugyoCd: "KJ001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "2": CourseModel(
                name: "消費心理学", room: "211", teacher: "浜田 正幸",
                startTime: "1040", endTime: "1210", colorIndex: 5,
                weekday: 2, period: 2, jugyoCd: "SK001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "3": CourseModel(
                name: "データベースII(SQL)", room: "241", teacher: "齋藤 S.裕美",
                startTime: "1300", endTime: "1430", colorIndex: 6,
                weekday: 2, period: 3, jugyoCd: "DB001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "世界の宗教", room: "201", teacher: "高橋 恭寛",
                startTime: "1440", endTime: "1610", colorIndex: 7,
                weekday: 2, period: 4, jugyoCd: "SR001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "5": CourseModel(
                name: "マーケティング・心理実践II", room: "111", teacher: "菅沼 睦",
                startTime: "1620", endTime: "1750", colorIndex: 8,
                weekday: 2, period: 5, jugyoCd: "MP001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
        "水": [
            "3": CourseModel(
                name: "Webプログラミング入門", room: "201", teacher: "出原 至道",
                startTime: "1300", endTime: "1430", colorIndex: 9,
                weekday: 3, period: 3, jugyoCd: "WP001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "現代メディア論", room: "101", teacher: "中澤 弥",
                startTime: "1440", endTime: "1610", colorIndex: 10,
                weekday: 3, period: 4, jugyoCd: "GM001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
        "木": [
            "1": CourseModel(
                name: "経営科学", room: "212", teacher: "新西 誠人",
                startTime: "0900", endTime: "1030", colorIndex: 2,
                weekday: 4, period: 1, jugyoCd: "KK001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "2": CourseModel(
                name: "図化技術概論", room: "201", teacher: "出原 至道",
                startTime: "1040", endTime: "1210", colorIndex: 3,
                weekday: 4, period: 2, jugyoCd: "ZG001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "5": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫",
                startTime: "1620", endTime: "1750", colorIndex: 4,
                weekday: 4, period: 5, jugyoCd: "HZ001",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
        "金": [
            "3": CourseModel(
                name: "図化技概論", room: "201", teacher: "出原 至道",
                startTime: "1300", endTime: "1430", colorIndex: 5,
                weekday: 5, period: 3, jugyoCd: "ZG002",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
            "4": CourseModel(
                name: "ホームゼII", room: "113", teacher: "小林 英夫",
                startTime: "1440", endTime: "1610", colorIndex: 6,
                weekday: 5, period: 4, jugyoCd: "HZ002",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
        "土": [
            "6": CourseModel(
                name: "ホームゼミII", room: "113", teacher: "小林 英夫",
                startTime: "1800", endTime: "1930", colorIndex: 7,
                weekday: 6, period: 6, jugyoCd: "HZ003",
                academicYear: 2025, courseYear: 2025, courseTerm: 1,
                jugyoKbn: "A", keijiMidokCnt: 1
            ),
        ],
    ]
}
