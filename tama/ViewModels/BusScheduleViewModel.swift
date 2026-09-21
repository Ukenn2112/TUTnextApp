import Combine
import Foundation
import SwiftUI

/// バス時刻表ViewModel
@MainActor
final class BusScheduleViewModel: ObservableObject {

    // MARK: - 公開プロパティ

    @Published var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @Published var selectedRouteType: BusSchedule.RouteType = .fromSeisekiToSchool
    @Published var currentTime = Date()
    @Published var scrollToHour: Int?
    @Published var selectedTimeEntry: BusSchedule.TimeEntry?
    @Published var cardInfoAppeared: Bool = false
    @Published var busSchedule: BusSchedule?
    @Published var errorMessage: String?
    @Published var userInSchoolArea: Bool = false

    /// 2列表示（Duoの内側ディスプレイ・横向き）で左右に出している駅。
    /// 左の列がこの駅の「駅発」、右の列が同じ駅の「駅行」になる。
    /// 初期値は利用者が最後に自分で選んだ駅（`BusSelectionStore`）
    @Published var selectedStation: BusStation = .seiseki

    /// 選んだ便がどちらの路線のものか（未選択なら nil）。
    ///
    /// 1列表示では常に `selectedRouteType` と同じになるため、従来の判定と結果は変わらない。
    /// 2列表示では同じ「分」が両方の列にあり得るので、どちらの列で押したのかをここで区別する
    @Published var selectedEntryRoute: BusSchedule.RouteType?

    /// いま2列表示かどうか（ページが自分の大きさから判定して渡す）。
    ///
    /// 2列表示では両方向を同時に出しているので、現在地による路線の自動切り替えには
    /// 切り替えるものが無い。駅セレクタと取り合いにならないよう、その間は自動切り替えを止める
    var isTwoPaneLayout: Bool = false

    // MARK: - プライベートプロパティ

    private var timer: Timer?
    private var secondsTimer: Timer?
    private let busScheduleService = BusScheduleService.shared

    // 位置情報関連（判定は CampusPresenceService が一箇所で持つ）
    private var presenceCancellable: AnyCancellable?

    // 通知オブザーバー
    private var willEnterForegroundObserver: NSObjectProtocol?
    private var busParametersObserver: NSObjectProtocol?

    // MARK: - 日付フォーマッター

    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    // MARK: - 時計

