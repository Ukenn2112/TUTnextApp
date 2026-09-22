import Foundation

// MARK: - お知らせ

/// 「今日」ペインが覚えておく1件の掲示（題名と、掲示そのものを開くための手がかり）
struct TodayNotice: Identifiable, Equatable {

    /// 掲示番号（`AnnouncementModel.id`）
    let id: Int

    let title: String

    /// 掲示の登録日（`AnnouncementModel.torkDate`）
    let torkDate: String?

    /// 掲示された日時（古い掲示を出さないための判定に使う）
    let postedAt: Date
}

// MARK: - 弁当箱

/// 「今日」ペインに並べる4枚のタイル。
///
/// タイルの並びは時刻によって入れ替わらない。授業がいちばん上、その下にこのあとの授業、
/// 下の段の左がバス、右が課題。**どのタイルも必ず同じ場所に在る**ので、
/// 利用者は「ここを見ればバスの話」と覚えたまま使える。
/// 出すものが無いときも、タイルごと消えるのは「このあとの授業」だけ（残りは静かな一言になる）
struct TodayBoard: Equatable {

    let lesson: TodayLessonTileModel
    let upcoming: TodayUpcomingTileModel?
    let bus: TodayBusTileModel
    let assignments: TodayAssignmentTileModel
}

// MARK: - ①授業のタイル

/// いまの授業／次の授業のタイル（いつでも「授業」の話しかしない）
struct TodayLessonTileModel: Equatable {

    /// 授業中か、これからか
    enum State: Equatable {
        case inClass
        case next
    }

    /// 出す授業があるときの中身
    struct Lesson: Equatable {

        let state: State

        /// 時限のキー（"1"〜"7"）
        let period: String
        let periodNumber: Int

        let courseName: String

        /// 出る教室（教室変更があればその新しい教室）
        let room: String

        /// 教室変更の元の教室（変更が無ければ nil）
        let previousRoom: String?

        let teacher: String?

        /// 残り時間（授業中は終了まで、これからなら開始まで）
        let remaining: TimeInterval

        /// システムの時計に合わせた目標時刻（残り10分を切ったときの m:ss に渡す）
        let systemTarget: Date

        /// 授業の進み具合（0…1）。授業中だけ値を持つ
        let progress: Double?

        let startTime: String
        let endTime: String

        /// 掲示の未読件数（0なら札は出さない）
        let unreadCount: Int

        /// 掲示ボタンを押したときに開く、いちばん新しい掲示（まだ取れていなければ nil）
        let notice: TodayNotice?

        /// 掲示ボタンそのものを出すかどうか
        let showsNotice: Bool
    }

    /// 授業があるときはその授業、無いときは一言だけ
    enum Content: Equatable {
        case lesson(Lesson)
        case quiet(String)
    }

    let content: Content

    /// 出している授業の時限（掲示の取得先を決めるのに使う）
    var period: String? {
        guard case .lesson(let lesson) = content else { return nil }
        return lesson.period
    }
}

// MARK: - ②このあとの授業のタイル

/// これから始まる授業の一覧（①に出している授業は含めない）。空なら丸ごと出さない
struct TodayUpcomingTileModel: Equatable {

    let rows: [Row]

    /// 1行＝1コマ
    struct Row: Identifiable, Equatable {

        /// 時限のキー（"1"〜"7"）がそのまま識別子になる
        let id: String

        let time: String
        let periodLabel: String
        let courseName: String

        /// 「〜14:30 · 出原 至道」
        let detail: String?

        /// 教室（空なら nil）
        let room: String?

        /// 教室変更があった行（丸札を橙色にする）
        let isRoomChanged: Bool

        let accessibilityLabel: String
    }
}

// MARK: - ③バスのタイル

/// これから乗れる便の一覧。駅で分けず、いまの向きの両路線を混ぜて時刻順に並べる
struct TodayBusTileModel: Equatable {

    /// 学校へ向かうのか、学校から帰るのか（見出しの文言が変わる）
    let isTowardSchool: Bool

    /// 時刻順の便（1本目が「いま乗るべき便」）
    let rows: [Row]

    /// 便が無いときの一言
    let emptyText: String?

    /// タイルを押したときに開くバスタブの路線
    let route: BusSchedule.RouteType

    /// 2段目の文字の色づけ
    enum StatusStyle: Equatable {
        case plain
        case warning
        case urgency(BusUrgency)
    }

    struct Row: Identifiable, Equatable {

        let id: String

