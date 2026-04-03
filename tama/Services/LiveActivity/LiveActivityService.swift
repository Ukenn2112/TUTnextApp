import ActivityKit
import Foundation

/// 授業 Live Activity のユーティリティ
/// 主な管理は LiveActivityScheduler が行う。このクラスはログアウト時の一括終了等に使用。
@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    /// アクティブな Activity が存在するか
    var hasActiveActivity: Bool {
        !Activity<ClassLiveActivityAttributes>.activities.isEmpty
    }

    /// アクティブな Activity をすべて即座に終了する（ログアウト時等）
    func endAllActivities() async {
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
