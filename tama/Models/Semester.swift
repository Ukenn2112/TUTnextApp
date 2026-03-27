import Foundation

/// 学期情報を表すモデル
struct Semester {
    let year: Int
    let termNo: Int
    let termName: String

    /// 短縮年度表示（例: "26"）
    var shortYearString: String {
        String(year % 100)
    }

    /// 完全な学期名表示（例: "2026年度春学期"）
    var fullDisplayName: String {
        "\(year)年度\(termName)"
    }

    /// 現在の学期（UserDefaultsから読み込み、なければフォールバック値）
    static var current: Semester {
        let year = UserDefaults.standard.integer(forKey: "semester_year")
        let termNo = UserDefaults.standard.integer(forKey: "semester_termNo")
        let termName = UserDefaults.standard.string(forKey: "semester_termName")
        if year > 0, termNo > 0, let termName = termName, !termName.isEmpty {
            return Semester(year: year, termNo: termNo, termName: termName)
        }
        return Semester(year: 2_026, termNo: 1, termName: "春学期")
    }
}
