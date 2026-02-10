import Foundation
import UIKit
import UserNotifications

/// プッシュ通知管理サービス
final class NotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var deviceToken: String?

    static let shared = NotificationService()

    /// 最後にトークンを更新した日時
    private var lastTokenRefreshDate: Date?
    /// トークン更新間隔（7日）
    private let tokenRefreshInterval: TimeInterval = 7 * 24 * 60 * 60

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        self.deviceToken = UserService.shared.getDeviceToken()
        self.lastTokenRefreshDate = UserDefaults.standard.object(forKey: "lastTokenRefreshDate") as? Date
    }

    // MARK: - 通知権限

    /// 通知権限をリクエストする
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.registerForRemoteNotifications()
                } else {
                    UserService.shared.clearDeviceToken()
                    self.deviceToken = nil
                    UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
                    self.lastTokenRefreshDate = nil
                }

                if let error = error {
                    print("【通知】権限リクエストエラー: \(error.localizedDescription)")
                }
            }
        }
    }

    /// リモート通知を登録する
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 通知権限ステータスを確認し、必要に応じて再登録する
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let wasAuthorized = self.isAuthorized
                self.isAuthorized = settings.authorizationStatus == .authorized
                self.deviceToken = UserService.shared.getDeviceToken()

                if !wasAuthorized && self.isAuthorized {
                    if self.deviceToken == nil {
                        self.registerForRemoteNotifications()
                    }
                } else if wasAuthorized && !self.isAuthorized {
                    if let token = self.deviceToken {
                        self.unregisterDeviceTokenFromServer(token: token)
                        UserService.shared.clearDeviceToken()
                        self.deviceToken = nil
                    }
                }
            }
        }
    }

    // MARK: - デバイストークン管理

    /// デバイストークンをサーバーに送信する
    func sendDeviceTokenToServer(token: String, username: String, encryptedPassword: String) {
        guard let url = URL(string: "https://tama.qaq.tw/push/send") else { return }

        let body: [String: Any] = [
            "username": username,
            "encryptedPassword": encryptedPassword,
            "deviceToken": token
        ]

        guard let request = APIService.shared.createRequest(url: url, method: "POST", body: body) else { return }

        APIService.shared.request(
            request: request,
            logTag: "デバイストークン登録",
            replacingPercentEncoding: false
        ) { data, response, error in
            if let error = error {
                print("【通知】デバイストークン登録失敗: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool,
                   let message = json["message"] as? String {
                    print("【通知】デバイストークン登録\(status ? "成功" : "失敗"): \(message)")
                }
            } catch {
                print("【通知】デバイストークン登録レスポンス解析失敗: \(error.localizedDescription)")
            }
        }
    }

    /// デバイストークンをサーバーから登録解除する
    func unregisterDeviceTokenFromServer(token: String) {
        guard let url = URL(string: "https://tama.qaq.tw/push/unregister") else { return }

        let body: [String: Any] = ["deviceToken": token]

        guard let request = APIService.shared.createRequest(url: url, method: "POST", body: body) else { return }

        APIService.shared.request(
            request: request,
            logTag: "デバイストークン登録解除",
            replacingPercentEncoding: false
        ) { data, response, error in
            if let error = error {
                print("【通知】デバイストークン登録解除失敗: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool,
                   let message = json["message"] as? String {
                    print("【通知】デバイストークン登録解除\(status ? "成功" : "失敗"): \(message)")
                }
            } catch {
                print("【通知】デバイストークン登録解除レスポンス解析失敗: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - アプリライフサイクル

    /// アプリがフォアグラウンドに戻ったときに呼び出す
    func applicationWillEnterForeground() {
        checkAuthorizationStatus()
        checkAndRefreshDeviceToken()
        syncNotificationStatusWithServer()
    }

    /// 通知登録状態を確認する
    var isRegistered: Bool {
        return isAuthorized && deviceToken != nil
    }

    /// 通知状態をサーバーと同期する
    func syncNotificationStatusWithServer() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                let token = UserService.shared.getDeviceToken()
                self.deviceToken = token

                let needsTokenRefresh = self.shouldRefreshDeviceToken()

                if self.isAuthorized, let token = token {
                    if !needsTokenRefresh {
                        if let currentUser = UserService.shared.getCurrentUser() {
                            self.sendDeviceTokenToServer(
                                token: token,
                                username: currentUser.username,
                                encryptedPassword: currentUser.encryptedPassword ?? ""
                            )
                        }
                    } else {
                        self.registerForRemoteNotifications()
                    }
                } else if !self.isAuthorized, let token = self.deviceToken {
                    self.unregisterDeviceTokenFromServer(token: token)
                    UserService.shared.clearDeviceToken()
                    self.deviceToken = nil
                    UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
                    self.lastTokenRefreshDate = nil
                }
            }
        }
    }

    /// デバイストークンの有効期限をチェックし、必要に応じて再取得する
    func checkAndRefreshDeviceToken() {
        guard isAuthorized else { return }

        if shouldRefreshDeviceToken() {
            registerForRemoteNotifications()
        }
    }

    // MARK: - プライベートメソッド

    /// デバイストークンを更新すべきかどうかを判断する
    private func shouldRefreshDeviceToken() -> Bool {
        guard deviceToken != nil else { return true }
        guard let lastRefreshDate = lastTokenRefreshDate else { return true }

        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshDate)
        return timeSinceLastRefresh > tokenRefreshInterval
    }

    /// デバイストークンの有効性チェック
    private func isValidDeviceToken(_ token: String) -> Bool {
        let hexPattern = "^[0-9a-f]{64}$"
        let regex = try? NSRegularExpression(pattern: hexPattern, options: .caseInsensitive)
        guard let regex = regex,
              regex.firstMatch(in: token, options: [], range: NSRange(location: 0, length: token.count)) != nil else {
            return false
        }

        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    /// フォアグラウンドでの通知表示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    /// 通知タップ時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let toPage = userInfo["toPage"] as? String {
            navigateToPage(toPage)
        }

        completionHandler()
    }

    /// 通知タップ時の画面遷移処理
    private func navigateToPage(_ page: String) {
        NotificationCenter.default.post(
            name: .navigateToPageFromNotification,
            object: nil,
            userInfo: ["page": page]
        )
    }
}

