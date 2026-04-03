import ActivityKit
import Foundation

// NOTE: This struct must remain structurally identical to the definition
// in TimetableWidget/ClassLiveActivityWidget.swift (widget extension target).

// MARK: - フェーズ定義（5つの排他的フェーズ）

enum ClassPhase: String, Codable, Hashable {
    /// 授業前（約5分以上前）
    case upcoming
    /// 直前（約5分以内）
    case imminent
    /// 授業中
    case inProgress
    /// 休み時間
    case breakTime
    /// 本日の授業終了
    case finished
}

// MARK: - Live Activity 属性

struct ClassLiveActivityAttributes: ActivityAttributes {
    public typealias ClassActivityState = ContentState

    // MARK: 動的コンテンツ（フェーズ変化で更新される）

    public struct ContentState: Codable, Hashable {
        /// 現在のフェーズ
        var phase: ClassPhase

        /// カウントダウン対象日時（フェーズ別 contract）
        /// - upcoming/imminent: 授業開始時刻
        /// - inProgress: 授業終了時刻
        /// - breakTime: 次の授業開始時刻
        /// - finished: タイマー非表示（最後の授業終了時刻）
        var countdownDate: Date

        // MARK: 現在の授業情報

        /// 授業名
        var courseName: String
        /// 教室
        var room: String
        /// 担当教員名
        var teacher: String
        /// 時限（1〜7）
        var period: Int
        /// 授業開始日時（ProgressView(timerInterval:) 用）
        var startDate: Date
        /// 授業終了日時
        var endDate: Date

        // MARK: 教室変更オーバーレイ（フェーズと独立、授業全体を通して保持）

        /// 教室変更があるか
        var hasRoomChange: Bool = false
        /// 変更後の教室（hasRoomChange == true の場合のみ）
        var newRoom: String?

        // MARK: 次の授業情報（breakTime のみ使用）

        /// 次の授業名
        var nextCourseName: String?
        /// 次の授業の教室
        var nextCourseRoom: String?
        /// 次の担当教員名
        var nextCourseTeacher: String?
        /// 次の時限
        var nextCoursePeriod: Int?
    }

    // MARK: 静的属性（なし — すべて ContentState で管理）
}
