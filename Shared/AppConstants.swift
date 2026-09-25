import Foundation

/// アプリ本体と拡張で共有する定数
enum AppConstants {

    /// App Group ID（UserDefaults・SwiftData の共有に使用）
    static let appGroupID = "group.com.meikenn.tama"

    /// T-NEXT のホスト名
    static let tnextHost = "next.tama.ac.jp"

    /// 自前バックエンドのベースURL（T-NEXT が使えない場合のフォールバック等）
    static let backendBaseURL = "https://tama.qaq.tw"
}
