import ActivityKit
import Foundation

/// バス Live Activity の開始・終了を管理するサービス
/// ユーザーがバス時刻をタップ選択した際に Live Activity を開始し、
/// 解除時や発車時刻経過時に終了する。
@MainActor
final class BusLiveActivityService {

    static let shared = BusLiveActivityService()
    private init() {}

    // MARK: - 内部状態

    private var currentActivity: Activity<BusLiveActivityAttributes>?
    private var dismissalTimer: Timer?

    /// 発車後に「出発済み」を表示してから自動終了するまでの秒数
    private let dismissalDelay: TimeInterval = 30

    // MARK: - Public API

    /// バス Live Activity が実行中かどうか
    var isActive: Bool { currentActivity != nil }

    /// 選択されたバスの Live Activity を開始する
    func startActivity(
        timeEntry: BusSchedule.TimeEntry,
        routeType: BusSchedule.RouteType
    ) {
        // 既存の bus activity を先に終了
        endActivity()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("【Bus LA】Live Activity 無効 → スキップ")
            return
        }

        let departureDate = Self.departureDate(from: timeEntry)

        // 発車時刻が既に過ぎている場合は開始しない
        guard departureDate > Date() else {
            print("【Bus LA】発車時刻が過去 → スキップ")
            return
        }

        let state = BusLiveActivityAttributes.ContentState(
            departureDate: departureDate,
            routeName: Self.routeDisplayName(routeType),
            departureTimeText: timeEntry.formattedTime,
            specialNote: timeEntry.isSpecial ? timeEntry.specialNote : nil
        )

        let attributes = BusLiveActivityAttributes()
        let content = ActivityContent(state: state, staleDate: departureDate)

        do {
            currentActivity = try Activity<BusLiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("【Bus LA】開始: \(timeEntry.formattedTime) \(Self.routeDisplayName(routeType))")

            // 発車時刻 + dismissalDelay 後に自動終了するタイマーを設定
            scheduleDismissal(at: departureDate.addingTimeInterval(dismissalDelay))
        } catch {
            print("【Bus LA】開始失敗: \(error)")
        }
    }

    /// 現在のバス Live Activity を即座に終了する
    func endActivity() {
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        guard let activity = currentActivity else { return }
        let activityToEnd = activity
        currentActivity = nil
        Task {
            await activityToEnd.end(nil, dismissalPolicy: .immediate)
        }
        print("【Bus LA】終了")
    }

    /// すべてのバス Live Activity を終了する（ログアウト時等）
    func endAllActivities() async {
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        for activity in Activity<BusLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: - プライベート

    /// 指定時刻に Activity を終了するタイマーをセット
    private func scheduleDismissal(at date: Date) {
        dismissalTimer?.invalidate()
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            // 既に過ぎている場合は即終了
            endActivity()
            return
        }
        dismissalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.endActivity()
            }
        }
    }

    // MARK: - ヘルパー

    /// TimeEntry から今日の発車時刻 Date を生成
    static func departureDate(from entry: BusSchedule.TimeEntry) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = entry.hour
        components.minute = entry.minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    /// RouteType の日本語表示名
    static func routeDisplayName(_ route: BusSchedule.RouteType) -> String {
        switch route {
        case .fromSeisekiToSchool:  return String(localized: "聖蹟桜ヶ丘駅発")
        case .fromNagayamaToSchool: return String(localized: "永山駅発")
        case .fromSchoolToSeiseki:  return String(localized: "聖蹟桜ヶ丘駅行")
        case .fromSchoolToNagayama: return String(localized: "永山駅行")
        }
    }
}
