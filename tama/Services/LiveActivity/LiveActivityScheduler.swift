import ActivityKit
import BackgroundTasks
import Foundation

// MARK: - トランジションモデル

struct ScheduleTransition {
    let date: Date
    let state: ClassLiveActivityAttributes.ContentState
}

// MARK: - スケジューラ

/// 授業 Live Activity のライフサイクル全体を管理する
/// - スケジュール取得 → トランジション計算 → Activity 開始/更新/終了
/// - フォアグラウンド Timer + バックグラウンド push で状態遷移
@MainActor
final class LiveActivityScheduler: ObservableObject {

    static let shared = LiveActivityScheduler()
    private init() {}

    // MARK: - 内部状態

    private var transitions: [ScheduleTransition] = []
    private var foregroundTimer: Timer?
    private var lastComputedDateKey: String = ""
    private var lastClassEndDate: Date?
    private var pushTokenObservationTask: Task<Void, Never>?

    // MARK: - Public API

    /// アプリ起動時・フォアグラウンド復帰時に呼ぶ
    /// Activity の健全性チェック → スケジュール取得 → 状態同期
    func syncLiveActivity() async {
        print("【LA】syncLiveActivity 開始")

        guard UserService.shared.getCurrentUser()?.encryptedPassword != nil else {
            print("【LA】ユーザー未認証 → スキップ")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("【LA】Live Activity 無効 → スキップ")
            return
        }

        // 1. 既存 Activity のクリーンアップ
        await cleanupStaleActivities()

        // 2. 当日のスケジュール取得
        let todayKey = todayDateKey()
        if todayKey != lastComputedDateKey {
            // 日付が変わった場合はキャッシュを破棄して再取得
            print("【LA】日付変更検出 (\(todayKey)) → キャッシュ破棄")
            TodayScheduleService.shared.invalidateCache()
        }

        guard let schedule = try? await TodayScheduleService.shared.fetchTodaySchedule() else {
            print("【LA】スケジュール取得失敗 → スキップ")
            return
        }

        let lessons = schedule.timeTable.filter { !$0.isCancelled && $0.name != nil }

        guard !lessons.isEmpty else {
            print("【LA】授業なし → 全 Activity 終了")
            await endAllActivities()
            transitions = []
            lastComputedDateKey = todayKey
            return
        }

        // 3. トランジション計算
        transitions = computeTransitions(lessons: lessons, dateString: schedule.dateInfo.date)
        lastComputedDateKey = todayKey
        print("【LA】\(lessons.count)件の授業 → \(transitions.count)件のトランジション生成")

        // 最後の授業終了時刻を記録
        lastClassEndDate = transitions.last(where: { $0.state.phase == .finished })?.state.endDate

        // 4. 有効な Activity を探す or 新規作成
        let now = Date()

        // 全授業終了 + 猶予時間超過なら何もしない
        if let lastEnd = lastClassEndDate, now > lastEnd.addingTimeInterval(15 * 60) {
            print("【LA】全授業終了 + 猶予時間超過 → 全 Activity 終了")
            await endAllActivities()
            return
        }

        // まだ最初の授業前で、30分以上先なら開始しない
        if let firstTransition = transitions.first,
           firstTransition.date > now.addingTimeInterval(30 * 60) {
            print("【LA】最初の授業まで30分以上 → Activity 開始しない")
            return
        }

        var activity = findValidActivity()
        if activity == nil {
            print("【LA】有効な Activity なし → 新規作成")
            activity = await startNewActivity()
        }
        guard let activity else { return }

        // 5. 現在の状態にキャッチアップ
        if let currentState = transitions.last(where: { $0.date <= now })?.state {
            print("【LA】状態キャッチアップ → phase=\(currentState.phase.rawValue), period=\(currentState.period)")
            if currentState.phase == .finished {
                await endActivityWithDelay(activity)
            } else {
                let content = ActivityContent(state: currentState, staleDate: staleDateForCurrentState())
                await activity.update(content)
            }
        } else if let firstState = transitions.first?.state {
            print("【LA】初期状態適用 → phase=\(firstState.phase.rawValue), period=\(firstState.period)")
            // まだ最初のトランジション前 → 最初の状態を適用
            let content = ActivityContent(state: firstState, staleDate: staleDateForCurrentState())
            await activity.update(content)
        }

        // 6. フォアグラウンド Timer 開始
        scheduleNextTimer()

        print("【LA】syncLiveActivity 完了")
    }

