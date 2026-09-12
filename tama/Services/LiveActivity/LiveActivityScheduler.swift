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
    /// Activity ID ごとの push token 監視タスク
    private var pushTokenTasks: [String: Task<Void, Never>] = [:]
    /// push-to-start 等で外部から開始された Activity を検知する長命タスク
    private var activityUpdatesTask: Task<Void, Never>?
    /// push-to-start トークン監視タスク（iOS 17.2+）
    private var pushToStartTask: Task<Void, Never>?

    // MARK: - 定数

    private static let apiBase = "https://tama.qaq.tw"
    private static let pushToStartTokenKey = "LiveActivity.lastSentPushToStartToken"

    // MARK: - Public API

    /// アプリ起動時・フォアグラウンド復帰時に呼ぶ
    /// Activity の健全性チェック → スケジュール取得 → 状態同期
    func syncLiveActivity() async {
        print("【LA】syncLiveActivity 開始")

        // バス Live Activity の後始末（プロセス再起動後の取りこぼし対策）
        await BusLiveActivityService.shared.cleanupDepartedActivities()

        guard UserService.shared.getCurrentUser()?.encryptedPassword != nil else {
            print("【LA】ユーザー未認証 → スキップ")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("【LA】Live Activity 無効 → スキップ")
            return
        }

        // 0. トークン監視（既存 Activity / push-to-start）を開始
        observeAllActivities()
        startPushToStartObservation()

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
        // アプリ起動時点でトークン監視を開始しておく
        observeAllActivities()
        startPushToStartObservation()

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
            // ⚠️ .stale は「内容が古い」だけで update 可能なため終了しない
            let isFinished =
                state == .ended ||
                state == .dismissed

            // 最後の授業終了 + 30分超過
            let isPastGrace: Bool
            if let lastEnd = lastClassEndDate {
                isPastGrace = now > lastEnd.addingTimeInterval(30 * 60)
            } else {
                isPastGrace = false
            }

            if isFinished || isPastGrace {
                await endAndUnregister(activity)
                removedCount += 1
            } else {
                validCount += 1
                // 2つ以上の有効 Activity があれば古い方を終了（最大1つ維持）
                if validCount > 1 {
                    await endAndUnregister(activity)
                    removedCount += 1
                }
            }
        }

        if removedCount > 0 {
            print("【LA】クリーンアップ完了: \(removedCount)件終了, \(min(validCount, 1))件維持")
        }
    }

    /// 有効な Activity を1つ返す
    /// `.stale` は「内容が古い」だけで update 可能なので有効として扱う
    private func findValidActivity() -> Activity<ClassLiveActivityAttributes>? {
        Activity<ClassLiveActivityAttributes>.activities.first { activity in
            activity.activityState == .active || activity.activityState == .stale
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
        cancelPushTokenObservation(for: activity.id)
        unregisterActivity(id: activity.id)
        await activity.end(
            content,
            dismissalPolicy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    /// Activity を即座に終了し、バックエンドの登録も解除する
    private func endAndUnregister(_ activity: Activity<ClassLiveActivityAttributes>) async {
        cancelPushTokenObservation(for: activity.id)
        unregisterActivity(id: activity.id)
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// 全 Activity を即座に終了する
    private func endAllActivities() async {
        let count = Activity<ClassLiveActivityAttributes>.activities.count
        if count > 0 {
            print("【LA】全 Activity を即座に終了: \(count)件")
        }
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            await endAndUnregister(activity)
        }
        for task in pushTokenTasks.values { task.cancel() }
        pushTokenTasks.removeAll()
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

    /// 既存のすべての Activity にトークン監視を張り、
    /// push-to-start 等で新たに開始された Activity も監視対象に加える
    private func observeAllActivities() {
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            observePushToken(for: activity)
        }

        guard activityUpdatesTask == nil else { return }
        activityUpdatesTask = Task { [weak self] in
            for await activity in Activity<ClassLiveActivityAttributes>.activityUpdates {
                await MainActor.run {
                    print("【LA】新しい Activity を検出: \(activity.id.prefix(8))")
                    self?.observePushToken(for: activity)
                }
            }
        }
    }

    /// Activity ごとに1つだけ pushTokenUpdates 監視タスクを保持する
    private func observePushToken(for activity: Activity<ClassLiveActivityAttributes>) {
        let id = activity.id
        guard pushTokenTasks[id] == nil else { return }

        pushTokenTasks[id] = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                print("【LA】Push token 更新 (\(id.prefix(8))): \(token.prefix(16))...")
                await self?.sendPushTokenToBackend(token: token, activityId: id)
            }
            self?.clearPushTokenTask(for: id)
        }
    }

    private func clearPushTokenTask(for id: String) {
        pushTokenTasks[id] = nil
    }

    private func cancelPushTokenObservation(for id: String) {
        pushTokenTasks[id]?.cancel()
        pushTokenTasks[id] = nil
    }

    // MARK: - Push-to-Start（iOS 17.2+）

    /// push-to-start トークンを監視し、バックエンドへ送信する
    /// Activity が1つも動いていない状態でもサーバ側から開始できるようになる
    func startPushToStartObservation() {
        guard pushToStartTask == nil else { return }
        guard UserService.shared.getCurrentUser()?.encryptedPassword != nil else { return }

        if #available(iOS 17.2, *) {
            pushToStartTask = Task { [weak self] in
                for await tokenData in Activity<ClassLiveActivityAttributes>.pushToStartTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    await self?.sendPushToStartToken(token)
                }
            }
            print("【LA】push-to-start トークン監視を開始")
        }
    }

    /// push-to-start トークンをバックエンドへ送信する（同一トークンは送信しない）
    private func sendPushToStartToken(_ token: String) async {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else { return }

        let defaults = UserDefaults.standard
        if defaults.string(forKey: Self.pushToStartTokenKey) == token {
            print("【LA】push-to-start トークン変化なし → 送信スキップ")
            return
        }

        let body: [String: String] = [
            "username": user.username,
            "encryptedPassword": encryptedPassword,
            "pushToStartToken": token,
        ]

        let ok = await postJSON(path: "/live-activity/push-to-start", body: body)
        if ok {
            defaults.set(token, forKey: Self.pushToStartTokenKey)
            print("【LA】push-to-start トークン登録成功: \(token.prefix(16))...")
        } else {
            print("【LA】push-to-start トークン登録失敗")
        }
    }

    // MARK: - バックエンド通信

    /// Activity の push token を登録する（失敗時は 2s / 5s / 10s のバックオフで最大3回リトライ）
    private func sendPushTokenToBackend(token: String, activityId: String) async {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else { return }

        let body: [String: String] = [
            "username": user.username,
            "encryptedPassword": encryptedPassword,
            "liveActivityToken": token,
            "activityId": activityId,
        ]

        let backoff: [UInt64] = [2, 5, 10]
        for attempt in 0...backoff.count {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: backoff[attempt - 1] * 1_000_000_000)
                if Task.isCancelled { return }
                print("【LA】トークン登録リトライ \(attempt)/\(backoff.count)")
            }
            if await postJSON(path: "/live-activity/register", body: body) {
                print("【LA】トークン登録成功 (\(activityId.prefix(8)))")
                return
            }
        }
        print("【LA】トークン登録失敗: リトライ上限に到達 (\(activityId.prefix(8)))")
    }

    /// Activity の登録を解除する（fire-and-forget、1回のみ）
    private func unregisterActivity(id: String) {
        guard let user = UserService.shared.getCurrentUser() else { return }
        let body: [String: String] = [
            "username": user.username,
            "activityId": id,
        ]
        Task { [body] in
            let ok = await self.postJSON(path: "/live-activity/unregister", body: body)
            print("【LA】登録解除\(ok ? "成功" : "失敗") (\(id.prefix(8)))")
        }
    }

    /// JSON を POST し、レスポンスの `status` が true なら成功とみなす
    private func postJSON(path: String, body: [String: String]) async -> Bool {
        guard let url = URL(string: Self.apiBase + path) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("【LA】\(path) HTTP \(http.statusCode)")
                return false
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Bool else {
                return false
            }
            return status
        } catch {
            print("【LA】\(path) 通信エラー: \(error)")
            return false
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
                  lesson.name != nil,
                  let startDate = lesson.startTime(on: dateString),
                  let endDate = lesson.endTime(on: dateString) else { continue }

            // 授業名には教員名が末尾に付くため displayName で除去する
            let name = lesson.displayName
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
               next.name != nil {

                // 隣接授業チェック: [start, end) ルール
                // nextStart <= endDate → breakTime をスキップ
                if nextStart > endDate {
                    let gap = nextStart.timeIntervalSince(endDate)
                    let nextName = next.displayName
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

    /// 現在の状態に対する staleDate を返す
    /// ルール: 次のトランジション時刻 + 10分の猶予。次が無ければ nil
    /// ⚠️ バックエンドの stale-date 算出ルールと一致させること
    private func staleDateForCurrentState() -> Date? {
        let now = Date()
        guard let next = transitions.first(where: { $0.date > now }) else { return nil }
        return next.date.addingTimeInterval(10 * 60)
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
