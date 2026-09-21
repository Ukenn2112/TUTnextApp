#if DEBUG
import Foundation

// MARK: - 課題タブのDuo検証用の起動引数

/// 課題タブのDuo検証用の起動引数（DEBUGビルドのみ、`UserDefaults` の同名キーでも可）。
///
/// 検証用のアカウントには課題が1件も入っておらず、2列のグリッドが空のままになってしまうため、
/// プレビュー用のモックデータ（`Assignment.previewAssignments`）をそのまま画面に流し込む:
///
/// - `-DuoAssignmentsMock YES` … 課題一覧をモックデータに差し替える
enum DuoDebugAssignments {

    /// 課題一覧をモックデータに差し替えるかどうか
    static var usesMock: Bool {
        UserDefaults.standard.bool(forKey: "DuoAssignmentsMock")
    }

    /// グリッド確認用の課題一覧。
    ///
    /// プレビュー用の6件（期限切れ1件を含む）に、
    /// 「残り2時間未満の緊急」と「題名が長く2行になる」の2件を足して、
    /// 題名の長さ・締切の近さがばらついた8件にしてある
    static var mockAssignments: [Assignment] {
        let now = Date()
        let calendar = Calendar.current
        let urgent = calendar.date(byAdding: .minute, value: 70, to: now) ?? now
        let longTitled = calendar.date(byAdding: .day, value: 9, to: now) ?? now

        return Assignment.previewAssignments + [
            Assignment(
                id: "preview-urgent-1",
                title: "統計学基礎 小テスト",
                courseId: "TK001",
                courseName: "統計学基礎",
                dueDate: urgent,
                description: "第5回講義の範囲から出題。制限時間は20分です。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            ),
            Assignment(
                id: "preview-long-1",
                title: "ホームゼミII グループ研究 中間発表スライドと発表原稿の提出",
                courseId: "HZ001",
                courseName: "ホームゼミII",
                dueDate: longTitled,
                description: "スライド10枚程度と発表原稿をあわせてPDFで提出してください。",
                status: .pending,
                url: "https://next.tama.ac.jp/"
            )
        ]
    }
}
#endif
