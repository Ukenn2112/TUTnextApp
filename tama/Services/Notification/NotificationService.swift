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
        self.lastTokenRefreshDate = AppDefaults.lastTokenRefreshDate
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
                    AppDefaults.lastTokenRefreshDate = nil
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
        ) { data, _, error in
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
        ) { data, _, error in
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
                    AppDefaults.lastTokenRefreshDate = nil
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
        AppDefaults.lastTokenRefreshDate = now
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
        AppDefaults.lastTokenRefreshDate = nil
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

        // Live Activity のスケジュールキャッシュを無効化して再同期
        TodayScheduleService.shared.invalidateCache()
        Task { @MainActor in
            await LiveActivityScheduler.shared.syncLiveActivity()
        }
    }

    /// 課題数変更通知を処理する
    private func handleAssignmentCountChangeNotification(userInfo: [AnyHashable: Any]) {
        AssignmentService.shared.handleAssignmentCountChangeNotification(userInfo: userInfo)
    }

    // MARK: - 締め切りリマインダー

    /// 課題一覧をもとに締め切りリマインダー通知をスケジュールする
    /// 毎回全クリアして再登録する（同期のたびにIDが変わるため）
    func scheduleAssignmentDeadlineNotifications(_ assignments: [Assignment]) {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            // 既存の締め切りリマインダーのみ削除（他の通知は残す）
            let deadlineIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("deadline-") }
            center.removePendingNotificationRequests(withIdentifiers: deadlineIds)

            let now = Date()

            // 締め切りが未来の課題のみ、近い順に最大40件（iOS上限64件以内）
            let upcoming = assignments
                .filter { $0.dueDate > now }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(40)

            for (index, assignment) in upcoming.enumerated() {
                self.scheduleDeadlineReminder(assignment: assignment, index: index, hoursBefore: 1)
            }

            print("【通知】締め切りリマインダーを登録しました: \(upcoming.count)件")
        }
    }

    /// 新しく追加された課題のローカル通知を即時送信する
    /// 新しく追加された課題をまとめて1件のローカル通知で送信する
    /// 締め切りまで1h未満の課題が含まれる場合は time-sensitive で送る
    func sendNewAssignmentLocalNotifications(_ assignments: [Assignment]) {
        guard !assignments.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let now = Date()

        let hasUrgent = assignments.contains {
            $0.dueDate > now && $0.dueDate.timeIntervalSince(now) < 3600
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = hasUrgent ? .timeSensitive : .active
        content.userInfo = ["toPage": "assignment"]

        if assignments.count == 1 {
            let assignment = assignments[0]
            content.title = NSLocalizedString("新しい課題が追加されました", comment: "new assignment title")
            content.body = String(
                format: NSLocalizedString("授業「%@」に新しい課題が追加されました。\n締め切り: %@", comment: "new assignment body"),
                assignment.courseName,
                formatter.string(from: assignment.dueDate)
            )
        } else {
            content.title = NSLocalizedString("新しい課題が追加されました", comment: "new assignment title")
            content.body = String(
                format: NSLocalizedString("%d件の新しい課題が追加されました。", comment: "new assignments body2"),
                assignments.count
            )
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "new-assignments-\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("【通知】新課題通知送信失敗: \(error.localizedDescription)")
            }
        }

        // 1h未満の課題は締め切りリマインダーの重複を防ぐ
        for assignment in assignments where assignment.dueDate > now && assignment.dueDate.timeIntervalSince(now) < 3600 {
            let sentKey = "deadline-sent-\(assignment.courseId)-\(Int(assignment.dueDate.timeIntervalSince1970))-\(assignment.title)-1h"
            UserDefaults.standard.set(true, forKey: sentKey)
        }
    }

    /// 指定時間前のリマインダーを1件登録する
    private func scheduleDeadlineReminder(assignment: Assignment, index: Int, hoursBefore: Int) {
        let sentKey = "deadline-sent-\(assignment.courseId)-\(Int(assignment.dueDate.timeIntervalSince1970))-\(assignment.title)-\(hoursBefore)h"
        guard !UserDefaults.standard.bool(forKey: sentKey) else { return }

        let fireDate = assignment.dueDate.addingTimeInterval(-Double(hoursBefore) * 3600)
        let now = Date()

        // 期限切れはスキップ
        guard assignment.dueDate > now else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("【注意】課題の締切が近づいています！", comment: "deadline reminder title")
        content.body = String(
            format: NSLocalizedString("授業「%@」の課題の締切が近づいています！\n締め切り: %@", comment: "deadline reminder body"),
            assignment.courseName,
            formatter.string(from: assignment.dueDate)
        )
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["toPage": "assignment"]

        // 1h未満は即時、それ以外はカレンダートリガー
        let trigger: UNNotificationTrigger
        let identifier: String
        if fireDate <= now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            identifier = "deadline-immediate-\(assignment.courseId)-\(Int(assignment.dueDate.timeIntervalSince1970))"
        } else {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            identifier = "deadline-\(index)-\(hoursBefore)h"
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: sentKey)
            } else {
                print("【通知】締め切りリマインダー登録失敗[\(assignment.title)]: \(error!.localizedDescription)")
            }
        }
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
