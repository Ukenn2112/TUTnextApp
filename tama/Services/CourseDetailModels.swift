import Foundation

// 課程詳細レスポンス
struct CourseDetailResponse {
    let announcements: [AnnouncementModel]
    let attendance: AttendanceModel
    let memo: String
    let syllabusPubFlg: Bool
    let syuKetuKanriFlg: Bool
}

// 掲示情報モデル
struct AnnouncementModel: Identifiable {
    let id: Int
    let title: String
    let date: Int

    // 日付をフォーマットして表示
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "ja_JP")

        let date = Date(timeIntervalSince1970: TimeInterval(self.date / 1000))
        return dateFormatter.string(from: date)
    }
}

// 出欠情報モデル
struct AttendanceModel {
    let present: Int  // 出席
    let absent: Int  // 欠席
    let late: Int  // 遅刻
    let early: Int  // 早退
    let sick: Int  // 公欠

    // 合計回数
    var total: Int {
        return present + absent + late + early + sick
    }

    // 出席率（パーセント）
    var presentRate: Double {
        guard total > 0 else { return 0 }
        return Double(present) / Double(total) * 100
    }

    // 欠席率（パーセント）
    var absentRate: Double {
        guard total > 0 else { return 0 }
        return Double(absent) / Double(total) * 100
    }

    // 遅刻率（パーセント）
    var lateRate: Double {
        guard total > 0 else { return 0 }
        return Double(late) / Double(total) * 100
    }

    // 早退率（パーセント）
    var earlyRate: Double {
        guard total > 0 else { return 0 }
        return Double(early) / Double(total) * 100
    }

    // 公欠率（パーセント）
    var sickRate: Double {
        guard total > 0 else { return 0 }
        return Double(sick) / Double(total) * 100
    }
}
