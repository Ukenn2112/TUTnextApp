import ActivityKit
import Foundation

// NOTE: This struct must remain structurally identical to the definition
// in BusWidget/BusLiveActivityWidget.swift (widget extension target).

// MARK: - バス Live Activity 属性

struct BusLiveActivityAttributes: ActivityAttributes {
    public typealias BusActivityState = ContentState

    // MARK: 動的コンテンツ

    public struct ContentState: Codable, Hashable {
        /// カウントダウン対象の発車時刻（Text(date, style: .timer) 用）
        var departureDate: Date
        /// 路線表示名（例: "聖蹟桜ヶ丘駅発"）
        var routeName: String
        /// 発車時刻文字列（例: "08:35"）
        var departureTimeText: String
        /// 特別便の注記（例: "M", "C"）
        var specialNote: String?
    }

    // MARK: 静的属性（なし — すべて ContentState で管理）
}
