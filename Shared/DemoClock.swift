#if DEBUG
import Foundation

/// アプリのデモモード（`DemoMode`、DEBUGビルドのみ）がウィジェットへ渡す時計のずれ。
///
/// アプリはデモモードで起動するたびに、デモの「今」（今週の火曜日 9:41）と実時間のずれ（秒）を
/// App Group の `UserDefaults` に書き、デモモードでない起動では消す。
/// ウィジェットはこのずれだけ進めた時刻で「今日の曜日・時限」「次のバス」を決め、
/// 画面に出す日時（カウントダウンの基準など）は実時間へ戻して使う
enum DemoClock {

    /// App Group の `UserDefaults` のキー
    static let offsetKey = "DemoClockOffset"

    /// 実時間からのずれ（秒）。デモモードで起動していなければ 0
    static var offset: TimeInterval {
        UserDefaults(suiteName: AppConstants.appGroupID)?.double(forKey: offsetKey) ?? 0
    }
}
#endif