        /// 「18:00」
        let time: String

        /// 備考の記号（◎ / * / M）。赤い文字だけで出す
        let note: String?

        /// 「聖蹟桜ヶ丘駅行」
        let name: String

        /// 2段目（1本目は状態、それ以降は「40分後」）
        let status: String?
        let statusStyle: StatusStyle

        /// 1本目かどうか（時刻を少しだけ大きくする）
        let isKey: Bool

        /// 見出しの記号に使う切迫度（1本目だけ。まだ数えない便では nil）
        var urgency: BusUrgency?

        let remaining: TimeInterval
        let systemTarget: Date
    }
}

// MARK: - ④課題のタイル

/// 見出しに出す締切の数（今日・明日・総数）と、締切が近い順の未提出
struct TodayAssignmentTileModel: Equatable {

    /// 共有の控えが一度でも読み込まれたか（まだなら見出しの数を出さない）
    let isLoaded: Bool

    let todayCount: Int
    let tomorrowCount: Int

    /// いちばん近い課題の締切が迫っているか（見出しの記号と「今日 N」を赤にする）
    let isUrgent: Bool

    /// 締切が近い順の未提出（高さが余る分だけ行として並べる）
    let items: [Item]

    /// 1件も無いときの一言
    let emptyText: String?

    /// 未提出（期限切れを除く）の総数
    let totalPending: Int

    struct Item: Identifiable, Equatable {

        let id: String

        let title: String

        /// 「今日 · あと 1時間」
        let detail: String

        /// 締切が迫っているので `detail` に差し色を使うか
        let isAccented: Bool

        let url: String
    }
}

// MARK: - 組み立て

/// 場面・授業・課題から4枚のタイルを組み立てる純粋な計算（表示を持たない）
enum TodayBoardBuilder {

    /// 掲示を出す期限（これより古い掲示は「今日」ペインには出さない）
    private static let noticeFreshnessDays = 14

    /// - Parameters:
    ///   - state: `TodayPhaseEngine` が決めた場面
    ///   - classes: 今日の授業（時限順）
    ///   - assignments: 共有の控えにある課題（締切が近い順）
    ///   - hasLoadedAssignments: 課題の控えが一度でも読み込まれたか
    ///   - roomChange: その授業の教室変更（無ければ nil）
    ///   - notice: その授業の掲示（新しい順。まだ取れていなければ空）
    static func make(
        state: TodayPaneState,
        classes: [TodayClass],
        assignments: [Assignment],
        now: Date,
        clock: TodayClock = TodayClock(),
        roomChange: (CourseModel) -> RoomChange? = { _ in nil },
        notice: (CourseModel) -> [TodayNotice] = { _ in [] },
        hasLoadedAssignments: Bool = true
    ) -> TodayBoard {
        let lesson = lessonTile(
            state: state, now: now, clock: clock, roomChange: roomChange, notice: notice)
        return TodayBoard(
            lesson: lesson,
            upcoming: upcomingTile(
                classes: classes, now: now, excluding: lesson.period, roomChange: roomChange),
            bus: busTile(state: state, classes: classes, now: now, clock: clock),
            assignments: assignmentTile(
                assignments, now: now, hasLoaded: hasLoadedAssignments))
    }
}

// MARK: - ①授業

extension TodayBoardBuilder {

    fileprivate static func lessonTile(
        state: TodayPaneState,
        now: Date,
        clock: TodayClock,
        roomChange: (CourseModel) -> RoomChange?,
        notice: (CourseModel) -> [TodayNotice]
    ) -> TodayLessonTileModel {
        func lesson(_ value: TodayClass, _ lessonState: TodayLessonTileModel.State)
            -> TodayLessonTileModel {
            TodayLessonTileModel(
                content: .lesson(
                    self.lesson(
                        value, state: lessonState, now: now, clock: clock,
                        roomChange: roomChange(value.course), notices: notice(value.course))))
        }

        switch state.phase {
        case .inClass(let value):
            return lesson(value, .inClass)

        case .headToRoom(let value), .breakTime(next: let value):
            return lesson(value, .next)

        case .beforeDeparture(let plan):
            guard let target = plan.targetClass else { return quiet(noClassesText) }
            return lesson(target, .next)

        case .afterSchool:
            return quiet(NSLocalizedString("本日の授業は終了しました", comment: "「今日」ペイン"))

        case .noClasses:
            return quiet(noClassesText)
        }
    }

