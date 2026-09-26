import Combine
import Foundation
import SwiftUI

/// バス時刻表ViewModel
@MainActor
final class BusScheduleViewModel: ObservableObject {

    // MARK: - 公開プロパティ

    @Published var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @Published var selectedRouteType: BusSchedule.RouteType = .fromSeisekiToSchool

    /// ページの「今」（分の境目ちょうどに進む）。
    ///
    /// 次のバス・強調する行・選んだ便の発車判定はどれも分単位なので、ここは1分に1回だけ進める。
    /// 秒単位のカウントダウンは時刻カードが自分の `TimelineView` で描くため、
    /// 毎秒ページ全体（2列表示では2つの時刻表）を描き直すことはない
    @Published var currentTime = Date()
    /// 表を次のバスの時間までスクロールし直してほしいときに増やす番号。
    ///
    /// 表は次のバスの時間が変わったときだけ自分でスクロールする（毎分の時計では動かさない）ので、
    /// 開いたとき・路線や駅や曜日を変えたとき・フォアグラウンドに戻ったときは、ここで明示的に頼む
    @Published private(set) var scrollRequestID = 0
    @Published var selectedTimeEntry: BusSchedule.TimeEntry?

    /// 利用者が時刻表の便を押した回数（選択・解除のどちらも数える）。
    ///
    /// 触覚のきっかけにだけ使う。`selectedTimeEntry` を見張ると、発車による自動解除や
    /// 起動時の選択の復元のように利用者が触っていない変化でも鳴り、
    /// 2列表示では左右の表が同時に鳴ってしまうため、押したときだけ増やすこの番号を見る
    @Published private(set) var timeEntryTapCount = 0
    @Published var busSchedule: BusSchedule?
    @Published var errorMessage: String?
    @Published var userInSchoolArea: Bool = false

    /// 2列表示（Duoの内側ディスプレイ・横向き）で左右に出している駅。
    /// 左の列がこの駅の「駅発」、右の列が同じ駅の「駅行」になる。
    /// 初期値は利用者が最後に自分で選んだ駅（`BusSelectionStore`）
    @Published var selectedStation: BusStation = .seiseki

    /// 選んだ便がどちらの路線のものか（未選択なら nil）。
    ///
    /// 1列表示でも2列表示でも、表とカードはこの路線まで見て選択を出す。
    /// 2列表示では同じ「分」が両方の列にあり得るので、どちらの列で押したのかをここで区別する
    @Published var selectedEntryRoute: BusSchedule.RouteType?

    /// いま2列表示かどうか（ページが自分の大きさから判定して渡す）。
    ///
    /// 2列表示では両方向を同時に出しているので、現在地による路線の自動切り替えには
    /// 切り替えるものが無い。駅セレクタと取り合いにならないよう、その間は自動切り替えを止め、
    /// 1列に戻ったときに、止めている間に届いた現在地の変化を当て直す
    var isTwoPaneLayout: Bool = false {
        didSet {
            guard oldValue, !isTwoPaneLayout, hasPendingPresenceUpdate else { return }
            hasPendingPresenceUpdate = false
            updateRouteBasedOnLocation()
        }
    }

    // MARK: - プライベートプロパティ

    /// 分の境目ごとに `currentTime` を進めるタスク
    private var clockTask: Task<Void, Never>?
    private let busScheduleService = BusScheduleService.shared

    // 位置情報関連（判定は CampusPresenceService が一箇所で持つ）
    fileprivate var presenceCancellable: AnyCancellable?

    /// 2列表示の間に届いて、路線の切り替えを見送った現在地の変化があるか
    fileprivate var hasPendingPresenceUpdate = false

    // 通知オブザーバー
    private var willEnterForegroundObserver: NSObjectProtocol?
    fileprivate var busParametersObserver: NSObjectProtocol?

    // MARK: - 日付フォーマッター

    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    // MARK: - 時計

    /// 実時間からのずれ（秒）。
    /// DEBUGビルドで `-DuoBusNowOverride HH:mm` が指定されたときだけ0以外になる
    static var clockOffset: TimeInterval {
        #if DEBUG
        return DuoDebugBus.nowOffset
        #else
        return 0
        #endif
    }

    /// バスページの「今」
    static func now() -> Date {
        pageTime(from: Date())
    }

    /// 実時間（`TimelineView` の日付など）をバスページの「今」に直す
    static func pageTime(from realDate: Date) -> Date {
        let offset = clockOffset
        return offset == 0 ? realDate : realDate.addingTimeInterval(offset)
    }

