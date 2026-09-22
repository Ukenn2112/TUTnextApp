import Foundation

// MARK: - 通学の定数

/// 「今日」ペインが通学の案内に使う定数（値の出どころをここ一箇所にまとめる）
enum CommuteRule {

    /// 授業開始の何分前までに学校へ着いていたいか。
    /// 「授業の10分前には教室へ向かう」という案内と揃えてある
    static let arrivalMarginMinutes = 10

    /// 教室へ向かう案内を始める時刻（授業開始の何分前か）。
    /// Live Activity の `LiveActivityScheduler.computeTransitions` と同じ考え方にしてある
    static let headToRoomMinutes = 10

    /// 学校に居るときに、その日の最初の授業の案内を始める時刻（開始の何分前か）
    static let firstLessonHeadStartMinutes = 30

    /// 授業と授業の間がこれ以下なら、休み時間を挟まず次の授業の案内に切り替える（分）
    static let shortBreakMinutes = 10
}

// MARK: - 今日のバス時刻表

/// その日に使える便の一覧（路線ごと）。
///
/// 12時間より古いキャッシュしか無いとき `BusScheduleService` はダミーの時刻を返すので、
/// 呼び出し側は `isCacheValid()` を見て、無効なら `nil` を渡すこと（＝バスの案内を出さない）
struct BusSnapshot {

    /// その曜日の時刻表（日曜・データ無しのときは空）
    let daySchedules: [BusSchedule.DaySchedule]

    /// 時刻を当てはめる日
    let referenceDate: Date

    private let calendar: Calendar