    private static var noClassesText: String {
        NSLocalizedString("本日は授業がありません", comment: "「今日」ペイン")
    }

    private static func quiet(_ text: String) -> TodayLessonTileModel {
        TodayLessonTileModel(content: .quiet(text))
    }

    private static func lesson(
        _ lesson: TodayClass,
        state: TodayLessonTileModel.State,
        now: Date,
        clock: TodayClock,
        roomChange: RoomChange?,
        notices: [TodayNotice]
    ) -> TodayLessonTileModel.Lesson {
        let target = state == .inClass ? lesson.end : lesson.start
        let total = lesson.end.timeIntervalSince(lesson.start)
        let elapsed = now.timeIntervalSince(lesson.start)
        let unread = max(0, lesson.course.keijiMidokCnt ?? 0)
        let newest = notices.first
        let isFresh = newest.map {
            now.timeIntervalSince($0.postedAt) <= TimeInterval(noticeFreshnessDays * 24 * 60 * 60)
        } ?? false

        let changed = changedRoom(roomChange, current: lesson.course.room)

        return TodayLessonTileModel.Lesson(
            state: state,
            period: lesson.period,
            periodNumber: lesson.periodNumber,
            courseName: lesson.course.name,
            room: changed ?? lesson.course.room,
            previousRoom: changed != nil && !lesson.course.room.isEmpty
                ? lesson.course.room : nil,
            teacher: lesson.course.teacher.isEmpty ? nil : lesson.course.teacher,
            remaining: target.timeIntervalSince(now),
            systemTarget: clock.systemDate(for: target),
            progress: state == .inClass && total > 0 ? min(max(elapsed / total, 0), 1) : nil,
            startTime: TodayFormat.time(lesson.start),
            endTime: TodayFormat.time(lesson.end),
            unreadCount: unread,
            notice: newest,
            showsNotice: unread > 0 || isFresh)
    }

    /// 教室変更が実際に教室を変えているときだけ、その新しい教室を返す（①②で同じ判定を使う）
    fileprivate static func changedRoom(_ change: RoomChange?, current: String) -> String? {
        guard let newRoom = change?.newRoom, newRoom != current else { return nil }
        return newRoom
    }
}

// MARK: - ②このあとの授業

extension TodayBoardBuilder {

    fileprivate static func upcomingTile(
        classes: [TodayClass],
        now: Date,
        excluding period: String?,
        roomChange: (CourseModel) -> RoomChange?
    ) -> TodayUpcomingTileModel? {
        let rows = classes
            .filter { $0.start > now && $0.period != period }
            .map { row($0, roomChange: roomChange) }
        return rows.isEmpty ? nil : TodayUpcomingTileModel(rows: rows)
    }

    private static func row(
        _ lesson: TodayClass, roomChange: (CourseModel) -> RoomChange?
    ) -> TodayUpcomingTileModel.Row {
        let changed = changedRoom(roomChange(lesson.course), current: lesson.course.room)
        let room = changed ?? (lesson.course.room.isEmpty ? nil : lesson.course.room)
        let periodLabel = PeriodLabel.text(for: lesson.periodNumber)
        let time = TodayFormat.time(lesson.start)

        var spoken = [periodLabel, time, lesson.course.name]
        if let room {
            spoken.append(String(format: NSLocalizedString("教室 %@", comment: "「今日」ペイン"), room))
        }
        if changed != nil, !lesson.course.room.isEmpty {
            spoken.append(
                String(
                    format: NSLocalizedString("教室変更 %@ から %@", comment: "「今日」ペイン"),
                    lesson.course.room, room ?? ""))
        }

        var detail = String(
            format: NSLocalizedString("〜%@", comment: "「今日」ペインの終了時刻"),
            TodayFormat.time(lesson.end))
        if !lesson.course.teacher.isEmpty {
            detail += " · " + lesson.course.teacher
        }

        return TodayUpcomingTileModel.Row(
            id: lesson.period,
            time: time,
            periodLabel: periodLabel,
            courseName: lesson.course.name,
            detail: detail,
            room: room,
            isRoomChanged: changed != nil,
            accessibilityLabel: spoken.joined(separator: " "))
    }
}

// MARK: - ③バス

extension TodayBoardBuilder {

