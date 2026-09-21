import Foundation

// MARK: - 最寄り駅

/// スクールバスが結んでいる2つの駅。
///
/// 「今日」ペインは、どちらの駅を使う学生なのかをバスタブでの選択から覚えておき、
/// 行き（朝）と帰り（放課後）で向きだけを切り替える
enum BusStation: String, Codable, CaseIterable {

    case seiseki
    case nagayama

    /// 駅と学校の間の乗車時間（分）。
    /// 所要時間はどこにもデータが無いため、運行実績としてプロジェクトオーナーから示された値を
    /// ここ一箇所だけに定数として持つ
    var rideMinutes: Int {
        switch self {
        case .seiseki: return 15
        case .nagayama: return 10
        }
    }

    /// もう一方の駅
    var other: BusStation {
        self == .seiseki ? .nagayama : .seiseki
    }

    /// 駅発（学校行き）の路線
    var toSchoolRoute: BusSchedule.RouteType {
        switch self {
        case .seiseki: return .fromSeisekiToSchool
        case .nagayama: return .fromNagayamaToSchool
        }
    }

    /// 学校発（駅行き）の路線
    var fromSchoolRoute: BusSchedule.RouteType {
        switch self {
        case .seiseki: return .fromSchoolToSeiseki
        case .nagayama: return .fromSchoolToNagayama
        }
    }

    /// 路線から駅を求める
    static func station(of route: BusSchedule.RouteType) -> BusStation {
        switch route {
        case .fromSeisekiToSchool, .fromSchoolToSeiseki: return .seiseki
        case .fromNagayamaToSchool, .fromSchoolToNagayama: return .nagayama
        }
    }
}

// MARK: - 路線の表示名

extension BusSchedule.RouteType {

    /// 路線の表示名（バスタブの路線チップと同じ訳語を使う）
    var displayName: String {
        switch self {
        case .fromSeisekiToSchool: return NSLocalizedString("聖蹟桜ヶ丘駅発", comment: "バス路線")
        case .fromNagayamaToSchool: return NSLocalizedString("永山駅発", comment: "バス路線")
        case .fromSchoolToSeiseki: return NSLocalizedString("聖蹟桜ヶ丘駅行", comment: "バス路線")
        case .fromSchoolToNagayama: return NSLocalizedString("永山駅行", comment: "バス路線")
        }
    }

    /// 学校へ向かう路線かどうか
    var isTowardSchool: Bool {
        self == .fromSeisekiToSchool || self == .fromNagayamaToSchool
    }
}

// MARK: - 1本の便

/// 「今日」ペインが扱う1本の便（路線・時刻表の項目・その日の発車時刻）
struct BusDeparture: Equatable, Codable, Identifiable {

    let route: BusSchedule.RouteType
    let entry: BusSchedule.TimeEntry
    let date: Date

    var id: String { "\(route.rawValue)-\(entry.hour)-\(entry.minute)" }

    /// 発車時刻の表示（"08:20"）
    var formattedTime: String { entry.formattedTime }

    /// 備考の記号（◎ / * / M など）。大学生が乗れない便はそもそも候補に入れない
    var badge: String? { entry.specialNote }

    /// 乗車時間を足した到着予想時刻
    func arrival(rideMinutes: Int) -> Date {
        date.addingTimeInterval(TimeInterval(rideMinutes * 60))
    }
}

// MARK: - 乗れない便

extension BusSchedule.TimeEntry {

    /// この大学のアプリの利用者（大学生）が乗れる便かどうか。
    /// `C`（中学生限定）・`K`（高校生限定）の便は勧めてはいけない。
    /// `M`（大学生用マイクロバス）や `◎` / `*`（永山駅経由）はそのまま候補になる
    var isAvailableToUniversityStudent: Bool {
        guard let note = specialNote?.trimmingCharacters(in: .whitespaces), !note.isEmpty else {
            return true
        }
        return note != "C" && note != "K"
    }
}
