import SwiftUI
import UIKit

/// アプリケーションのライフサイクルとURLスキームを管理するデリゲート
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - シングルトン

    static let shared = AppDelegate()

    // MARK: - プロパティ

    /// URLスキームから起動した場合のパスを保存
    private(set) var initialURLPath: String?
    private(set) var initialURLComponents: URLComponents?

    // MARK: - 通知名

    /// URLスキーム処理用の通知名
    static let handleURLSchemeNotification: Notification.Name = .handleURLScheme

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let url = launchOptions?[.url] as? URL {
            _ = handleURL(url)
        }

        TimetableService.shared.cleanupExpiredRoomChanges()
        NotificationService.shared.checkAuthorizationStatus()
        NotificationService.shared.syncNotificationStatusWithServer()
        RatingService.shared.onAppLaunch()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.application(
            application,
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.application(
            application,
            didFailToRegisterForRemoteNotificationsWithError: error
        )
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationService.shared.application(
            application,
            didReceiveRemoteNotification: userInfo,
            fetchCompletionHandler: completionHandler
        )
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationService.shared.applicationWillEnterForeground()
        TimetableService.shared.cleanupExpiredRoomChanges()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return handleURL(url)
    }

    // MARK: - URL処理

    /// URLスキームを処理する
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        // Google OAuthコールバック処理
        if handleGoogleOAuthCallback(url) {
            return true
        }

        // カスタムURLスキームの処理（tama://）
        guard url.scheme == "tama" else {
            return false
        }

        initialURLPath = url.host
        initialURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

        NotificationCenter.default.post(
            name: Self.handleURLSchemeNotification,
            object: url
        )
        return true
    }

    /// 特定のパスを取得
    func getPathComponent() -> String? {
        return initialURLPath
    }

    /// 特定のクエリパラメータの値を取得
    func getQueryValue(for key: String) -> String? {
        return initialURLComponents?.queryItems?.first { $0.name == key }?.value
    }

    /// URLスキーム処理をリセット
    func resetURLProcessing() {
        initialURLPath = nil
        initialURLComponents = nil
    }

    // MARK: - プライベートメソッド

    /// Google OAuthコールバックを処理する
    private func handleGoogleOAuthCallback(_ url: URL) -> Bool {
        guard
            let reversedClientId = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID")
                as? String,
            url.scheme == reversedClientId
        else {
            return false
        }

        // OAuthコールバック受信を通知し、WebViewを閉じる
        NotificationCenter.default.post(name: .googleOAuthCallbackReceived, object: nil)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems
        else {
            return false
        }

        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            GoogleOAuthService.shared.handleAuthCode(code)
            return true
        }

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            NotificationCenter.default.post(
                name: .googleOAuthError,
                object: nil,
                userInfo: ["error": error]
            )
            return true
        }

        return false
    }
}
