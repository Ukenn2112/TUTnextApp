import Foundation

// MARK: - 通知名定義

extension Notification.Name {

    // MARK: - URLスキーム関連

    /// URLスキーム処理用の通知
    static let handleURLScheme = Notification.Name("HandleURLScheme")

    /// バスパラメータのURL通知
    static let busParametersFromURL = Notification.Name("BusParametersFromURL")

    // MARK: - ナビゲーション関連

    /// 通知からの画面遷移
    static let navigateToPageFromNotification = Notification.Name("NavigateToPageFromNotification")

    // MARK: - Google OAuth関連

    /// Google OAuth認証成功
    static let googleOAuthSuccess = Notification.Name("GoogleOAuthSuccess")

    /// Google OAuthエラー
    static let googleOAuthError = Notification.Name("GoogleOAuthError")

    /// Google OAuth WebView閉じ
    static let googleOAuthWebViewDismissed = Notification.Name("GoogleOAuthWebViewDismissed")

    /// Google OAuthコールバック受信
    static let googleOAuthCallbackReceived = Notification.Name("GoogleOAuthCallbackReceived")

    /// Google OAuth状態変更
    static let googleOAuthStatusChanged = Notification.Name("GoogleOAuthStatusChanged")

    // MARK: - 課題関連

    /// 課題データ更新
    static let assignmentsUpdated = Notification.Name("AssignmentsUpdatedNotification")

    // MARK: - 掲示関連

    /// 掲示Safari閉じ
    static let announcementSafariDismissed = Notification.Name("AnnouncementSafariDismissed")
}
