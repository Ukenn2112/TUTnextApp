import Foundation

// MARK: - 課題モデル

/// 課題を表すモデル
struct Assignment: Identifiable, Codable {
    var id: String
    var title: String
    var courseId: String
    var courseName: String
    var dueDate: Date
    var description: String
    var status: AssignmentStatus
    var url: String

    /// 残り時間のテキスト表示
    var remainingTimeText: String {
        let now = Date()
        guard now <= dueDate else {
            return NSLocalizedString("期限切れ", comment: "")
        }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: dueDate)

        if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("%d日", comment: ""), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("%d時間", comment: ""), hours)
        } else if let minutes = components.minute {
            return String(format: NSLocalizedString("%d分", comment: ""), minutes)
        }

        return NSLocalizedString("まもなく期限", comment: "")
    }

    /// 期限切れかどうか
    var isOverdue: Bool {
        Date() > dueDate
    }

    /// 未完了かどうか
    var isPending: Bool {
        status == .pending
    }

    /// 緊急かどうか（残り2時間未満）
    var isUrgent: Bool {
        guard !isOverdue else { return false }
        let components = Calendar.current.dateComponents([.hour], from: Date(), to: dueDate)
        return (components.hour ?? 0) < 2
    }
}

// MARK: - 課題ステータス

/// 課題の状態
enum AssignmentStatus: String, Codable {
    case pending
    case completed
}

// MARK: - APIレスポンス

/// 課題APIのレスポンス
struct AssignmentResponse: Codable {
    var status: Bool
    var data: [APIAssignment]?
}

/// APIから返される課題データ
struct APIAssignment: Codable {
    var title: String
    var courseId: String
    var courseName: String
    var dueDate: String
    var dueTime: String
    var description: String
    var url: String

    /// Assignmentモデルに変換する
    func toAssignment() -> Assignment {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateTimeString = "\(dueDate) \(dueTime)"
        let date = dateFormatter.date(from: dateTimeString) ?? Date()

        return Assignment(
            id: UUID().uuidString,
            title: title,
            courseId: courseId,
            courseName: courseName,
            dueDate: date,
            description: description,
            status: .pending,
            url: url
        )
    }
}
