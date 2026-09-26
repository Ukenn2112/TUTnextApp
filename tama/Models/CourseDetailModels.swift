import Foundation

// MARK: - 授業詳細レスポンス

/// 授業詳細情報のレスポンスモデル
struct CourseDetailResponse {
    let announcements: [AnnouncementModel]
    let attendance: AttendanceModel
    let memo: String
    let syllabusPubFlg: Bool
    let syuKetuKanriFlg: Bool

    /// プレビュー/スクリーンショット用のモックデータを生成する
    static func previewMock(for course: CourseModel) -> CourseDetailResponse {
        // データベースII(SQL) 用の詳細モック（メイン動線のスクリーンショット用）
        if course.jugyoCd == "DB001" {
            return CourseDetailResponse(
                announcements: [
                    AnnouncementModel(
                        id: 101,
                        title: "第5回レポート『正規化』提出について",
                        date: 1_745_020_800_000,
                        torkDate: nil
                    ),
                    AnnouncementModel(
                        id: 102,
                        title: "中間試験範囲のお知らせ（JOIN/GROUP BY まで）",
                        date: 1_744_416_000_000,
                        torkDate: nil
                    ),
                    AnnouncementModel(
                        id: 103,
                        title: "演習用サンプルDBを配布しました",
                        date: 1_743_811_200_000,
                        torkDate: nil
                    )
                ],
                attendance: AttendanceModel(
                    present: 11, absent: 1, late: 1, early: 0, sick: 0, unregistered: 0
                ),
                memo: "第6回までの SQL 演習問題を復習する。\n- サブクエリ\n- 外部結合",
                syllabusPubFlg: true,
                syuKetuKanriFlg: true
            )
        }
        // その他の授業用の汎用モック
        return CourseDetailResponse(
            announcements: [
                AnnouncementModel(
                    id: 1,
                    title: NSLocalizedString("お知らせはまだありません", comment: ""),
                    date: Int(Date().timeIntervalSince1970 * 1_000),
                    torkDate: nil
                )
            ],
            attendance: AttendanceModel(
                present: 8, absent: 0, late: 0, early: 0, sick: 0, unregistered: 0
            ),
            memo: "",
            syllabusPubFlg: true,
            syuKetuKanriFlg: true
        )
    }
}

// MARK: - 読み込み中の仮のデータ

extension CourseDetailResponse {

    /// 科目詳細の読み込み中に、スケルトンの下へ敷く仮のデータ。
    ///
    /// 文字は `.redacted` で塗りの形に置き換わるので利用者には読まれない（ローカライズもしない）。
    /// 掲示・出欠のカードが読み込み後とおおよそ同じ高さになるよう、件数だけ本物らしくしてある
    static let placeholder = CourseDetailResponse(
        announcements: (1...3).map { index in
            AnnouncementModel(
                id: -index,
                title: "掲示のタイトルを読み込んでいます",
                date: 0,
                torkDate: nil
            )
        },
        attendance: AttendanceModel(
            present: 10, absent: 1, late: 1, early: 0, sick: 0, unregistered: 0
        ),
        memo: "",
        syllabusPubFlg: false,
        syuKetuKanriFlg: false
    )
}

// MARK: - 掲示情報モデル

/// 掲示情報を表すモデル
struct AnnouncementModel: Identifiable {
    let id: Int
    let title: String
    let date: Int
    let torkDate: String?

    /// フォーマットされた日付文字列
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "ja_JP")
        let date = Date(timeIntervalSince1970: TimeInterval(self.date / 1_000))
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
    let unregistered: Int

    /// 合計回数
    var total: Int {
        present + absent + late + early + sick + unregistered
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