    /// フォアグラウンド Timer を停止する（バックグラウンド移行時）
    func pauseForegroundTimer() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
        // バックグラウンド保底タスクをスケジュール
        scheduleBackgroundRefresh()
    }

    // MARK: - BGAppRefreshTask（バックグラウンド保底）

    static let bgTaskIdentifier = "com.meikenn.tama.liveactivity.refresh"

    /// BGAppRefreshTask のハンドラを登録する（AppDelegate で1回だけ呼ぶ）
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor [weak self] in
                guard let self else {
                    task.setTaskCompleted(success: false)
                    return
                }
                print("【LA】BGAppRefreshTask 発火")
                if let activity = self.findValidActivity(),
                   let currentState = self.transitions.last(where: { $0.date <= Date() })?.state {
                    if currentState.phase == .finished {
                        await self.endActivityWithDelay(activity)
                    } else {
                        let content = ActivityContent(state: currentState, staleDate: self.staleDateForCurrentState())
                        await activity.update(content)
                    }
                }
                self.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// 次のトランジション時刻に合わせて BGAppRefreshTask をスケジュール
    private func scheduleBackgroundRefresh() {
        let now = Date()
        guard let nextTransition = transitions.first(where: { $0.date > now }) else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = nextTransition.date
        do {
            try BGTaskScheduler.shared.submit(request)
            print("【LA】BGAppRefreshTask スケジュール → \(nextTransition.state.phase.rawValue) @ \(nextTransition.date)")
        } catch {
            print("【LA】BGAppRefreshTask スケジュール失敗: \(error)")
        }
    }

    // MARK: - Activity ライフサイクル

    /// 既存の全 Activity を走査し、不要なものを終了する
    private func cleanupStaleActivities() async {
        let activities = Activity<ClassLiveActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        print("【LA】クリーンアップ開始: \(activities.count)件の Activity を検出")

        let now = Date()
        var validCount = 0
        var removedCount = 0

        for activity in activities {
            let state = activity.activityState
            let isStale =
                state == .ended ||
                state == .dismissed ||
                state == .stale

            // 最後の授業終了 + 30分超過
            let isPastGrace: Bool
            if let lastEnd = lastClassEndDate {
                isPastGrace = now > lastEnd.addingTimeInterval(30 * 60)
            } else {
                isPastGrace = false
            }

            if isStale || isPastGrace {
                await activity.end(nil, dismissalPolicy: .immediate)
                removedCount += 1
            } else {
                validCount += 1
                // 2つ以上の有効 Activity があれば古い方を終了（最大1つ維持）
                if validCount > 1 {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    removedCount += 1
                }
            }
        }

        if removedCount > 0 {
            print("【LA】クリーンアップ完了: \(removedCount)件終了, \(min(validCount, 1))件維持")
        }
    }

    /// 有効な（アクティブまたは stale でない）Activity を1つ返す
    private func findValidActivity() -> Activity<ClassLiveActivityAttributes>? {
        Activity<ClassLiveActivityAttributes>.activities.first { activity in
            activity.activityState == .active
        }
    }

    /// 新しい Activity を開始する
    private func startNewActivity() async -> Activity<ClassLiveActivityAttributes>? {
        guard let initialState = transitions.last(where: { $0.date <= Date() })?.state
                ?? transitions.first?.state else {
            return nil
        }

        let attributes = ClassLiveActivityAttributes()
        let content = ActivityContent(state: initialState, staleDate: staleDateForCurrentState())

        do {
            let activity = try Activity<ClassLiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            observePushToken(for: activity)
            return activity
        } catch {
            print("【LA】Activity 開始失敗: \(error)")
            return nil
        }
    }

    /// finished フェーズで Activity を終了する（15分後に自動消去）
    private func endActivityWithDelay(_ activity: Activity<ClassLiveActivityAttributes>) async {
        let finishedState = transitions.last(where: { $0.state.phase == .finished })?.state
        let content: ActivityContent<ClassLiveActivityAttributes.ContentState>
        if let finishedState {
            content = ActivityContent(state: finishedState, staleDate: nil)
        } else {
            return
        }

        print("【LA】Activity を finished で終了（15分後に消去）")
        await activity.end(
            content,
            dismissalPolicy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    /// 全 Activity を即座に終了する
    private func endAllActivities() async {
        let count = Activity<ClassLiveActivityAttributes>.activities.count
        if count > 0 {
            print("【LA】全 Activity を即座に終了: \(count)件")
        }
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        pushTokenObservationTask?.cancel()
        pushTokenObservationTask = nil
    }

    // MARK: - フォアグラウンド Timer

    private func scheduleNextTimer() {
        foregroundTimer?.invalidate()

        let now = Date()
        guard let nextTransition = transitions.first(where: { $0.date > now }) else {
            print("【LA】次のトランジションなし → Timer 不要")
            return
        }

        let interval = max(0.1, nextTransition.date.timeIntervalSince(now))
        print("【LA】次のトランジション: phase=\(nextTransition.state.phase.rawValue) まで \(String(format: "%.0f", interval))秒後")
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 現在の状態にキャッチアップ
                if let activity = self.findValidActivity(),
                   let currentState = self.transitions.last(where: { $0.date <= Date() })?.state {
                    print("【LA】Timer 発火 → phase=\(currentState.phase.rawValue), period=\(currentState.period)")
                    if currentState.phase == .finished {
                        await self.endActivityWithDelay(activity)
                    } else {
                        let content = ActivityContent(state: currentState, staleDate: self.staleDateForCurrentState())
                        await activity.update(content)
                    }
                }
                // 次のタイマーをスケジュール
                self.scheduleNextTimer()
            }
        }
    }

    // MARK: - Push Token

    private func observePushToken(for activity: Activity<ClassLiveActivityAttributes>) {
        pushTokenObservationTask?.cancel()
        pushTokenObservationTask = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                print("【LA】Push token 更新: \(token.prefix(16))...")
                await self?.sendPushTokenToBackend(token: token, activityId: activity.id)
            }
        }
    }

    private func sendPushTokenToBackend(token: String, activityId: String) async {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else { return }

        guard let url = URL(string: "https://tama.qaq.tw/live-activity/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "username": user.username,
            "encryptedPassword": encryptedPassword,
            "liveActivityToken": token,
            "activityId": activityId,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Bool {
                print("【LA】トークン登録\(status ? "成功" : "失敗")")
            }
        } catch {
            print("【LA】トークン登録エラー: \(error)")
        }
    }

    // MARK: - トランジション計算

    /// 当日のレッスン配列からすべてのトランジションイベントを計算する
    /// ⚠️ このロジックはバックエンドの compute_transitions と完全に一致させること
    func computeTransitions(lessons: [TodayLesson], dateString: String) -> [ScheduleTransition] {
        var result: [ScheduleTransition] = []
        let sorted = lessons
            .filter { $0.lessonNum != nil }
            .sorted { ($0.lessonNum ?? 0) < ($1.lessonNum ?? 0) }

        for (i, lesson) in sorted.enumerated() {
            guard let lessonNum = lesson.lessonNum,
                  let name = lesson.name,
                  let startDate = lesson.startTime(on: dateString),
                  let endDate = lesson.endTime(on: dateString) else { continue }

            let room = lesson.cleanRoom
            let teacher = lesson.primaryTeacher
            let hasRoomChange = lesson.hasRoomChange

            // --- upcoming ---
            // 長い休憩（>10分）: upcoming は授業開始10分前から
            // 短い休憩（≤10分）: upcoming は前の授業終了直後から
            let upcomingDate: Date
            if i == 0 {
                upcomingDate = startDate.addingTimeInterval(-30 * 60)
            } else if let prevEnd = sorted[i - 1].endTime(on: dateString) {
                let gap = startDate.timeIntervalSince(prevEnd)
                if gap > 10 * 60 {
                    upcomingDate = startDate.addingTimeInterval(-10 * 60)
                } else {
                    upcomingDate = prevEnd
                }
            } else {
                upcomingDate = startDate.addingTimeInterval(-30 * 60)
            }

            result.append(ScheduleTransition(
                date: upcomingDate,
                state: .init(
                    phase: .upcoming,
                    countdownDate: startDate,
                    courseName: name,
                    room: room,
                    teacher: teacher,
                    period: lessonNum,
                    startDate: startDate,
                    endDate: endDate,
                    hasRoomChange: hasRoomChange,
                    newRoom: hasRoomChange ? room : nil
                )
            ))

            // --- imminent（upcoming から5分以上ある場合のみ生成）---
            let imminentDate = startDate.addingTimeInterval(-5 * 60)
            if imminentDate > upcomingDate {
                result.append(ScheduleTransition(
                    date: imminentDate,
                    state: .init(
                        phase: .imminent,
                        countdownDate: startDate,
                        courseName: name,
                        room: room,
                        teacher: teacher,
                        period: lessonNum,
                        startDate: startDate,
                        endDate: endDate,
                        hasRoomChange: hasRoomChange,
                        newRoom: hasRoomChange ? room : nil
                    )
                ))
            }

            // --- inProgress ---
            result.append(ScheduleTransition(
                date: startDate,
                state: .init(
                    phase: .inProgress,
                    countdownDate: endDate,
                    courseName: name,
                    room: room,
                    teacher: teacher,
                    period: lessonNum,
                    startDate: startDate,
                    endDate: endDate,
                    hasRoomChange: hasRoomChange,
                    newRoom: hasRoomChange ? room : nil
                )
            ))

            // --- breakTime or finished ---
            let nextLesson: TodayLesson? = i + 1 < sorted.count ? sorted[i + 1] : nil

            if let next = nextLesson,
               let nextStart = next.startTime(on: dateString),
               next.endTime(on: dateString) != nil,
               let nextNum = next.lessonNum,
               let nextName = next.name {

                // 隣接授業チェック: [start, end) ルール
                // nextStart <= endDate → breakTime をスキップ
                if nextStart > endDate {
                    let gap = nextStart.timeIntervalSince(endDate)
                    let nextRoom = next.cleanRoom
                    let nextTeacher = next.primaryTeacher

                    // 休憩が10分超 → breakTime を表示（昼休み等）
                    // 10分以下 → breakTime スキップ、upcoming がそのまま続く
                    if gap > 10 * 60 {
                        result.append(ScheduleTransition(
                            date: endDate,
                            state: .init(
                                phase: .breakTime,
                                countdownDate: nextStart,
                                courseName: name,
                                room: room,
                                teacher: teacher,
                                period: lessonNum,
                                startDate: startDate,
                                endDate: endDate,
                                hasRoomChange: false,
                                newRoom: nil,
                                nextCourseName: nextName,
                                nextCourseRoom: nextRoom,
                                nextCourseTeacher: nextTeacher,
                                nextCoursePeriod: nextNum
                            )
                        ))
                    }
                }
            } else {
                // 最後の授業 → finished
                result.append(ScheduleTransition(
                    date: endDate,
                    state: .init(
                        phase: .finished,
                        countdownDate: endDate,
                        courseName: name,
                        room: room,
                        teacher: teacher,
                        period: lessonNum,
                        startDate: startDate,
                        endDate: endDate
                    )
                ))
            }
        }

        return result.sorted { a, b in
            if a.date == b.date {
                return phaseSortOrder(a.state.phase) < phaseSortOrder(b.state.phase)
            }
            return a.date < b.date
        }
    }

    /// トランジションの安定ソート用フェーズ優先度
    /// breakTime(前の授業の終了) → upcoming(次の授業の準備) の順序を保証
    private func phaseSortOrder(_ phase: ClassPhase) -> Int {
        switch phase {
        case .finished:   return 0
        case .breakTime:  return 1
        case .upcoming:   return 2
        case .imminent:   return 3
        case .inProgress: return 4
        }
    }

    // MARK: - ユーティリティ

    /// 現在の状態に対する staleDate を返す（カウントダウン対象時刻）
    /// staleDate = countdownDate にすることで、倒計時が0に達した瞬間に
    /// isStale = true → "0:00" 表示（正向計時を防止）
    private func staleDateForCurrentState() -> Date? {
        let now = Date()
        return transitions.last(where: { $0.date <= now })?.state.countdownDate
            ?? transitions.first?.state.countdownDate
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()

    private func todayDateKey() -> String {
        Self.dateKeyFormatter.string(from: Date())
    }
}