    fileprivate static func busTile(
        state: TodayPaneState, classes: [TodayClass], now: Date, clock: TodayClock
    ) -> TodayBusTileModel {
        guard let plan = busPlan(state: state) else {
            return empty(state: state, classes: classes, now: now)
        }

        let isTowardSchool = plan.departure.route.isTowardSchool

        // 最後の授業より後の便は、授業が終わるまでカウントダウンを出さない（何時間も前から数えない）
        let lastEnd = classes.last?.end
        let waitsForLastLesson = !plan.isSelected && !isTowardSchool
            && (lastEnd.map { $0 > now && plan.departure.date >= $0 } ?? false)

        let key = keyRow(
            plan, now: now, clock: clock, waitsForLastLesson: waitsForLastLesson)
        let others = (plan.following + plan.otherFollowing)
            .sorted { $0.date < $1.date }
            .prefix(listRowLimit)
            .map { row($0, now: now, clock: clock) }

        return TodayBusTileModel(
            isTowardSchool: isTowardSchool,
            rows: [key] + others,
            emptyText: nil,
            route: plan.departure.route)
    }

    /// 一覧に持っておく行数の上限
    private static let listRowLimit = 6

    /// 1本目（いま乗るべき便）
    private static func keyRow(
        _ plan: BusPlan, now: Date, clock: TodayClock, waitsForLastLesson: Bool
    ) -> TodayBusTileModel.Row {
        let remaining = plan.departure.date.timeIntervalSince(now)
        // 最終授業を待っているあいだは数えないので、切迫度も持たせない
        let urgency = waitsForLastLesson
            ? nil : BusUrgency.level(minutesUntil: TodayFormat.minutes(remaining))
        var status: String
        var style: TodayBusTileModel.StatusStyle

        if let urgency {
            status = String(
                format: NSLocalizedString("あと %@", comment: "「今日」ペイン"),
                TodayFormat.durationText(remaining))
            style = .urgency(urgency)
        } else {
            status = NSLocalizedString("最終授業のあと", comment: "「今日」ペイン")
            style = .plain
        }

        if let target = plan.targetClass {
            if plan.makesIt {
                status = String(
                    format: NSLocalizedString("%@に間に合います", comment: "「今日」ペイン"),
                    PeriodLabel.text(for: target.periodNumber))
                style = .plain
            } else {
                status = NSLocalizedString("遅刻の可能性", comment: "「今日」ペイン")
                style = .warning
            }
        }

        return TodayBusTileModel.Row(
            id: plan.departure.id,
            time: plan.departure.formattedTime,
            note: plan.departure.badge,
            name: plan.departure.route.displayName,
            status: status,
            statusStyle: style,
            isKey: true,
            urgency: urgency,
            remaining: waitsForLastLesson ? 0 : remaining,
            systemTarget: clock.systemDate(for: plan.departure.date))
    }

    /// 2本目から下
    private static func row(
        _ departure: BusDeparture, now: Date, clock: TodayClock
    ) -> TodayBusTileModel.Row {
        TodayBusTileModel.Row(
            id: departure.id,
            time: departure.formattedTime,
            note: departure.badge,
            name: departure.route.displayName,
            status: shortRelative(until: departure.date.timeIntervalSince(now)),
            statusStyle: .plain,
            isKey: false,
            remaining: 0,
            systemTarget: departure.date)
    }

    /// 1時間より先は何も言わない（時刻そのものが答えになっているため）
    private static func shortRelative(until remaining: TimeInterval) -> String? {
        let minutes = TodayFormat.minutes(remaining)
        guard minutes > 0, minutes < 60 else { return nil }
        return String(format: NSLocalizedString("%d分後", comment: "「今日」ペイン"), minutes)
    }

    /// タイルに出す便を決める（朝の便 → 遅刻しうる便 → 放課後の便 → 帰りの便 の順に見る）
    private static func busPlan(state: TodayPaneState) -> BusPlan? {
        if case .beforeDeparture(let plan) = state.phase { return plan }
        if case .noClasses(let plan) = state.phase, let plan { return plan }
        if let late = state.lateBus { return late }
        if case .afterSchool(let plan) = state.phase, let plan { return plan }
        return state.homeBus
    }

    /// 便が1本も無いとき。向きだけは場面から決めて、見出しが揺れないようにする
    private static func empty(
        state: TodayPaneState, classes: [TodayClass], now: Date
    ) -> TodayBusTileModel {
        let isTowardSchool = (classes.first?.start).map { $0 > now } ?? false
        let station = state.station

        return TodayBusTileModel(
            isTowardSchool: isTowardSchool,
            rows: [],
            emptyText: state.hasSchedule
                ? NSLocalizedString("本日の運行は終了しました", comment: "「今日」ペイン")
                : NSLocalizedString("バスの情報がありません", comment: "「今日」ペイン"),
            route: isTowardSchool ? station.toSchoolRoute : station.fromSchoolRoute)
    }
}

