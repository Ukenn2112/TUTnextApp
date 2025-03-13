import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // アプリ起動時の処理
        return true
    }
    
    // リモート通知の登録成功時
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    // リモート通知の登録失敗時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationService.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    // バックグラウンドでの通知受信時
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationService.shared.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    // アプリがバックグラウンドから復帰する時
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 通知権限の状態を確認
        NotificationService.shared.applicationWillEnterForeground()
    }
}
