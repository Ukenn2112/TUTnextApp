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

// MARK: - プレビュー用モックデータ

extension Assignment {
    /// プレビュー/スクリーンショット用の課題一覧（現在時刻を基準に相対的に生成）
    static var previewAssignments: [Assignment] {
        let now = Date()
        let calendar = Calendar.current

        func date(daysFromNow days: Int, hour: Int = 23, minute: Int = 59) -> Date {
            let base = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: base
            ) ?? base
        }

        return [
            // 期限切れ
            Assignment(
                id: "preview-overdue-1",
                title: "第4回 SQL 演習レポート",
                courseId: "DB001",
                courseName: "データベースII(SQL)",
                dueDate: date(daysFromNow: -2, hour: 23),
                description: "正規化に関する演習問題を解いて提出してください。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            // 今日締切
            Assignment(
                id: "preview-today-1",
                title: "Web プログラミング基礎課題",
                courseId: "WP001",
                courseName: "Webプログラミング入門",
                dueDate: date(daysFromNow: 0, hour: 23, minute: 59),
                description: "HTML/CSS で自己紹介ページを作成。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            // 今週締切
            Assignment(
                id: "preview-week-1",
                title: "消費心理学 レポート",
                courseId: "SK001",
                courseName: "消費心理学",
                dueDate: date(daysFromNow: 3, hour: 17),
                description: "配布資料 P.45〜60 を踏まえて考察を 800 字でまとめる。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            Assignment(
                id: "preview-week-2",
                title: "キャリア・デザイン 自己分析ワーク",
                courseId: "CD001",
                courseName: "キャリア・デザインII C",
                dueDate: date(daysFromNow: 5, hour: 12),
                description: "ワークシートを記入し PDF で提出。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            // 今月締切
            Assignment(
                id: "preview-month-1",
                title: "現代メディア論 中間レポート",
                courseId: "GM001",
                courseName: "現代メディア論",
                dueDate: date(daysFromNow: 14, hour: 23, minute: 59),
                description: "任意のメディアを取り上げて 2,000 字で分析。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            Assignment(
                id: "preview-month-2",
                title: "iOS アプリ企画書",
                courseId: "IA001",
                courseName: "iOSアプリ開発演習",
                dueDate: date(daysFromNow: 21, hour: 18),
                description: "チームで企画したアプリの概要をまとめて提出。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            )
        ]
    }
}

// MARK: - スケルトン用の仮データ

extension Assignment {
    /// 初回の読み込み中にスケルトン（塗りつぶしの形）として並べる仮の課題。
    ///
    /// `.redacted(reason: .placeholder)` で塗りつぶして形だけを見せるので、文字は画面に出ない。
    /// 文字数だけ実際の課題に近づけ、カードの高さがばらけて見えるようにしている。
    /// id は固定（`ForEach` の同一性を保つため）
    static var placeholderAssignments: [Assignment] {
        let now = Date()
        let calendar = Calendar.current

        // 期限は数日先にして、残り時間の帯を急ぎ・期限切れの色にしない
        func placeholder(_ index: Int, title: String, courseName: String, description: String) -> Assignment {
            Assignment(
                id: "placeholder-\(index)",
                title: title,
                courseId: "",
                courseName: courseName,
                dueDate: calendar.date(byAdding: .day, value: 3 + index, to: now) ?? now,
                description: description,
                status: .pending,
                url: ""
            )
        }

        return [
            placeholder(0, title: "第4回 演習レポート", courseName: "データベースII",
                        description: "演習問題を解いて提出してください。"),
            placeholder(1, title: "基礎課題の提出", courseName: "Webプログラミング入門",
                        description: "指示に従って作成し、ファイルを提出。"),
            placeholder(2, title: "レポート課題", courseName: "消費心理学",
                        description: "配布資料を踏まえて考察をまとめる。"),
            placeholder(3, title: "中間レポート", courseName: "現代メディア論",
                        description: "任意のテーマを取り上げて分析。")
        ]
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
