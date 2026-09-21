#if DEBUG
import Foundation

// MARK: - バスタブのDuo検証用の起動引数

/// バスタブのDuo検証用の起動引数（DEBUGビルドのみ、`UserDefaults` の同名キーでも可）。
///
/// `-DuoInitialTab`（`ContentView`）・`-DuoMetricsOverlay`（`DuoMetricsOverlay`）と同じ仕組み。
/// CLIからは時刻表のセルをタップできず、撮影できる時間帯も限られるため、
/// 2列表示のどの場面でもスクリーンショットが撮れるようにしてある:
///
/// - `-DuoBusNowOverride HH:mm` … バスページの時計を差し替える（起動時からの経過は進む）
/// - `-DuoBusDayOverride weekday|wednesday|saturday` … 時刻表の種類を差し替える
/// - `-DuoBusSelectFirstUpcoming YES` … 読み込み後、駅発の列の次の便を選んだ状態にする
/// - `-DuoBusStation seiseki|nagayama` … 2列表示で左右に出す駅を差し替える
///   （利用者が選んだ駅としては記録しないので、`BusSelectionStore` の設定は書き換えない）
enum DuoDebugBus {

    // MARK: - 時計

    /// 起動時に一度だけ決める時計のずれ（秒）。
    /// `-DuoBusNowOverride 8:10` を付けると「今」が 8:10 から始まり、そのあとは実時間と同じだけ進む
    static let nowOffset: TimeInterval = {
        guard let text = UserDefaults.standard.string(forKey: "DuoBusNowOverride"),
              let target = parseTime(text)
        else {
            return 0
        }
        return target.timeIntervalSince(Date())
    }()

    private static func parseTime(_ text: String) -> Date? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    // MARK: - 時刻表の種類

    /// 曜日から決める時刻表の種類の差し替え（指定が無ければ nil＝実際の曜日に従う）
    static var scheduleTypeOverride: BusSchedule.ScheduleType? {
        switch UserDefaults.standard.string(forKey: "DuoBusDayOverride")?.lowercased() {
        case "weekday": return .weekday
        case "wednesday": return .wednesday
        case "saturday": return .saturday
        default: return nil
        }
    }

    // MARK: - 駅

    /// 2列表示で左右に出す駅の差し替え（指定が無ければ nil＝`BusSelectionStore` の設定に従う）
    static var station: BusStation? {
        switch UserDefaults.standard.string(forKey: "DuoBusStation")?.lowercased() {
        case "seiseki": return .seiseki
        case "nagayama": return .nagayama
        default: return nil
        }
    }

    // MARK: - 選択

    /// 駅発の列の次の便を選んだ状態で始めるかどうか
    static var selectsFirstUpcoming: Bool {
        UserDefaults.standard.bool(forKey: "DuoBusSelectFirstUpcoming")
    }
}
#endif