    /// バスページの「今」。
    /// DEBUGビルドで `-DuoBusNowOverride HH:mm` が指定されたときだけ、その時刻から始まる
    private static func now() -> Date {
        #if DEBUG
        return Date().addingTimeInterval(DuoDebugBus.nowOffset)
        #else
        return Date()
        #endif
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
        setupTimers()
        checkIfWeekday()
        updateScrollToHour()
        setupBusParametersObserver()

        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Self.now()
                self?.fetchBusScheduleData()
            }
        }
    }

    func cleanupOnDisappear() {
        cleanupTimers()
        removeObservers()
    }

    private func setupTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Self.now()
                self?.updateScrollToHour()
            }
        }

        secondsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Self.now()
                self?.checkIfSelectedTimePassed()
            }
        }
    }

    private func cleanupTimers() {
        timer?.invalidate()
        timer = nil
        secondsTimer?.invalidate()
        secondsTimer = nil

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

    func updateScrollToHour() {
        scrollToHour = nil
        DispatchQueue.main.async {
            if let nextBus = self.getNextBus() {
                self.scrollToHour = nextBus.hour
            } else {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour], from: self.currentTime)
                self.scrollToHour = components.hour
            }
        }
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

    func isCurrentHour(_ hour: Int) -> Bool {
        isCurrentHour(hour, on: selectedRouteType)
    }

    /// 指定した路線で、その時間の行を強調するかどうか
    func isCurrentHour(_ hour: Int, on route: BusSchedule.RouteType) -> Bool {
        guard let nextBus = getNextBus(for: route) else { return false }
        return nextBus.hour == hour
    }

    func isTimeEqual(_ timeEntry: BusSchedule.TimeEntry, to date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return false
        }
        return timeEntry.hour == hour && timeEntry.minute == minute
    }

    func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry) -> Bool {
        isCurrentOrNextBus(time, on: selectedRouteType)
    }

    /// 指定した路線で、その便が「次のバス」かどうか
    func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry, on route: BusSchedule.RouteType) -> Bool {
        guard let nextBus = getNextBus(for: route) else { return false }
        return time.hour == nextBus.hour && time.minute == nextBus.minute
    }

    /// 2列表示で、その列に出している選択（別の列で選ばれた便はその列には出さない）
    func selectedEntry(on route: BusSchedule.RouteType) -> BusSchedule.TimeEntry? {
        selectedEntryRoute == route ? selectedTimeEntry : nil
    }

    /// 2列表示で、その便が選ばれているかどうか（列の路線まで見る）
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

    /// 指定した路線の次のバス
    func getNextBus(for route: BusSchedule.RouteType) -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
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

    func getCountdownText(to nextBus: BusSchedule.TimeEntry) -> String {
        let calendar = Calendar.current

        var nextBusDateComponents = calendar.dateComponents(
            [.year, .month, .day], from: currentTime)
        nextBusDateComponents.hour = nextBus.hour
        nextBusDateComponents.minute = nextBus.minute
        nextBusDateComponents.second = 0

        guard let nextBusDate = calendar.date(from: nextBusDateComponents) else {
            return ""
        }

        let currentComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
        if let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute,
            currentHour == nextBus.hour && currentMinute == nextBus.minute {
            return "0分0秒"
        }

        if nextBusDate < currentTime {
            guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nextBusDate) else {
                return ""
            }
            return formatTimeDifference(from: currentTime, to: tomorrowDate)
        } else {
            return formatTimeDifference(from: currentTime, to: nextBusDate)
        }
    }

    private func formatTimeDifference(from: Date, to: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: from, to: to)

        if let hour = components.hour, let minute = components.minute,
            let second = components.second {
            if hour > 0 {
                return "\(hour)時間\(minute)分\(second)秒"
            } else {
                return "\(minute)分\(second)秒"
            }
        }

        return ""
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
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                selectedEntryRoute = nil
                cardInfoAppeared = false
            }
        }
    }

    // MARK: - 時間エントリー操作

    func handleTimeEntryTap(_ time: BusSchedule.TimeEntry) {
        handleTimeEntryTap(time, on: selectedRouteType)
    }

    /// 時刻表の便を押したとき。
    ///
    /// 選択はアプリ全体で1つ（ライブアクティビティも1つ）なので、2列表示でどちらの列を押しても
    /// ここへ来る。どの列で押したのかは `route` で区別し、同じ便をもう一度押したときだけ解除する
    func handleTimeEntryTap(_ time: BusSchedule.TimeEntry, on route: BusSchedule.RouteType) {
        if selectedTimeEntry == time && selectedEntryRoute == route {
            BusLiveActivityService.shared.endActivity()
            BusSelectionStore.shared.clear()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                selectedEntryRoute = nil
                cardInfoAppeared = false
            }
        } else {
            BusLiveActivityService.shared.startActivity(
                timeEntry: time,
                routeType: route
            )
            // 時間割タブの「今日」ペインからも同じ便を数えられるよう、選択を共有しておく
            BusSelectionStore.shared.select(
                entry: time, route: route, now: currentTime)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = time
                selectedEntryRoute = route
                cardInfoAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.cardInfoAppeared = true
                    }
                }
            }
        }
    }

    func clearSelection() {
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTimeEntry = nil
            selectedEntryRoute = nil
            cardInfoAppeared = false
        }
    }

    func onScheduleTypeChanged() {
        BusLiveActivityService.shared.endActivity()
        BusSelectionStore.shared.clear()
        selectedTimeEntry = nil
        selectedEntryRoute = nil
        updateScrollToHour()
    }

    /// 利用者が2列表示の駅セレクタを押したとき。
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
        updateScrollToHour()
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
        updateScrollToHour()
    }

    // MARK: - 位置情報関連

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

    private func applyPresence(_ isOnCampus: Bool?) {
        guard let isOnCampus, isOnCampus != userInSchoolArea else { return }
        userInSchoolArea = isOnCampus
        updateRouteBasedOnLocation()
    }

    private func updateRouteBasedOnLocation() {
        // 2列表示では駅発・駅行の両方を同時に出しているため、切り替えるものが無い。
        // 駅セレクタと取り合いにならないよう、ここでは何もしない
        guard !isTwoPaneLayout else { return }

        if userInSchoolArea {
            let isAlreadySchoolDeparture =
                selectedRouteType == .fromSchoolToSeiseki
                || selectedRouteType == .fromSchoolToNagayama
            if !isAlreadySchoolDeparture {
                withAnimation {
                    selectedRouteType = .fromSchoolToNagayama
                    updateScrollToHour()
                }
            }
        } else {
            let isAlreadyStationDeparture =
                selectedRouteType == .fromSeisekiToSchool
                || selectedRouteType == .fromNagayamaToSchool
            if !isAlreadyStationDeparture {
                withAnimation {
                    selectedRouteType = .fromSeisekiToSchool
                    updateScrollToHour()
                }
            }
        }
    }

    // MARK: - URLスキーム処理

    private func setupBusParametersObserver() {
        busParametersObserver = NotificationCenter.default.addObserver(
            forName: .busParametersFromURL,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                if let userInfo = notification.userInfo {
                    if let routeString = userInfo["route"] as? String {
                        switch routeString {
                        case "fromSeisekiToSchool":
                            self.selectedRouteType = .fromSeisekiToSchool
                        case "fromNagayamaToSchool":
                            self.selectedRouteType = .fromNagayamaToSchool
                        case "fromSchoolToSeiseki":
                            self.selectedRouteType = .fromSchoolToSeiseki
                        case "fromSchoolToNagayama":
                            self.selectedRouteType = .fromSchoolToNagayama
                        default:
                            break
                        }
                        // ディープリンクで指定された路線も、利用者が自分で選んだものとして扱う
                        BusSelectionStore.shared.recordUserSelectedRoute(self.selectedRouteType)
                        // 2列表示では路線チップが無いため、その路線の駅を選んだ状態にする
                        // （左＝その駅の駅発、右＝その駅の駅行）
                        self.selectedStation = BusStation.station(of: self.selectedRouteType)
                    }

                    if let scheduleString = userInfo["schedule"] as? String {
                        switch scheduleString {
                        case "weekday":
                            self.selectedScheduleType = .weekday
                        case "saturday":
                            self.selectedScheduleType = .saturday
                        case "wednesday":
                            self.selectedScheduleType = .wednesday
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
}