    /// ページの時計で次の「秒の境目」にあたる実時間。
    /// 時刻カードの `TimelineView` をここから1秒刻みにすると、表示は秒の境目ちょうどで進む
    static func nextSecondBoundary() -> Date {
        let pageNow = now().timeIntervalSinceReferenceDate
        let boundary = Date(timeIntervalSinceReferenceDate: pageNow.rounded(.down) + 1)
        return boundary.addingTimeInterval(-clockOffset)
    }

    /// ページの時計で次の「分の境目」までの秒数
    private static func secondsUntilNextMinute() -> TimeInterval {
        let pageNow = now()
        let next = Calendar.current.nextDate(
            after: pageNow, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? pageNow.addingTimeInterval(60)
        return max(next.timeIntervalSince(pageNow), 0)
    }

    // MARK: - データ取得

    func fetchBusScheduleData() {
        busScheduleService.fetchBusScheduleData { [weak self] schedule, error in
            guard let self = self else { return }
            if let schedule = schedule {
                // キャッシュまたはAPI成功時：データを更新してエラーをクリア
                self.busSchedule = schedule
                self.errorMessage = nil
            } else if let error = error {
                // API失敗かつキャッシュが12時間を超えている場合のみエラー表示
                print("BusScheduleViewModel: エラー - \(error.localizedDescription)")
                if self.busSchedule == nil {
                    self.errorMessage = NSLocalizedString(
                        "時刻表の読み込みに失敗しました。\nネットワーク接続を確認してください。", comment: "")
                }
            }
        }
    }

    // MARK: - セットアップとクリーンアップ

    func setupOnAppear() {
        currentTime = Self.now()
        // 2列表示で左右に出す駅は、利用者が最後に自分で選んだ駅から始める
        selectedStation = BusSelectionStore.shared.preferredStation
        #if DEBUG
        if let overridden = DuoDebugBus.station {
            selectedStation = overridden
        }
        #endif
        fetchBusScheduleData()
        setupLocationManager()
        startClock()
        checkIfWeekday()
        restoreSelectionIfNeeded()
        requestScrollToNextBus()
        setupBusParametersObserver()

        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = Self.now()
                self.checkIfSelectedTimePassed()
                self.requestScrollToNextBus()
                self.fetchBusScheduleData()
                // バックグラウンドの間に分の境目がずれるので、次の境目から数え直す
                self.startClock()
            }
        }
    }

    func cleanupOnDisappear() {
        cleanupTimers()
        removeObservers()
    }

    /// 分の境目ちょうどに `currentTime` を進める。
    ///
    /// 60秒ごとの `Timer` は起動した時刻からの60秒になってしまい、表示が分の境目から最大1分ずれる。
    /// ここでは毎回「次の分の境目」までを数え直して待つので、ずれが積み重ならない
    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.secondsUntilNextMinute()))
                guard !Task.isCancelled else { return }
                self?.advanceClock()
            }
        }
    }

    private func advanceClock() {
        currentTime = Self.now()
        checkIfSelectedTimePassed()
    }

    private func cleanupTimers() {
        clockTask?.cancel()
        clockTask = nil

        presenceCancellable?.cancel()
        presenceCancellable = nil
        CampusPresenceService.shared.stop()

        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            willEnterForegroundObserver = nil
        }
    }

    private func removeObservers() {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = busParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - スケジュールロジック

    func checkIfWeekday() {
        #if DEBUG
        if let overridden = DuoDebugBus.scheduleTypeOverride {
            selectedScheduleType = overridden
            return
        }
        #endif
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Self.now())
        if weekday == 4 {
            selectedScheduleType = .wednesday
        } else if weekday == 7 {
            selectedScheduleType = .saturday
        } else {
            selectedScheduleType = .weekday
        }
    }

    /// 表に次のバスの時間までスクロールし直してもらう（次のバスの時間が変わっていなくても動かす）
    func requestScrollToNextBus() {
        scrollRequestID &+= 1
    }

    func getFilteredSchedule() -> BusSchedule.DaySchedule {
        getFilteredSchedule(for: selectedRouteType)
    }

    /// 指定した路線の時刻表（曜日の種類は共通）。
    /// 2列表示は左右それぞれの路線でこれを呼ぶ
    func getFilteredSchedule(for route: BusSchedule.RouteType) -> BusSchedule.DaySchedule {
        guard let busSchedule = busSchedule else {
            return BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool, scheduleType: selectedScheduleType,
                hourSchedules: [])
        }

        let schedules: [BusSchedule.DaySchedule]
        switch selectedScheduleType {
        case .weekday:
            schedules = busSchedule.weekdaySchedules
        case .saturday:
            schedules = busSchedule.saturdaySchedules
        case .wednesday:
            schedules = busSchedule.wednesdaySchedules
        }

        if let schedule = schedules.first(where: { $0.routeType == route }) {
            return schedule
        }

        return schedules.first
            ?? BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: selectedScheduleType,
                hourSchedules: []
            )
    }

    func isTimeEqual(_ timeEntry: BusSchedule.TimeEntry, to date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return false
        }
        return timeEntry.hour == hour && timeEntry.minute == minute
    }

    /// その列に出している選択（別の路線で選ばれた便はその列・その路線の表には出さない）
    func selectedEntry(on route: BusSchedule.RouteType) -> BusSchedule.TimeEntry? {
        selectedEntryRoute == route ? selectedTimeEntry : nil
    }

    /// その便が選ばれているかどうか（路線まで見る）
    func isSelected(_ time: BusSchedule.TimeEntry, on route: BusSchedule.RouteType) -> Bool {
        selectedEntryRoute == route && selectedTimeEntry == time
    }

    /// その路線の時刻表を開いたときに見せたい時間（次のバスの時間。無ければ現在の時間）
    func scrollHour(for route: BusSchedule.RouteType) -> Int? {
        if let nextBus = getNextBus(for: route) {
            return nextBus.hour
        }
        return Calendar.current.dateComponents([.hour], from: currentTime).hour
    }

    func getNextBus() -> BusSchedule.TimeEntry? {
        getNextBus(for: selectedRouteType)
    }

    /// 指定した路線の次のバス（ページの「今」＝分単位の時計で見る）
    func getNextBus(for route: BusSchedule.RouteType) -> BusSchedule.TimeEntry? {
        getNextBus(for: route, at: currentTime)
    }

    /// 指定した路線の、ある時刻から見た次のバス。
    /// 時刻カードは自分の `TimelineView` の時刻でこれを呼び、カウントダウンと食い違わないようにする
    func getNextBus(for route: BusSchedule.RouteType, at date: Date) -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return nil
        }

        let schedule = getFilteredSchedule(for: route)

        if let currentHourSchedule = schedule.hourSchedules.first(where: { $0.hour == currentHour }),
            let nextBus = currentHourSchedule.times.first(where: { $0.minute > currentMinute }) {
            return nextBus
        }

        if currentHour < 23 {
            for hour in (currentHour + 1)...23 {
                if let hourSchedule = schedule.hourSchedules.first(where: { $0.hour == hour }),
                    let firstBus = hourSchedule.times.first {
                    return firstBus
                }
            }
        }

        return nil
    }

    private func checkIfSelectedTimePassed() {
        guard let selectedTime = selectedTimeEntry else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return
        }

        if (selectedTime.hour < currentHour)
            || (selectedTime.hour == currentHour && selectedTime.minute <= currentMinute) {
            BusLiveActivityService.shared.endActivity()
            BusSelectionStore.shared.clear()
            withMotion(Motion.quick) {
                selectedTimeEntry = nil
                selectedEntryRoute = nil
            }
        }
    }

    // MARK: - 時間エントリー操作

    /// 時刻表の便を押したとき。
    ///
    /// 選択はアプリ全体で1つ（ライブアクティビティも1つ）なので、2列表示でどちらの列を押しても
    /// ここへ来る。どの列で押したのかは `route` で区別し、同じ便をもう一度押したときだけ解除する
    func handleTimeEntryTap(_ time: BusSchedule.TimeEntry, on route: BusSchedule.RouteType) {
        timeEntryTapCount &+= 1
        if selectedTimeEntry == time && selectedEntryRoute == route {
            BusLiveActivityService.shared.endActivity()
            BusSelectionStore.shared.clear()
            withMotion(Motion.quick) {
                selectedTimeEntry = nil
                selectedEntryRoute = nil
            }
        } else {
            BusLiveActivityService.shared.startActivity(
                timeEntry: time,
                routeType: route
            )
            // 時間割タブの「今日」ペインからも同じ便を数えられるよう、選択を共有しておく
            BusSelectionStore.shared.select(
                entry: time, route: route, now: Self.now())
            // カードの「バス時刻」の行は、この変更に乗って `motionTransition(.rise)` で持ち上がる
            withMotion(Motion.quick) {
                selectedTimeEntry = time
                selectedEntryRoute = route
            }
        }
    }

    /// 表の余白などを押して選択を外したとき。
    /// 何も選んでいなければ、共有の選択やライブアクティビティには触らない
    func clearSelection() {
        guard selectedTimeEntry != nil else { return }
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        withMotion(Motion.quick) {
            selectedTimeEntry = nil
            selectedEntryRoute = nil
        }
    }

    /// 前回選んだ便を、共有の選択（`BusSelectionStore`）から戻す。
    ///
    /// 画面を作り直したり、アプリを起動し直したりしても、まだ発車していない便なら選んだままにする
    /// （ライブアクティビティは選んだときに始めたものがそのまま続いている）
    private func restoreSelectionIfNeeded() {
        guard selectedTimeEntry == nil,
              let departure = BusSelectionStore.shared.selectedDeparture,
              Calendar.current.isDate(departure.date, inSameDayAs: currentTime),
              departure.date > currentTime
        else {
            return
        }
        selectedRouteType = departure.route
        selectedStation = BusStation.station(of: departure.route)
        selectedTimeEntry = departure.entry
        selectedEntryRoute = departure.route
    }

    /// 利用者が曜日セレクタを押したとき（プログラムからの変更では呼ばない）
    func onScheduleTypeChanged() {
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        selectedTimeEntry = nil
        selectedEntryRoute = nil
        requestScrollToNextBus()
    }

    /// 利用者が2列表示の駅セレクタを押したとき（ディープリンクなどプログラムからの変更では呼ばない）。
    ///
    /// 自分で選んだ駅なので、路線チップと同じように「その学生が使う駅」として覚える。
    /// 1列に戻ったときに同じ駅の時刻表が出るよう、選択中の路線もその駅の駅発に合わせる
    func onStationChanged() {
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        BusSelectionStore.shared.recordUserSelectedRoute(selectedStation.toSchoolRoute)
        selectedRouteType = selectedStation.toSchoolRoute
        selectedTimeEntry = nil
        selectedEntryRoute = nil
        requestScrollToNextBus()
    }

    /// 利用者が路線チップを押したとき。
    /// 自分で選んだ路線なので、「今日」ペインが使う駅もここで覚える
    /// （現在地による自動切り替え `updateRouteBasedOnLocation` からは呼ばない）
    func onRouteTypeChanged() {
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        BusSelectionStore.shared.recordUserSelectedRoute(selectedRouteType)
        selectedStation = BusStation.station(of: selectedRouteType)
        selectedTimeEntry = nil
        selectedEntryRoute = nil
        requestScrollToNextBus()
    }
}