// MARK: - ④課題

extension TodayBoardBuilder {

    fileprivate static func assignmentTile(
        _ assignments: [Assignment], now: Date, hasLoaded: Bool
    ) -> TodayAssignmentTileModel {
        let calendar = Calendar.current
        let pending = assignments.filter { $0.isPending && $0.dueDate > now }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)

        let dueToday = pending.filter { calendar.isDate($0.dueDate, inSameDayAs: now) }
        let dueTomorrow = tomorrow.map { day in
            pending.filter { calendar.isDate($0.dueDate, inSameDayAs: day) }
        } ?? []

        let sorted = pending.sorted { $0.dueDate < $1.dueDate }

        return TodayAssignmentTileModel(
            isLoaded: hasLoaded,
            todayCount: dueToday.count,
            tomorrowCount: dueTomorrow.count,
            isUrgent: sorted.first?.isUrgent ?? false,
            items: hasLoaded
                ? sorted.prefix(itemLimit).map { item($0, now: now, calendar: calendar) }
                : [],
            emptyText: hasLoaded && sorted.isEmpty
                ? NSLocalizedString("期限の近い課題はありません", comment: "「今日」ペイン")
                : nil,
            totalPending: pending.count)
    }

    /// 行として持っておく上限（これ以上は高さが余っても出さない）
    private static let itemLimit = 8

    private static func item(
        _ assignment: Assignment, now: Date, calendar: Calendar
    ) -> TodayAssignmentTileModel.Item {
        let remaining = String(
            format: NSLocalizedString("あと %@", comment: "「今日」ペイン"),
            assignment.remainingTimeText)
        let day = dayLabel(for: assignment.dueDate, now: now, calendar: calendar)
        return TodayAssignmentTileModel.Item(
            id: assignment.id,
            title: assignment.title,
            detail: "\(day) · \(remaining)",
            isAccented: assignment.isUrgent,
            url: assignment.url)
    }

    /// 「今日」「明日」、それより先は「9/25」
    private static func dayLabel(for due: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(due, inSameDayAs: now) {
            return NSLocalizedString("今日", comment: "「今日」ペインの課題の数の名札")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(due, inSameDayAs: tomorrow) {
            return NSLocalizedString("明日", comment: "「今日」ペインの課題の数の名札")
        }
        return due.formatted(.dateTime.month(.defaultDigits).day())
    }
}

// MARK: - 表記

/// 「今日」ペインの時刻・残り時間の表記をここ一箇所にまとめる
enum TodayFormat {

    /// これを切ったら残り時間を秒まで出す（①の残り時間と③の1本目で同じ境目にする）
    static let liveThreshold: TimeInterval = 10 * 60

    /// 時刻（「9:00」）。授業・課題・バスで同じ書き方にする
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 残り秒数を分に切り上げる
    static func minutes(_ remaining: TimeInterval) -> Int {
        max(0, Int((remaining / 60).rounded(.up)))
    }

    /// 大きな数字とその単位の組（「70」＋「分」／「1」＋「時間」・「10」＋「分」）
    struct DurationPart: Identifiable, Equatable {
        let value: String
        let unit: String
        var id: String { unit }
    }

    /// 残り時間を「数字」と「単位」に分ける。
    /// 数字だけを28ptで、単位を15ptで組むために分けて返す
    static func durationParts(_ remaining: TimeInterval) -> [DurationPart] {
        let total = minutes(remaining)
        let hourUnit = NSLocalizedString("時間", comment: "「今日」ペインの大きな数字の単位")
        let minuteUnit = NSLocalizedString("分", comment: "「今日」ペインの大きな数字の単位")
        guard total >= 60 else { return [DurationPart(value: "\(total)", unit: minuteUnit)] }

        let hours = total / 60
        let rest = total % 60
        let hourPart = DurationPart(value: "\(hours)", unit: hourUnit)
        if rest == 0 { return [hourPart] }
        return [hourPart, DurationPart(value: "\(rest)", unit: minuteUnit)]
    }

    /// 「7分」／「1時間20分」（読み上げと1行の文の中で使う）
    static func durationText(_ remaining: TimeInterval) -> String {
        durationParts(remaining).map { $0.value + $0.unit }.joined()
    }
}
