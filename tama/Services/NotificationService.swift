//
//  NotificationService.swift
//  tama
//
//  Created by AI Assistant on 2024/09/01.
//

import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    static let shared = NotificationService()
    
    // 保存最后一次令牌刷新的时间
    private var lastTokenRefreshDate: Date?
    // 令牌刷新间隔（7天）
    private let tokenRefreshInterval: TimeInterval = 7 * 24 * 60 * 60
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // 初期化時にUserServiceからデバイストークンを取得
        self.deviceToken = UserService.shared.getDeviceToken()
        
        // 初期化時の最後のトークン更新日時を取得
        self.lastTokenRefreshDate = UserDefaults.standard.object(forKey: "lastTokenRefreshDate") as? Date
    }
    
    // 通知権限をリクエスト
    func requestAuthorization() {
        print("通知権限をリクエストします")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    print("通知権限が許可されました。リモート通知を登録します。")
                    self.registerForRemoteNotifications()
                } else {
                    // 拒否された場合
                    print("通知権限が拒否されました。")
                    // 通知が拒否された場合、デバイストークンを削除
                    UserService.shared.clearDeviceToken()
                    self.deviceToken = nil
                    // 保存されたトークン更新日時をクリア
                    UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
                    self.lastTokenRefreshDate = nil
                }
                
                if let error = error {
                    print("通知権限リクエストエラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // リモート通知の登録
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // 通知権限ステータスの確認と必要に応じた再登録
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let wasAuthorized = self.isAuthorized
                self.isAuthorized = settings.authorizationStatus == .authorized
                
                // 通知権限の状態をログに出力
                print("通知権限の状態: \(settings.authorizationStatus.rawValue)")
                print("isAuthorized: \(self.isAuthorized)")
                
                // UserServiceからデバイストークンを取得して状態を更新
                self.deviceToken = UserService.shared.getDeviceToken()
                
                // 権限状態が変更された場合の処理
                if !wasAuthorized && self.isAuthorized {
                    // 以前は許可されていなかったが、今は許可されている場合
                    print("通知権限が新たに許可されました。")
                    
                    // デバイストークンがない場合は登録
                    if self.deviceToken == nil {
                        print("リモート通知を登録します。")
                        self.registerForRemoteNotifications()
                    }
                } else if wasAuthorized && !self.isAuthorized {
                    // 以前は許可されていたが、今は許可されていない場合
                    print("通知権限が取り消されました。")
                    
                    // デバイストークンがある場合は、サーバーから登録解除
                    if let token = self.deviceToken {
                        self.unregisterDeviceTokenFromServer(token: token)
                        // デバイストークンを削除
                        UserService.shared.clearDeviceToken()
                        self.deviceToken = nil
                    }
                }
            }
        }
    }
    
    // デバイストークンをサーバーに送信
    func sendDeviceTokenToServer(token: String, username: String, encryptedPassword: String) {
        print("デバイストークンをサーバーに送信: \(token)")
        
        // APIエンドポイント
        let endpoint = "https://tama.qaq.tw/push/send"
        
        guard let url = URL(string: endpoint) else {
            print("デバイストークンの送信に失敗: 無効なURL")
            return
        }
        
        // リクエストボディの作成
        let body: [String: Any] = [
            "username": username,
            "encryptedPassword": encryptedPassword,
            "deviceToken": token
        ]
        
        // URLRequestの作成
        guard let request = APIService.shared.createRequest(url: url, method: "POST", body: body) else {
            print("デバイストークンの送信に失敗: リクエスト作成エラー")
            return
        }
        
        // APIリクエストの実行
        APIService.shared.request(
            request: request,
            logTag: "デバイストークン登録",
            replacingPercentEncoding: false
        ) { data, response, error in
            if let error = error {
                print("デバイストークンの登録に失敗しました: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("デバイストークンの登録に失敗: データなし")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool,
                   let message = json["message"] as? String {
                    
                    if status {
                        print("デバイストークンの登録に成功しました: \(message)")
                    } else {
                        print("デバイストークンの登録に失敗しました: \(message)")
                    }
                }
            } catch {
                print("デバイストークンの登録レスポンス解析に失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // デバイストークンをサーバーから登録解除
    func unregisterDeviceTokenFromServer(token: String) {
        print("デバイストークンをサーバーから登録解除: \(token)")
        
        // APIエンドポイント
        let endpoint = "https://tama.qaq.tw/push/unregister"
        
        guard let url = URL(string: endpoint) else {
            print("デバイストークンの登録解除に失敗: 無効なURL")
            return
        }
        
        // リクエストボディの作成
        let body: [String: Any] = [
            "deviceToken": token
        ]
        
        // URLRequestの作成
        guard let request = APIService.shared.createRequest(url: url, method: "POST", body: body) else {
            print("デバイストークンの登録解除に失敗: リクエスト作成エラー")
            return
        }
        
        // APIリクエストの実行
        APIService.shared.request(
            request: request,
            logTag: "デバイストークン登録解除",
            replacingPercentEncoding: false
        ) { data, response, error in
            if let error = error {
                print("デバイストークンの登録解除に失敗しました: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("デバイストークンの登録解除に失敗: データなし")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool,
                   let message = json["message"] as? String {
                    
                    if status {
                        print("デバイストークンの登録解除に成功しました: \(message)")
                    } else {
                        print("デバイストークンの登録解除に失敗しました: \(message)")
                    }
                }
            } catch {
                print("デバイストークンの登録解除レスポンス解析に失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // アプリがフォアグラウンドに戻ったときに呼び出す
    func applicationWillEnterForeground() {
        checkAuthorizationStatus()
        
        // トークンの有効期限をチェックし、必要に応じて再取得
        checkAndRefreshDeviceToken()
        
        // 最後に確認したトークンでサーバーと同期
        syncNotificationStatusWithServer()
    }
    
    // 通知登録状態を確認するヘルパーメソッド
    var isRegistered: Bool {
        return isAuthorized && deviceToken != nil
    }
    
    // 通知状態をサーバーと同期する
    func syncNotificationStatusWithServer() {
        print("通知状態をサーバーと同期します")
        
        // 現在の通知権限とデバイストークンを確認
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                
                // 最新のデバイストークンを取得
                let token = UserService.shared.getDeviceToken()
                self.deviceToken = token
                
                // トークンの有効期限をチェック
                let needsTokenRefresh = self.shouldRefreshDeviceToken()
                
                // 通知が有効で、デバイストークンがある場合
                if self.isAuthorized, let token = token {
                    // トークンの有効期限が切れていなければサーバーに送信
                    if !needsTokenRefresh {
                        // ユーザー情報を取得
                        if let currentUser = UserService.shared.getCurrentUser() {
                            // サーバーに最新のデバイストークンと通知設定を送信
                            self.sendDeviceTokenToServer(
                                token: token,
                                username: currentUser.username,
                                encryptedPassword: currentUser.encryptedPassword ?? ""
                            )
                        }
                    } else {
                        // トークンの有効期限が切れている場合は再登録
                        print("デバイストークンの有効期限が切れているため、再登録します")
                        self.registerForRemoteNotifications()
                    }
                }
                // 通知が無効だがデバイストークンがある場合は登録解除
                else if !self.isAuthorized, let token = self.deviceToken {
                    self.unregisterDeviceTokenFromServer(token: token)
                    // デバイストークンを削除
                    UserService.shared.clearDeviceToken()
                    self.deviceToken = nil
                    // 保存されたトークン更新日時をクリア
                    UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
                    self.lastTokenRefreshDate = nil
                }
            }
        }
    }
    
    // デバイストークンの有効期限をチェックし、必要に応じて再取得する
    func checkAndRefreshDeviceToken() {
        // 通知が許可されているか確認
        if !isAuthorized {
            return
        }
        
        let shouldRefreshToken = shouldRefreshDeviceToken()
        if shouldRefreshToken {
            print("デバイストークンの更新期間が経過したため、リモート通知を再登録します")
            registerForRemoteNotifications()
        }
    }
    
    // デバイストークンを更新すべきかどうかを判断
    private func shouldRefreshDeviceToken() -> Bool {
        // デバイストークンがない場合は更新が必要
        guard deviceToken != nil else {
            return true
        }
        
        // 前回の更新日時がない場合も更新が必要
        guard let lastRefreshDate = lastTokenRefreshDate else {
            return true
        }
        
        // 更新間隔が経過したかどうかを確認
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshDate)
        return timeSinceLastRefresh > tokenRefreshInterval
    }
    
    // デバイストークンの有効性チェック
    private func isValidDeviceToken(_ token: String) -> Bool {
        // 基本的な形式チェック (64文字の16進数)
        let hexPattern = "^[0-9a-f]{64}$"
        let regex = try? NSRegularExpression(pattern: hexPattern, options: .caseInsensitive)
        guard let regex = regex,
              regex.firstMatch(in: token, options: [], range: NSRange(location: 0, length: token.count)) != nil else {
            print("デバイストークンの形式が無効です: \(token)")
            return false
        }
        
        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    // フォアグラウンドでの通知表示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // 通知タップ時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // 通知のペイロードに基づいて適切な画面に遷移するなどの処理を実装
        print("通知がタップされました: \(userInfo)")
        
        // "toPage"キーがある場合、それに基づいて画面遷移
        if let toPage = userInfo["toPage"] as? String {
            print("通知から画面遷移: \(toPage)")
            navigateToPage(toPage)
        }
        
        completionHandler()
    }
    
    // 通知タップ時の画面遷移処理
    private func navigateToPage(_ page: String) {
        // NotificationCenterを使用して画面遷移を通知
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToPageFromNotification"),
            object: nil,
            userInfo: ["page": page]
        )
    }
}

// MARK: - AppDelegate拡張用メソッド
extension NotificationService {
    // デバイストークン取得成功時
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("デバイストークン取得成功: \(deviceToken)")
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token
        print("デバイストークン: \(token)")
        
        // 現在の日時を最後のトークン更新日時として保存
        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastTokenRefreshDate")
        self.lastTokenRefreshDate = now
        
        // UserServiceにデバイストークンを保存
        UserService.shared.saveDeviceToken(token)

        // ユーザー情報を取得
        let currentUser = UserService.shared.getCurrentUser() ?? nil
        
        // サーバーにデバイストークンを送信
        sendDeviceTokenToServer(
            token: token, 
            username: currentUser?.username ?? "",
            encryptedPassword: currentUser?.encryptedPassword ?? ""
        )
    }
    
    // デバイストークン取得失敗時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("リモート通知の登録に失敗しました: \(error.localizedDescription)")
        self.deviceToken = nil
        
        // 失敗した場合、UserServiceからデバイストークンを削除
        UserService.shared.clearDeviceToken()
        
        // 保存されたトークン更新日時をクリア
        UserDefaults.standard.removeObject(forKey: "lastTokenRefreshDate")
        self.lastTokenRefreshDate = nil
    }
    
    // リモート通知受信時
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("バックグラウンドで通知を受信しました: \(userInfo)")
        
        // 通知タイプを確認
        if let updateType = userInfo["updateType"] as? String {
            // 部屋変更通知の処理
            if updateType == "roomChange" {
                handleRoomChangeNotification(userInfo: userInfo)
                completionHandler(.newData)
                return
            }
            
            // 課題数変更通知の処理
            if updateType == "kaidaiNumChange" {
                handleAssignmentCountChangeNotification(userInfo: userInfo)
                completionHandler(.newData)
                return
            }
        }
        
        // その他の通知処理
        completionHandler(.newData)
    }
    
    // 部屋変更通知を処理するメソッド
    private func handleRoomChangeNotification(userInfo: [AnyHashable: Any]) {
        print("部屋変更通知を処理します")
        
        guard let courseName = userInfo["name"] as? String,
              let newRoom = userInfo["room"] as? String else {
            print("部屋変更通知の処理に失敗: 必要な情報がありません")
            return
        }
        
        print("部屋変更: \(courseName) → \(newRoom)")
        
        // TimetableServiceの部屋変更処理を呼び出す
        TimetableService.shared.handleRoomChange(courseName: courseName, newRoom: newRoom)
        
        // ローカル通知で部屋変更を知らせる
        sendRoomChangeLocalNotification(courseName: courseName, newRoom: newRoom)
    }
    
    // 課題数変更通知を処理するメソッド
    private func handleAssignmentCountChangeNotification(userInfo: [AnyHashable: Any]) {
        print("課題数変更通知を処理します")
        
        // AssignmentServiceに処理を委譲
        AssignmentService.shared.handleAssignmentCountChangeNotification(userInfo: userInfo)
    }
    
    // 部屋変更をユーザーに通知するローカル通知
    private func sendRoomChangeLocalNotification(courseName: String, newRoom: String) {
        let content = UNMutableNotificationContent()
        content.title = "教室変更のお知らせ"
        content.body = "「\(courseName)」の教室が\(newRoom)に変更されました。"
        content.sound = .default
        
        // 通知を即時に表示
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("部屋変更通知の送信に失敗: \(error.localizedDescription)")
            }
        }
    }
} 