// MARK: - カウントダウン

extension BusScheduleViewModel {

    /// 次のバス（または選んだ便）までの残り時間の表示（"12分34秒" / "1時間2分3秒"）。
    /// 時刻カードは `TimelineView` の時刻を `now` に渡し、秒の境目ちょうどで描き直す
    func getCountdownText(to nextBus: BusSchedule.TimeEntry, now: Date) -> String {
        let calendar = Calendar.current

        var nextBusDateComponents = calendar.dateComponents(
            [.year, .month, .day], from: now)
        nextBusDateComponents.hour = nextBus.hour
        nextBusDateComponents.minute = nextBus.minute
        nextBusDateComponents.second = 0

        guard let nextBusDate = calendar.date(from: nextBusDateComponents) else {
            return ""
        }

        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        if let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute,
            currentHour == nextBus.hour && currentMinute == nextBus.minute {
            return NSLocalizedString("0分0秒", comment: "")
        }

        if nextBusDate < now {
            guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nextBusDate) else {
                return ""
            }
            return formatTimeDifference(from: now, to: tomorrowDate)
        } else {
            return formatTimeDifference(from: now, to: nextBusDate)
        }
    }

    private func formatTimeDifference(from: Date, to: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: from, to: to)

        guard let hour = components.hour, let minute = components.minute,
              let second = components.second
        else {
            return ""
        }

        if hour > 0 {
            return String(
                format: NSLocalizedString(
                    "%d時間%d分%d秒", comment: "バスのカウントダウン（時間・分・秒）"),
                hour, minute, second)
        }
        return String(
            format: NSLocalizedString("%d分%d秒", comment: "バスのカウントダウン（分・秒）"),
            minute, second)
    }
}

