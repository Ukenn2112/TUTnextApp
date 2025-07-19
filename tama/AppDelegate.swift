import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // シングルトンインスタンス化して他のクラスからURLを処理できるようにする
    static let shared = AppDelegate()

    // URLスキームから起動した場合のパスを保存するプロパティ
    var initialURLPath: String?
    var initialURLComponents: URLComponents?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // URLから起動された場合
        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
            let _ = handleURL(url)
        }

        // 期限切れの部屋変更情報をクリーンアップ
        TimetableService.shared.cleanupExpiredRoomChanges()

        // 通知状態を確認してサーバーと同期
        NotificationService.shared.checkAuthorizationStatus()
        NotificationService.shared.syncNotificationStatusWithServer()
        
        // アプリ起動時の評価サービス初期化
        RatingService.shared.onAppLaunch()

        return true
    }

    // リモート通知の登録成功時
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.application(
            application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // リモート通知の登録失敗時
    func application(
        _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.application(
            application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    // バックグラウンドでの通知受信時
    func application(
        _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationService.shared.application(
            application, didReceiveRemoteNotification: userInfo,
            fetchCompletionHandler: completionHandler)
    }

    // アプリがバックグラウンドから復帰する時
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 通知権限の状態を確認
        NotificationService.shared.applicationWillEnterForeground()

        // 期限切れの部屋変更情報をクリーンアップ
        TimetableService.shared.cleanupExpiredRoomChanges()
    }

    // URLスキームで起動された場合の処理
    func application(
        _ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return handleURL(url)
    }

    // URLの処理ロジック
    func handleURL(_ url: URL) -> Bool {
        print("Handling URL: \(url.absoluteString)")

        // Google OAuth コールバック処理 (新しいリダイレクトURI形式)
        // Info.plistからReversed Client IDを動的に取得
        guard let reversedClientId = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String else {
            print("REVERSED_CLIENT_ID not found in Info.plist")
            return false
        }
        
        if url.scheme == reversedClientId {
            print("Google OAuth callback detected")
            
            // 立即发送回调收到通知，强制关闭WebView
            NotificationCenter.default.post(name: .googleOAuthCallbackReceived, object: nil)
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems,
               let code = queryItems.first(where: { $0.name == "code" })?.value {
                
                print("OAuth authorization code received: \(code)")
                GoogleOAuthService.shared.handleAuthCode(code)
                return true
            } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                      let queryItems = components.queryItems,
                      let error = queryItems.first(where: { $0.name == "error" })?.value {
                
                print("OAuth error received: \(error)")
                // エラー処理
                NotificationCenter.default.post(
                    name: .googleOAuthError,
                    object: nil,
                    userInfo: ["error": error]
                )
                return true
            }
        }

        // カスタムURLスキームのフォーマット確認 (tama://の場合)
        guard url.scheme == "tama" else {
            print("Invalid scheme: \(url.scheme ?? "nil"), expected: tama or Google OAuth scheme")
            return false
        }

        // ホスト部分を取得 (例: tama://timetable のホストは "timetable")
        initialURLPath = url.host
        initialURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)

        print(
            "URL components: host=\(url.host ?? "nil"), path=\(url.path), query=\(url.query ?? "nil")"
        )
        print("Parsed initialURLPath=\(initialURLPath ?? "nil")")

        if let components = initialURLComponents {
            print("URL components: \(components)")
            print("Query items: \(components.queryItems ?? [])")
        }

        // 印刷URLのケース（Share Extensionから起動された場合）
        if url.host == "print" {
            print("Print URL detected - showing PrintSystemView")

            // モーダルでの表示処理はContentViewに任せる
            // 通知を発行して他のビューに知らせる
            NotificationCenter.default.post(name: Notification.Name("HandleURLScheme"), object: url)
            return true
        }

        // 通知を発行して他のビューに知らせる
        NotificationCenter.default.post(name: Notification.Name("HandleURLScheme"), object: url)
        return true
    }

    // 特定のパスを取得
    func getPathComponent() -> String? {
        let path = initialURLPath
        print("getPathComponent returning: \(path ?? "nil")")
        return path
    }

    // URLクエリパラメータを取得
    func getQueryItems() -> [URLQueryItem]? {
        return initialURLComponents?.queryItems
    }

    // 特定のクエリパラメータの値を取得
    func getQueryValue(for key: String) -> String? {
        return initialURLComponents?.queryItems?.first(where: { $0.name == key })?.value
    }

    // URLスキーム処理をリセット
    func resetURLProcessing() {
        initialURLPath = nil
        initialURLComponents = nil
    }
}
