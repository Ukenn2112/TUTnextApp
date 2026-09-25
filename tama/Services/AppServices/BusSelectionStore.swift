import Foundation

// MARK: - バスの選択の共有

/// バスタブで選んだ便と、その学生が使う駅を、画面をまたいで共有する小さなストア。
///
/// バスタブの選択（`BusScheduleViewModel.selectedTimeEntry`）は画面と一緒に消えてしまうので、
/// 時間割タブの「今日」ペインからは見えない。ここへ写しておくことで、
/// 「バスタブで押した便のカウントダウンを『今日』ペインにも出す」ができる。
///
/// - 便は App Group の `UserDefaults` に日付ごと保存する。日付が変われば無視するので、
///   昨日の選択が今日のカウントダウンに出ることはない
/// - 駅は「利用者が自分で選んだ路線」だけを記録する。現在地による自動切り替え
///   （`BusScheduleViewModel.updateRouteBasedOnLocation`）は記録しない
@MainActor
final class BusSelectionStore: ObservableObject {

    // MARK: - 公開プロパティ

    static let shared = BusSelectionStore()

    /// バスタブで選んでいる便（未選択・発車済みなら nil）
    @Published private(set) var selectedDeparture: BusDeparture?

    /// その学生が使う駅（最後に自分で選んだ路線の駅。記録が無ければ聖蹟桜ヶ丘駅）
    @Published private(set) var preferredStation: BusStation = .seiseki

    /// 最後に「発車済み」として捨てた学校行きの便の発車時刻。
    ///
    /// 選択を捨てるだけだと、もうバスに乗っている人に次の便を勧め直してしまう。
    /// いつの便に乗ったかを覚えておき、その日のあいだは通学の案内を出さない合図にする
    @Published private(set) var departedTowardSchoolAt: Date?

    // MARK: - 保存先

    private static let suiteName = AppConstants.appGroupID
    private static let stationKey = "TodayPane.preferredStation"
    private static let departureKey = "TodayPane.selectedDeparture"
    private static let departedKey = "TodayPane.departedTowardSchoolAt"

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: Self.suiteName)
        loadStation()
        loadDeparture()
        departedTowardSchoolAt = defaults?.object(forKey: Self.departedKey) as? Date
    }

    // MARK: - 駅

    /// 利用者が自分で路線を選んだことを記録する（チップのタップ・ディープリンク）。
    /// 現在地による自動切り替えからは呼ばないこと
    func recordUserSelectedRoute(_ route: BusSchedule.RouteType) {
        let station = BusStation.station(of: route)
        guard station != preferredStation else { return }
        preferredStation = station
        defaults?.set(station.rawValue, forKey: Self.stationKey)
    }

    private func loadStation() {
        guard let raw = defaults?.string(forKey: Self.stationKey),
              let station = BusStation(rawValue: raw)
        else {
            return
        }
        preferredStation = station
    }

    // MARK: - 選んだ便

    /// バスタブで便を選んだ
    func select(entry: BusSchedule.TimeEntry, route: BusSchedule.RouteType, now: Date = Date()) {
        guard let date = Self.date(of: entry, on: now) else { return }
        let departure = BusDeparture(route: route, entry: entry, date: date)
        selectedDeparture = departure
        if let data = try? JSONEncoder().encode(departure) {
            defaults?.set(data, forKey: Self.departureKey)
        }
    }

    /// バスタブで選択を解除した
    func clear() {
        selectedDeparture = nil
        defaults?.removeObject(forKey: Self.departureKey)
    }

    /// 発車時刻を過ぎた選択を捨てる（「今日」ペインが時計を進めるたびに呼ぶ）。
    /// 学校行きの便だったときは、その発車時刻を覚えてから捨てる
    func pruneIfPassed(now: Date) {
        guard let departure = selectedDeparture, departure.date <= now else { return }
        if departure.route.isTowardSchool {
            departedTowardSchoolAt = departure.date
            defaults?.set(departure.date, forKey: Self.departedKey)
        }
        clear()
    }

    /// その日のうちに、自分で選んだ学校行きの便がもう発車したか
    func hasDepartedTowardSchool(on day: Date) -> Bool {
        guard let departed = departedTowardSchoolAt else { return false }
        return Calendar.current.isDate(departed, inSameDayAs: day)
    }

    private func loadDeparture() {
        guard let data = defaults?.data(forKey: Self.departureKey),
              let departure = try? JSONDecoder().decode(BusDeparture.self, from: data)
        else {
            return
        }
        // 日をまたいだ選択は無視する（前日の便のカウントダウンを出さない）
        guard Calendar.current.isDateInToday(departure.date), departure.date > Date() else {
            defaults?.removeObject(forKey: Self.departureKey)
            return
        }
        selectedDeparture = departure
    }

    /// 時刻表の項目を、その日の発車時刻（`Date`）に直す
    private static func date(of entry: BusSchedule.TimeEntry, on day: Date) -> Date? {
        Calendar.current.date(
            bySettingHour: entry.hour, minute: entry.minute, second: 0, of: day)
    }
}