// MARK: - 位置情報関連

extension BusScheduleViewModel {

    /// 学内かどうかの判定を購読する。
    ///
    /// ジオフェンスと `CLLocationManager` は `CampusPresenceService` が一箇所で持っており、
    /// 時間割タブの「今日」ペインも同じ判定を使う。
    /// ここでの振る舞い（学内なら学校発の路線へ、学外なら駅発の路線へ切り替える）は以前のまま
    func setupLocationManager() {
        CampusPresenceService.shared.start()
        presenceCancellable = CampusPresenceService.shared.$isOnCampus
            .sink { [weak self] isOnCampus in
                Task { @MainActor in
                    self?.applyPresence(isOnCampus)
                }
            }
    }

    fileprivate func applyPresence(_ isOnCampus: Bool?) {
        guard let isOnCampus, isOnCampus != userInSchoolArea else { return }
        userInSchoolArea = isOnCampus
        updateRouteBasedOnLocation()
    }

    fileprivate func updateRouteBasedOnLocation() {
        // 2列表示では駅発・駅行の両方を同時に出しているため、切り替えるものが無い。
        // 駅セレクタと取り合いにならないよう、ここでは覚えておくだけにして、1列に戻ったときに当て直す
        guard !isTwoPaneLayout else {
            hasPendingPresenceUpdate = true
            return
        }

        if userInSchoolArea {
            let isAlreadySchoolDeparture =
                selectedRouteType == .fromSchoolToSeiseki
                || selectedRouteType == .fromSchoolToNagayama
            if !isAlreadySchoolDeparture {
                withMotion(Motion.standard) {
                    selectedRouteType = .fromSchoolToNagayama
                    requestScrollToNextBus()
                }
            }
        } else {
            let isAlreadyStationDeparture =
                selectedRouteType == .fromSeisekiToSchool
                || selectedRouteType == .fromNagayamaToSchool
            if !isAlreadyStationDeparture {
                withMotion(Motion.standard) {
                    selectedRouteType = .fromSeisekiToSchool
                    requestScrollToNextBus()
                }
            }
        }
    }
}

