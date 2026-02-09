import Foundation

// MARK: - 授業詳細レスポンス

/// 授業詳細情報のレスポンスモデル
struct CourseDetailResponse {
    let announcements: [AnnouncementModel]
    let attendance: AttendanceModel
    let memo: String
    let syllabusPubFlg: Bool
    let syuKetuKanriFlg: Bool
}

// MARK: - 掲示情報モデル

/// 掲示情報を表すモデル
struct AnnouncementModel: Identifiable {
    let id: Int
    let title: String
    let date: Int

    /// フォーマットされた日付文字列
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "ja_JP")
        let date = Date(timeIntervalSince1970: TimeInterval(self.date / 1000))
        return dateFormatter.string(from: date)
    }
}

// MARK: - 出欠情報モデル

/// 出欠記録を表すモデル
struct AttendanceModel {
    let present: Int
    let absent: Int
    let late: Int
    let early: Int
    let sick: Int

    /// 合計回数
    var total: Int {
        present + absent + late + early + sick
    }

    /// 指定項目の割合を計算する
    private func rate(for count: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    /// 出席率（パーセント）
    var presentRate: Double { rate(for: present) }

    /// 欠席率（パーセント）
    var absentRate: Double { rate(for: absent) }

    /// 遅刻率（パーセント）
    var lateRate: Double { rate(for: late) }

    /// 早退率（パーセント）
    var earlyRate: Double { rate(for: early) }

    /// 公欠率（パーセント）
    var sickRate: Double { rate(for: sick) }
}