    init(
        daySchedules: [BusSchedule.DaySchedule],
        referenceDate: Date,
        calendar: Calendar = .current
    ) {
        self.daySchedules = daySchedules
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    /// 便がまったく無い（日曜・データ無し）
    var isEmpty: Bool { daySchedules.isEmpty }

    /// その日の時刻表から `BusSnapshot` を作る。
    /// - Parameters:
    ///   - schedule: 有効なキャッシュから読んだ時刻表（無効なら nil を渡す）
    ///   - weekday: `Calendar.component(.weekday)` の値（1＝日曜）
    static func make(
        schedule: BusSchedule?,
        weekday: Int,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> BusSnapshot {
        guard let schedule, let type = scheduleType(forWeekday: weekday) else {
            return BusSnapshot(daySchedules: [], referenceDate: referenceDate, calendar: calendar)
        }

        let schedules: [BusSchedule.DaySchedule]
        switch type {
        case .weekday: schedules = schedule.weekdaySchedules
        case .wednesday: schedules = schedule.wednesdaySchedules
        case .saturday: schedules = schedule.saturdaySchedules
        }
        return BusSnapshot(
            daySchedules: schedules, referenceDate: referenceDate, calendar: calendar)
    }

    /// 曜日から時刻表の種類を決める。日曜は運行が無いので nil を返す。
    ///
    /// バスタブ（`BusScheduleViewModel.checkIfWeekday`）は日曜を平日として扱ってしまうが、
    /// 時刻表の種類に日曜が無いため一行では直せない。ここでは案内を出さない側に倒す
    static func scheduleType(forWeekday weekday: Int) -> BusSchedule.ScheduleType? {
        switch weekday {
        case 1: return nil  // 日曜は運行なし
        case 4: return .wednesday
        case 7: return .saturday
        default: return .weekday
        }
    }

    /// その路線の、大学生が乗れる便を時刻順に並べて返す
    func departures(route: BusSchedule.RouteType) -> [BusDeparture] {
        guard let schedule = daySchedules.first(where: { $0.routeType == route }) else { return [] }
        return schedule.hourSchedules
            .flatMap { $0.times }
            .filter { $0.isAvailableToUniversityStudent }
            .compactMap { entry in
                guard let date = calendar.date(
                    bySettingHour: entry.hour, minute: entry.minute, second: 0, of: referenceDate)
                else {
                    return nil
                }
                return BusDeparture(route: route, entry: entry, date: date)
            }
            .sorted { $0.date < $1.date }
    }

    /// その路線の、指定時刻より後の最初の便
    func nextDeparture(route: BusSchedule.RouteType, after now: Date) -> BusDeparture? {
        departures(route: route).first { $0.date > now }
    }
}

// MARK: - 案内する便

/// バスのタイルの1本目に出す便と、その後ろに続く便。
///
/// 便が無いときの文言は `TodayPaneState.hasSchedule` から決めるので、
/// ここには「案内できる便がある」ときの情報だけを持たせる
struct BusPlan: Equatable {

    /// 1本目の便（いま乗るべき便）
    let departure: BusDeparture

    /// バスタブで利用者自身が選んだ便かどうか
    let isSelected: Bool

    /// 間に合う便かどうか（帰りの便では常に true）
    let makesIt: Bool

    /// この便で間に合わせたい授業（帰りの便では nil）
    let targetClass: TodayClass?

    /// この便のあとに続く同じ路線の便
    var following: [BusDeparture] = []

    /// もう一方の駅の、同じ向きの便（時刻順に混ぜて一覧に出す）
    var otherFollowing: [BusDeparture] = []
}

// MARK: - 1日の場面

/// 「今日」ペインが今どの場面を映しているか。
///
/// 朝（どのバスに乗る）→ 教室へ → 授業中 → 休み時間 → 放課後（どのバスで帰る）と、
/// 1日の流れをそのまま追う。判定は時刻と、分かっていれば学内かどうかだけで決まる。
///
/// 「乗車中」の場面は持たない。所要時間はあくまで目安なので、
/// 「あと何分で着く」と言い切るのは作り話になってしまう。
/// 間に合う便が出てしまったあとは通学の話をやめ、最初の授業の案内に切り替える
enum TodayPhase: Equatable {

    /// 出発前（最初の授業に間に合う便を案内する）
    case beforeDeparture(BusPlan)

    /// 教室へ向かう時間
    case headToRoom(TodayClass)

    /// 授業中
    case inClass(TodayClass)

    /// 休み時間（次の授業まで10分より長く空いている）
    case breakTime(next: TodayClass)

    /// 放課後（帰りの便を案内できるならその便）
    case afterSchool(BusPlan?)

    /// 今日は授業が無い
    case noClasses(BusPlan?)
}

// MARK: - ペインの状態

/// 場面と、バスのタイルが使う便をまとめたもの（表示側はこれだけを見る）
struct TodayPaneState: Equatable {

    /// いま映している場面（授業のタイルになる）
    let phase: TodayPhase

    /// 帰りの便。授業中・休み時間は「最後の授業のあとの便」、
    /// 放課後は「いまより後の最初の便」を指す（自分で選んだ帰りの便があればそちら）
    let homeBus: BusPlan?

    /// 間に合う便がもう無いときの、次の学校行きの便。
    /// 「遅刻の可能性」を添えてバスのタイルに出す
    let lateBus: BusPlan?

    /// その学生が使う駅（便が1本も無いときの行き先を決めるのに使う）
    let station: BusStation

    /// 今日の時刻表そのものが手元にあるか。
    /// 「運行が終わった」と「そもそも時刻表が無い（日曜・控えが古い）」を言い分けるために使う
    let hasSchedule: Bool
}

// MARK: - 入力

/// 場面を決めるための入力（すべて値で渡すので、そのままテストできる）
struct TodayPaneInput {

    /// 「今」（DEBUGの時刻差し替えを通した後の値）
    let now: Date

    /// 今日の授業（時限順）
    let classes: [TodayClass]

    /// 今日のバス時刻表
    let bus: BusSnapshot

    /// その学生が使う駅
    let station: BusStation

    /// バスタブで選んでいる便
    let selection: BusDeparture?

    /// 学内に居るか（nil＝分からない／位置情報が許可されていない）
    let isOnCampus: Bool?

    /// 今日、自分で選んだ学校行きの便がもう発車したか。
    /// 発車したあとに「次はこの便に乗れば間に合います」と勧めるのは、
    /// すでに乗っている人には的外れなので、通学の案内そのものをやめる合図に使う
    var hasDepartedTowardSchool = false
}

// MARK: - 場面を決める

/// 入力から場面を決める純粋な計算（表示を持たない）
enum TodayPhaseEngine {

    // MARK: - 入口

    static func state(for input: TodayPaneInput) -> TodayPaneState {
        let phase = resolvePhase(input)
        return TodayPaneState(
            phase: phase,
            homeBus: homeBus(input),
            lateBus: lateBus(input: input),
            station: input.station,
            hasSchedule: !input.bus.isEmpty)
    }

    // MARK: - 場面

    private static func resolvePhase(_ input: TodayPaneInput) -> TodayPhase {
        let classes = input.classes
        let now = input.now

        if let current = classes.first(where: { $0.start <= now && now <= $0.end }) {
            return .inClass(current)
        }

        if let index = classes.firstIndex(where: { $0.start > now }) {
            let next = classes[index]

            // その日の最初の授業の前だけ、通学（バス）の案内を出す
            if index == 0, input.isOnCampus != true,
               let commuting = commutePhase(input, firstLesson: next) {
                return commuting
            }

            if now >= headToRoomStart(for: next, at: index, in: classes, isOnCampus: input.isOnCampus) {
                return .headToRoom(next)
            }
            return .breakTime(next: next)
        }

        if classes.isEmpty {
            return .noClasses(selectedPlan(input))
        }
        return .afterSchool(afterSchoolBus(input))
    }

    /// 教室へ向かう案内を始める時刻
    private static func headToRoomStart(
        for lesson: TodayClass, at index: Int, in classes: [TodayClass], isOnCampus: Bool?
    ) -> Date {
        if index == 0 {
            let minutes = isOnCampus == true
                ? CommuteRule.firstLessonHeadStartMinutes
                : CommuteRule.headToRoomMinutes
            return lesson.start.addingTimeInterval(TimeInterval(-minutes * 60))
        }

        let previousEnd = classes[index - 1].end
        let gap = lesson.start.timeIntervalSince(previousEnd)
        if gap <= TimeInterval(CommuteRule.shortBreakMinutes * 60) {
            // 続けて次の授業がある場合は、前の授業が終わった時点で切り替える
            return previousEnd
        }
        return lesson.start.addingTimeInterval(TimeInterval(-CommuteRule.headToRoomMinutes * 60))
    }

    // MARK: - 朝のバス

    /// 出発前の案内を返す。
    ///
    /// 間に合う便が1本も残っていない（＝勧められる便が無い）ときは nil を返し、
    /// 最初の授業の案内（`headToRoom` / `breakTime`）に任せる。
    /// 自分で選んだ便がもう発車しているときも、通学の話は終わったものとして nil を返す
    private static func commutePhase(
        _ input: TodayPaneInput, firstLesson: TodayClass
    ) -> TodayPhase? {
        guard !input.hasDepartedTowardSchool else { return nil }
        let now = input.now

        // バスタブで選んだ便があれば、それを最優先で案内する
        if let selection = input.selection, selection.route.isTowardSchool, selection.date > now {
            let station = BusStation.station(of: selection.route)
            let arrival = selection.arrival(rideMinutes: station.rideMinutes)
            return .beforeDeparture(
                BusPlan(
                    departure: selection,
                    isSelected: true,
                    makesIt: arrival <= deadline(for: firstLesson),
                    targetClass: firstLesson,
                    following: following(input, after: selection),
                    otherFollowing: otherFollowing(input, after: selection)
                )
            )
        }

        let station = input.station
        let ride = station.rideMinutes
        let departures = input.bus.departures(route: station.toSchoolRoute)
        guard !departures.isEmpty else { return nil }

        let limit = deadline(for: firstLesson)
        let future = departures.filter { $0.date >= now }
        let onTime = future.filter { $0.arrival(rideMinutes: ride) <= limit }

        // 間に合う便がもう無いなら通学の案内は出さない（一覧の `lateBus` に任せる）
        guard let recommended = onTime.last else { return nil }

        return .beforeDeparture(
            BusPlan(
                departure: recommended,
                isSelected: false,
                makesIt: true,
                targetClass: firstLesson,
                following: following(input, after: recommended),
                otherFollowing: otherFollowing(input, after: recommended)
            )
        )
    }

    /// その便のあとに続く同じ路線の便（表示側が入るだけ並べるので多めに渡す）
    private static func following(
        _ input: TodayPaneInput, after departure: BusDeparture, limit: Int = 6
    ) -> [BusDeparture] {
        Array(
            input.bus.departures(route: departure.route)
                .filter { $0.date > departure.date }
                .prefix(limit))
    }

    /// もう一方の駅の、同じ向きの便（一覧に時刻順で混ぜる）
    private static func otherFollowing(
        _ input: TodayPaneInput, after departure: BusDeparture, limit: Int = 6
    ) -> [BusDeparture] {
        let station = BusStation.station(of: departure.route).other
        let route = departure.route.isTowardSchool
            ? station.toSchoolRoute : station.fromSchoolRoute
        return Array(
            input.bus.departures(route: route)
                .filter { $0.date > departure.date }
                .prefix(limit))
    }

    // MARK: - 遅刻しうる便

    /// 間に合う便がもう無いときに、一覧へ1行だけ出す次の学校行きの便。
    ///
    /// 学内に居ると分かっている・もう発車した便に乗っている・まだ間に合う便が残っている、
    /// のいずれかなら出さない（すでに大学に居る人に「遅刻の可能性」と言わない）
    private static func lateBus(input: TodayPaneInput) -> BusPlan? {
        guard input.isOnCampus != true, !input.hasDepartedTowardSchool else { return nil }
        guard let first = input.classes.first, first.start > input.now else { return nil }

        let station = input.station
        let ride = station.rideMinutes
        let limit = deadline(for: first)
        let future = input.bus.departures(route: station.toSchoolRoute)
            .filter { $0.date >= input.now }

        guard !future.contains(where: { $0.arrival(rideMinutes: ride) <= limit }),
              let next = future.first
        else {
            return nil
        }

        return BusPlan(
            departure: next,
            isSelected: false,
            makesIt: false,
            targetClass: first,
            following: following(input, after: next),
            otherFollowing: otherFollowing(input, after: next)
        )
    }

    /// その授業に間に合うために、学校へ着いていたい時刻
    private static func deadline(for lesson: TodayClass) -> Date {
        lesson.start.addingTimeInterval(TimeInterval(-CommuteRule.arrivalMarginMinutes * 60))
    }

    // MARK: - 帰りのバス

    /// 放課後に案内する帰りの便（勧められる便が無ければ nil）
    private static func afterSchoolBus(_ input: TodayPaneInput) -> BusPlan? {
        if let plan = selectedPlan(input, towardSchool: false) { return plan }

        // 学校に居ないと分かっているなら、帰りのバスは勧めない
        guard input.isOnCampus != false else { return nil }

        let station = input.station
        guard let next = input.bus.nextDeparture(route: station.fromSchoolRoute, after: input.now)
        else {
            return nil
        }

        return BusPlan(
            departure: next,
            isSelected: false,
            makesIt: true,
            targetClass: nil,
            following: following(input, after: next),
            otherFollowing: otherFollowing(input, after: next)
        )
    }

    /// バスタブで選んだ便だけを案内する（授業が無い日など）
    private static func selectedPlan(
        _ input: TodayPaneInput, towardSchool: Bool? = nil
    ) -> BusPlan? {
        guard let selection = input.selection, selection.date > input.now else { return nil }
        if let towardSchool, selection.route.isTowardSchool != towardSchool { return nil }

        return BusPlan(
            departure: selection,
            isSelected: true,
            makesIt: true,
            targetClass: nil,
            following: following(input, after: selection),
            otherFollowing: otherFollowing(input, after: selection)
        )
    }

    // MARK: - 帰りの便

    /// 帰りの便（バスのタイルが授業中・休み時間・放課後に出す便）。
    ///
    /// 自分で選んだ帰りの便があればそれを、無ければ「最後の授業が終わったあと」の最初の便を返す。
    /// 授業がもう終わっている（または今日は授業が無い）ときは、いまより後の最初の便になる
    private static func homeBus(_ input: TodayPaneInput) -> BusPlan? {
        if let selected = selectedPlan(input, towardSchool: false) { return selected }

        let station = input.station
        let anchor = max(input.now, input.classes.last?.end ?? input.now)
        // 最後の授業のあとに便が無いときは、いまより後の便を案内する
        // （「運行は終了しました」と言い切ると、まだ走っている時間帯に嘘になる）
        guard let next = input.bus.nextDeparture(route: station.fromSchoolRoute, after: anchor)
            ?? input.bus.nextDeparture(route: station.fromSchoolRoute, after: input.now)
        else {
            return nil
        }

        return BusPlan(
            departure: next,
            isSelected: false,
            makesIt: true,
            targetClass: nil,
            following: following(input, after: next),
            otherFollowing: otherFollowing(input, after: next)
        )
    }
}
