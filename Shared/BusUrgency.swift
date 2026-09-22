import SwiftUI

// MARK: - 発車までの切迫度

/// 発車までの残り時間を「落ち着いている／そろそろ／もう間に合わない寸前」の3段階で表す。
///
/// バスウィジェット（`BusWidget`）が使っている「近づくほど暖色にする」考え方を、
/// アプリ本体の「今日」ペインでも同じ段階で使えるように共有コードへ置いたもの。
/// 色だけに意味を持たせてはいけないので、使う側では必ず文字か記号も添えること
enum BusUrgency {

    /// まだ余裕がある（15分超）
    case calm

    /// そろそろ出る時間（5分超15分以下）
    case soon

    /// 直前（5分以下）
    case imminent

    /// 残り分数から段階を決める（nil＝発車済み・不明）
    static func level(minutesUntil minutes: Int?) -> BusUrgency {
        guard let minutes else { return .calm }
        if minutes <= 5 { return .imminent }
        if minutes <= 15 { return .soon }
        return .calm
    }

    /// 段階の色（ダークモードでも見える標準の色を使う）
    var color: Color {
        switch self {
        case .calm: return .green
        case .soon: return .orange
        case .imminent: return .red
        }
    }
}
