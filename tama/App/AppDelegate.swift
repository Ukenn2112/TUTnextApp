import SwiftData
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
        // 旧データが存在する場合、すべてのデータをクリアする
        KeychainService.shared.clearLegacyDataIfNeeded()
        clearLegacyUserDefaultsIfNeeded()

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

    /// UserDefaults に旧キャッシュデータが存在する場合、すべてクリアする
    private func clearLegacyUserDefaultsIfNeeded() {
        guard !AppDefaults.legacyUserDefaultsCleared else { return }

        let defaults = UserDefaults.standard
        let appGroupDefaults = UserDefaults(suiteName: "group.com.meikenn.tama")
        
        // 旧データの存在をチェック
        let hasLegacyStandardDefaults = 
            defaults.data(forKey: "roomChanges") != nil ||
            defaults.data(forKey: "courseColors") != nil ||
            defaults.data(forKey: "recentUploads") != nil
        
        let hasLegacyAppGroupDefaults = 
            appGroupDefaults?.data(forKey: "cachedTimetableData") != nil ||
            appGroupDefaults?.data(forKey: "cachedBusSchedule") != nil
        
        if hasLegacyStandardDefaults || hasLegacyAppGroupDefaults {
            print("【AppDelegate】旧キャッシュデータ検出 - クリアします")
            
            // UserDefaults のキャッシュデータをクリア
            defaults.removeObject(forKey: "roomChanges")
            defaults.removeObject(forKey: "courseColors")
            defaults.removeObject(forKey: "recentUploads")
            
            // App Group のキャッシュデータをクリア
            appGroupDefaults?.removeObject(forKey: "cachedTimetableData")
            appGroupDefaults?.removeObject(forKey: "lastTimetableFetchTime")
            appGroupDefaults?.removeObject(forKey: "cachedBusSchedule")
            appGroupDefaults?.removeObject(forKey: "lastBusScheduleFetchTime")
            
            // SwiftData も念のためクリア
            clearSwiftDataIfNeeded()
            
            print("【AppDelegate】旧キャッシュデータをクリアしました")
        }
        
        // クリア完了フラグを設定
        AppDefaults.legacyUserDefaultsCleared = true
    }
    
    /// SwiftData のすべてのデータをクリアする
    private func clearSwiftDataIfNeeded() {
        do {
            let context = ModelContext(SharedModelContainer.shared)
            
            // すべてのモデルを削除
            try context.delete(model: CachedTimetable.self)
            try context.delete(model: CachedBusSchedule.self)
            try context.delete(model: RoomChangeRecord.self)
            try context.delete(model: CourseColorRecord.self)
            try context.delete(model: PrintUploadRecord.self)
            
            try context.save()
            print("【AppDelegate】SwiftData をクリアしました")
        } catch {
            print("【AppDelegate】SwiftData クリア失敗: \(error.localizedDescription)")
        }
    }

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
