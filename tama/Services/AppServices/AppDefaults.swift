import Foundation

/// UserDefaults の型安全ラッパー
///
/// すべての UserDefaults キーを一元管理し、型安全なアクセスを提供する。
enum AppDefaults {
    private static let standard = UserDefaults.standard

    // MARK: - 外観設定

    static var darkMode: Int {
        get { standard.integer(forKey: "darkMode") }
        set { standard.set(newValue, forKey: "darkMode") }
    }

    // MARK: - 評価サービス

    static var appLaunchCount: Int {
        get { standard.integer(forKey: "AppLaunchCount") }
        set { standard.set(newValue, forKey: "AppLaunchCount") }
    }

    static var lastRatingRequestDate: Date? {
        get { standard.object(forKey: "LastRatingRequestDate") as? Date }
        set { standard.set(newValue, forKey: "LastRatingRequestDate") }
    }

    static var hasUserRated: Bool {
        get { standard.bool(forKey: "HasUserRated") }
        set { standard.set(newValue, forKey: "HasUserRated") }
    }

    static var significantEventsCount: Int {
        get { standard.integer(forKey: "SignificantEventsCount") }
        set { standard.set(newValue, forKey: "SignificantEventsCount") }
    }

    // MARK: - 通知

    static var lastTokenRefreshDate: Date? {
        get { standard.object(forKey: "lastTokenRefreshDate") as? Date }
        set {
            if let newValue {
                standard.set(newValue, forKey: "lastTokenRefreshDate")
            } else {
                standard.removeObject(forKey: "lastTokenRefreshDate")
            }
        }
    }

    // MARK: - ワンタイムフラグ

    static var hasShownNFCTip: Bool {
        get { standard.bool(forKey: "hasShownNFCTip") }
        set { standard.set(newValue, forKey: "hasShownNFCTip") }
    }

    // MARK: - 移行フラグ

    static var legacyDataCleared: Bool {
        get { standard.bool(forKey: "legacyDataCleared") }
        set { standard.set(newValue, forKey: "legacyDataCleared") }
    }

    static var legacyUserDefaultsCleared: Bool {
        get { standard.bool(forKey: "legacyUserDefaultsCleared") }
        set { standard.set(newValue, forKey: "legacyUserDefaultsCleared") }
    }

    // MARK: - リセット

    /// 評価関連データをリセット
    static func resetRatingData() {
        standard.removeObject(forKey: "AppLaunchCount")
        standard.removeObject(forKey: "LastRatingRequestDate")
        standard.removeObject(forKey: "HasUserRated")
        standard.removeObject(forKey: "SignificantEventsCount")
    }
}