// MARK: - AppDelegate拡張用メソッド
extension NotificationService {
    /// デバイストークン取得成功時
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token

        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastTokenRefreshDate")
        self.lastTokenRefreshDate = now

        UserService.shared.saveDeviceToken(token)

        let currentUser = UserService.shared.getCurrentUser()

        sendDeviceTokenToServer(
            token: token,
            username: currentUser?.username ?? "",
            encryptedPassword: currentUser?.encryptedPassword ?? ""
        )
    }

    /// デバイストークン取得失敗時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("【通知】リモート通知の登録失敗: \(error.localizedDescription)")
        self.deviceToken = nil
        UserService.shared.clearDeviceToken()
        UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
        self.lastTokenRefreshDate = nil
    }

    /// リモート通知受信時
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let updateType = userInfo["updateType"] as? String {
            if updateType == "roomChange" {
                handleRoomChangeNotification(userInfo: userInfo)
                completionHandler(.newData)
                return
            }

            if updateType == "kaidaiNumChange" {
                handleAssignmentCountChangeNotification(userInfo: userInfo)
                completionHandler(.newData)
                return
            }
        }

        completionHandler(.newData)
    }

    /// 部屋変更通知を処理する
    private func handleRoomChangeNotification(userInfo: [AnyHashable: Any]) {
        guard let courseName = userInfo["name"] as? String,
              let newRoom = userInfo["room"] as? String else {
            return
        }

        TimetableService.shared.handleRoomChange(courseName: courseName, newRoom: newRoom)
        sendRoomChangeLocalNotification(courseName: courseName, newRoom: newRoom)
    }

    /// 課題数変更通知を処理する
    private func handleAssignmentCountChangeNotification(userInfo: [AnyHashable: Any]) {
        AssignmentService.shared.handleAssignmentCountChangeNotification(userInfo: userInfo)
    }

    /// 部屋変更をユーザーに通知するローカル通知
    private func sendRoomChangeLocalNotification(courseName: String, newRoom: String) {
        let content = UNMutableNotificationContent()
        content.title = "教室変更のお知らせ"
        content.body = "「\(courseName)」の教室が\(newRoom)に変更されました。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("【通知】部屋変更通知の送信失敗: \(error.localizedDescription)")
            }
        }
    }
}