// MARK: - URLスキーム処理

extension BusScheduleViewModel {

    fileprivate func setupBusParametersObserver() {
        if let observer = busParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        busParametersObserver = NotificationCenter.default.addObserver(
            forName: .busParametersFromURL,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let routeString = userInfo?["route"] as? String
            let scheduleString = userInfo?["schedule"] as? String
            Task { @MainActor in
                self?.applyDeepLink(route: routeString, schedule: scheduleString)
            }
        }
    }

    /// `tama://bus?route=&schedule=` の指定を当てる。
    ///
    /// 駅や曜日はプロパティへ直接入れるだけで、セレクタを押したときの後始末
    /// （ライブアクティビティの終了・共有の選択の解除）は走らない
    private func applyDeepLink(route routeString: String?, schedule scheduleString: String?) {
        if let routeString {
            if let route = BusSchedule.RouteType(deepLinkValue: routeString) {
                selectedRouteType = route
            }
            // ディープリンクで指定された路線も、利用者が自分で選んだものとして扱う
            BusSelectionStore.shared.recordUserSelectedRoute(selectedRouteType)
            // 2列表示では路線チップが無いため、その路線の駅を選んだ状態にする
            // （左＝その駅の駅発、右＝その駅の駅行）
            selectedStation = BusStation.station(of: selectedRouteType)
        }

        if let scheduleString {
            switch scheduleString {
            case "weekday":
                selectedScheduleType = .weekday
            case "saturday":
                selectedScheduleType = .saturday
            case "wednesday":
                selectedScheduleType = .wednesday
            default:
                break
            }
        }
        requestScrollToNextBus()
    }
}

// MARK: - ディープリンクの路線名

private extension BusSchedule.RouteType {

    /// `tama://bus?route=` の値から路線を求める
    init?(deepLinkValue: String) {
        switch deepLinkValue {
        case "fromSeisekiToSchool": self = .fromSeisekiToSchool
        case "fromNagayamaToSchool": self = .fromNagayamaToSchool
        case "fromSchoolToSeiseki": self = .fromSchoolToSeiseki
        case "fromSchoolToNagayama": self = .fromSchoolToNagayama
        default: return nil
        }
    }
}
